//
//  ContentView.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allChallenges: [DailyChallenge]
    @StateObject private var locationManager = LocationManager()
    @StateObject private var reminderManager = ReminderManager()
    
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showSplash = true
    
    @AppStorage("preferredRadiusMeters") private var preferredRadiusMeters = 1_000.0
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 18
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 15
    @AppStorage("remindersEnabled") private var remindersEnabled = false

    private let generator = ChallengeGenerator()

    init() {
        _allChallenges = Query(sort: \DailyChallenge.createdAt, order: .reverse)
    }

    var body: some View {
        ZStack {
            TabView {
                TodayTab(
                    allChallenges: allChallenges,
                    locationManager: locationManager,
                    preferredRadiusMeters: preferredRadiusMeters,
                    generator: generator
                )
                .tabItem {
                    Label("Today", systemImage: "figure.walk.circle.fill")
                }

                HistoryTab(allChallenges: allChallenges)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }

                ProfileTab(allChallenges: allChallenges) {
                    isLoggedIn = false
                    showSplash = true
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }

                SettingsTab(
                    preferredRadiusMeters: $preferredRadiusMeters,
                    dailyReminderHour: $dailyReminderHour,
                    dailyReminderMinute: $dailyReminderMinute,
                    remindersEnabled: $remindersEnabled,
                    reminderManager: reminderManager
                )
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
            }
            .tint(colorScheme == .dark ? .white : .black)

            if !isLoggedIn && showSplash {
                DailyAdventureSplashView {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isLoggedIn = true
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .task {
            locationManager.refreshLocation()
            await reminderManager.refreshStatus()
            await syncReminderSchedule()
        }
    }

    private func syncReminderSchedule() async {
        if remindersEnabled == false {
            return
        }

        if reminderManager.authorizationStatus == .notDetermined {
            let granted = await reminderManager.requestPermission()
            guard granted else {
                remindersEnabled = false
                return
            }
        }

        await reminderManager.scheduleDailyReminder(hour: dailyReminderHour, minute: dailyReminderMinute)
    }
}

private struct DailyAdventureSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pathProgress = 0.0
    @State private var showContent = false
    var onSignIn: () -> Void

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            SciFiGrid()
                .foregroundStyle(primaryColor)
                .opacity(0.12)

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("DAILY")
                    Text("ADVENTURE")
                }
                .font(.system(size: 12, weight: .black))
                .kerning(8)
                .foregroundStyle(primaryColor)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .padding(.top, 80)

                Spacer()

                MazePathView(progress: pathProgress, color: primaryColor, secondaryColor: secondaryColor, backgroundColor: backgroundColor)
                    .frame(height: 280)
                    .padding(.horizontal, 40)
                    .scaleEffect(showContent ? 0.92 : 1.0)
                    .blur(radius: showContent ? 4 : 0)
                    .opacity(showContent ? 0.2 : 1)
                    .offset(y: -40)

                Spacer()

                if showContent {
                    VStack(spacing: 12) {
                        AuthButton(title: "CONTINUE WITH APPLE", symbol: "apple.logo", isPrimary: true, action: onSignIn)
                        AuthButton(title: "CONTINUE WITH GOOGLE", symbol: "google", isPrimary: false, action: onSignIn)
                        
                        Text("V.01")
                            .font(.system(size: 9, weight: .black))
                            .kerning(2)
                            .foregroundStyle(primaryColor.opacity(0.3))
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 60)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .opacity
                    ))
                }
            }
        }
        .task {
            withAnimation(.linear(duration: 5.2)) {
                pathProgress = 1
            }

            try? await Task.sleep(for: .seconds(5.5))
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                showContent = true
            }
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(white: 0.98)
    }

    private var primaryColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryColor: Color {
        primaryColor.opacity(0.4)
    }
}

private struct AuthButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let symbol: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if symbol == "google" {
                    Image("google")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(2)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(foregroundColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isPrimary {
            return colorScheme == .dark ? .white : .black
        }
        return .clear
    }

    private var foregroundColor: Color {
        if isPrimary {
            return colorScheme == .dark ? .black : .white
        }
        return colorScheme == .dark ? .white : .black
    }
}

