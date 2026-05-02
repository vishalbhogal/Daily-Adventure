//
//  Badge.swift
//  Daily Adventure
//
//  SwiftData model for earned badges plus the catalog of all possible
//  badges and the logic for deciding when each one is awarded.
//

import Foundation
import SwiftData

// MARK: - Badge (persisted)

/// A single badge instance that the user has earned.
/// The `definitionID` links back to `BadgeDefinition.all` for display info.
@Model final class Badge {
    var id: UUID
    var definitionID: String
    var earnedAt: Date

    init(definitionID: String, earnedAt: Date = .now) {
        self.id          = UUID()
        self.definitionID = definitionID
        self.earnedAt    = earnedAt
    }

    /// Looks up the display metadata for this earned badge.
    var definition: BadgeDefinition? {
        BadgeDefinition.all.first { $0.id == definitionID }
    }
}

// MARK: - Badge Definition (not persisted — static catalog)

/// Describes a badge: what it's called, what it looks like, and when it's awarded.
/// `Identifiable` lets SwiftUI use these in `ForEach` and `.sheet(item:)` directly.
struct BadgeDefinition: Identifiable {
    let id: String
    let title: String
    let description: String
    let symbolName: String
    let category: Category

    enum Category: String {
        case explorer   = "Explorer"
        case streak     = "Streak"
        case xp         = "XP"
        case adventure  = "Adventure"
    }

    // MARK: Full catalog

    static let all: [BadgeDefinition] = [

        // ── Explorer: earned by visiting parks and landmarks ─────────────────
        BadgeDefinition(
            id: "first_park",
            title: "First Steps",
            description: "Visited your first park or landmark",
            symbolName: "leaf.fill",
            category: .explorer
        ),
        BadgeDefinition(
            id: "park_5",
            title: "Park Hopper",
            description: "Visited 5 parks or landmarks",
            symbolName: "tree.fill",
            category: .explorer
        ),
        BadgeDefinition(
            id: "park_10",
            title: "Nature Seeker",
            description: "Visited 10 parks or landmarks",
            symbolName: "mountain.2.fill",
            category: .explorer
        ),
        BadgeDefinition(
            id: "park_25",
            title: "Trail Blazer",
            description: "Visited 25 parks or landmarks",
            symbolName: "figure.hiking",
            category: .explorer
        ),

        // ── Streak: consecutive days with at least one completed adventure ──
        BadgeDefinition(
            id: "streak_3",
            title: "On a Roll",
            description: "Maintained a 3-day adventure streak",
            symbolName: "flame.fill",
            category: .streak
        ),
        BadgeDefinition(
            id: "streak_7",
            title: "Week Warrior",
            description: "Maintained a 7-day streak",
            symbolName: "sparkles",
            category: .streak
        ),
        BadgeDefinition(
            id: "streak_30",
            title: "Unstoppable",
            description: "Maintained a 30-day streak",
            symbolName: "bolt.circle.fill",
            category: .streak
        ),

        // ── XP: cumulative experience-point milestones ────────────────────
        BadgeDefinition(
            id: "xp_100",
            title: "Getting Started",
            description: "Earned your first 100 XP",
            symbolName: "star.fill",
            category: .xp
        ),
        BadgeDefinition(
            id: "xp_500",
            title: "Active Explorer",
            description: "Earned 500 XP total",
            symbolName: "star.circle.fill",
            category: .xp
        ),
        BadgeDefinition(
            id: "xp_1000",
            title: "Adventure Pro",
            description: "Earned 1,000 XP total",
            symbolName: "trophy.fill",
            category: .xp
        ),

        // ── Adventure: total completed walks ────────────────────────────────
        BadgeDefinition(
            id: "walk_1",
            title: "First Walk",
            description: "Completed your first adventure",
            symbolName: "shoeprints.fill",
            category: .adventure
        ),
        BadgeDefinition(
            id: "walk_10",
            title: "Regular Walker",
            description: "Completed 10 adventures",
            symbolName: "figure.walk.circle.fill",
            category: .adventure
        ),
        BadgeDefinition(
            id: "walk_50",
            title: "Dedicated",
            description: "Completed 50 adventures",
            symbolName: "medal.fill",
            category: .adventure
        ),
    ]

    // MARK: Award logic

    /// Returns definitions that should be newly awarded given the current stats,
    /// filtering out any the user has already earned.
    static func newlyEarned(
        earnedIDs: Set<String>,
        parkVisits: Int,
        streak: Int,
        totalXP: Int,
        totalWalks: Int
    ) -> [BadgeDefinition] {
        all.filter { def in
            !earnedIDs.contains(def.id) &&
            def.qualifies(parkVisits: parkVisits, streak: streak, totalXP: totalXP, totalWalks: totalWalks)
        }
    }

    /// Whether this specific badge's threshold has been reached.
    func qualifies(parkVisits: Int, streak: Int, totalXP: Int, totalWalks: Int) -> Bool {
        switch id {
        case "first_park":  return parkVisits >= 1
        case "park_5":      return parkVisits >= 5
        case "park_10":     return parkVisits >= 10
        case "park_25":     return parkVisits >= 25
        case "streak_3":    return streak >= 3
        case "streak_7":    return streak >= 7
        case "streak_30":   return streak >= 30
        case "xp_100":      return totalXP >= 100
        case "xp_500":      return totalXP >= 500
        case "xp_1000":     return totalXP >= 1000
        case "walk_1":      return totalWalks >= 1
        case "walk_10":     return totalWalks >= 10
        case "walk_50":     return totalWalks >= 50
        default:            return false
        }
    }
}
