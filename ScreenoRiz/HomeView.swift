//
//  HomeView.swift
//  ScreenoRiz
//

import SwiftUI
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentDate: Date = Date()
    @State private var period: Period = .day
    @State private var showSettings = false
    @State private var showCharities = false
    @State private var showAddApp = false
    @State private var detailItem: AppDetailItem?
    @State private var isRefreshing: Bool = false

    enum Period { case day, week }

    private var sortedTokens: [(key: String, token: ApplicationToken)] {
        appState.activitySelection.applicationTokens
            .map { (key: appState.tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        Color.black.ignoresSafeArea()
            .overlay {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 0) {
                            // UIKit bridge — transparent UIRefreshControl for gesture detection
                            UIKitRefreshControl(isRefreshing: $isRefreshing) {
                                appState.objectWillChange.send()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    isRefreshing = false
                                }
                            }
                            .frame(width: 0, height: 0)

                            // Custom indicator visible while refreshing
                            if isRefreshing {
                                ThreeBallsTriangle(color: Color(hex: "E94200"), size: 32)
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }

                            appsGrid
                                .padding(.horizontal, 16)
                                .padding(.bottom, 220)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        periodToggle
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        bottomSection
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(showAddApp: $showAddApp)
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
        .sheet(isPresented: $showCharities) {
            CharitiesView(donationAmount: charitiesAmount)
        }
        .sheet(item: $detailItem) { detail in
            AppDetailSheet(item: detail, currentDate: currentDate)
                .environmentObject(appState)
        }
    }

    // MARK: Top bar (logo + date nav + settings)

    private var topBar: some View {
        HStack(spacing: 0) {
            Image("illus-knife")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)

            Spacer()

            HStack(spacing: 4) {
                Button { changeDate(by: period == .week ? -7 : -1) } label: {
                    Image("icon-arrow-left")
                        .resizable().frame(width: 14, height: 14)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                }

                Text(dateText)
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .fixedSize()

                Button { changeDate(by: period == .week ? 7 : 1) } label: {
                    Image("icon-arrow-right")
                        .resizable().frame(width: 14, height: 14)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                }
            }

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

    // MARK: Apps grid

    private var appsGrid: some View {
        VStack(spacing: 8) {
            totalScreenTimeCard

            ForEach(sortedTokens, id: \.key) { item in
                AppGridCard(
                    tokenKey: item.key,
                    token: item.token,
                    date: currentDate,
                    period: period
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    detailItem = AppDetailItem(id: item.key, token: item.token)
                }
            }

            addAppCell
        }
    }

    private var totalScreenTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Загальний екранний час")
                .font(.ktfBody)
                .foregroundStyle(.white)
            HStack(alignment: .firstTextBaseline) {
                Text(fmtMinutes(totalMinutes))
                    .font(.ktfTitle)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(min(100, totalMinutes * 100 / 1440))% дня")
                    .font(.ktfBody)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
    }

    private var totalMinutes: Int {
        if period == .day {
            return appState.getTotalMinutes(on: currentDate)
        }
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start else { return 0 }
        return (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .map { appState.getTotalMinutes(on: $0) }
            .reduce(0, +)
    }

    private func fmtMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }

    private var addAppCell: some View {
        Button { showAddApp = true } label: {
            HStack(spacing: 12) {
                Image("icon-add-app")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white.opacity(0.5))
                Text("додати застосунок")
                    .font(.ktfBody)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
        }
    }

    // MARK: Bottom section (fixed)

    private let sectionShape = UnevenRoundedRectangle(
        topLeadingRadius: 34, bottomLeadingRadius: 0,
        bottomTrailingRadius: 0, topTrailingRadius: 34
    )

    @ViewBuilder
    private var bottomSection: some View {
        if #available(iOS 26.0, *) {
            donationCard
                .background {
                    Color.clear
                        .glassEffect(.regular.interactive(), in: sectionShape)
                        .ignoresSafeArea(edges: .bottom)
                }
        } else {
            donationCard
                .background {
                    sectionShape
                        .fill(Color(hex: "292929"))
                        .ignoresSafeArea(edges: .bottom)
                }
        }
    }

    private var periodToggle: some View {
        HStack(spacing: 0) {
            periodOption("день", isSelected: period == .day) { period = .day }
            periodOption("тиждень", isSelected: period == .week) { period = .week }
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

    private func periodOption(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.ktfBody)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if isSelected {
                        // Concentric radius: outer 16 − padding 4 = 12
                        RoundedRectangle(cornerRadius: 12).fill(Color(hex: "292929"))
                    }
                }
        }
    }

    private var charitiesAmount: String {
        let amount: Double = period == .day
            ? appState.getTotalDonation(for: currentDate)
            : appState.getWeeklyDebt(for: currentDate)
        return amount.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(amount)) ₴"
            : String(format: "%.1f ₴", amount)
    }

    private var donationCard: some View {
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("сума донату")
                        .font(.ktfTitle)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("можете і більше, звісно")
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
            .padding(.bottom, 24)

            Button { showCharities = true } label: {
                Text("переглянути фонди та збори")
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 100).fill(Color(hex: "292929")))
            }
            .padding(.horizontal, 18)
        }
    }

    // MARK: Helpers

    private static let monthAbbreviations: [Int: String] = [
        1: "січ.", 2: "лют.", 3: "берез.", 4: "квіт.",
        5: "трав.", 6: "черв.", 7: "лип.", 8: "серп.",
        9: "верес.", 10: "жовт.", 11: "листоп.", 12: "груд."
    ]

    private static func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        return "\(day) \(monthAbbreviations[month] ?? "")"
    }

    private var dateText: String {
        if period == .week {
            let calendar = Calendar.current
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start,
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
                return Self.shortDate(currentDate)
            }
            return "\(Self.shortDate(weekStart)) – \(Self.shortDate(weekEnd))"
        }
        return Calendar.current.isDateInToday(currentDate)
            ? "сьогодні"
            : Self.shortDate(currentDate)
    }

    private func changeDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.startOfDay(for: newDate) <= today {
            currentDate = newDate
        }
    }
}

