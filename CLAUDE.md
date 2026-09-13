# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an iOS app built with Xcode. There are no test targets.

- **Build/Run**: Open `Medication Sidekick.xcodeproj` in Xcode and use ⌘R or the scheme selector.
- **Version bump**: `bash _set-version-bump.sh` — sets marketing version and generates a date-based build number via `agvtool`.

## Coding Standards

- **Always use `@Observable`** — never `ObservableObject`, `@Published`, `@StateObject`, or `@EnvironmentObject`. Inject with `.environment(obj)`, read with `@Environment(Type.self)`.
- **Every view must have a `#Preview`** — add one at the bottom of every SwiftUI view file.

## Architecture Overview

**Stack**: SwiftUI · SwiftData (CloudKit) · StoreKit 2 · UserNotifications

### Data Models (`Models/`)

Three SwiftData `@Model` classes form the persistence layer:

- **`Medication`** — core entity. Stores scheduling info (`frequencyRaw`, `mealsRaw`), stock tracking (`currentStock`, `doseQuantity`, `stockUnit`), and has a cascade-delete relationship to its doses.
- **`MedicationDose`** — one row per scheduled dose occurrence. Linked to a `Medication` via `@Relationship`. Status transitions (scheduled → taken/skipped/missed) are handled by `markAsTaken()` and `undoTaken()`, which also update the parent medication's stock.
- **`MealTimeSetting`** — user-editable meal time slots (name, hour, minute, stable string key). Seeded on first launch by `MealTimeSettingSeedService`.

**Important pattern**: SwiftData doesn't support enum storage, so all enum fields are stored as raw `String` values (e.g., `frequencyRaw`, `mealTimeRaw`, `statusRaw`) with `var frequency: MedicationFrequency` computed wrappers on top.

**Meal time resolution**: Both `MealTime` (enum) and `MealTimeSetting` (SwiftData record) use the same stable string keys (e.g., `"breakfast"`, `"bedTime"`). Code always checks `MealTimeSetting` records first and falls back to the `MealTime` enum — this means custom meal times work as drop-in replacements.

### App Startup (`Services/AppStartupSequence.swift`)

`AppStartupSequence.runPhase1IfNeeded(...)` is called once from `HomeView.task`. It runs in order:
1. `SubscriptionService.start()` — begins listening for StoreKit transaction updates and loads the pro product
2. `MealTimeSettingSeedService.seedIfNeeded()` — seeds default meal slots
3. `MedicationSeedService.seedIfNeeded()` — seeds default medications
4. `MedicationBootstrap.generateTodayEvents()` — creates today's dose rows
5. Schedules three delayed reconcile passes (8s, 20s, 45s) to clean up CloudKit duplicates

`InteractionGuard` prevents background reconcile passes from running within 10 seconds of a user dose interaction (to avoid conflicts with in-flight UI saves).

### Dose Generation

- **`MedicationBootstrap`** — generates today's doses only (used at startup).
- **`MedicationDoseGenerator`** — generates doses for the next 7 days. Callers are responsible for saving the context after calling it. The `refreshDoses(for:)` method also prunes stale future doses when a medication's schedule changes.

### Services

- **`MedicationAdherenceService`** — pure struct that computes `AdherenceSummary` and per-medication summaries from dose arrays. Also promotes overdue `scheduled` doses to `missed` via `syncMissedStatuses()`. Grace period is `Constants.medicationMissedGracePeriod` (2 hours).
- **`MedicationNotificationService`** — manages `UNUserNotificationCenter`. Groups doses by (mealKey, scheduledDate) into at most 64 notifications. Notification IDs use the prefix `meddose.`. Re-syncs are triggered by the `medicationDidChange` `Notification.Name`.
- **`MedicationSeedService`** (Swift `actor`) — seeds default medications, and reconciles CloudKit-introduced duplicates via logical + relaxed identity signatures. Keeper selection prefers the record with more dose history.

### Navigation

`NavigationRouter` (`@Observable`) owns a `NavigationPath` and the active `Route` enum case. `HomeView` hosts the single `NavigationStack` and its `navigationDestination(for: Route.self)` switch, keeping all navigation wiring in one place.

### Theming

`ThemeProtocol` defines semantic color/font tokens (e.g., `accentPrimary`, `textSecondary`, `surfaceElevated`). `Main()` is the only concrete theme. `ThemeManager` (`@Observable`) holds the selected theme and is injected via `.environment(themeManager)` from the root. Always use semantic tokens from the theme rather than hard-coded colors.

### Subscription / Paywall

`SubscriptionService` (`@Observable`) uses StoreKit 2 natively — no third-party SDK. It exposes `isPro`, `hasLoadedCustomerInfo`, and `subscriptionPriceDisclosure`. The free tier allows up to 5 medications (`SubscriptionService.freeMedicationLimit`). The product ID is `SubscriptionService.proProductID`.

`SubscriptionSheetView` is the native paywall UI (red diagonal header, black pricing card, feature list, pinned footer). It is presented as a sheet from `HomeView` (initial prompt) and `MedicationListView` (limit gate).

On startup, `SubscriptionService.start()` opens a `Transaction.updates` listener for real-time entitlement changes and calls `Transaction.currentEntitlements` to determine `isPro`. Restore uses `AppStore.sync()`.

### Toast System

`ToastManager.shared` is a global singleton. The `.toast()` SwiftUI modifier (defined in `ViewExt.swift`) must be applied to the root view for toasts to appear. Use `ToastManager.shared.showSuccess/showError/showGeneral(_:)` from anywhere on `@MainActor`.

### Help System

Help content is Markdown files in `_HelpDocs/`. They are bundled into the app and loaded at runtime via `HelpDocumentation.localDoc(_:)`. When adding a new help page, add the `.md` file to `_HelpDocs/`, add it to the Xcode target, and register a `HelpPage` entry in `HelpDocumentation.helpPages`.

### CloudKit Considerations

The SwiftData container uses `.cloudKitDatabase: .automatic`. CloudKit sync can create duplicate records on first install or multi-device scenarios. The three reconcile passes in `MedicationSeedService` handle this — they use identity signatures to find and merge duplicates, preserving the record with the most history.
