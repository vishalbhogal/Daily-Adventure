//
//  DailyChallenge.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import Foundation
import SwiftData

@Model
final class DailyChallenge {
    enum CompletionKind: String, Codable {
        case exact
        case nearby
    }

    var id: UUID
    var dayStamp: Date
    var title: String
    var detail: String
    var prompt: String
    var placeName: String
    var categoryName: String
    var symbolName: String
    var latitude: Double
    var longitude: Double
    var targetMinutes: Int
    var rewardXP: Int
    var nearbyRewardXP: Int
    var exactRadiusMeters: Double
    var nearbyRadiusMeters: Double
    var createdAt: Date
    var completedAt: Date?
    var completionKindRawValue: String?
    var proofNote: String
    var proofImagePath: String?
    var isBonus: Bool

    init(
        id: UUID = UUID(),
        dayStamp: Date,
        title: String,
        detail: String,
        prompt: String,
        placeName: String,
        categoryName: String,
        symbolName: String,
        latitude: Double,
        longitude: Double,
        targetMinutes: Int,
        rewardXP: Int,
        nearbyRewardXP: Int,
        exactRadiusMeters: Double = 75,
        nearbyRadiusMeters: Double = 375,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        completionKindRawValue: String? = nil,
        proofNote: String = "",
        proofImagePath: String? = nil,
        isBonus: Bool = false
    ) {
        self.id = id
        self.dayStamp = dayStamp
        self.title = title
        self.detail = detail
        self.prompt = prompt
        self.placeName = placeName
        self.categoryName = categoryName
        self.symbolName = symbolName
        self.latitude = latitude
        self.longitude = longitude
        self.targetMinutes = targetMinutes
        self.rewardXP = rewardXP
        self.nearbyRewardXP = nearbyRewardXP
        self.exactRadiusMeters = exactRadiusMeters
        self.nearbyRadiusMeters = nearbyRadiusMeters
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.completionKindRawValue = completionKindRawValue
        self.proofNote = proofNote
        self.proofImagePath = proofImagePath
        self.isBonus = isBonus
    }

    var completionKind: CompletionKind? {
        get {
            guard let completionKindRawValue else { return nil }
            return CompletionKind(rawValue: completionKindRawValue)
        }
        set {
            completionKindRawValue = newValue?.rawValue
        }
    }

    var awardedXP: Int {
        switch completionKind {
        case .exact:
            return rewardXP
        case .nearby:
            return nearbyRewardXP
        case .none:
            return 0
        }
    }
}
