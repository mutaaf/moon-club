import SwiftUI
import MetalKit
import MoonClubCore

// GPU celebrations (0.14): confetti, fireworks, cannons and sparkles as instanced quads in one MTKView.
// The CPU writes each particle's launch values ONCE per burst (a few hundred structs); after that every
// frame is a single draw call whose positions come from the vertex shader (`particleVertex` in
// Shaders.metal) as a pure function of time. The view is hidden and paused whenever no burst is playing,
// so an idle party overlay costs nothing. Falls back to the Canvas path if Metal isn't available.

/// Mirrors `Particle` in Shaders.metal (16-byte aligned float2/float4 layout).
struct GPUParticle {
  var origin: SIMD2<Float>
  var vel: SIMD2<Float>
  var color: SIMD4<Float>
  var delay: Float
  var life: Float
  var size: Float
  var spin: Float
  var gravity: Float
  var shape: Float
  var sway: Float
  var drag: Float
}
private struct ParticleUniforms { var viewSize: SIMD2<Float>; var t: Float; var pad: Float = 0 }

/// The device, queue and pipeline, built once (off the main thread by `ShaderWarmup`).
final class ParticleRenderer: @unchecked Sendable {
  static let lock = NSLock()
  nonisolated(unsafe) private static var _shared: ParticleRenderer?
  let device: MTLDevice
  let queue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState

  /// nil when Metal isn't available (the caller falls back to Canvas).
  static var shared: ParticleRenderer? { prepareShared(); return lock.withLock { _shared } }
  static func prepareShared() {
    lock.withLock {
      guard _shared == nil, let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue(),
            let lib = d.makeDefaultLibrary(), let vf = lib.makeFunction(name: "particleVertex"),
            let ff = lib.makeFunction(name: "particleFragment") else { return }
      let desc = MTLRenderPipelineDescriptor()
      desc.vertexFunction = vf; desc.fragmentFunction = ff
      let att = desc.colorAttachments[0]!
      att.pixelFormat = .bgra8Unorm
      att.isBlendingEnabled = true
      att.rgbBlendOperation = .add; att.alphaBlendOperation = .add
      att.sourceRGBBlendFactor = .one; att.sourceAlphaBlendFactor = .one          // premultiplied
      att.destinationRGBBlendFactor = .oneMinusSourceAlpha; att.destinationAlphaBlendFactor = .oneMinusSourceAlpha
      guard let p = try? d.makeRenderPipelineState(descriptor: desc) else { return }
      _shared = ParticleRenderer(device: d, queue: q, pipeline: p)
    }
  }
  private init(device: MTLDevice, queue: MTLCommandQueue, pipeline: MTLRenderPipelineState) {
    self.device = device; self.queue = queue; self.pipeline = pipeline
  }
}

/// The shows, as particle lists. Pure functions of (size, seed), so a burst always looks the same for
/// its trigger. Counts are generous for the GPU but capped.
enum ParticleShow {
  static let brand: [SIMD4<Float>] = [0xF0C64A, 0xEC6461, 0x7E62EE, 0x3F82EE, 0x3DB97F, 0xF2BE2E, 0xF7A8B8].map { hex in
    SIMD4(Float((hex >> 16) & 0xFF) / 255, Float((hex >> 8) & 0xFF) / 255, Float(hex & 0xFF) / 255, 1)
  }
  private struct LCG { var s: UInt64; mutating func next() -> Float { s = s &* 6364136223846793005 &+ 1442695040888963407; return Float(s >> 40) / Float(1 << 24) } }

