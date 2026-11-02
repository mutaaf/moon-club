// "Move my progress": a one-way code from the Metaphases Kids website into the app (web → app).
// The grown-up copies it from the website's grown-ups corner and pastes it into the app's grown-ups
// corner; the app merges it with `merged(with:)`, so pasting twice, or pasting an older code, is harmless.
// No server, no account, no camera: just text a grown-up moves by hand.
//
// Format (mirrors metaphases shared/kidsTransfer.ts; test vectors come from `npm run export:kids`):
//   MOONP1-<base64url of compact JSON>-<4-character Crockford checksum>
// The JSON holds only progress: lesson ids and dates, quest stages, badges, guesses (company, day, pick),
// the pretend piggy bank, and Family League codes. Never a name or anything a child typed.
import Foundation

public enum Transfer {
  public static let prefix = "MOONP1-"
  static let b32 = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
  public static let maxLength = 60_000

  public enum Failure: Error, Equatable { case notACode, damaged, tooBig }

  /// FNV-1a 32-bit over the body's UTF-8, folded to 20 bits → 4 Crockford characters.
  static func checksum(_ body: String) -> String {
    var h: UInt32 = 0x811C9DC5
    for b in body.utf8 { h ^= UInt32(b); h = h &* 0x01000193 }
    let v = Int((h ^ (h >> 20)) & 0xFFFFF)
    return String([15, 10, 5, 0].map { b32[(v >> $0) & 31] })
  }

  /// Find and check a code anywhere in pasted text (messages often add words or line breaks).
  public static func decode(_ raw: String, companies: [KidCo]) -> Result<KidsState, Failure> {
    let text = raw.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
    guard text.count <= maxLength else { return .failure(.tooBig) }
    guard let r = text.range(of: prefix, options: .caseInsensitive) else { return .failure(.notACode) }
    let rest = text[r.upperBound...]
    guard let dash = rest.lastIndex(of: "-") else { return .failure(.damaged) }
    let body = String(rest[..<dash]), sum = String(rest[rest.index(after: dash)...].prefix(4)).uppercased()
    guard checksum(body) == sum else { return .failure(.damaged) }
    var b64 = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while b64.count % 4 != 0 { b64 += "=" }
    guard let data = Data(base64Encoded: b64),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], (j["v"] as? Int) == 1
    else { return .failure(.damaged) }
    return .success(state(from: j, companies: companies))
  }

  static func state(from j: [String: Any], companies: [KidCo]) -> KidsState {
    var s = KidsState()
    for x in j["l"] as? [[String]] ?? [] where !x.isEmpty {
      s.lessons.append(x[0]); if x.count > 1, !x[1].isEmpty { s.lessonDates[x[0]] = x[1] }
    }
    s.quest = j["q"] as? [String] ?? []
    s.questDone = (j["qd"] as? Int ?? 0) == 1
    s.seenBadges = j["b"] as? [String] ?? []
    s.me = j["me"] as? Int
    for code in j["lg"] as? [String] ?? [] {
      if case .success(let p) = League.decode(code, companies: companies) { s.league.append(p) }
    }
    for x in j["g"] as? [[String]] ?? [] where x.count >= 5 {
      let out: (String) -> Outcome? = { $0 == "r" ? .right : $0 == "w" ? .wrong : nil }
      s.guesses.append(Guess(s: x[0], d: x[1], pick: x[2] == "m" ? .miss : .beat, price: x[3] == "u" ? .up : x[3] == "d" ? .down : nil,
                             at: x[4], result: x.count > 5 ? out(x[5]) : nil, priceResult: x.count > 6 ? out(x[6]) : nil))
    }
    if let p = j["p"] as? [String: Any], let st = p["st"] as? String {
      let hold = (p["h"] as? [[Any]] ?? []).compactMap { h -> PiggyHolding? in
        guard h.count == 4, let sym = h[0] as? String else { return nil }
        let n = h.dropFirst().map { ($0 as? NSNumber)?.doubleValue ?? 0 }
        return PiggyHolding(s: sym, coins: n[0], shares: n[1], start: n[2])
      }
      var hist: [String: Double] = [:]
      for h in p["hi"] as? [[Any]] ?? [] where h.count == 2 { if let d = h[0] as? String, let v = (h[1] as? NSNumber)?.doubleValue { hist[d] = v } }
      s.piggy = Piggy(started: st, holdings: hold, history: hist)
    }
    return s.normalized()
  }
}
