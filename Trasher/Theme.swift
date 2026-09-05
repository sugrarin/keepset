import AppKit
import SwiftUI

enum Theme {
    /// Window and grid fill. `#18191C`
    static let canvas = Color(red: 24 / 255, green: 25 / 255, blue: 28 / 255)
    /// Selection ring and primary actions. `#5095F7`
    static let accent = Color(red: 80 / 255, green: 149 / 255, blue: 247 / 255)
    /// Chips and secondary buttons. `#2B2C2F`
    static let surface = Color(red: 43 / 255, green: 44 / 255, blue: 47 / 255)

    static let canvasNS = NSColor(srgbRed: 24 / 255, green: 25 / 255, blue: 28 / 255, alpha: 1)
}
