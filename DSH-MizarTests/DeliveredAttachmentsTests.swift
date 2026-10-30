//
//  DeliveredAttachmentsTests.swift
//  DSH-MizarTests
//
//  The note the phone keeps about what it sent, because the computer's record
//  is the words alone.
//

import Foundation
import Testing
@testable import DSH_Mizar

@MainActor
struct DeliveredAttachmentsTests {
    @Test("a prompt's attachments come back by its words")
    func roundTrip() {
        let prompt = "look at these \(UUID().uuidString)"
        DeliveredAttachments.record(
            [DeliveredAttachment(isImage: true, name: "IMG_0001.jpg")],
            for: prompt,
        )
        let found = DeliveredAttachments.attachments(for: prompt)
        #expect(found == [DeliveredAttachment(isImage: true, name: "IMG_0001.jpg")])
    }

    @Test("a prompt that carried nothing has nothing")
    func empty() {
        #expect(DeliveredAttachments.attachments(for: "a prompt nobody attached to \(UUID().uuidString)").isEmpty)
        // Recording nothing must not create an entry either.
        let prompt = "no attachments \(UUID().uuidString)"
        DeliveredAttachments.record([], for: prompt)
        #expect(DeliveredAttachments.attachments(for: prompt).isEmpty)
    }

    @Test("surrounding whitespace does not hide the note")
    func whitespace() {
        let prompt = "padded \(UUID().uuidString)"
        DeliveredAttachments.record([DeliveredAttachment(isImage: false, name: "notes.pdf")], for: prompt)
        #expect(DeliveredAttachments.attachments(for: "  \(prompt)\n").count == 1)
    }
}
