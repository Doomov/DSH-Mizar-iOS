//
//  UsageOverview.swift
//  MizarKit
//
//  What the home page charts: the last weeks of work, one row per day that had
//  any, folded across every agent the host serves.
//
//  The host already does the folding -- a date two engines worked on is one row
//  -- because the alternative is the phone adding up rows that disagree about
//  where a day starts. The phone reads what it is given and draws it.
//

import Foundation

/// One day of work.
public struct UsageDay: Codable, Sendable, Equatable, Identifiable {
    /// "YYYY-MM-DD", the host's local calendar day.
    public let date: String
    /// Every user or assistant message counts once; tool calls do not.
    public let messages: Int
    public let inputTokens: Int
    public let outputTokens: Int
    /// 24 buckets, the host's local hours, index 0 being midnight.
    public let hours: [Int]?

    public var id: String { date }

    /// Everything billed for this day, as the one number a chart can scale by.
    public var tokens: Int { inputTokens + outputTokens }

    public init(
        date: String,
        messages: Int,
        inputTokens: Int,
        outputTokens: Int,
        hours: [Int]? = nil,
    ) {
        self.date = date
        self.messages = messages
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.hours = hours
    }
}

/// The whole history the host keeps, oldest day first.
public struct UsageOverview: Codable, Sendable, Equatable {
    /// Top-level sessions across every agent.
    public let sessions: Int
    /// Only days with activity, oldest first.
    public let days: [UsageDay]

    public init(sessions: Int, days: [UsageDay]) {
        self.sessions = sessions
        self.days = days
    }

    /// The day for a "YYYY-MM-DD" label, when the host worked on it.
    public func day(_ date: String) -> UsageDay? {
        days.first { $0.date == date }
    }

    /// Several computers' histories, added up day by day.
    ///
    /// A day that two machines worked on is one row, the same rule the host
    /// applies to two agents on one machine: the operator's question is "what
    /// did I do on Tuesday", not "which machine was it".
    ///
    /// - Parameter readings: one overview per computer.
    /// - Returns: the merged history, oldest day first.
    public static func merged(_ readings: [UsageOverview]) -> UsageOverview {
        var byDate: [String: UsageDay] = [:]
        var sessions = 0
        for reading in readings {
            sessions += reading.sessions
            for day in reading.days {
                if let existing = byDate[day.date] {
                    byDate[day.date] = UsageDay(
                        date: day.date,
                        messages: existing.messages + day.messages,
                        inputTokens: existing.inputTokens + day.inputTokens,
                        outputTokens: existing.outputTokens + day.outputTokens,
                        hours: nil,
                    )
                } else {
                    byDate[day.date] = day
                }
            }
        }
        return UsageOverview(sessions: sessions, days: byDate.values.sorted { $0.date < $1.date })
    }
}
