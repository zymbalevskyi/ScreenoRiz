//
//  HomeView.swift
//  ScreenoRiz
//

import SwiftUI
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Screen Time Severity

private enum ScreenTimeSeverity: Equatable {
    case none, low, medium, high

    init(minutes: Int) {
        switch minutes {
        case 0: self = .none
        case 1..<90: self = .low
        case 90..<240: self = .medium
        default: self = .high
        }
    }

    var activeDots: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var color: Color {
        switch self {
        case .none: return .white.opacity(0.4)
        case .low: return Color(hex: "24835B")
        case .medium: return Color(hex: "F5A623")
        case .high: return Color(hex: "E94200")
        }
    }
}

private struct SeverityDots: View {
    let severity: ScreenTimeSeverity
    var dotSize: CGFloat = 5
    var noneColor: Color = Color(hex: "292929")

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        severity == .none
                            ? noneColor
                            : (i < severity.activeDots ? severity.color : Color.white.opacity(0.15))
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false
    @State private var showAddApp = false
    @State private var detailItem: AppDetailItem?
    @State private var isRefreshing: Bool = false
    @State private var isSheetExpanded: Bool = false
    @State private var sheetDragTranslation: CGFloat = 0

    private var sortedTokens: [(key: String, token: ApplicationToken)] {
        appState.activitySelection.applicationTokens
            .map { (key: appState.tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }
    }

    // MARK: - Week helpers

    private var currentWeekDays: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysToMonday = weekday == 1 ? 6 : weekday - 2
        guard let monday = cal.date(byAdding: .day, value: -daysToMonday, to: today) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private static let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]

    private func severityFor(_ date: Date) -> ScreenTimeSeverity {
        ScreenTimeSeverity(minutes: appState.getTotalMinutes(on: date))
    }

