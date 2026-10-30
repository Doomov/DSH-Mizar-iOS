//
//  DeliveredAttachments.swift
//  DSH-Mizar
//
//  What was sent with a prompt, remembered on the phone.
//
//  The host stores an uploaded attachment and hands the engine the bytes, but
//  the record it writes for the operator's prompt is the text alone: there is
//  no attachment field on `user/message`, so a conversation reloaded from the
//  computer shows the words and not the photo that came with them. The phone
//  sent both, so the phone keeps the second half.
//
//  Keyed by the prompt's own text, because that is the only thing the two sides
//  share: the record has no request id on hosts that predate the field, and the
//  operator's words are what identifies the message on screen anyway. A prompt
//  sent twice with the same words gets the newest chips -- the same choice the
//  conversation makes when it collapses two identical messages into one.
//
//  This is a convenience for the reader, never the source of truth: the file
//  itself lives on the computer, and the chips are a note that something was
//  attached, not a way to get it back.
//

import Foundation

/// One attachment, as the conversation shows it above the words.
struct DeliveredAttachment: Codable, Sendable, Equatable, Identifiable {
    /// Image or file, which decides the glyph.
    let isImage: Bool
    /// The file name the host stored.
    let name: String

    var id: String { "\(isImage)-\(name)" }

    /// What the chip says: a photo is a photo, a file is its name.
    var label: String {
        isImage ? String(localized: "Photo") : name
    }
}

/// What was attached to each prompt, by the prompt's text.
enum DeliveredAttachments {
    /// The defaults key the whole map lives under.
    private static let key = "mizar.deliveredAttachments"
    /// How many prompts are remembered. A conversation is read newest first and
    /// a note about a prompt from a year ago is not worth the storage.
    private static let limit = 200

    /// Write down what went with a prompt.
    ///
    /// - Parameters:
    ///   - attachments: the attachments, in the order they were shown.
    ///   - text: the prompt's words, which is what the record will carry.
    static func record(_ attachments: [DeliveredAttachment], for text: String) {
        guard !attachments.isEmpty else { return }
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        var map = stored()
        map[prompt] = attachments
        // Newest last, and only the newest are kept.
        let trimmed = map.count > limit ? Dictionary(uniqueKeysWithValues: Array(map).suffix(limit)) : map
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// What went with this prompt, when this phone sent it.
    ///
    /// - Parameter text: the prompt's words.
    /// - Returns: the attachments, or an empty list.
    static func attachments(for text: String) -> [DeliveredAttachment] {
        stored()[text.trimmingCharacters(in: .whitespacesAndNewlines)] ?? []
    }

    private static func stored() -> [String: [DeliveredAttachment]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: [DeliveredAttachment]].self, from: data)
        else { return [:] }
        return map
    }
}
