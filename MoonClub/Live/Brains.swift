import Foundation
import MoonClubCore
#if canImport(FoundationModels)
import FoundationModels
#endif

// Live Luna brains (see MoonClubCore/Brain.swift for the rules they all share):
//   FreeBrain     — the Metaphases free kid-safe brain, no key, answers cached on disk
//   OnDeviceBrain — Apple Intelligence via FoundationModels; nothing leaves the device
//   ByokBrain     — a grown-up's own key, straight to the provider, only after consent for that provider

private let session: URLSession = {
  let c = URLSessionConfiguration.default
  c.timeoutIntervalForRequest = 30
  c.urlCache = nil
  c.httpAdditionalHeaders = ["user-agent": "MoonClub-iOS/1"]
  return URLSession(configuration: c)
}()
private func cacheDir(_ name: String) -> URL {
  FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonClub/\(name)")
}

// MARK: Settings (UserDefaults) — the key itself only ever lives in the Keychain.
enum BrainStore {
  static let key = "moonclub.brain.v1"
  static func load() -> BrainSettings { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(BrainSettings.self, from: $0) } ?? BrainSettings() }
  static func save(_ s: BrainSettings) { UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: key) }
  static var lunaKey: String? { Keychain.get(service: Keychain.lunaService) }
  /// What answers right now (read on every question, so a change in the grown-up corner applies at once).
  static func resolve() -> BrainKind {
    let s = load()
    return BrainRouter.resolve(s, onDevice: OnDevice.status(), hasKey: !(lunaKey ?? "").isEmpty)
  }
}

enum OnDevice {
  static func status() -> OnDeviceStatus {
    #if canImport(FoundationModels)
    if #available(iOS 26, *) {
      switch SystemLanguageModel.default.availability {
      case .available: return .available
      case .unavailable(.deviceNotEligible): return .notEligible
      case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
      case .unavailable(.modelNotReady): return .downloading
      case .unavailable: return .notEligible
      }
    }
    #endif
    return .unsupportedOS
  }
}

// MARK: Free — the old LiveLuna, now one brain among three (single-turn, cached 7 days).
final class FreeBrain: LunaBrain, @unchecked Sendable {
  let kind = BrainKind.free
  private let disk = DiskLRU(dir: cacheDir("luna"), capacity: 1 << 20)
  private let version: String
  init(contentVersion: String) { version = contentVersion }

  func stream(_ p: LunaPrompt) -> AsyncThrowingStream<String, Error> {
    let key = lunaCacheKey(p.question, contentVersion: version)
    return AsyncThrowingStream { cont in
      let task = Task {
        if let (d, age) = disk.get(key), age < CachePolicy.luna.ttl, let s = String(data: d, encoding: .utf8) {
          for word in s.split(separator: " ", omittingEmptySubsequences: false) { cont.yield(word + " "); try? await Task.sleep(for: .milliseconds(18)) }
          cont.finish(); return
        }
        do {
          let (bytes, resp) = try await session.bytes(for: Requests.luna(question: p.question, context: p.context))
          guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { throw KidError.resting }
          var full = ""
          for try await line in bytes.lines where line.hasPrefix("data:") {
            for e in SSE.parse(line + "\n\n").0 {
              switch e {
              case let .text(t): full += t; cont.yield(t)
              case .error: throw KidError.resting
              case .done: break
              }
            }
          }
          if !full.isEmpty && !LunaGuard.isBlocked(full) { disk.set(key, Data(full.utf8)) }
          cont.finish()
        } catch { cont.finish(throwing: (error as? KidError) ?? .resting) }
      }
      cont.onTermination = { _ in task.cancel() }
    }
  }
}

// MARK: Apple Intelligence — on this device, nothing sent anywhere.
final class OnDeviceBrain: LunaBrain, @unchecked Sendable {
  let kind = BrainKind.onDevice
  func stream(_ p: LunaPrompt) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { cont in
      #if canImport(FoundationModels)
      if #available(iOS 26, *) {
        let task = Task {
          do {
            let s = LanguageModelSession(instructions: p.system)
            var text = p.user
            if !p.history.isEmpty {
              text = "Earlier in this chat:\n" + p.history.map { ($0.role == .kid ? "Kid: " : "Luna: ") + $0.text }.joined(separator: "\n") + "\n\n" + text
            }
            var sent = ""
            for try await snap in s.streamResponse(to: text, options: GenerationOptions(temperature: 0.5, maximumResponseTokens: p.caps.maxTokens)) {
              let now = snap.content
              if now.hasPrefix(sent) { cont.yield(String(now.dropFirst(sent.count))) } else { cont.yield(now) }
              sent = now
            }
            cont.finish()
          } catch let e as LanguageModelSession.GenerationError {
            if case .guardrailViolation = e { cont.yield(LunaGuard.redirect); cont.finish() } else { cont.finish(throwing: KidError.resting) }
          } catch { cont.finish(throwing: KidError.resting) }
        }
        cont.onTermination = { _ in task.cancel() }
        return
      }
      #endif
      cont.finish(throwing: KidError.resting)
    }
  }
}

// MARK: Your own key — straight to the provider; never through our server.
final class ByokBrain: LunaBrain, @unchecked Sendable {
  let kind = BrainKind.byok
  func stream(_ p: LunaPrompt) -> AsyncThrowingStream<String, Error> {
    let s = BrainStore.load()
    // Requests.byok returns nil without consent for this provider: the second lock after the router.
    guard let key = BrainStore.lunaKey,
          let req = Requests.byok(s.provider, key: key, model: s.model ?? s.provider.fallbackModel, prompt: p, consent: s.consentFor)
    else { return AsyncThrowingStream { $0.finish(throwing: KidError.resting) } }
    return AsyncThrowingStream { cont in
      let task = Task {
        do {
          let (bytes, resp) = try await session.bytes(for: req)
          guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { throw KidError.resting }
          for try await line in bytes.lines where line.hasPrefix("data:") {
            let d = SSE.delta(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            if !d.isEmpty { cont.yield(d) }
          }
          cont.finish()
        } catch { cont.finish(throwing: (error as? KidError) ?? .resting) }
      }
      cont.onTermination = { _ in task.cancel() }
    }
  }

  /// The grown-up's one-tap check: list models with the key (no kid text), pick a sensible one.
  static func check(_ p: KeyProvider, key: String) async -> Result<String, KidError> {
    do {
      let (d, r) = try await session.data(for: Requests.models(p, key: key))
      let status = (r as? HTTPURLResponse)?.statusCode ?? 500
      guard status < 400 else { return .failure(KidError(SSE.keyProblem(status, p))) }
      return .success(p.pickModel(Requests.modelIds(d)))
    } catch { return .failure(KidError("Couldn't reach \(p.label). Check the internet connection and try again.")) }
  }
}
