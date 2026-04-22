//
//  ChallengeGenerator.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftData

struct ChallengeGenerator {
    struct PlaceTemplate {
        let categories: [MKPointOfInterestCategory]
        let symbolName: String
        let categoryName: String
        let verbs: [String]
        let prompts: [String]
    }

    private let templates: [PlaceTemplate] = [
        PlaceTemplate(
            categories: [.park],
            symbolName: "tree.fill",
            categoryName: "Park",
            verbs: ["Take a breather", "Reset your brain", "Step away from the desk"],
            prompts: ["Notice one color you usually ignore.", "Spend a minute without looking at a screen.", "Spot something moving naturally: leaves, water, birds."]
        ),
        PlaceTemplate(
            categories: [.cafe, .bakery],
            symbolName: "cup.and.saucer.fill",
            categoryName: "Cafe",
            verbs: ["Take a walking break", "Change your scene", "Grab a low-pressure detour"],
            prompts: ["Look for the coziest corner, even if you do not go in.", "Take in the smell and energy of the street.", "Notice one small design detail on the way there."]
        ),
        PlaceTemplate(
            categories: [.library, .university],
            symbolName: "books.vertical.fill",
            categoryName: "Library",
            verbs: ["Move with purpose", "Trade scrolling for curiosity", "Walk into a focused zone"],
            prompts: ["Read one sign or poster that teaches you something.", "Look for a place where people are intentionally learning.", "Pick one thing to remember from the walk."]
        ),
        PlaceTemplate(
            categories: [.museum, .theater],
            symbolName: "building.columns.fill",
            categoryName: "Landmark",
            verbs: ["Take the scenic option", "Do a small urban quest", "Turn today into a micro-adventure"],
            prompts: ["Notice one architectural detail worth stealing for inspiration.", "Walk slower for the last 100 meters.", "Find one angle that makes the place feel cinematic."]
        ),
        PlaceTemplate(
            categories: [.store, .pharmacy],
            symbolName: "bag.fill",
            categoryName: "Street Spot",
            verbs: ["Get your steps without overthinking it", "Break the indoor loop", "Stack movement onto your day"],
            prompts: ["Take a different route than usual if it feels safe.", "Pay attention to the soundscape outside.", "Look for something oddly satisfying on the street."]
        )
    ]

    func ensureChallenges(
        in context: ModelContext,
        around userLocation: CLLocation,
        preferredRadius: CLLocationDistance,
        now: Date = .now
    ) async throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let existingDescriptor = FetchDescriptor<DailyChallenge>(
            predicate: #Predicate { challenge in
                challenge.dayStamp == dayStart
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        let existing = try context.fetch(existingDescriptor)
        let expectedCount = calendar.component(.weekday, from: now) == 1 ? 2 : 1

        if existing.count >= expectedCount {
            return
        }

        let blockedCoordinates = existing.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }

        for index in existing.count..<expectedCount {
            guard let draft = try await generateChallenge(
                around: userLocation,
                for: dayStart,
                preferredRadius: preferredRadius,
                blockedCoordinates: blockedCoordinates + context.usedChallengeLocations(excluding: dayStart),
                isBonus: index > 0
            ) else {
                continue
            }

            context.insert(draft)
        }