private struct ProfileTab: View {
    @Environment(\.colorScheme) private var colorScheme
    let allChallenges: [DailyChallenge]
    var onSignOut: () -> Void

    private var totalXP: Int {
        allChallenges.reduce(0) { $0 + $1.awardedXP }
    }

    private var completedCount: Int {
        allChallenges.filter { $0.completedAt != nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(primaryTone.opacity(0.08), lineWidth: 1.5)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(primaryTone)
                        }
                        
                        Text("TRAVELLER #\(String(format: "%04d", 420))")
                            .font(.system(size: 14, weight: .black))
                            .kerning(1.2)
                            .foregroundStyle(primaryTone)
                    }
                    .padding(.top, 40)

                    HStack(spacing: 16) {
                        ProfileMetric(title: "TOTAL XP", value: "\(totalXP)", symbol: "bolt.fill")
                        ProfileMetric(title: "WALKS", value: "\(completedCount)", symbol: "shoeprints.fill")
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACCOUNT SETTINGS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)

                        VStack(spacing: 0) {
                            ProfileRow(title: "Linked Identity", value: "Apple ID", symbol: "link")
                            ProfileRow(title: "Privacy Shield", value: "Active", symbol: "lock.shield")
                            ProfileRow(title: "Global Rank", value: "Top 4%", symbol: "globe.americas.fill")
                            
                            Button(action: onSignOut) {
                                ProfileRow(title: "Sign Out", value: "", symbol: "arrow.right.square", isLast: true, isDestructive: true)
                            }
                        }
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("PROFILE")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var primaryTone: Color { colorScheme == .dark ? .white : .black }
}

private struct ProfileMetric: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProfileRow: View {
    let title: String
    let value: String
    let symbol: String
    var isLast = false
    var isDestructive = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }
            .foregroundStyle(isDestructive ? .red : .primary)
            .padding(.horizontal, 20)
            .frame(height: 58)

            if !isLast {
                Divider()
                    .padding(.leading, 20)
            }
        }
    }
}

