//
//  AgentEngine.swift
//  DSH-Mizar
//
//  Which agent on the computer this phone is talking to.
//
//  A computer runs three agents at once and they do not share sessions, working
//  directories or even tool surfaces. A phone that wants to drive Claude Code is
//  not "a phone connected to the Mac" in any useful sense -- it is a phone
//  connected to the Mac's Claude Code, and the other two lists would be noise
//  and, worse, a way to send a prompt to the wrong agent.
//
//  The choice is made once, when the computer is opened, and travels in the
//  token: the relay asks the computer to mint a token scoped to it, and the
//  computer refuses to list or answer anything else.
//

import Foundation
import MizarKit

/// The agents a computer can serve.
enum AgentEngine: String, CaseIterable, Sendable, Identifiable {
    case dsh
    case claude
    case codex

    var id: String { rawValue }

    /// The name the wire uses (`EngineId::as_str` on the desktop).
    var wireName: String { rawValue }

    /// The prefix a session id carries, e.g. `dsh:session-…`.
    var sessionPrefix: String { "\(rawValue):" }

    /// What the picker calls it.
    ///
    /// A product name, so it is not translated: DSH is DSH in every language.
    var title: String {
        switch self {
        case .dsh: return "DSH"
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    /// One line under the name.
    var detail: String {
        switch self {
        case .dsh:
            String(localized: "DeepSeek Harness workspaces and sessions")
        case .claude:
            String(localized: "Claude Code transcripts on this computer")
        case .codex:
            String(localized: "Codex threads on this computer")
        }
    }

    /// What a workspace heading calls it when the list names its agent.
    ///
    /// Shorter than ``title`` on purpose: this is a capsule beside a folder name
    /// in a drawer, not a row in a picker.
    var shortTitle: String {
        switch self {
        case .dsh: return "DSH"
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}
