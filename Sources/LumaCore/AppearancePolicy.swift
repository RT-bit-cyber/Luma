import Foundation

public enum Appearance: String { case light, dark }

/// A continuous threshold crossing is required. A neutral or missing sample
/// cancels the pending change; long gaps must never count as stable light.
public struct AppearancePolicy {
    public var darkThreshold: Double
    public var lightThreshold: Double
    public var delay: TimeInterval
    public private(set) var pending: Appearance?
    private var pendingSince: TimeInterval?
    private var lastSample: TimeInterval?

    public init(darkThreshold: Double = 40, lightThreshold: Double = 80, delay: TimeInterval = 10) {
        self.darkThreshold = darkThreshold
        self.lightThreshold = lightThreshold
        self.delay = delay
    }

    public mutating func reset() {
        pending = nil
        pendingSince = nil
        lastSample = nil
    }

    public mutating func update(lux: Double?, current: Appearance, now: TimeInterval) -> Appearance? {
        guard let lux, lux.isFinite, lux >= 0,
              darkThreshold.isFinite, lightThreshold.isFinite, delay.isFinite,
              darkThreshold >= 0, lightThreshold > darkThreshold, delay >= 0 else {
            reset(); return nil
        }
        if let lastSample, now < lastSample || now - lastSample > 5 { reset() }
        lastSample = now
        let target: Appearance?
        if lux < darkThreshold { target = .dark }
        else if lux > lightThreshold { target = .light }
        else { target = nil }
        guard let target, target != current else {
            pending = nil; pendingSince = nil; return nil
        }
        if pending != target { pending = target; pendingSince = now }
        guard let since = pendingSince, now - since >= delay else { return nil }
        reset()
        return target
    }
}
