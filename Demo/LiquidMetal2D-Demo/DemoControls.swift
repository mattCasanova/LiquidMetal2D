//
//  DemoControls.swift
//  LiquidMetal2D-Demo
//
//  SwiftUI pieces the scene panels share, so every scene's controls look the same.
//

import SwiftUI

/// The demo's button: dark rounded background, bold blue title.
struct DemoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(TokyoNight.color(TokyoNight.blue))
            .padding(.horizontal, 16)
            .frame(minWidth: 100, minHeight: 44)
            .background(TokyoNight.color(TokyoNight.darker), in: RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == DemoButtonStyle {
    static var demo: DemoButtonStyle { DemoButtonStyle() }
}

/// A row of buttons along the bottom edge of the window, centred.
struct BottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) { content }
                .buttonStyle(.demo)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A live readout (frame counts, angles) in monospaced digits.
struct ReadoutText: View {
    let text: String
    var size: CGFloat = 16

    init(_ text: String, size: CGFloat = 16) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundStyle(TokyoNight.color(TokyoNight.fg))
            .multilineTextAlignment(.center)
    }
}

/// One tunable: a slider over a range, with the value in its label.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var format: String = "%.1f"

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "\(title): \(format)", value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(TokyoNight.color(TokyoNight.fg))
            Slider(value: $value, in: range)
                .tint(TokyoNight.color(TokyoNight.blue))
        }
    }
}

/// A column of controls docked to the right edge; scrolls when the window is short.
struct ControlColumn<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(width: 200)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 48)
    }
}
