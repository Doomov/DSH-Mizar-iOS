//
//  AccountDesktop.swift
//  MizarKit
//
//  The computers an account can reach, and what it takes to open one.
//
//  Discovery is the relay's answer, not something the phone derives: a computer
//  is online because its tunnel is up, and the room is where that tunnel
//  answers. The token is minted by the computer itself, at the relay's request,
//  when the phone asks to connect — it is the same kind of credential pairing
//  issues, so the rest of the client treats it the same way.
//

import Foundation

/// One computer of the signed-in account.
public struct AccountDesktop: Codable, Sendable, Equatable, Identifiable {
    /// The computer's device id in the account.
    public let deviceId: String
    /// What the computer calls itself.
    public let name: String
    /// The hardware model, e.g. `Mac16,10`.
    public let model: String
    /// `macos`, `windows`, … as the computer reported it.
    public let platform: String
    /// Whether its tunnel is connected right now.
    public let online: Bool
    /// The relay room it answers in, once it has one.
    public let room: String?

    public var id: String { deviceId }

    public init(
        deviceId: String,
        name: String,
        model: String = "",
        platform: String = "macos",
        online: Bool,
        room: String? = nil,
    ) {
        self.deviceId = deviceId
        self.name = name
        self.model = model
        self.platform = platform
        self.online = online
        self.room = room
    }
}

/// What `/account/v1/connect` hands back: where the computer is, and the token
/// it just minted for this phone.
public struct DesktopConnection: Codable, Sendable, Equatable {
    /// The relay room, as the relay named it.
    public let room: String
    /// The Mizar token to present on the socket.
    public let token: String

    public init(room: String, token: String) {
        self.room = room
        self.token = token
    }
}
