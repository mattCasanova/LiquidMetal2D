//
//  EasingType.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// A named, `Codable` choice of ``Easing`` curve, so animation files can say
/// which curve a keyframe segment uses.
public enum EasingType: String, Codable, CaseIterable, Sendable {
    case linear
    case easeInQuad, easeOutQuad, easeInOutQuad
    case easeInCubic, easeOutCubic, easeInOutCubic
    case easeInQuart, easeOutQuart, easeInOutQuart
    case easeInSine, easeOutSine, easeInOutSine
    case easeInExpo, easeOutExpo, easeInOutExpo
    case easeInElastic, easeOutElastic, easeInOutElastic
    case easeInBounce, easeOutBounce, easeInOutBounce
    case easeInBack, easeOutBack, easeInOutBack

    /// Maps `t` in 0–1 through this curve.
    ///
    /// One case per curve, and no `default`, so adding a case without a curve fails to compile.
    public func apply(_ t: Float) -> Float { // swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .linear: return t
        case .easeInQuad: return Easing.easeInQuad(t)
        case .easeOutQuad: return Easing.easeOutQuad(t)
        case .easeInOutQuad: return Easing.easeInOutQuad(t)
        case .easeInCubic: return Easing.easeInCubic(t)
        case .easeOutCubic: return Easing.easeOutCubic(t)
        case .easeInOutCubic: return Easing.easeInOutCubic(t)
        case .easeInQuart: return Easing.easeInQuart(t)
        case .easeOutQuart: return Easing.easeOutQuart(t)
        case .easeInOutQuart: return Easing.easeInOutQuart(t)
        case .easeInSine: return Easing.easeInSine(t)
        case .easeOutSine: return Easing.easeOutSine(t)
        case .easeInOutSine: return Easing.easeInOutSine(t)
        case .easeInExpo: return Easing.easeInExpo(t)
        case .easeOutExpo: return Easing.easeOutExpo(t)
        case .easeInOutExpo: return Easing.easeInOutExpo(t)
        case .easeInElastic: return Easing.easeInElastic(t)
        case .easeOutElastic: return Easing.easeOutElastic(t)
        case .easeInOutElastic: return Easing.easeInOutElastic(t)
        case .easeInBounce: return Easing.easeInBounce(t)
        case .easeOutBounce: return Easing.easeOutBounce(t)
        case .easeInOutBounce: return Easing.easeInOutBounce(t)
        case .easeInBack: return Easing.easeInBack(t)
        case .easeOutBack: return Easing.easeOutBack(t)
        case .easeInOutBack: return Easing.easeInOutBack(t)
        }
    }
}