// MARK: - App Grid Card

struct AppGridCard: View {
    @EnvironmentObject var appState: AppState
    let tokenKey: String
    let token: ApplicationToken
    let date: Date
    let period: HomeView.Period

    private var limitMinutes: Int { appState.appLimits[tokenKey] ?? 15 }

    private var usedMinutes: Int {
        period == .day
            ? appState.getMinutes(forTokenKey: tokenKey, on: date)
            : weekAggregate { appState.getMinutes(forTokenKey: tokenKey, on: $0) }
    }

    private var effectiveLimit: Int {
        period == .day ? limitMinutes : limitMinutes * 7
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
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Label(token)
                    .labelStyle(AppCardLabelStyle())
                Spacer()
                Text(timeSummary)
                    .font(.ktfBody)
                    .foregroundStyle(overLimit ? Color(hex: "E94200") : Color(hex: "24835B"))
                progressIndicator
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)

            if appDebt > 0 {
                Text(appDebt.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(appDebt)) ₴ донату"
                    : String(format: "%.1f ₴ донату", appDebt))
                    .font(.ktfBody)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                    .background(Color(hex: "292929"))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var progressIndicator: some View {
        if overLimit {
            ZStack {
                Circle().fill(Color(hex: "E94200"))
                Image("icon-screentime")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .frame(width: 32, height: 32)
        } else if usedMinutes > 0 {
            ZStack {
                Circle().fill(Color(hex: "24835B").opacity(0.25))
                PieShape(progress: pieProgress).fill(Color(hex: "24835B"))
            }
            .frame(width: 32, height: 32)
        } else {
            Circle()
                .fill(Color(hex: "292929"))
                .frame(width: 32, height: 32)
        }
    }

    private func fmt(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }

    private var timeSummary: String { "\(fmt(usedMinutes)) / \(fmt(effectiveLimit))" }

    private func weekAggregate(_ getValue: (Date) -> Int) -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        return (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .map(getValue)
            .reduce(0, +)
    }
}

private struct AppCardLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            configuration.title
                .font(.ktfTitleSmall)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

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
    @Environment(\.dismiss) var dismiss

    private let rates: [Double] = [0.5, 1, 2, 3, 4, 5]
    @State private var selectedRate: Double = 1
    @State private var showPickerInSheet = false
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
                                                // Concentric radius: outer 16 − padding 4 = 12
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
                        // Card 1 — середній (selected)
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

                        // Card 2 — важкий (locked)
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
