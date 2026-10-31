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
    /// What each model did on this day, when the host says.
    ///
    /// The home page's "top model" is folded from these: the host already knows
    /// which model answered which message, and the phone asking per session
    /// would be one request per session for a figure about the month.
    public let models: [ModelUsage]?

    public var id: String { date }

    /// Everything billed for this day, as the one number a chart can scale by.
    public var tokens: Int { inputTokens + outputTokens }

    public init(
        date: String,
        messages: Int,
        inputTokens: Int,
        outputTokens: Int,
        hours: [Int]? = nil,
        models: [ModelUsage]? = nil,
    ) {
        self.date = date
        self.messages = messages
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.hours = hours
        self.models = models
    }
}

/// What one model did on one day.
public struct ModelUsage: Codable, Sendable, Equatable, Identifiable {
    public let model: String
    public let messages: Int
    public let inputTokens: Int
    public let outputTokens: Int

    public var id: String { model }

    public init(model: String, messages: Int, inputTokens: Int, outputTokens: Int) {
        self.model = model
        self.messages = messages
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
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
    /// Two per-hour arrays added bucket by bucket, when either side has one.
    private static func add(_ left: [Int]?, _ right: [Int]?) -> [Int]? {
        switch (left, right) {
        case (nil, nil): return nil
        case (let only?, nil), (nil, let only?): return only
        case (let a?, let b?):
            let count = max(a.count, b.count)
            return (0..<count).map { (a.indices.contains($0) ? a[$0] : 0) + (b.indices.contains($0) ? b[$0] : 0) }
        }
    }

    /// Two model lists added by model name.
    private static func add(_ left: [ModelUsage]?, _ right: [ModelUsage]?) -> [ModelUsage]? {
        guard left != nil || right != nil else { return nil }
        var byModel: [String: ModelUsage] = [:]
        for usage in (left ?? []) + (right ?? []) {
            let existing = byModel[usage.model]
            byModel[usage.model] = ModelUsage(
                model: usage.model,
                messages: (existing?.messages ?? 0) + usage.messages,
                inputTokens: (existing?.inputTokens ?? 0) + usage.inputTokens,
                outputTokens: (existing?.outputTokens ?? 0) + usage.outputTokens,
            )
        }
        return byModel.values.sorted { $0.messages > $1.messages }
    }

    /// - Returns: the merged history, oldest day first.
    public static func merged(_ readings: [UsageOverview]) -> UsageOverview {
        var byDate: [String: UsageDay] = [:]
        var sessions = 0
        for reading in readings {
            sessions += reading.sessions
            for day in reading.days {
                if let existing = byDate[day.date] {
                    // Hours and models are added up per bucket rather than
                    // dropped: the home page's "busiest hour" and "top model"
                    // are read from the merged history, and a merge that kept
                    // only the first computer's day would answer both questions
                    // with one machine's work.
                    byDate[day.date] = UsageDay(
                        date: day.date,
                        messages: existing.messages + day.messages,
                        inputTokens: existing.inputTokens + day.inputTokens,
                        outputTokens: existing.outputTokens + day.outputTokens,
                        hours: Self.add(existing.hours, day.hours),
                        models: Self.add(existing.models, day.models),
                    )
                } else {
                    byDate[day.date] = day
                }
            }
        }
        return UsageOverview(sessions: sessions, days: byDate.values.sorted { $0.date < $1.date })
    }
}
