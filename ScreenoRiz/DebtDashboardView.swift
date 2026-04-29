//
//  DebtDashboardView.swift
//  ScreenoRiz
//

import SwiftUI
import Charts
import Combine

struct DebtDashboardView: View {
    @EnvironmentObject var appState: AppState

    // Live debt from the shield system (updated by the monitor after each overage session)
    @State private var shieldDebt: Double = 0

    // Refresh every 30 seconds so the displayed value stays current
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private let rates: [Double] = [0.5, 1, 2, 3, 4, 5, 10]
    @State private var rateIndex: Int = 1

    private var today: Date { .now }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                todayCard
                weeklyCard
                rateCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: refresh)
        .onReceive(refreshTimer) { _ in refresh() }
    }

    // MARK: – Today's debt

    private var todayCard: some View {
        let computed = appState.getTotalDonation(for: today)
        let displayed = max(computed, shieldDebt)
        return VStack(alignment: .leading, spacing: 8) {
            Text("борг за сьогодні")
                .font(.ktfCaption)
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(displayed))")
                    .font(.ktfTitleLarge)
                    .foregroundColor(.white)
                Text("₴")
                    .font(.ktfTitle)
                    .foregroundColor(Color(hex: "#E94200"))
            }
            Text("× \(appState.ratePerMinute.formatted(.number.precision(.fractionLength(1))))₴/хв")
                .font(.ktfCaption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: – Weekly breakdown

    private var weeklyCard: some View {
        let days = appState.getDailyDebtForWeek(for: today)
        let weekTotal = days.map(\.amount).reduce(0, +)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("цей тиждень")
                    .font(.ktfCaption)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(Int(weekTotal))₴")
                    .font(.ktfBody)
                    .foregroundColor(Color(hex: "#E94200"))
            }
            Chart(days, id: \.date) { item in
                BarMark(
                    x: .value("День", item.date, unit: .day),
                    y: .value("₴", item.amount)
                )
                .foregroundStyle(
                    Calendar.current.isDate(item.date, inSameDayAs: today)
                        ? Color(hex: "#E94200")
                        : Color.white.opacity(0.3)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))₴").foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: – Rate picker

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ставка за хвилину")
                .font(.ktfCaption)
                .foregroundColor(.white.opacity(0.5))
            HStack {
                Text("1хв =")
                    .font(.ktfBody)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(rates[rateIndex].formatted(.number.precision(.fractionLength(rates[rateIndex] < 1 ? 1 : 0))))₴")
                    .font(.ktfTitle)
                    .foregroundColor(Color(hex: "#E94200"))
            }
            Slider(
                value: Binding(
                    get: { Double(rateIndex) },
                    set: { rateIndex = Int($0.rounded()); applyRate() }
                ),
                in: 0...Double(rates.count - 1),
                step: 1
            )
            .tint(Color(hex: "#E94200"))
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            let current = appState.ratePerMinute
            rateIndex = rates.firstIndex(where: { $0 == current }) ?? 1
        }
    }

    // MARK: – Helpers

    private func refresh() {
        shieldDebt = appState.sharedDefaults.double(forKey: "dailyDebtUAH")
    }

    private func applyRate() {
        appState.ratePerMinute = rates[rateIndex]
    }
}


#Preview {
    DebtDashboardView()
        .environmentObject(AppState())
}
