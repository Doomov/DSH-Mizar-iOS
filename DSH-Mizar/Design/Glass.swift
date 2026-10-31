//
//  Glass.swift
//  DSH-Mizar
//
//  Liquid Glass and compatibility shims for iOS 18 / Xcode 16.
//

import SwiftUI

struct GlassShim {
    func tint(_ color: Color?) -> Self { self }
    func interactive(_ val: Bool = true) -> Self { self }
    static var regular: GlassShim { GlassShim() }
}

typealias Glass = GlassShim

enum ScrollEdgeEffectOption {
    case soft
}

extension View {
    /// A capsule of glass.
    func liquidCapsule(interactive: Bool = false) -> some View {
        liquidSurface(in: Capsule(), interactive: interactive)
    }

    /// Glass in any shape, or nothing at all.
    @ViewBuilder
    func liquidSurface<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        when condition: Bool = true,
    ) -> some View {
        if condition {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
        }
    }

    /// A continuous rounded rectangle of glass.
    func liquidCard(radius: CGFloat = Theme.Radius.card, tint: Color? = nil) -> some View {
        liquidSurface(in: RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint)
    }

    func glassEffect(_ effect: Any? = nil, in shape: some Shape) -> some View {
        self.background(.ultraThinMaterial, in: shape)
    }

    func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectOption = .soft, for axis: Axis.Set = .vertical) -> some View {
        self
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

/// Groups neighbouring glass so it blends instead of meeting in a seam.
struct GlassEffectContainer<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
    }
}

struct GlassRow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}

/// A round control on glass: the sidebar toggle, refresh, jump-to-latest.
struct GlassCircleLabel<Content: View>: View {
    var size: CGFloat = 40
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(.circle)
            .liquidSurface(in: Circle(), interactive: true)
    }
}
