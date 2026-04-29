# ScreenoRiz

Ukrainian iOS app that converts social media screen time overage into charitable donations.

## Project Overview

**Core concept:** Users set daily limits for social media apps. Every minute over the limit becomes a monetary "debt" (in UAH) that should be donated to charity.

**Status:** In development. ScreenTime API integration is not yet implemented — time logging is manual. Donation verification is also manual.

## Tech Stack

- **Platform:** iOS 16+
- **Language:** Swift
- **UI:** SwiftUI
- **Architecture:** MVVM with `ObservableObject` / `@EnvironmentObject`
- **Persistence:** UserDefaults (no database)
- **Charts:** iOS 16 Charts framework
- **Font:** KTFPrima (custom .otf — Light & Regular)

## Project Structure

```
ScreenoRiz/
├── ScreenoRizApp.swift       # Entry point, forces dark mode
├── ContentView.swift         # Root: routes between onboarding and main app
├── AppState.swift            # Central state (ObservableObject), all UserDefaults logic
├── CustomTabBar.swift        # Shared tab bar with floating "+" button
├── Font+KTFPrima.swift       # Font extension helpers
│
├── Onboarding flow:
│   ├── SplashView.swift
│   ├── WelcomeView.swift
│   ├── AppSelectionView.swift
│   ├── LimitSelectionView.swift
│   ├── RateSelectionView.swift
│   ├── InfoView.swift
│   └── PermissionsView.swift
│
└── Main app:
    ├── HomeView.swift         # Two tabs: Overview (usage/chart) + Settings
    ├── CharitiesView.swift    # Hardcoded list of 3 Ukrainian charities
    └── Charity.swift          # Charity data model
```

## Design System

- **Background:** Black (dark mode always on)
- **Accent color:** `#F55426` (orange-red)
- **Typography:** KTFPrima font — use `Font.ktfTitleLarge`, `.ktfTitle`, `.ktfBody`, etc.
- **Cards:** Rounded corners, `Color.white.opacity(x)` backgrounds
- **Layout:** Card grids, bottom sheets for input, full-screen covers for navigation

## Key State (AppState)

- `selectedApps: [SocialApp]` — user-selected social media apps
- `dailyLimitMinutes: Int` — daily time limit
- `donationRate: Int` — UAH per minute over limit (1–5)
- `usageHistory: [dateString: [appName: minutes]]` — manual time log
- `isOnboardingComplete: Bool`

**Important calculations:**
- `getDonationAmount()` — excess minutes × rate for today
- `getWeeklyDebt()` — sum of daily donations this week
- `getDailyDebtForWeek()` — array for the weekly chart

## Supported Apps

`SocialApp` enum: Instagram, TikTok, Twitter/X, Threads, Facebook, Telegram, YouTube, OLX. Custom logo assets exist for Instagram, TikTok, Twitter, and Threads.

## Language

All UI text is in Ukrainian.