  static func make(_ tier: CelebrationTier, size: CGSize, crossFold: Bool, seed: UInt64) -> [GPUParticle] {
    var r = LCG(s: seed | 1)
    let w = Float(size.width), h = Float(size.height)
    var out: [GPUParticle] = []
    func burst(_ c: SIMD2<Float>, count: Int, speed: Float, delay: Float = 0, life: Float = 1.6, stars: Bool = false) {
      for i in 0..<count {
        let a = Float(i) / Float(count) * 2 * .pi + (r.next() - 0.5) * 0.4
        let v = speed * (0.45 + r.next() * 0.55)
        out.append(GPUParticle(origin: c, vel: SIMD2(cos(a) * v, sin(a) * v), color: brand[i % brand.count], delay: delay, life: life,
                               size: 7 + r.next() * 8, spin: (r.next() - 0.5) * 12, gravity: 420, shape: stars || i % 3 == 0 ? 1 : 0, sway: 0, drag: 0.6))
      }
    }
    func shower(count: Int, delay: Float) {
      for i in 0..<count {
        out.append(GPUParticle(origin: SIMD2(r.next() * w, -20), vel: SIMD2(0, 180 + r.next() * 260), color: brand[i % brand.count],
                               delay: delay + r.next() * 0.6, life: 2.6, size: 9 + r.next() * 6, spin: r.next() * 8 - 4, gravity: 20,
                               shape: i % 7 == 0 ? 1 : 0, sway: 24, drag: 0))
      }
    }
    func cannons(count: Int) {
      for side in [Float(0), 1] {
        for i in 0..<count / 2 {
          let a = (side == 0 ? -1.15 : -.pi + 1.15) + (r.next() - 0.5) * 0.6
          let v = h * (0.9 + r.next() * 0.6)
          out.append(GPUParticle(origin: SIMD2(side * w, h), vel: SIMD2(cos(a) * v, sin(a) * v), color: brand[(i + Int(side)) % brand.count],
                                 delay: r.next() * 0.15, life: 2.6, size: 10 + r.next() * 7, spin: r.next() * 14 - 7, gravity: 900,
                                 shape: i % 4 == 0 ? 1 : 0, sway: 6, drag: 0.25))
        }
      }
    }
    func fireworks(shells: Int) {
      for s in 0..<shells {
        let delay = Float(s) * 0.32 + r.next() * 0.1
        let fromLeft = s % 2 == 0
        let x0 = crossFold ? w * (fromLeft ? 0.2 : 0.8) : w * (0.2 + r.next() * 0.6)
        let x1 = crossFold ? w * (fromLeft ? 0.72 : 0.28) + (r.next() - 0.5) * 60 : x0 + (r.next() - 0.5) * 80
        let peak = SIMD2(x1, h * (0.18 + r.next() * 0.22))
        let rise: Float = 0.55
        let color = brand[(s * 2) % brand.count]
        // The rising shell and its trail: sparks launched so they arrive at the peak at `rise`.
        for k in 0..<6 {
          let lag = Float(k) * 0.03
          let g: Float = 300
          let vy = (peak.y - h - 0.5 * g * rise * rise) / rise
          out.append(GPUParticle(origin: SIMD2(x0, h), vel: SIMD2((peak.x - x0) / rise, vy), color: k == 0 ? SIMD4(1, 1, 1, 1) : color,
                                 delay: delay + lag, life: rise, size: k == 0 ? 10 : 7 - Float(k), spin: 0, gravity: g, shape: 2, sway: 0, drag: 0))
        }
        // The burst: two rings of glowing sparks plus a few stars.
        for i in 0..<48 {
          let a = Float(i) / 48 * 2 * .pi
          let v: Float = 170 + Float(i % 3) * 45 + r.next() * 20
          out.append(GPUParticle(origin: peak, vel: SIMD2(cos(a) * v, sin(a) * v), color: i % 2 == 0 ? color : SIMD4(1, 0.97, 0.88, 1),
                                 delay: delay + rise, life: 1.4, size: 9, spin: 0, gravity: 110, shape: i % 8 == 0 ? 1 : 2, sway: 0, drag: 0.8))
        }
      }
    }
    switch tier {
    case .small: burst(SIMD2(w / 2, h * 0.42), count: 24, speed: 240, life: 0.9, stars: true)
    case .medium:
      burst(SIMD2(w / 2, h * 0.42), count: 64, speed: 440)
      shower(count: 110, delay: 0)
    case .large:
      cannons(count: 90)
      fireworks(shells: 6)
      shower(count: 140, delay: 0.5)
    }
    return out
  }
}

/// The MTKView host. Shown and running only while a burst plays.
struct GPUParticles: UIViewRepresentable {
  let trigger: Int
  let tier: CelebrationTier
  var crossFold = false
  let duration: Double

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> MTKView {
    let v = MTKView(frame: .zero, device: ParticleRenderer.shared?.device)
    v.isOpaque = false
    v.backgroundColor = .clear
    v.layer.isOpaque = false
    v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    v.colorPixelFormat = .bgra8Unorm
    v.framebufferOnly = true
    v.isPaused = true
    v.enableSetNeedsDisplay = false
    v.isHidden = true
    v.isUserInteractionEnabled = false
    v.preferredFramesPerSecond = 120     // ProMotion where available; the system caps it elsewhere
    v.delegate = context.coordinator
    context.coordinator.view = v
    context.coordinator.last = trigger
    return v
  }
  func updateUIView(_ v: MTKView, context: Context) {
    let c = context.coordinator
    guard trigger != c.last else { return }
    c.last = trigger
    c.launch(tier: tier, crossFold: crossFold, duration: duration, seed: UInt64(truncatingIfNeeded: trigger &* 2654435761))
  }

  @MainActor final class Coordinator: NSObject, MTKViewDelegate {
    weak var view: MTKView?
    var last = 0
    private var buffer: MTLBuffer?
    private var count = 0
    private var start: CFTimeInterval = 0
    private var duration: Double = 0

    func launch(tier: CelebrationTier, crossFold: Bool, duration: Double, seed: UInt64) {
      guard let v = view, let r = ParticleRenderer.shared else { return }
      let size = v.bounds.size
      guard size.width > 0 else { return }
      var ps = ParticleShow.make(tier, size: size, crossFold: crossFold, seed: seed)
      count = ps.count
      buffer = r.device.makeBuffer(bytes: &ps, length: MemoryLayout<GPUParticle>.stride * max(1, ps.count), options: .storageModeShared)
      start = CACurrentMediaTime()
      self.duration = duration
      v.isHidden = false
      v.isPaused = false
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    nonisolated func draw(in view: MTKView) {
      MainActor.assumeIsolated { render(view) }
    }
    private func render(_ view: MTKView) {
      guard let r = ParticleRenderer.shared, let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
            let cb = r.queue.makeCommandBuffer(), let enc = cb.makeRenderCommandEncoder(descriptor: pass) else { return }
      let t = CACurrentMediaTime() - start
      if let buffer, count > 0, t <= duration {
        var u = ParticleUniforms(viewSize: SIMD2(Float(view.bounds.width), Float(view.bounds.height)), t: Float(t))
        enc.setRenderPipelineState(r.pipeline)
        enc.setVertexBuffer(buffer, offset: 0, index: 0)
        enc.setVertexBytes(&u, length: MemoryLayout<ParticleUniforms>.stride, index: 1)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
        FrameProbe.shared.tick()
      }
      enc.endEncoding()
      cb.present(drawable)
      cb.commit()
      if t > duration {
        // Done: one cleared frame went out above; now hide and stop the display link.
        view.isPaused = true
        view.isHidden = true
        buffer = nil
      }
    }
  }
}