    private var isBeforeFirstUse: Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: currentDate) < cal.startOfDay(for: appState.firstUsedDate)
    }

    // MARK: - Body

    var body: some View {
        Color.black.ignoresSafeArea()
            .overlay {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    weekCalendarStrip
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    if isBeforeFirstUse {
                        noDataView
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                UIKitRefreshControl(isRefreshing: $isRefreshing) {
                                    appState.objectWillChange.send()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        isRefreshing = false
                                    }
                                }
                                .frame(width: 0, height: 0)

                                if isRefreshing {
                                    ThreeBallsTriangle(color: Color(hex: "E94200"), size: 32)
                                        .frame(height: 50)
                                        .frame(maxWidth: .infinity)
                                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                }

                                VStack(spacing: 8) {
                                    screenTimeSummary
                                        .padding(.horizontal, 16)

                                    appsGrid2Col
                                        .padding(.horizontal, 16)
                                }
                                .padding(.bottom, 200)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                expandableBottomSheet
                    .ignoresSafeArea(edges: .bottom)
            }
            .task { appState.resolveDisplayNames() }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(showAddApp: $showAddApp, currentDate: currentDate)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showAddApp) {
                NavigationStack {
                    FamilyActivityPicker(selection: $appState.activitySelection)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("готово") { showAddApp = false }
                            }
                        }
                }
            }
            .sheet(item: $detailItem) { detail in
                AppDetailSheet(item: detail, currentDate: currentDate)
                    .environmentObject(appState)
            }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Image("header-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
            Spacer()
            Button { showSettings = true } label: {
                Image("icon-gear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(hex: "292929")))
            }
        }
    }

    // MARK: - Week calendar strip

    private var weekCalendarStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(currentWeekDays.enumerated()), id: \.offset) { index, day in
                let cal = Calendar.current
                let isToday = cal.isDateInToday(day)
                let isSelected = cal.isDate(day, inSameDayAs: currentDate)
                let isFuture = day > cal.startOfDay(for: Date())
                let dayNum = cal.component(.day, from: day)
                let label = Self.weekdayLabels[index]
                let severity = severityFor(day)

                Button {
                    currentDate = day
                } label: {
                    VStack(spacing: 0) {
                        Text(label)
                            .font(.ktfCaptionSmall)
                            .foregroundStyle(
                                severity == .none
                                    ? (isToday ? .white : Color(hex: "5E5E5E"))
                                    : severity.color
                            )
                            .frame(height: 18)

                        Text("\(dayNum)")
                            .font(.ktfBody)
                            .foregroundStyle(severity == .none ? Color.white.opacity(0.28) : severity.color)
                            .frame(width: 32, height: 32)

                        SeverityDots(severity: severity, dotSize: 5,
                                     noneColor: isFuture ? Color(hex: "191919") : Color(hex: "292929"))
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected || isToday {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isToday ? Color(hex: "191919") : Color.clear)
                                .overlay {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(hex: "292929"), lineWidth: 1.5)
                                    }
                                }
                                .padding(.horizontal, 2.5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Screen time summary

    private var screenTimeSummary: some View {
        let mins = totalMinutes
        let severity = ScreenTimeSeverity(minutes: mins)
        let pct = mins > 0 ? min(100, mins * 100 / 960) : 0

        return VStack(alignment: .leading, spacing: 20) {
            Text("ЗАГАЛЬНИЙ ЕКРАННИЙ ЧАС")
                .font(.ktfCaption)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .center) {
                Text(fmtMinutes(mins))
                    .font(.ktfTitle)
                    .foregroundStyle(.white)
                Spacer()
                if mins > 0 {
                    HStack(spacing: 6) {
                        SeverityDots(severity: severity, dotSize: 6)
                        Text("\(pct)% дня")
                            .font(.ktfBody)
                            .foregroundStyle(severity.color)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "121212")))
    }

    // MARK: - 2-column app grid

    private var appsGrid2Col: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ОБМЕЖЕНІ АПКИ")
                .font(.ktfCaption)
                .foregroundStyle(.white.opacity(0.8))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(sortedTokens, id: \.key) { item in
                    AppGridCard2Col(
                        tokenKey: item.key,
                        token: item.token,
                        date: currentDate
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        detailItem = AppDetailItem(id: item.key, token: item.token)
                    }
                }

                addAppGridButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "121212")))
    }

    private var addAppGridButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddApp = true
        } label: {
            VStack(spacing: 18) {
                Image("icon-add-app")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 38, height: 38)

                Text("додати застосунок")
                    .font(.ktfCaption)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expandable Bottom Sheet

    private let sheetCollapsedHeight: CGFloat = 140
    private var sheetExpandedHeight: CGFloat { UIScreen.main.bounds.height * 0.88 }
    private var sheetTravel: CGFloat { sheetExpandedHeight - sheetCollapsedHeight }
    private var sheetOffset: CGFloat {
        let base: CGFloat = isSheetExpanded ? 0 : sheetTravel
        return max(0, min(sheetTravel, base + sheetDragTranslation))
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                sheetDragTranslation = value.translation.height
            }
            .onEnded { value in
                let t = value.translation.height
                let predicted = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    if isSheetExpanded {
                        if t > 60 || predicted > 120 { isSheetExpanded = false }
                    } else {
                        if t < -60 || predicted < -120 { isSheetExpanded = true }
                    }
                    sheetDragTranslation = 0
                }
            }
    }

    @ViewBuilder
    private var expandableBottomSheet: some View {
        let sheetShape = UnevenRoundedRectangle(
            topLeadingRadius: 34, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 34
        )

        VStack(spacing: 0) {
            // ── Draggable header — fixed height pins the ScrollView below the
            //    collapsed fold so charity cards never peek into collapsed state.
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("сума донату")
                            .font(.ktfTitle)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("накопичено за цей тиждень")
                            .font(.ktfCaption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(charitiesAmount)
                        .font(.custom("KTFPrima-Light", size: 20))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Tappable text-divider row — replaces the old button
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        isSheetExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                        Text("куди задонатити ?")
                            .font(.ktfCaption)
                            .foregroundStyle(.white.opacity(0.35))
                            .fixedSize()
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .frame(height: sheetCollapsedHeight, alignment: .top)
            .clipped()
            .highPriorityGesture(sheetDragGesture)

            // ── Charity cards ─────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Charity.all) { jar in JarCard(jar: jar) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollDisabled(!isSheetExpanded)
            .opacity(isSheetExpanded ? 1 : 0)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSheetExpanded)
        }
        .frame(height: sheetExpandedHeight)
        .background {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular.interactive(), in: sheetShape)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                sheetShape
                    .fill(Color(hex: "292929"))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .offset(y: sheetOffset)
    }

    // MARK: - No-data state

    private var noDataView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image("nodata-illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 303)
                Text("у цей день ми\nще не збирали данні")
                    .font(.ktfTitle)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, sheetCollapsedHeight)
    }

    // MARK: - Helpers

    private var totalMinutes: Int {
        appState.getTotalMinutes(on: currentDate)
    }

    private func fmtMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }

    private var charitiesAmount: String {
        let amount = appState.getWeeklyDebt(for: currentDate)
        return amount.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(amount)) ₴"
            : String(format: "%.1f ₴", amount)
    }
}

