---
name: design_system_conventions
description: Card opacity values, icon sizing, button tap-target sizing, and color conventions observed in the codebase
type: project
---

Card backgrounds use .white.opacity(0.08) for primary cards, .white.opacity(0.06) for secondary/add cells.
Settings gear button: 20×20 icon inside 44×44 tap target with Circle().fill(.white.opacity(0.12)) background.
Arrow icons in nav bars: 14×14 resizable inside 28×28 tap target (no background circle).
NavBar back button: 20×20 icon inside 32×32 with Circle().fill(.white.opacity(0.15)).
Accent color: #F55426 (confirmed used for overLimit state and slider tint).
Color(hex:) extension lives in HomeView.swift — potential candidate to extract to a shared file if it grows.

JarCard (CharitiesView) uses a different card style: background Color(hex: "1D1D1D"), border .white.opacity(0.3) strokeBorder lineWidth 1.25, corner radius 12pt. This is a richer card style than the standard .white.opacity() cards used elsewhere.
Sheet background: Color(hex: "161616") — used as ZStack fill and via presentationBackgroundCompat.
Logo circle overlays: 44×44, .clipShape(Circle()), border .white.opacity(0.2) strokeBorder lineWidth 1, padding 4.
Raw .custom("KTFPrima-Light", size: 20) found in CharitiesView header — should use .ktfTitleSmall token instead. Flag as design system bypass in future reviews.