        try context.save()
    }

    private func generateChallenge(
        around userLocation: CLLocation,
        for dayStart: Date,
        preferredRadius: CLLocationDistance,
        blockedCoordinates: [CLLocation],
        isBonus: Bool
    ) async throws -> DailyChallenge? {
        let shuffledTemplates = templates.shuffled()

        for template in shuffledTemplates {
            let items = try await fetchMapItems(
                around: userLocation.coordinate,
                categories: template.categories
            )

            let filtered = items.filter { item in
                guard let location = item.placemark.location else { return false }
                guard isAllowed(item: item) else { return false }
                let distance = userLocation.distance(from: location)
                let maxDistance = min(preferredRadius + (isBonus ? 350 : 150), 2500)
                guard distance >= 250, distance <= maxDistance else { return false }

                return blockedCoordinates.allSatisfy { blocked in
                    blocked.distance(from: location) > 180
                }
            }

            guard let chosen = filtered.randomElement(), let location = chosen.placemark.location else {
                continue
            }

            return makeChallenge(
                from: chosen,
                template: template,
                coordinate: location.coordinate,
                dayStart: dayStart,
                walkDistance: userLocation.distance(from: location),
                isBonus: isBonus
            )
        }

        return fallbackChallenge(around: userLocation, for: dayStart, preferredRadius: preferredRadius, isBonus: isBonus)
    }

    private func fetchMapItems(
        around coordinate: CLLocationCoordinate2D,
        categories: [MKPointOfInterestCategory]
    ) async throws -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 2200)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }

    private func makeChallenge(
        from item: MKMapItem,
        template: PlaceTemplate,
        coordinate: CLLocationCoordinate2D,
        dayStart: Date,
        walkDistance: CLLocationDistance,
        isBonus: Bool
    ) -> DailyChallenge {
        let verb = template.verbs.randomElement() ?? "Step outside"
        let prompt = template.prompts.randomElement() ?? "Notice one good thing on the walk."
        let minutes = max(6, min(18, Int((walkDistance / 85).rounded())))
        let reward = isBonus ? 45 : 30
        let nearbyReward = Int((Double(reward) * 0.65).rounded())
        let distanceString = Measurement(value: walkDistance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0))))

        return DailyChallenge(
            dayStamp: dayStart,
            title: isBonus ? "Sunday Bonus" : "Today’s Adventure",
            detail: "\(verb) at \(item.name ?? "a nearby spot"), about \(distanceString) away.",
            prompt: prompt,
            placeName: item.name ?? template.categoryName,
            categoryName: template.categoryName,
            symbolName: template.symbolName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            targetMinutes: minutes,
            rewardXP: reward,
            nearbyRewardXP: nearbyReward,
            exactRadiusMeters: 75,
            nearbyRadiusMeters: 375,
            isBonus: isBonus
        )
    }

    private func fallbackChallenge(
        around userLocation: CLLocation,
        for dayStart: Date,
        preferredRadius: CLLocationDistance,
        isBonus: Bool
    ) -> DailyChallenge {
        let meters = min(max(preferredRadius * (isBonus ? 0.9 : 0.65), 350), 1200)
        let offset = meters / 111_000
        let coordinate = CLLocationCoordinate2D(
            latitude: userLocation.coordinate.latitude + offset,
            longitude: userLocation.coordinate.longitude + offset
        )

        return DailyChallenge(
            dayStamp: dayStart,
            title: isBonus ? "Sunday Bonus" : "Today’s Adventure",
            detail: "Take a short walk to a fresh nearby spot and check in when you arrive.",
            prompt: "Take a slightly different route if it feels safe.",
            placeName: "Fresh Air Marker",
            categoryName: "Walk",
            symbolName: "figure.walk.motion",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            targetMinutes: isBonus ? 16 : 10,
            rewardXP: isBonus ? 45 : 30,
            nearbyRewardXP: isBonus ? 30 : 20,
            exactRadiusMeters: 75,
            nearbyRadiusMeters: 375,
            isBonus: isBonus
        )
    }

    private func isAllowed(item: MKMapItem) -> Bool {
        let name = (item.name ?? "").lowercased()
        let blockedTerms = [
            "hospital", "clinic", "police", "embassy", "consulate",
            "funeral", "cemetery", "jail", "prison", "detention"
        ]

        return blockedTerms.allSatisfy { name.contains($0) == false }
    }
}

private extension ModelContext {
    func usedChallengeLocations(excluding dayStart: Date) -> [CLLocation] {
        let descriptor = FetchDescriptor<DailyChallenge>(
            predicate: #Predicate { challenge in
                challenge.dayStamp != dayStart
            }
        )

        let challenges = (try? fetch(descriptor)) ?? []
        return challenges.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
