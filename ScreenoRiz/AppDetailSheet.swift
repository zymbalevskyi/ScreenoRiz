//
//  AppDetailSheet.swift
//  ScreenoRiz
//

import SwiftUI
import Charts
import FamilyControls
import ManagedSettings

// MARK: - Identifiable wrapper

struct AppDetailItem: Identifiable {
    let id: String          // tokenKey
    let token: ApplicationToken
}

// MARK: - Chart data

private struct DayUsage: Identifiable {
    let id: Int             // 0 = Mon … 6 = Sun
    let date: Date
    let minutes: Int
}

// MARK: - Main sheet

struct AppDetailSheet: View {
    @EnvironmentObject var appState: AppState
    let item: AppDetailItem
    let currentDate: Date

    @State private var isLimitExpanded = false
    @State private var limitMinutes: Int = 15
    @State private var pickerHours: Int = 0
    @State private var pickerMinutes: Int = 15
    @State private var selectedDetent: PresentationDetent = .height(500)

    private static let collapsedHeight: CGFloat = 500
    private static let expandedHeight:  CGFloat = 740

    private let hoursRange = Array(0...23)
    private let minutesRange = Array(stride(from: 0, through: 55, by: AppState.limitMinuteStep))

    // MARK: Computed data

    private var weekData: [DayUsage] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: currentDate)?.start
        else { return [] }
        return (0..<7).compactMap { i in
            guard let date = cal.date(byAdding: .day, value: i, to: weekStart) else { return nil }
            return DayUsage(id: i, date: date,
                            minutes: appState.getMinutes(forTokenKey: item.id, on: date))
        }
    }

    private var todayMinutes: Int     { appState.getMinutes(forTokenKey: item.id, on: currentDate) }
    private var weeklyTotal: Int      { weekData.map(\.minutes).reduce(0, +) }
    private var dailyAverage: Double  { Double(weeklyTotal) / 7.0 }

    private var limitTimeText: String {
        let h = limitMinutes / 60, m = limitMinutes % 60
        if h == 0 { return "\(m) хв" }
        if m == 0 { return "\(h) год" }
        return "\(h) год \(m) хв"
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Glass + dark background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Color(hex: "121212").opacity(0.92)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // App name only — no icon (with X→X (Twitter) override)
                    Group {
                        if let name = appState.tokenDisplayNames[item.id] {
                            Text(name)
                                .font(.ktfTitleLarge)
                                .foregroundStyle(.white)
                        } else {
                            Label(item.token)
                                .labelStyle(AppNameOnlyLabelStyle())
                        }
                    }
                    .padding(.top, 20)

                    // Limit row
                    limitRow

                    // Section label
                    Text("екранний час")
                        .font(.ktfCaption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, -8)

                    // Weekly card (big time + chart + average)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(fmtMinutes(weeklyTotal))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.bottom, 12)

                        barChart
                            .frame(height: 140)

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.vertical, 12)

                        HStack {
                            Text("Середнє за день")
                                .font(.ktfBody)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(fmtMinutes(Int(dailyAverage.rounded())))
                                .font(.ktfBody)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents(
            [.height(Self.collapsedHeight), .height(Self.expandedHeight)],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackgroundCompat(Color(hex: "121212"))
        .floatingSheetStyle()
        .onAppear {
            let savedLimit = appState.appLimits[item.id] ?? 15
            limitMinutes = AppState.steppedLimitMinutes(savedLimit)
            if savedLimit != limitMinutes {
                appState.appLimits[item.id] = limitMinutes
            }
            syncPickerToLimit()
            appState.resolveDisplayNames()
        }
    }

    // MARK: Limit row

    @ViewBuilder
    private var limitRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    isLimitExpanded.toggle()
                    selectedDetent = isLimitExpanded
                        ? .height(Self.expandedHeight)
                        : .height(Self.collapsedHeight)
                }
            } label: {
                HStack {
                    Text("ліміт часу")
                        .font(.ktfBody)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(limitTimeText)
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: isLimitExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(16)
            }

            if isLimitExpanded {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    Picker("", selection: $pickerHours) {
                        ForEach(hoursRange, id: \.self) { h in
                            Text("\(h)").foregroundStyle(.white).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("год")
                        .foregroundStyle(.white)
                        .font(.ktfBody)
                        .padding(.horizontal, 8)

                    Picker("", selection: $pickerMinutes) {
                        ForEach(minutesRange, id: \.self) { m in
                            Text("\(m)").foregroundStyle(.white).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("хв")
                        .foregroundStyle(.white)
                        .font(.ktfBody)
                        .padding(.horizontal, 8)
                }
                .onChange(of: pickerHours) { _ in commitLimit() }
                .onChange(of: pickerMinutes) { _ in commitLimit() }
                .padding(.bottom, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private func syncPickerToLimit() {
        limitMinutes = AppState.steppedLimitMinutes(limitMinutes)
        pickerHours = limitMinutes / 60
        pickerMinutes = limitMinutes % 60
    }

    private func commitLimit() {
        let total = AppState.steppedLimitMinutes(pickerHours * 60 + pickerMinutes)
        limitMinutes = total
        pickerHours = total / 60
        pickerMinutes = total % 60
        appState.appLimits[item.id] = total
    }

    // MARK: Chart

    @ViewBuilder
    private var barChart: some View {
        Chart {
            ForEach(weekData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("хв", day.minutes)
                )
                .foregroundStyle(Color(hex: "E94200"))
                .cornerRadius(3)
            }

            if dailyAverage > 0 {
                RuleMark(y: .value("сер", dailyAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .annotation(position: .trailing, alignment: .center) {
                        Text("сер")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.15))
                AxisValueLabel {
                    if let mins = value.as(Double.self) {
                        if mins == 0 {
                            Text("0")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.4))
                        } else if mins >= 60 {
                            Text("\(Int(mins / 60))г")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }

    // MARK: Helpers

    private func fmtMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }
}

// MARK: - Label styles

struct AppDetailLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            configuration.title
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

struct AppNameOnlyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.title
            .font(.ktfTitleLarge)
            .foregroundStyle(.white)
    }
}

// MARK: - Sheet style helpers

extension View {
    @ViewBuilder
    func presentationBackgroundCompat(_ color: Color) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(color)
        } else {
            self
        }
    }

    /// Adds iOS 26-style 8 pt floating margins around the sheet.
    @ViewBuilder
    func floatingSheetStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.presentationSizing(.form)
        } else {
            self
        }
    }
}
