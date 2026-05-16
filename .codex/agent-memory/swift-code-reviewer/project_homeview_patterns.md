---
name: HomeView architectural patterns
description: Key conventions and gotchas discovered in the HomeView.swift redesign (May 2026)
type: project
---

HomeView uses `.overlay(alignment: .bottom)` for the donation bottom sheet rather than a native SwiftUI sheet — height is driven by a `@State var isDonationExpanded` bool with `.animation(.spring(...), value:)` applied directly on the VStack. The `frame(height:alignment:.top)` pattern is the intended way to keep content pinned while the container animates.

`resolveDisplayNames()` is `@MainActor` and is intentionally called from `.task { }` in HomeView body — this is valid because `.task` runs on the MainActor by default in SwiftUI.

`Label(token).labelStyle(.iconOnly/.titleOnly)` is the established pattern for rendering FamilyControls ApplicationToken icons and names throughout this codebase — it is deliberately used rather than a fallback image.

`UnevenRoundedRectangle` requires iOS 16+ — confirmed available for this project's deployment target.

`Combine` is imported in HomeView but not used there directly — it is only used in AppState. This is a stale import.

**Why:** Discovered during HomeView redesign code review.
**How to apply:** Do not flag Label(token) usage as suspicious — it is the canonical pattern. Flag unused Combine imports in views as warnings.
