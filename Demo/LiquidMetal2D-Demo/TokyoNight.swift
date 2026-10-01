//
//  TokyoNight.swift
//  LiquidMetal2D-Demo
//
//  Tokyo Night color palette for consistent theming across all demo scenes.
//

import UIKit
import LiquidMetal2D

enum TokyoNight {
    // Accent colors
    static let red       = Vec4(0.969, 0.463, 0.557, 1.0)  // #f7768e
    static let orange    = Vec4(1.000, 0.620, 0.392, 1.0)  // #ff9e64
    static let yellow    = Vec4(0.878, 0.686, 0.408, 1.0)  // #e0af68
    static let beige     = Vec4(0.812, 0.788, 0.761, 1.0)  // #cfc9c2
    static let green     = Vec4(0.620, 0.808, 0.416, 1.0)  // #9ece6a
    static let teal      = Vec4(0.451, 0.855, 0.792, 1.0)  // #73daca
    static let lightCyan = Vec4(0.706, 0.976, 0.973, 1.0)  // #b4f9f8
    static let cyan      = Vec4(0.165, 0.765, 0.871, 1.0)  // #2ac3de
    static let sky       = Vec4(0.490, 0.812, 1.000, 1.0)  // #7dcfff
    static let blue      = Vec4(0.478, 0.635, 0.969, 1.0)  // #7aa2f7
    static let purple    = Vec4(0.733, 0.604, 0.969, 1.0)  // #bb9af7

    // Foreground / text
    static let fg        = Vec4(0.753, 0.792, 0.961, 1.0)  // #c0caf5
    static let fgDark    = Vec4(0.663, 0.694, 0.839, 1.0)  // #a9b1d6
    static let comment   = Vec4(0.604, 0.647, 0.808, 1.0)  // #9aa5ce

    // Background
    static let dark      = Vec4(0.337, 0.373, 0.537, 1.0)  // #565f89
    static let darker    = Vec4(0.255, 0.282, 0.408, 1.0)  // #414868
    static let bg        = Vec4(0.102, 0.106, 0.149, 1.0)  // #1a1b26

    // UIKit colors
    static let uiFg      = UIColor(red: 0.753, green: 0.792, blue: 0.961, alpha: 1.0)
    static let uiFgDark  = UIColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1.0)
    static let uiComment = UIColor(red: 0.604, green: 0.647, blue: 0.808, alpha: 1.0)
    static let uiBlue    = UIColor(red: 0.478, green: 0.635, blue: 0.969, alpha: 1.0)
    static let uiPurple  = UIColor(red: 0.733, green: 0.604, blue: 0.969, alpha: 1.0)
    static let uiDarker  = UIColor(red: 0.255, green: 0.282, blue: 0.408, alpha: 1.0)
    static let uiBg      = UIColor(red: 0.102, green: 0.106, blue: 0.149, alpha: 1.0)

    // Metal clear color (Vec3 for renderer.setClearColor)
    static let clearColor = Vec3(0.102, 0.106, 0.149)  // #1a1b26

    // Ship tint colors — matched to texture load order [blue, green, orange]
    static let shipTints: [Vec4] = [blue, teal, red]

    /// Returns the Tokyo Night tint for a texture loaded in standard order
    /// (blue=0, green=1, orange=2). Falls back to white if index is out of range.
    static func tintForShip(index: Int) -> Vec4 {
        return index < shipTints.count ? shipTints[index] : Vec4(1, 1, 1, 1)
    }

    // All bright accent colors for random tinting
    static let accents: [Vec4] = [red, orange, yellow, green, teal, cyan, sky, blue, purple]
}
