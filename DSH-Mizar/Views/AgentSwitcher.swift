//
//  AgentSwitcher.swift
//  DSH-Mizar
//
//  The agents one computer serves, as a small window off the sidebar's capsule.
//
//  A desktop fronts DSH, Claude Code and Codex at the same time and they share
//  nothing -- not sessions, not working directories, not tool surfaces -- so
//  "this computer's list" is really "this agent on this computer". The capsule
//  over the session list names the one on screen and opens this, which is the
//  whole of the switch: pick, and the socket is redialled with the choice.
//
//  "All agents" is offered rather than implied. It is what a phone that never
//  chose sees, and what an older host can only answer, so a list that mixes
//  three agents has to be something the operator can name -- and leave.
//

import SwiftUI
import MizarKit

struct AgentSwitcher: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Which agent this connection is for")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(model.engineChoices) { engine in
                row(title: engine.title, detail: engine.detail, engine: engine)
            }
            // Last, and set apart by its own line: it is not one of the agents,
            // it is the absence of a choice.
            Divider()
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
            row(
                title: String(localized: "All agents"),
                detail: String(localized: "Every session on this computer, mixed together"),
                engine: nil,
            )
        }
        .padding(.bottom, 6)
        .frame(width: 244)
    }

    /// One agent, ticked when it is the one on screen.
    ///
    /// - Parameters:
    ///   - title: the product's name.
    ///   - detail: one line about what it holds.
    ///   - engine: the agent, or `nil` for all of them.
    private func row(title: String, detail: String, engine: AgentEngine?) -> some View {
        let isCurrent = engine == model.engineScope
        return Button {
            dismiss()
            Task { await model.chooseEngine(engine) }
        } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.98))
        .accessibilityIdentifier("agent.switch.\(engine?.rawValue ?? "all")")
        // VoiceOver reads the tick as part of the row rather than as a shape.
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }
}