private struct MazePathView: View, Animatable {
    var progress: Double
    let color: Color
    let secondaryColor: Color
    let backgroundColor: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private let normalizedPoints: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.92),
        CGPoint(x: 0.25, y: 0.92), 
        CGPoint(x: 0.25, y: 0.72),
        CGPoint(x: 0.45, y: 0.72),
        CGPoint(x: 0.45, y: 0.88),
        CGPoint(x: 0.75, y: 0.88),
        CGPoint(x: 0.75, y: 0.55),
        CGPoint(x: 0.55, y: 0.55),
        CGPoint(x: 0.55, y: 0.25),
        CGPoint(x: 0.90, y: 0.25)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let points = normalizedPoints.map { point in
                CGPoint(x: point.x * size.width, y: point.y * size.height)
            }
            let state = splashState(points: points, progress: progress)

            ZStack(alignment: .topLeading) {
                routePath(points: points)
                    .stroke(color.opacity(0.05), style: StrokeStyle(lineWidth: 1.0))

                renderedPath(points: points, state: state)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .offset(x: points[0].x - 4, y: points[0].y - 4)

                ForEach(iconNodes, id: \.pointIndex) { node in
                    if state.reachedCheckpointIndices.contains(node.pointIndex) {
                        CheckpointIcon(symbol: node.symbol, color: color)
                            .id("icon-\(node.pointIndex)")
                            .transition(.scale.combined(with: .opacity))
                            .offset(x: points[node.pointIndex].x - 18, y: points[node.pointIndex].y - 18)
                    } else {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 3, height: 3)
                            .offset(x: points[node.pointIndex].x - 1.5, y: points[node.pointIndex].y - 1.5)
                    }
                }

                if state.markerSymbol == nil {
                    BlinkingTraveller(color: color, progress: progress)
                        .offset(x: state.position.x - 4, y: state.position.y - 4)
                }
            }
        }
    }

    private var iconNodes: [(pointIndex: Int, symbol: String)] {
        [
            (2, "tree.fill"),
            (4, "cross.case.fill"),
            (6, "building.columns.fill"),
            (8, "cup.and.saucer.fill"),
            (9, "figure.walk.circle.fill")
        ]
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func renderedPath(points: [CGPoint], state: SplashRouteState) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        if state.completedSegments > 0 {
            for index in 0..<min(state.completedSegments, points.count - 1) {
                path.addLine(to: points[index + 1])
            }
        }

        if let segment = state.currentSegment {
            let start = points[segment]
            let end = points[segment + 1]
            let currentPoint = CGPoint(
                x: start.x + ((end.x - start.x) * state.segmentProgress),
                y: start.y + ((end.y - start.y) * state.segmentProgress)
            )
            path.addLine(to: currentPoint)
        }

        return path
    }

    private func splashState(points: [CGPoint], progress: Double) -> SplashRouteState {
        let stages: [RouteStage] = [
            .move(segment: 0, duration: 0.10),
            .move(segment: 1, duration: 0.11),
            .hold(pointIndex: 2, symbol: "tree.fill", duration: 0.08),
            .move(segment: 2, duration: 0.10),
            .move(segment: 3, duration: 0.08),
            .hold(pointIndex: 4, symbol: "cross.case.fill", duration: 0.08),
            .move(segment: 4, duration: 0.11),
            .move(segment: 5, duration: 0.12),
            .hold(pointIndex: 6, symbol: "building.columns.fill", duration: 0.08),
            .move(segment: 6, duration: 0.12),
            .move(segment: 7, duration: 0.09),
            .hold(pointIndex: 8, symbol: "cup.and.saucer.fill", duration: 0.08),
            .move(segment: 8, duration: 0.06),
            .hold(pointIndex: 9, symbol: "figure.walk.circle.fill", duration: 0.09),
        ]

        let clamped = max(0, min(progress, 1))
        
        if clamped == 0 {
            return SplashRouteState(
                position: points.first ?? .zero,
                markerSymbol: nil,
                reachedCheckpointIndices: [],
                completedSegments: 0,
                currentSegment: 0,
                segmentProgress: 0
            )
        }

        let total = stages.reduce(0.0) { $0 + $1.duration }
        let target = clamped * total

        var elapsed = 0.0
        var completedSegments = 0
        var reached = Set<Int>()

        for stage in stages {
            let nextElapsed = elapsed + stage.duration

            if target <= nextElapsed {
                switch stage {
                case .move(let segment, let duration):
                    let local = duration == 0 ? CGFloat(0) : CGFloat((target - elapsed) / duration)
                    let start = points[segment]
                    let end = points[segment + 1]
                    let position = CGPoint(
                        x: start.x + ((end.x - start.x) * local),
                        y: start.y + ((end.y - start.y) * local)
                    )
                    return SplashRouteState(
                        position: position,
                        markerSymbol: nil,
                        reachedCheckpointIndices: reached,
                        completedSegments: completedSegments,
                        currentSegment: segment,
                        segmentProgress: local
                    )
                case .hold(let pointIndex, let symbol, _):
                    reached.insert(pointIndex)
                    return SplashRouteState(
                        position: points[pointIndex],
                        markerSymbol: symbol,
                        reachedCheckpointIndices: reached,
                        completedSegments: completedSegments,
                        currentSegment: nil,
                        segmentProgress: 1
                    )
                }
            }

            switch stage {
            case .move(let segment, _):
                completedSegments = max(completedSegments, segment + 1)
            case .hold(let pointIndex, _, _):
                reached.insert(pointIndex)
            }

            elapsed = nextElapsed
        }

        return SplashRouteState(
            position: points.last ?? .zero,
            markerSymbol: "figure.walk.circle.fill",
            reachedCheckpointIndices: reached,
            completedSegments: points.count - 1,
            currentSegment: nil,
            segmentProgress: 1
        )
    }
}

private struct BlinkingTraveller: View {
    let color: Color
    let progress: Double
    @State private var pulse = 1.0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45 + (progress * 360)))
            .scaleEffect(pulse)
            .opacity(0.3 + (pulse * 0.7))
            .shadow(color: color.opacity(0.2), radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulse = 1.5
                }
            }
    }
}

private enum RouteStage {
    case move(segment: Int, duration: Double)
    case hold(pointIndex: Int, symbol: String, duration: Double)

    var duration: Double {
        switch self {
        case .move(_, let duration), .hold(_, _, let duration):
            return duration
        }
    }
}