// MARK: - 2-Column App Grid Card

struct AppGridCard2Col: View {
    @EnvironmentObject var appState: AppState
    let tokenKey: String
    let token: ApplicationToken
    let date: Date

    @State private var showTimeSplit: Bool = false

    private var limitMinutes: Int { appState.appLimits[tokenKey] ?? 15 }
    private var effectiveLimit: Int { limitMinutes }

    private var usedMinutes: Int {
        appState.getMinutes(forTokenKey: tokenKey, on: date)
    }

    private var overLimit: Bool { usedMinutes >= effectiveLimit }

    private var appDebt: Double {
        let excess = max(0, usedMinutes - effectiveLimit)
        return Double(excess) * appState.ratePerMinute
    }

    private var pieProgress: Double {
        guard effectiveLimit > 0 else { return 0 }
        return min(1.0, Double(usedMinutes) / Double(effectiveLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let name = appState.tokenDisplayNames[tokenKey], !name.isEmpty {
                        Text(name)
                    } else {
                        Label(token).labelStyle(.titleOnly)
                    }
                }
                .font(.ktfTitleSmall)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .center) {
                Text(bottomText)
                    .font(.ktfCaption)
                    .foregroundStyle(appDebt > 0 ? Color(hex: "E94200") : Color(hex: "24835B"))
                    .lineLimit(1)
                    .onTapGesture {
                        if appDebt > 0 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showTimeSplit.toggle()
                        }
                    }
                Spacer(minLength: 4)
                progressIndicator
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black))
    }

    @ViewBuilder
    private var progressIndicator: some View {
        if overLimit {
            ZStack {
                Circle().fill(Color(hex: "E94200"))
                Image("icon-screentime")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .frame(width: 28, height: 28)
        } else if usedMinutes > 0 {
            ZStack {
                Circle().fill(Color(hex: "24835B").opacity(0.25))
                PieShape(progress: pieProgress).fill(Color(hex: "24835B"))
            }
            .frame(width: 28, height: 28)
        } else {
            Circle()
                .fill(Color(hex: "292929"))
                .frame(width: 28, height: 28)
        }
    }

    private var bottomText: String {
        if appDebt > 0 {
            if showTimeSplit {
                return "\(fmt(usedMinutes)) / \(fmt(effectiveLimit))"
            }
            return appDebt.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(appDebt)) ₴ донату"
                : String(format: "%.1f ₴ донату", appDebt)
        }
        return "\(fmt(usedMinutes)) / \(fmt(effectiveLimit))"
    }

    private func fmt(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }

}

// MARK: - Pie Shape

private struct PieShape: Shape {
    let progress: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var showAddApp: Bool
    let currentDate: Date
    @Environment(\.dismiss) var dismiss

    private let rates: [Double] = [0.5, 1, 2, 3, 4, 5]
    @State private var selectedRate: Double = 1
    @State private var showPickerInSheet = false
    @State private var detailItem: AppDetailItem?
    @Namespace private var pillNamespace

