//
//  DraftStore.swift
//  DSH-Mizar
//
//  What was typed and not sent.
//
//  The composer's text lives in the screen's `@State`, which is the right place
//  for something the operator is still writing -- except that the screen is
//  built per session and thrown away when they leave, and an app that is closed
//  is a screen that was thrown away too. A paragraph written for one
//  conversation and lost by glancing at another is the kind of loss that
//  teaches somebody to write elsewhere.
//
//  So every change is written down, per session, and read back when that
//  session opens again. Nothing else is stored: no cursor, no attachments, no
//  "last edited" -- a draft is the words.
//
//  Writes are debounced by the caller (``save(_:for:)`` is cheap but not free),
//  and a session whose draft is emptied has its key removed rather than
//  storing an empty string: an app that keeps a key per session forever is an
//  app whose defaults grow with every conversation the operator ever opened.
//

import Foundation

/// The unsent text of each session's composer.
enum DraftStore {
    /// The defaults key one session's draft lives under.
    private static func key(_ sessionId: String) -> String {
        "mizar.draft.\(sessionId)"
    }

    /// The longest draft kept. A paste of an entire file is not a draft; it is
    /// a file, and it belongs in the attachment strip. The cap keeps one
    /// accidental paste from filling the defaults database.
    private static let limit = 20_000

    /// What was left in this session's composer, or an empty string.
    ///
    /// - Parameter sessionId: the session whose composer it is.
    /// - Returns: the text as it was last written.
    static func text(for sessionId: String) -> String {
        UserDefaults.standard.string(forKey: key(sessionId)) ?? ""
    }

    /// Write down what is in the composer now.
    ///
    /// - Parameters:
    ///   - text: the whole field.
    ///   - sessionId: the session whose composer it is.
    static func save(_ text: String, for sessionId: String) {
        let trimmed = String(text.prefix(limit))
        if trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clear(sessionId)
        } else if trimmed != Self.text(for: sessionId) {
            UserDefaults.standard.set(trimmed, forKey: key(sessionId))
        }
    }

    /// Forget this session's draft -- after it was sent, or when the operator
    /// emptied the field.
    ///
    /// - Parameter sessionId: the session whose composer it is.
    static func clear(_ sessionId: String) {
        UserDefaults.standard.removeObject(forKey: key(sessionId))
    }
}