private struct SplashRouteState {
    let position: CGPoint
    let markerSymbol: String?
    let reachedCheckpointIndices: Set<Int>
    let completedSegments: Int
    let currentSegment: Int?
    let segmentProgress: CGFloat
}

private struct CheckpointIcon: View {
    let symbol: String
    let color: Color
    @State private var scale = 0.4
    @State private var blur = 12.0
    @State private var opacity = 0.0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .black))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.15), radius: 10)
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)) {
                    scale = 1.0
                    blur = 0
                    opacity = 1.0
                }
            }
            .frame(width: 36, height: 36)
    }
}

private struct MazeGhostBlocks: View {
    let points: [CGPoint]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            guard points.count > 4 else { return }
            let ghostRects = [
                CGRect(x: points[1].x - 34, y: points[1].y - 56, width: 62, height: 56),
                CGRect(x: points[3].x - 52, y: points[3].y - 36, width: 68, height: 56),
                CGRect(x: points[6].x - 8, y: points[6].y - 46, width: 56, height: 62)
            ]

            for rect in ghostRects {
                context.stroke(Path(rect), with: .color(color.opacity(0.12)), lineWidth: 0.8)
            }
        }
    }
}

private struct SciFiGrid: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let spacing: CGFloat = 36
                for x in stride(from: 0, through: size.width, by: spacing) {
                    for y in stride(from: 0, through: size.height, by: spacing) {
                        let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 0.8))
                        context.fill(dot, with: .foreground)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct TodayTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let allChallenges: [DailyChallenge]
    @ObservedObject var locationManager: LocationManager
    let preferredRadiusMeters: Double
    let generator: ChallengeGenerator

    @State private var selectedChallenge: DailyChallenge?
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var completionTarget: DailyChallenge?

    private var todaysChallenges: [DailyChallenge] {
        let dayStart = Calendar.current.startOfDay(for: .now)
        return allChallenges.filter { Calendar.current.isDate($0.dayStamp, inSameDayAs: dayStart) }
            .sorted { lhs, rhs in
                if lhs.isBonus == rhs.isBonus {
                    return lhs.createdAt < rhs.createdAt
                }
                return rhs.isBonus == false
            }
    }

    private var completedChallenges: Int {
        allChallenges.filter { $0.completedAt != nil }.count
    }

    private var currentStreak: Int {
        let completedDays = Set(
            allChallenges.compactMap { challenge in
                challenge.completedAt.map { Calendar.current.startOfDay(for: $0) }
            }
        )

        var streak = 0
        var cursor = Calendar.current.startOfDay(for: .now)

        while completedDays.contains(cursor) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private var totalXP: Int {
        allChallenges.reduce(0) { partialResult, challenge in
            partialResult + challenge.awardedXP
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    permissionCard

                    if let selectedChallenge {
                        challengeMap(for: selectedChallenge)
                    }

                    ForEach(todaysChallenges) { challenge in
                        ChallengeCard(
                            challenge: challenge,
                            distance: locationManager.distance(to: challenge),
                            isSelected: selectedChallenge?.id == challenge.id,
                            eligibility: locationManager.eligibility(for: challenge),
                            onSelect: {
                                selectedChallenge = challenge
                            },
                            onCheckIn: {
                                completionTarget = challenge
                            }
                        )
                    }

                    if todaysChallenges.isEmpty {
                        emptyState
                    }

                    progressCard
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        locationManager.refreshLocation()
                        Task {
                            await generateChallenges(forceSelection: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    .foregroundStyle(primaryTone)
                    .disabled(isGenerating)
                }
            }
        }
        .sheet(item: $completionTarget) { challenge in
            CompletionSheet(
                challenge: challenge,
                onSave: { note, imageData in
                    complete(challenge, note: note, imageData: imageData)
                }
            )
        }
        .task {
            locationManager.refreshLocation()
            await generateChallenges(forceSelection: false)
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            Task {
                await generateChallenges(forceSelection: true)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Today’s briefing", systemImage: "figure.walk.circle.fill")
                        .font(.headline)
                        .foregroundStyle(primaryTone)
                    Text("A nearby micro-adventure built for people who spend too much time indoors.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryTone)
                }
            }

            HStack(spacing: 12) {
                StatPill(title: "Streak", value: "\(currentStreak)", symbolName: "flame.fill")
                StatPill(title: "XP", value: "\(totalXP)", symbolName: "bolt.fill")
                StatPill(title: "Done", value: "\(completedChallenges)", symbolName: "checkmark.seal.fill")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(permissionTitle, systemImage: permissionSymbol)
                    .font(.headline)
                    .foregroundStyle(primaryTone)
                Spacer()
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(permissionMessage)
                .font(.subheadline)
                .foregroundStyle(secondaryTone)

            if locationManager.status != .authorized {
                Button {
                    locationManager.requestAccess()
                } label: {
                    Label("Enable Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryTone)
            }

            HStack(spacing: 10) {
                InfoTag(symbolName: "ruler", text: preferredRadiusLabel)
                InfoTag(symbolName: "figure.walk.motion", text: todayLoadLabel)
            }

            if let generationError {
                Label(generationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(primaryTone)
            } else if let error = locationManager.lastErrorMessage {
                Label(error, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(primaryTone)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("How It Works", systemImage: "map.circle.fill")
                .font(.headline)
                .foregroundStyle(primaryTone)

            ProgressRow(symbol: "1.circle.fill", text: "Each day you get one nearby place worth walking to.")
            ProgressRow(symbol: "2.circle.fill", text: "Once you arrive, add a quick note and optional proof shot.")
            ProgressRow(symbol: "3.circle.fill", text: "Build streaks without turning your life into a grind.")

            if Calendar.current.component(.weekday, from: .now) == 1 {
                Label("Sunday unlocks a second optional challenge for bonus XP.", systemImage: "sun.max.fill")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTone)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 34))
                .foregroundStyle(secondaryTone)
            Text("No challenge yet")
                .font(.headline)
            Text("Once location is available, the app generates a nearby place using on-device MapKit search.")
                .multilineTextAlignment(.center)
                .foregroundStyle(secondaryTone)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func challengeMap(for challenge: DailyChallenge) -> some View {
        let destination = CLLocationCoordinate2D(latitude: challenge.latitude, longitude: challenge.longitude)

        Map(initialPosition: .region(challenge.regionSpan), interactionModes: [.all]) {
            Marker(challenge.placeName, systemImage: challenge.symbolName, coordinate: destination)

            if locationManager.currentLocation != nil {
                UserAnnotation()
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if challenge.completedAt != nil {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
    }

    private var permissionTitle: String {
        switch locationManager.status {
        case .idle:
            return "Location unlocks nearby challenges"
        case .denied:
            return "Location access is off"
        case .authorized:
            return "Today’s route is ready"
        }
    }

    private var permissionSymbol: String {
        switch locationManager.status {
        case .idle:
            return "location.magnifyingglass"
        case .denied:
            return "location.slash.fill"
        case .authorized:
            return "location.fill"
        }
    }

    private var permissionMessage: String {
        switch locationManager.status {
        case .idle:
            return "The app only needs your current area to generate a short walk to a useful nearby place."
        case .denied:
            return "Turn location back on to generate local adventures and unlock check-in."
        case .authorized:
            return "Get close to the place for partial credit, or hit the exact spot for full reward."
        }
    }

    private var preferredRadiusLabel: String {
        if preferredRadiusMeters >= 1000 {
            return String(format: "%.1f km range", preferredRadiusMeters / 1000)
        }
        return "\(Int(preferredRadiusMeters)) m range"
    }

    private var todayLoadLabel: String {
        Calendar.current.component(.weekday, from: .now) == 1 ? "2 on Sunday" : "1 today"
    }

    private func generateChallenges(forceSelection: Bool) async {
        guard !isGenerating else { return }
        guard let currentLocation = locationManager.currentLocation else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            try await generator.ensureChallenges(
                in: modelContext,
                around: currentLocation,
                preferredRadius: preferredRadiusMeters
            )
            generationError = nil

            if forceSelection || selectedChallenge == nil {
                selectedChallenge = todaysChallenges.first
            }
        } catch {
            generationError = "Could not load nearby places right now."
        }
    }

    private func complete(_ challenge: DailyChallenge, note: String, imageData: Data?) {
        guard challenge.completedAt == nil else { return }
        let eligibility = locationManager.eligibility(for: challenge)
        guard eligibility != .none else { return }

        challenge.completedAt = .now
        challenge.proofNote = note
        challenge.completionKind = eligibility == .exact ? .exact : .nearby

        if let imageData, let imagePath = try? ProofPhotoStore.save(imageData, for: challenge.id) {
            challenge.proofImagePath = imagePath
        }

        try? modelContext.save()
    }

    private var primaryTone: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.9)
    }

    private var secondaryTone: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.5)
    }
}

private struct HistoryTab: View {
    @Environment(\.colorScheme) private var colorScheme
    let allChallenges: [DailyChallenge]

    private var completedChallenges: [DailyChallenge] {
        allChallenges.filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var weeklyCompletionCount: Int {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return completedChallenges.filter { challenge in
            guard let completedAt = challenge.completedAt else { return false }
            return completedAt >= start
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        HistoryMetric(title: "This Week", value: "\(weeklyCompletionCount)", symbol: "calendar")
                        HistoryMetric(title: "Total", value: "\(completedChallenges.count)", symbol: "shoeprints.fill")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Completed Adventures") {
                    if completedChallenges.isEmpty {
                        Label("Your finished walks will appear here.", systemImage: "figure.walk.arrival")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(completedChallenges) { challenge in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Label(challenge.placeName, systemImage: challenge.symbolName)
                                    .font(.headline)
                                    .foregroundStyle(primaryTone)
                                Spacer()
                                Text(challenge.completedAt ?? challenge.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(challenge.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                InfoTag(symbolName: "bolt.fill", text: "\(challenge.awardedXP) XP")
                                InfoTag(symbolName: "timer", text: "\(challenge.targetMinutes) min")
                                if challenge.proofImagePath != nil {
                                    InfoTag(symbolName: "photo.fill", text: "Proof")
                                }
                                if let completionKind = challenge.completionKind {
                                    InfoTag(
                                        symbolName: completionKind == .exact ? "scope" : "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                                        text: completionKind == .exact ? "Exact" : "Nearby"
                                    )
                                }
                            }

                            if challenge.proofNote.isEmpty == false {
                                Label(challenge.proofNote, systemImage: "text.bubble.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var primaryTone: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.88)
    }
}

private struct SettingsTab: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var preferredRadiusMeters: Double
    @Binding var dailyReminderHour: Int
    @Binding var dailyReminderMinute: Int
    @Binding var remindersEnabled: Bool
    @ObservedObject var reminderManager: ReminderManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge Range") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(rangeLabel, systemImage: "ruler")
                            .foregroundStyle(primaryTone)
                        Slider(value: $preferredRadiusMeters, in: 500...2000, step: 250)
                    }
                }

                Section("Reminder") {
                    Toggle(isOn: $remindersEnabled) {
                        Label("Daily reminder", systemImage: "bell.badge.fill")
                            .foregroundStyle(primaryTone)
                    }

                    DatePicker(
                        "Reminder time",
                        selection: reminderDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(remindersEnabled == false)

                    Label(reminderStatusText, systemImage: reminderStatusSymbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About This Build") {
                    Label("Proof is a quick note plus optional photo for now.", systemImage: "photo.badge.checkmark")
                    Label("Use safe public places only.", systemImage: "shield.lefthalf.filled")
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var rangeLabel: String {
        if preferredRadiusMeters >= 1000 {
            return String(format: "Search within %.1f km", preferredRadiusMeters / 1000)
        }
        return "Search within \(Int(preferredRadiusMeters)) m"
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: dailyReminderHour,
                    minute: dailyReminderMinute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyReminderHour = components.hour ?? 18
                dailyReminderMinute = components.minute ?? 15
            }
        )
    }

    private var reminderStatusText: String {
        switch reminderManager.authorizationStatus {
        case .authorized, .provisional:
            return "Notification permission is available."
        case .denied:
            return "Notification permission is denied in system settings."
        case .notDetermined:
            return "Permission will be requested when you enable reminders."
        case .ephemeral:
            return "Temporary notification access is active."
        @unknown default:
            return "Notification status is unknown."
        }
    }

    private var reminderStatusSymbol: String {
        switch reminderManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined:
            return "bell.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var primaryTone: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.88)
    }
}

private struct CompletionSheet: View {
    let challenge: DailyChallenge
    let onSave: (_ note: String, _ imageData: Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Complete \(challenge.placeName)", systemImage: challenge.symbolName)
                        .font(.headline)

                    Text(challenge.prompt)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        InfoTag(symbolName: "scope", text: "Exact: \(Int(challenge.exactRadiusMeters)) m")
                        InfoTag(symbolName: "figure.walk.motion", text: "Nearby: \(Int(challenge.nearbyRadiusMeters)) m")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Reward logic", systemImage: "gift.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Hit the exact place for \(challenge.rewardXP) XP. If you get near the area but miss the pin, you still earn \(challenge.nearbyRewardXP) XP.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("What did you notice?", systemImage: "text.bubble.fill")
                            .font(.subheadline.weight(.semibold))
                        TextField("A quick line about the walk, place, or mood", text: $note, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Optional proof photo", systemImage: "photo.badge.plus")
                            .font(.subheadline.weight(.semibold))

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedPhotoData == nil ? "Pick Photo" : "Change Photo", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(note.trimmingCharacters(in: .whitespacesAndNewlines), selectedPhotoData)
                        dismiss()
                    }
                }
            }
        }
        .task(id: selectedPhotoItem) {
            selectedPhotoData = try? await selectedPhotoItem?.loadTransferable(type: Data.self)
        }
    }
}

private struct ChallengeCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let challenge: DailyChallenge
    let distance: CLLocationDistance?
    let isSelected: Bool
    let eligibility: LocationManager.CheckInEligibility
    let onSelect: () -> Void
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label(challenge.title, systemImage: challenge.symbolName)
                    .font(.headline)
                    .foregroundStyle(primaryTone)
                Spacer()
                if challenge.isBonus {
                    Text("Bonus")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                }
            }

            Text(challenge.detail)
                .font(.subheadline)

            Label(challenge.prompt, systemImage: "sparkle.magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                InfoTag(symbolName: "mappin.and.ellipse", text: challenge.placeName)
                InfoTag(symbolName: "figure.walk", text: distanceText)
                InfoTag(symbolName: "bolt.fill", text: xpLabel)
            }

            HStack(spacing: 12) {
                Button {
                    onSelect()
                } label: {
                    Label(isSelected ? "Viewing on Map" : "Show on Map", systemImage: "map.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onCheckIn()
                } label: {
                    Label(checkInTitle, systemImage: checkInSymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryTone)
                .disabled(eligibility == .none || challenge.completedAt != nil)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var primaryTone: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.88)
    }

    private var distanceText: String {
        guard let distance else { return "Need location" }

        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var checkInTitle: String {
        if challenge.completedAt != nil {
            return "Completed"
        }

        switch eligibility {
        case .exact:
            return "Full Check In"
        case .nearby:
            return "Nearby Check In"
        case .none:
            return "Get Closer"
        }
    }

    private var checkInSymbol: String {
        if challenge.completedAt != nil {
            return "checkmark.circle.fill"
        }

        switch eligibility {
        case .exact:
            return "flag.checkered.circle.fill"
        case .nearby:
            return "figure.walk.arrival"
        case .none:
            return "location.north.line.fill"
        }
    }

    private var xpLabel: String {
        switch eligibility {
        case .exact:
            return "\(challenge.rewardXP) XP"
        case .nearby:
            return "\(challenge.nearbyRewardXP)-\(challenge.rewardXP) XP"
        case .none:
            return "\(challenge.nearbyRewardXP)-\(challenge.rewardXP) XP"
        }
    }
}

private struct InfoTag: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbolName: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbolName)
            .font(.caption)
            .foregroundStyle(primaryTone)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private var primaryTone: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.78)
    }
}

private struct ProgressRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbolName)
                .font(.caption)
                .foregroundStyle(secondaryTone)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var secondaryTone: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.45)
    }
}

private struct HistoryMetric: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(secondaryTone)
            Text(value)
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var secondaryTone: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.45)
    }
}

private extension DailyChallenge {
    var regionSpan: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DailyChallenge.self], inMemory: true)
}
