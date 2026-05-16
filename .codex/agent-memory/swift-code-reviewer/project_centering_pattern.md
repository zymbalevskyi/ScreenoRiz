---
name: centering_pattern_in_nav_bars
description: How centering is achieved in top bars — NavBar uses a phantom spacer, topBar in HomeView uses two Spacers. Asymmetry between left and right anchors causes true-center drift.
type: project
---

NavBar.swift achieves centering with Spacer + title + Spacer + phantom Color.clear.frame(width:32) to counterbalance the back button width. This is the established correct pattern in this codebase.

HomeView's topBar (merged headerBar + dateNav) uses two bare Spacers around the date nav section (left anchor: illus-knife image ~24pt height intrinsic width; right anchor: settings button 44×44 with circle background). Because the two flanking elements have different widths (the logo is narrower than the 44pt settings button), the two Spacers do NOT distribute equally and the date nav section drifts toward the logo side.

**Why:** The left element (illus-knife image, fixed height 24, width determined by aspect ratio of the SVG) is almost certainly narrower than 44pt. The right element is explicitly 44×44. With only Spacers, SwiftUI shares the remaining space equally between the two gaps, pushing the center section left of true center.

**How to apply:** Flag any topBar / header implementation that uses Spacer+content+Spacer without compensating for unequal flanking widths. The fix is either: (a) give the left element the same fixed width as the right (44pt frame), or (b) use a ZStack with the date nav centered absolutely and the flanking items positioned with leading/trailing alignment.
