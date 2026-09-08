import AppKit
import SwiftUI

enum Theme {
    /// Window and grid fill. `#18191C`
    static let canvas = Color(red: 24 / 255, green: 25 / 255, blue: 28 / 255)
    /// Selection ring and primary actions.
    static let accent = Color.white
    /// Text on primary buttons.
    static let onAccent = Color.black
    /// Chips and secondary buttons. `#2B2C2F`
    static let surface = Color(red: 43 / 255, green: 44 / 255, blue: 47 / 255)

    static let canvasNS = NSColor(srgbRed: 24 / 255, green: 25 / 255, blue: 28 / 255, alpha: 1)
}