    private var sortedTokens: [(key: String, token: ApplicationToken)] {
        appState.activitySelection.applicationTokens
            .map { (key: appState.tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("налаштування")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                // Tracked apps
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("відстежувані застосунки")
                            .font(.ktfCaption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button { showPickerInSheet = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color(hex: "292929")))
                        }
                    }
                    .padding(.bottom, 8)

                    List {
                        ForEach(sortedTokens, id: \.key) { item in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                detailItem = AppDetailItem(id: item.key, token: item.token)
                            } label: {
                                HStack {
                                    Group {
                                        if let name = appState.tokenDisplayNames[item.key] {
                                            Text(name)
                                        } else {
                                            Label(item.token).labelStyle(.titleOnly)
                                        }
                                    }
                                    .font(.ktfBody)
                                    .foregroundStyle(.white)
                                    Spacer()
                                    Image("icon-arrow-right")
                                        .resizable().frame(width: 14, height: 14)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .frame(minHeight: 60)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "292929")))
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeToken(item.token)
                                } label: {
                                    Label("видалити", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listRowSpacing(2)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(sortedTokens.count) * 60 + CGFloat(max(sortedTokens.count - 1, 0)) * 2)
                }

                // Rate
                VStack(alignment: .leading, spacing: 8) {
                    Text("тариф")
                        .font(.ktfCaption)
                        .foregroundStyle(.white.opacity(0.5))

                    VStack(spacing: 12) {
                        Text("1 хвилина дорівнює")
                            .font(.ktfBody)
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            ForEach(rates, id: \.self) { rate in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        selectedRate = rate
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    appState.ratePerMinute = rate
                                } label: {
                                    Text(rateLabel(rate, active: rate == selectedRate))
                                        .font(.ktfBody)
                                        .foregroundStyle(.white.opacity(rate == selectedRate ? 1 : 0.45))
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background {
                                            if rate == selectedRate {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(hex: "292929"))
                                                    .matchedGeometryEffect(id: "settingsPill", in: pillNamespace)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212").opacity(0.88))
                            }
                            .environment(\.colorScheme, .dark)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "292929")))
                }

                // Difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text("рівень складності")
                        .font(.ktfCaption)
                        .foregroundStyle(.white.opacity(0.5))

                    VStack(spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("середній")
                                    .font(.ktfTitle)
                                    .foregroundStyle(.white)
                                Text("ми лише рахуємо вам суму, ви\nдонатите на власний розсуд")
                                    .font(.ktfCaption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 28, height: 28)
                                Image("icon-check")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.black)
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "292929")))

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("важкий")
                                        .font(.ktfTitle)
                                        .foregroundStyle(.white)
                                    Text("СКОРО")
                                        .font(.ktfCaption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "121212")))
                                }
                                Text("додамо платіжну систему для\nдонатів та блокування застосунків")
                                    .font(.ktfCaption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Image("icon-lock")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 24, height: 24)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "292929")))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackgroundCompat(Color(hex: "121212"))
        .floatingSheetStyle()
        .onAppear {
            selectedRate = appState.ratePerMinute
            appState.resolveDisplayNames()
        }
        .sheet(isPresented: $showPickerInSheet) {
            NavigationStack {
                FamilyActivityPicker(selection: $appState.activitySelection)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("готово") { showPickerInSheet = false }
                        }
                    }
            }
        }
        .sheet(item: $detailItem) { detail in
            AppDetailSheet(item: detail, currentDate: currentDate)
                .environmentObject(appState)
        }
    }

    private func rateLabel(_ rate: Double, active: Bool = false) -> String {
        let num = rate.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rate))"
            : String(format: "%.1f", rate)
        return active ? "\(num)₴" : num
    }

    private func removeToken(_ token: ApplicationToken) {
        var selection = appState.activitySelection
        selection.applicationTokens.remove(token)
        appState.activitySelection = selection
        appState.appLimits.removeValue(forKey: appState.tokenKey(token))
    }
}


#Preview {
    HomeView()
        .environmentObject(AppState())
}
