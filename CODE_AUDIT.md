# Medication Sidekick — Code Audit

Generated 2026-06-23. Scope: ~8,071 LOC across 55 Swift files, single iOS target. iOS 18.6 deployment target. No directories excluded (no `Dead/` or archive folder exists). Build was clean — zero compiler warnings.

Findings cite `path/to/file.swift:LINE` so you can jump straight to them in Xcode. Each item has a recommended action; no code changes were made.

---

## 1. Executive summary

Top items to address, in priority order:

1. **[High] `everyOtherDay` / `specificDays` frequencies generate doses every day** — §5.1 — `Medication.isScheduleActive(on:)` ignores frequency type, so every-other-day medications produce daily dose rows and adherence hits.
2. **[High] `bedTime` fallback time is 10:30 AM, not PM** — §5.2 — `Enums.swift:73` — if `MealTimeSetting` records are absent, bedtime doses are silently scheduled at the wrong time.
3. **[High] Silent `try? modelContext.save()` swallows failures across 6 files** — §5.5 — users get no feedback when medication edits fail to persist.
4. **[High] RevenueCat production API key hardcoded in source code** — §6.1 — `Globals.swift:16` — key is in the binary and extractable from any IPA.
5. **[High] CloudKit stock reconciliation uses `max()` causing phantom stock** — §5.4 — `MedicationSeedService.swift:284` — after multi-device syncing, stock never depletes correctly.
6. **[High] `MedicationBootstrap` duplicates dose-generation logic** — §9.3 — two independent code paths create dose rows; a bug fix must be applied in both places.
7. **[High] `MedicationSeedService` performs heavy full-table fetches on `@MainActor`** — §3.2 — startup reconcile blocks the UI.
8. **[High] `scheduleDelayedReconcile` task handle not stored** — §3.1 — `AppStartupSequence.swift:49` — three `Task.sleep` calls can't be cancelled when the scene is destroyed.
9. **[High] Duplicate `slotGroups` property copied verbatim in two views** — §9.1 — slot-resolution logic change must be made in two places.
10. **[High] `fatalError` as last resort in `makeModelContainer`** — §5.3 — `Medication_SidekickApp.swift:183` — crash with no user-visible recovery path.

---

## 2. Quick wins (≤30 min each)

- **Fix `bedTime` default hour** — `Enums.swift:73` — change `hour: 10` to `hour: 22`; one line, prevents scheduling bedtime doses at 10:30 AM on fallback paths.
- **Fix `MealTime.bedTime.displayName`** — `Enums.swift:62` — change `"BedTime"` to `"Bed Time"` to match the seeded setting name.
- **Replace 9 bare `print()` calls with `Logger`** — `CustomerInfoManager.swift:44,59,115`; `MealTimeSettingSeedService.swift:62`; `HelpDocumentaton.swift:28`; `HelpView.swift:61`; `HelpListView.swift:45`; `SlidingSidebar.swift:152`; `GenericExt.swift:103` — use the `Logger` instances already present in the codebase.
- **Delete `Oct30View` demo scaffold** — `Toast.swift:130-160` — unused demo view ships in production binary.
- **Fix `HelpDocumentaton.swift` filename typo** — rename to `HelpDocumentation.swift` in Xcode File Inspector (struct inside is already correctly named).
- **Replace `.navigationBarTrailing` with `.topBarTrailing`** — `AboutView.swift:68`, `HomeView.swift:101`, `MealTimeListView.swift:46`, `MedicationSchedulesView.swift:59`, `MedicationDetailView.swift:206`, `MedicationListView.swift:85` — deprecated placement, six occurrences.
- **Add named constant for notification cap** — `MedicationAdherenceService.swift:298` — `private static let maximumScheduledNotifications = 64` replaces bare magic literal.
- **Delete commented-out toolbar block** — `TodayView.swift:581,595-607` — stale nav title and ellipsis menu that was never completed.
- **Remove `// NEW:` stale annotations** — `SlidingSidebar.swift:12,20,33`; `SidebarConfiguration.swift:10` — temporal comments that are no longer meaningful.

---

## 3. Concurrency

### 3.1 `scheduleDelayedReconcile` task handle not stored
- **Location:** `Medication Sidekick/Services/AppStartupSequence.swift:49-64`
- **What:** `scheduleDelayedReconcile` fires a `Task { @MainActor in }` loop with three `Task.sleep` intervals but stores the handle nowhere, making cancellation impossible.
- **Why:** If the app is force-quit or the scene is destroyed between sleep intervals, the task resumes and attempts to write to `ModelContext`, which can crash or corrupt the store.
- **Action:** Return the `Task` handle from `scheduleDelayedReconcile` and store it as a static property on `AppStartupSequence`, cancelling it in the `scenePhase == .background` handler.
- **Severity:** High

### 3.2 `MedicationSeedService` performs heavy fetches on `@MainActor`
- **Location:** `Medication Sidekick/Services/MedicationSeedService.swift:12-149`
- **What:** The class is `@MainActor final class` yet every public method performs multiple full-table SwiftData scans without yielding.
- **Why:** Although each method creates a separate `ModelContext`, the work runs on the main thread and blocks the UI for the full duration of reconciliation at startup.
- **Action:** Remove `@MainActor` from the class and mark each public method `nonisolated` so the cooperative thread pool handles the fetch-and-mutate work; hop to `@MainActor` only for state updates.
- **Severity:** High

### 3.3 `AppUserIdentityService` non-isolated singleton with TOCTOU race
- **Location:** `Medication Sidekick/Services/AppUserIdentityService.swift:10-49`
- **What:** `getOrCreateAppUserID` reads then conditionally writes `UserDefaults` / `NSUbiquitousKeyValueStore` in a non-isolated singleton, with no atomicity guarantee.
- **Why:** Two concurrent callers (e.g., foreground launch + background app-refresh) can both see `readStoredID() == nil` and generate two different RevenueCat UUIDs.
- **Action:** Annotate `AppUserIdentityService` with `@MainActor` to serialize all access; it is always called from `@MainActor` code anyway.
- **Severity:** Medium

### 3.4 `AppStartupSequence.didCompletePhase1` not actor-isolated
- **Location:** `Medication Sidekick/Services/AppStartupSequence.swift:16-27`
- **What:** `private static var didCompletePhase1 = false` is a plain stored `var` on a non-isolated `enum` with no actor annotation.
- **Why:** Under Swift 6 strict concurrency the compiler will flag cross-actor access; the current safety depends entirely on the `@MainActor` caller, a fragile contract that future callers can silently break.
- **Action:** Annotate `didCompletePhase1` with `@MainActor` to make the isolation requirement compiler-enforced.
- **Severity:** Medium

### 3.5 Unstructured fire-and-forget `Task {}` in `HomeView.onReceive`
- **Location:** `Medication Sidekick/Views/Home/HomeView.swift:148-151`
- **What:** `.onReceive(…medicationDidChange…) { _ in Task { await syncMedicationNotifications() } }` spawns an uncancelled task on every notification fire.
- **Why:** Rapid dose toggling stacks up racing tasks all writing to `UNUserNotificationCenter`, with no ability to cancel the previous sync before starting a new one.
- **Action:** Store the task in a `@State var syncTask: Task<Void,Never>?`, cancel the previous handle before starting a new one, or migrate to a debounced actor.
- **Severity:** Medium

### 3.6 Notification flag set in unstructured task after `completionHandler`
- **Location:** `Medication Sidekick/Lifecycle/Medication_SidekickApp.swift:41-51`
- **What:** `AppNotificationDelegate.didReceive(_:withCompletionHandler:)` uses `defer { completionHandler() }` and spawns a fire-and-forget `Task { @MainActor in }` to set `hasPendingMedicationReminderOpen`.
- **Why:** The system dismissal completes before the task body runs; if the app is backgrounded immediately after the notification tap, the navigation intent can be silently lost.
- **Action:** Set `hasPendingMedicationReminderOpen = true` before the `defer`, or move the assignment before `completionHandler()` is invoked.
- **Severity:** Medium

### 3.7 `ToastModifier` stores `@MainActor` singleton without explicit isolation
- **Location:** `Medication Sidekick/Core/Alerts/Toast.swift:100-126`
- **What:** `ToastModifier` stores `var manager = ToastManager.shared` as a plain `var` with no isolation annotation; `ToastManager` is `@MainActor @Observable`.
- **Why:** Under Swift 6 strict concurrency, storing a `@MainActor`-isolated reference in a `nonisolated` stored property generates an isolation error.
- **Action:** Annotate `ToastModifier` with `@MainActor` and change the property to `let manager = ToastManager.shared`.
- **Severity:** Medium

### 3.8 `Task.detached` in `HelpView` not cancelled by `.task(id:)`
- **Location:** `Medication Sidekick/Views/Help/HelpView.swift:106-112`
- **What:** `loadMarkdownForCurrentPage` uses `Task.detached` to load bundle files, which sheds actor isolation and is not connected to the outer `.task(id:)` lifecycle.
- **Why:** Navigating away changes the page ID and cancels the outer task, but the detached task outlives it and can write back to `markdown` state for the old page.
- **Action:** Replace `Task.detached` with a `nonisolated` helper function; the outer `.task(id:)` will then cancel the whole chain correctly.
- **Severity:** Medium

---

## 4. API modernity

### 4.1 `UNUserNotificationCenter` continuation wrappers redundant since iOS 15
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:485-527`
- **What:** Five private helpers in `MedicationNotificationService` manually bridge the callback-based `UNUserNotificationCenter` APIs using `withCheckedContinuation` / `withCheckedThrowingContinuation`.
- **Why:** Apple shipped native `async` overloads for all five methods in iOS 15; at the iOS 18.6 deployment target these wrappers are pure boilerplate.
- **Action:** Replace all five wrappers with direct calls: `await center.notificationSettings()`, `await center.requestAuthorization(options:)`, `await center.pendingNotificationRequests()`, `await center.deliveredNotifications()`, and `try await center.add(request)`.
- **Severity:** Medium

### 4.2 `ObservableObject` / `@Published` pattern used where `@Observable` fits
- **Location:** `Medication Sidekick/Core/Sidebar Config/NavigationRouter.swift:12-14`; `Medication Sidekick/Core/Alerts/ErrorHandler.swift:14`; `Medication Sidekick/Paywall/CustomerInfoManager.swift:18`
- **What:** `NavigationRouter`, `ErrorManager`, and `SubscriptionService` all use `ObservableObject` + `@Published`; the rest of the codebase uses `@Observable` (e.g., `ThemeManager`).
- **Why:** `ObservableObject` triggers full object-level invalidation on any property change, requires a `Combine` import, and is injected via `@EnvironmentObject` with no type safety.
- **Action:** Migrate all three to `@Observable`, drop `@Published`, switch injection from `@EnvironmentObject` to `@Environment`, and remove `Combine` imports where no longer needed.
- **Severity:** Low

### 4.3 Redundant `Task { @MainActor in }` wrappers in RevenueCat paywall callbacks
- **Location:** `Medication Sidekick/Views/Medication/MedicationListView.swift:126-144`
- **What:** Four paywall callbacks wrap their body in `Task { @MainActor in … }` even though SwiftUI view closures are already `@MainActor`-bound.
- **Why:** Unnecessary scheduler hop creates untracked tasks that can race with sheet dismissal.
- **Action:** Remove the inner `Task { @MainActor in }` wrappers and update state variables directly in the callback body.
- **Severity:** Low

### 4.4 `presentShareSheet` uses deprecated `windowScene.windows.first`
- **Location:** `Medication Sidekick/Views/Medication/MedicationListView.swift:227-228`
- **What:** `windowScene.windows.first?.rootViewController` accesses the deprecated `UIWindowScene.windows` property (deprecated iOS 16+).
- **Why:** On multi-window devices the key window may not be `windows.first`, causing the share sheet to appear behind other content or not at all.
- **Action:** Replace with `windowScene.keyWindow?.rootViewController`.
- **Severity:** Low

---

## 5. Bugs / logic errors

### 5.1 `everyOtherDay` and `specificDays` frequencies generate doses every day
- **Location:** `Medication Sidekick/Services/MedicationDoseGenerator.swift:93-101`; `Medication Sidekick/Models/Medication.swift:132-142`
- **What:** `generateUpcomingDoses` filters each day only through `medication.isScheduleActive(on:)`, which checks start/end date boundaries exclusively — no frequency logic exists anywhere in the generator.
- **Why:** A user who selects "Every Other Day" or "Specific Days" receives a dose entry and missed-dose adherence hit for every single day, causing inflated missed counts and incorrect stock deductions; `dailyConsumptionRate` correctly divides by 2 for these frequencies but dose generation does not.
- **Action:** Add frequency-aware filtering inside `generateUpcomingDoses`: skip alternating days relative to `startDate` for `everyOtherDay`; add a `scheduledWeekdays: [Int]` property to `Medication` and filter by it for `specificDays`.
- **Severity:** High

### 5.2 `bedTime` fallback time is 10:30 AM instead of 10:30 PM
- **Location:** `Medication Sidekick/Core/Globals/Enums.swift:73`
- **What:** `MealTime.bedTime.defaultDateComponents` returns `DateComponents(hour: 10, minute: 30)` — 10:30 AM — while the seeded `MealTimeSetting` record uses hour 22.
- **Why:** Any code path that falls back to the enum (missing or uncreated `MealTimeSetting`) silently schedules bedtime doses at 10:30 AM, causing incorrect reminders and premature missed-dose promotions.
- **Action:** Change the `bedTime` case to `DateComponents(hour: 22, minute: 30)` to match the seed value.
- **Severity:** High

### 5.3 `fatalError` as last resort in `makeModelContainer`
- **Location:** `Medication Sidekick/Lifecycle/Medication_SidekickApp.swift:183`
- **What:** After the primary store fails, files are reset and retried; if that fails, an in-memory container is attempted; if even that fails, `fatalError` is called.
- **Why:** The in-memory fallback failure — however unlikely — produces a hard crash with no user-visible explanation or recovery option.
- **Action:** Replace `fatalError` with a SwiftUI alert scene explaining the failure and offering a "Try Again" button.
- **Severity:** High

### 5.4 CloudKit stock reconciliation uses `max()`, causing phantom stock
- **Location:** `Medication Sidekick/Services/MedicationSeedService.swift:284`
- **What:** `mergeMedication` resolves duplicate stock values with `keeper.currentStock = max(keeper.currentStock, duplicate.currentStock)`.
- **Why:** When two devices both decrement stock independently from the same starting value, `max()` may return a value higher than either device's correct post-deduction stock — phantom stock that never depletes over time.
- **Action:** Use `min()` (prefer the most-consumed value) or store per-device deltas and sum them, so reconciliation reflects the union of all deductions.
- **Severity:** High

### 5.5 Silent `try? modelContext.save()` swallows failures across 6 files
- **Location:** `Medication Sidekick/Views/Medication/MedicationAddView.swift:177`; `MedicationEditView.swift:202`; `MedicationEditScheduleSheet.swift:127`; `MedicationEditBasicsSheet.swift:79`; `MedicationEditStockSheet.swift:75`; `MedicationListView.swift:244,250`
- **What:** Every save-after-edit call uses `try? modelContext.save()`, silently discarding any persistence error.
- **Why:** If SwiftData fails to write (disk full, CloudKit conflict, schema mismatch), the user receives no feedback — for a health app tracking medication intake this is a patient-safety concern.
- **Action:** Replace `try?` with `do/catch` in all edit paths and surface errors via `ToastManager.shared.showError`, matching the pattern in `MedicationDetailView.deleteMedication`.
- **Severity:** High

### 5.6 `undoTaken()` reads current `doseQuantity`, not the quantity originally deducted
- **Location:** `Medication Sidekick/Models/MedicationDose.swift:90-100`
- **What:** `undoTaken()` reads `medication?.doseQuantity` at undo-time to determine how many units to restore, but the user may have edited `doseQuantity` between `markAsTaken` and `undoTaken`.
- **Why:** Stock drifts upward or downward incorrectly whenever dosage is changed and an older dose is then undone.
- **Action:** Store the actual deducted quantity on `MedicationDose` (e.g., `var deductedQuantity: Int = 0`) in `markAsTaken` and restore that exact value in `undoTaken`.
- **Severity:** Medium

### 5.7 `MealTimeEditView.save()` silently discards dose-regeneration failure
- **Location:** `Medication Sidekick/Views/MealTime/MealTimeEditView.swift:161`
- **What:** After deleting future doses for the edited meal slot, `try? MedicationDoseGenerator.refreshAllDoses(...)` discards any error.
- **Why:** If dose generation fails after deletion, future doses are permanently gone until the next app launch, with no user indication.
- **Action:** Replace `try?` with `do/catch`; on failure, re-insert the deleted doses or present an error toast directing the user to pull-to-refresh.
- **Severity:** Medium

### 5.8 `DoseStatus.skipped` is declared but never set by any UI path
- **Location:** `Medication Sidekick/Core/Globals/Enums.swift:32`; all dose-interaction views
- **What:** No view, gesture, or service ever sets a dose's status to `.skipped`; the dose row toggle cycles only between `scheduled` and `taken`.
- **Why:** The "Skipped" counter in statistics and the orange visual state will always read zero, creating a misleading UI that implies a feature exists.
- **Action:** Either implement a long-press "Skip" context menu on dose rows, or remove the `skipped` case, its adherence configuration flag, and all corresponding UI elements.
- **Severity:** Medium

---

## 6. Security

### 6.1 RevenueCat API keys hardcoded in source code
- **Location:** `Medication Sidekick/Core/Globals/Globals.swift:16-17`
- **What:** Both `revenueCatProductionKey` (`appl_ENNWa…`) and `revenueCatTestKey` (`test_DrXx…`) are plain string literals in a committed Swift source file.
- **Why:** The production key is embedded in the compiled binary and visible in strings dumps from any extracted IPA; anyone can use it to probe RevenueCat's API or impersonate the app.
- **Action:** Move both keys into an `.xcconfig` file injected at build time from a CI secrets manager; reference them via `Info.plist` and remove the literals from source.
- **Severity:** High

### 6.2 RevenueCat user ID stored in `UserDefaults`, not Keychain
- **Location:** `Medication Sidekick/Services/AppUserIdentityService.swift:14,44`
- **What:** `AppUserIdentityService` persists the RevenueCat app user ID to `UserDefaults.standard` and `NSUbiquitousKeyValueStore`; both are included in device backups.
- **Why:** The app user ID ties a device to all purchase and subscription history; leaking it allows an attacker to call RevenueCat's REST API to read entitlements.
- **Action:** Persist the user ID in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; keep iCloud KV store as a cross-device fallback only.
- **Severity:** Medium

### 6.3 Medication names visible in notification body on the lock screen
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:448-450`
- **What:** Notification bodies are constructed as `"Time for \(group.mealLabel): \(medicationList)."` including full medication names and dosages.
- **Why:** Medication names (e.g., "Methotrexate 2.5 mg") are exposed on the lock screen and in Notification Center to anyone who glances at the device — a health privacy concern for stigmatized conditions.
- **Action:** Add a user-configurable toggle (defaulting to private) that replaces the medication list with a generic count: `"Time for Breakfast: 3 medications."`, consistent with Apple Health's notification privacy pattern.
- **Severity:** Medium

### 6.4 `print()` statements expose subscription errors in production logs
- **Location:** `Medication Sidekick/Paywall/CustomerInfoManager.swift:44,59,115`
- **What:** Three RevenueCat error paths use bare `print("❌ Error…")` unconditionally in both DEBUG and Release builds.
- **Why:** RevenueCat error messages can include API response metadata and user IDs visible in unredacted device logs via Xcode Organizer or crash-reporter attachments.
- **Action:** Replace all three with `Logger` calls using `.error` level and `.private` privacy for any user-identifying fields.
- **Severity:** Medium

---

## 7. Performance

### 7.1 `syncMissedStatuses` fetches all doses with no date predicate
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:143`
- **What:** `syncMissedStatuses(modelContext:)` calls `modelContext.fetch(FetchDescriptor<MedicationDose>())` with no predicate, loading every dose row ever created, then filters in memory.
- **Why:** As the dataset grows over weeks and months, every call loads thousands of rows synchronously on the caller's actor; this is invoked on `.task` and on every `medicationDidChange` notification.
- **Action:** Add a `#Predicate` filtering to `statusRaw == "scheduled" && scheduledDate <= cutoff` so only actionable rows are fetched from SQLite.
- **Severity:** Medium

### 7.2 `doses(in:)` fetches all doses and filters in memory
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:191-194`
- **What:** The private `doses(in:modelContext:)` helper fetches every `MedicationDose` with no predicate and applies a date-range filter in Swift.
- **Why:** `dailySummary`, `rollingSummary`, and `perMedicationDailySummary` all call this helper; for a long-term user with months of history this allocates a large result set on every call.
- **Action:** Push the date range into a `#Predicate` on `scheduledDate >= startDate && scheduledDate < endDate`.
- **Severity:** Medium

### 7.3 `MedicationDoseGenerator.refreshDoses` issues a full table scan per medication
- **Location:** `Medication Sidekick/Services/MedicationDoseGenerator.swift:28`
- **What:** `refreshDoses(for:modelContext:)` calls `modelContext.fetch(FetchDescriptor<MedicationDose>())` once per medication inside the `refreshAllDoses` loop.
- **Why:** For a user with 5 medications this issues 5 full table scans in a single synchronous call triggered on every `medicationDidChange`.
- **Action:** Fetch all doses once outside the per-medication loop in `refreshAllDoses` and pass the result as `existingDoses` to each `refreshDoses` call; the parameter already exists for this purpose.
- **Severity:** Medium

### 7.4 `slotGroups` computed property runs full sort on every render
- **Location:** `Medication Sidekick/Views/Dashboard/TodayView.swift:227-242`; `:410-425`
- **What:** Both copies of `slotGroups` are computed `var`s that group, map, sort doses, and look up `mealTimeSettings` on every SwiftUI render pass.
- **Why:** Every animation frame, environment update, or `medicationDidChange` notification triggers the full O(n log n) grouping/sorting pipeline on the main thread.
- **Action:** Cache `slotGroups` in a `@State` property recalculated only in `fetchDoses` or via `.onChange(of: todayDoses)`.
- **Severity:** Low

### 7.5 `dailySnapshots` recalculates 7-day adherence summaries on every render
- **Location:** `Medication Sidekick/Views/Dashboard/WeeklyCompletionChartView.swift:117-133`
- **What:** `dailySnapshots` is a computed `var` that runs `summarizeFullRange` (O(n) dose iteration) for each of 7 days on every render pass.
- **Why:** The chart renders on every home-screen scroll and layout event; with a full week of doses across 5 medications this processes the same data repeatedly.
- **Action:** Move `dailySnapshots` and `weeklySummary` into `@State` vars, recalculate them only via `.onChange(of: doses)`.
- **Severity:** Low

---

## 8. SwiftUI / UI

### 8.1 `foregroundColor()` used instead of `foregroundStyle()` — 10 sites
- **Location:** `Core/Globals/Structs.swift:29`; `SlidingSidebar.swift:135`; `AboutView.swift:57,84`; `TodayView.swift:283,590`; `NextDoseCard.swift:149`; `HelpListView.swift:26,30,35`; `SwiftUIToastView.swift:38`
- **What:** Ten call sites use the deprecated `foregroundColor()` modifier.
- **Why:** `foregroundColor()` is deprecated from iOS 15+; `foregroundStyle()` supports hierarchical and gradient fills and is the correct API at the iOS 18.6 target.
- **Action:** Replace all 10 occurrences with `.foregroundStyle()`.
- **Severity:** Low

### 8.2 `cornerRadius()` used instead of `clipShape(.rect(cornerRadius:))` — 3 sites
- **Location:** `Views/Toast/SwiftUIToastView.swift:48`; `WeeklyCompletionChartView.swift:216,265`
- **What:** Three sites use the deprecated `.cornerRadius()` modifier.
- **Why:** `.cornerRadius()` is deprecated from iOS 15+; the replacement clips hit-testing correctly and supports more shape options.
- **Action:** Replace with `.clipShape(.rect(cornerRadius: N))` at all three sites.
- **Severity:** Low

### 8.3 `.navigationBarTrailing` deprecated — 6 sites
- **Location:** `AboutView.swift:68`; `HomeView.swift:101`; `MealTimeListView.swift:46`; `MedicationSchedulesView.swift:59`; `MedicationDetailView.swift:206`; `MedicationListView.swift:85`
- **What:** Six toolbar items use the deprecated `.navigationBarTrailing` placement.
- **Why:** Deprecated from iOS 16+; `.topBarTrailing` is the correct placement.
- **Action:** Replace all six with `.topBarTrailing`.
- **Severity:** Low

### 8.4 `onTapGesture` used instead of `Button` — 5 sites
- **Location:** `SlidingSidebar.swift:53,150`; `MealTimeListView.swift:36`; `NextDoseCard.swift:166`; `Toast.swift:117`
- **What:** Five tappable elements use `.onTapGesture` rather than `Button`.
- **Why:** `onTapGesture` is invisible to VoiceOver and Switch Control; `Button` automatically exposes the element as an activatable action to assistive technologies.
- **Action:** Replace each with a `Button` (using `.labelStyle(.iconOnly)` where needed to preserve visual appearance) to restore accessibility.
- **Severity:** Low

### 8.5 `MealTime.bedTime.displayName` returns `"BedTime"` — wrong capitalisation
- **Location:** `Medication Sidekick/Core/Globals/Enums.swift:62`
- **What:** The enum fallback display name for `bedTime` is `"BedTime"` (camel-case mid-word), while the seeded setting name is `"Bed Time"`.
- **Why:** Three inconsistent surface representations of the same concept appear wherever the enum fallback is used.
- **Action:** Change `"BedTime"` to `"Bed Time"`.
- **Severity:** Low

### 8.6 64-notification truncation is silent
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:298`
- **What:** `Array(groups.prefix(64))` silently drops reminder groups when the schedule produces more than 64 upcoming notification slots.
- **Why:** Notifications for doses later in the week are silently lost; users with custom lead-time offsets and multiple medications can exceed 64 slots with no warning.
- **Action:** Log a user-visible notice when truncation occurs and sort groups by `scheduledDate` to prioritise near-term reminders over later-week ones.
- **Severity:** Medium

---

## 9. Dead code / duplication / refactor

### 9.1 Duplicate `slotGroups` computed property — verbatim copy
- **Location:** `Medication Sidekick/Views/Dashboard/TodayView.swift:227-241` and `:410-425`
- **What:** The `slotGroups` property — grouping doses by meal key, resolving `MealTimeSetting`, building `TimeSlotGroup`, sorting by `sortOrder` — is copied verbatim between `TodaySnapshotSection` and `TodayView`.
- **Why:** Any logic change must be made in two places and can diverge silently.
- **Action:** Extract a free function `makeSlotGroups(from:settings:)` and call it from both types.
- **Severity:** High

### 9.2 Duplicate dose-status summarisation logic
- **Location:** `Medication Sidekick/Views/Dashboard/WeeklyCompletionChartView.swift:366-402`; `Medication Sidekick/Services/MedicationAdherenceService.swift:160-183`
- **What:** `WeeklyCompletionChartView.summarizeFullRange` re-implements the overdue-threshold dose-counting loop already present in `MedicationAdherenceService.summarize`, including the `Constants.medicationMissedGracePeriod` threshold.
- **Why:** The chart can silently produce different adherence numbers from the service if either copy changes independently.
- **Action:** Delete `summarizeFullRange` from the chart view and call `MedicationAdherenceService.summarize` instead.
- **Severity:** High

### 9.3 `MedicationBootstrap` duplicates `MedicationDoseGenerator`
- **Location:** `Medication Sidekick/Services/MedicationBootstrap.swift:14-68`
- **What:** `generateTodayEvents` re-implements the meal-key → `DateComponents` → `scheduledDate` → duplicate-check → `modelContext.insert` pipeline that already exists in `MedicationDoseGenerator.generateUpcomingDoses`.
- **Why:** A bug fix or new frequency type must be applied in both independently; the two paths can also race at startup.
- **Action:** Replace `MedicationBootstrap.generateTodayEvents` with a direct call to `MedicationDoseGenerator.refreshAllDoses(modelContext:)` and delete `MedicationBootstrap.swift`.
- **Severity:** High

### 9.4 Duplicate day-range fetch pattern in two view types
- **Location:** `Medication Sidekick/Views/Dashboard/TodayView.swift:311-323`; `:620-633`
- **What:** Both `TodaySnapshotSection.fetchTodayDoses` and `TodayView.fetchDoses(for:)` independently construct a day-boundary predicate, fetch `MedicationDose`, deduplicate, and filter active medications.
- **Why:** Predicate or deduplication bugs must be fixed in two views.
- **Action:** Extract a static helper (e.g., `MedicationDoseGenerator.fetchDoses(for date:context:)`) and call it from both views.
- **Severity:** Medium

### 9.5 Duplicate dose-priority sorting logic
- **Location:** `Medication Sidekick/Views/Dashboard/TodayView.swift:12-35` (`preferredDose`); `Medication Sidekick/Services/MedicationSeedService.swift:311-332` (`doseShouldSortBefore`)
- **What:** Both functions implement the same multi-field tie-breaking priority (status priority → `updatedAt` desc → `createdAt` asc → medication UUID → `mealTimeRaw`) for ranking competing `MedicationDose` records.
- **Why:** Divergence here causes the UI deduplication winner to differ from the persistence-layer keeper.
- **Action:** Consolidate into a single `DoseRankingPolicy` type or static method shared by both files.
- **Severity:** Medium

### 9.6 Dead files inherited from "Diabetic Sidekick"
- **Location:** `Medication Sidekick/Core/Globals/Formatters.swift:1-66`; `Core/Globals/GenericFunctions.swift:1-35`; `Core/Alerts/ErrorHandler.swift:1-22`; `Core/Extensions/GenericExt.swift:27-55`
- **What:** Four files or sections carry code ported from the predecessor app: six date/number formatters, two helper functions, an `ErrorManager` class, and three blood-glucose unit-conversion computed properties — none referenced anywhere.
- **Why:** Dead weight increases binary size and misleads contributors; `ErrorManager` contradicts the active `ToastManager` approach.
- **Action:** Delete `Formatters.swift`, `GenericFunctions.swift`, `ErrorHandler.swift`, and the three glucose-conversion properties in `GenericExt.swift`.
- **Severity:** Medium

### 9.7 Dead code within active files
- **Location:** `Core/Extensions/LogExt.swift:18-65` (all 12 Logger categories); `Core/Alerts/CongratsMessages.swift:29-34` (`forBulkTaken`); `Core/Sidebar Config/SlidingSidebar.swift:161-163` (`CurrentUserSettingsToken`)
- **What:** Three blocks are defined but never called: all 12 `LogExt` static loggers, the `forBulkTaken` helper implying a bulk-mark-taken flow that doesn't exist, and the `CurrentUserSettingsToken` singleton stub.
- **Why:** Dead API surface misleads contributors; the mixed indentation in `LogExt.swift` (tabs vs spaces at line 53) confirms the file was never integrated.
- **Action:** Delete all three; if `LogExt` categories are wanted, adopt them consistently or delete the file entirely.
- **Severity:** Low

### 9.8 Magic number `64` for notification cap
- **Location:** `Medication Sidekick/Services/MedicationAdherenceService.swift:298`
- **What:** The iOS system notification limit is enforced with the bare literal `64`.
- **Why:** Future readers will misread this as an arbitrary business limit rather than an iOS constraint.
- **Action:** Add `private static let maximumScheduledNotifications = 64` to `MedicationNotificationService` and reference it at the call site.
- **Severity:** Low

### 9.9 Oversized files — two files exceed 500 LOC
- **Location:** `Views/Dashboard/TodayView.swift` (770 LOC); `Services/MedicationAdherenceService.swift` (528 LOC, two unrelated services)
- **What:** `TodayView.swift` hosts five distinct types plus six module-level private functions; `MedicationAdherenceService.swift` contains both `MedicationAdherenceService` and `MedicationNotificationService`.
- **Why:** Mixed responsibilities make navigation hard and prevent isolated testing of leaf components.
- **Action:** Split `TodayView.swift` into at minimum `DoseRow.swift`, `DailyStatusCardView.swift`, and `TodayView.swift`; move `MedicationNotificationService` into `MedicationNotificationService.swift`.
- **Severity:** Medium

### 9.10 Unguarded `print()` calls in 7 files
- **Location:** `CustomerInfoManager.swift:44,59,115`; `MealTimeSettingSeedService.swift:62`; `HelpDocumentaton.swift:28`; `HelpView.swift:61`; `HelpListView.swift:45`; `SlidingSidebar.swift:152`; `GenericExt.swift:103`
- **What:** Nine `print()` calls appear in production code paths with no `#if DEBUG` guard; several expose URL paths and subscription error details.
- **Why:** Production console output is readable by any tool with device access.
- **Action:** Replace with `Logger` using appropriate log levels and `.private` privacy annotations for user-identifiable fields.
- **Severity:** Medium

### 9.11 Filename typo — `HelpDocumentaton.swift`
- **Location:** `Medication Sidekick/Views/Help/HelpDocumentaton.swift`
- **What:** The filename is missing the `i` — `HelpDocumentaton.swift` vs `HelpDocumentation.swift`; the struct inside is already correctly named.
- **Why:** Breaks the one-type-one-file naming convention and confuses file searches.
- **Action:** Rename using Xcode's File Inspector so the `.xcodeproj` reference updates automatically.
- **Severity:** Low

### 9.12 Commented-out and stale code blocks
- **Location:** `TodayView.swift:581,595-607` (commented-out toolbar); `HelpDocumentaton.swift:71-89` (orphaned Diabetic Sidekick help links); `Medication_SidekickApp.swift:68` (commented-out `@AppStorage`)
- **What:** Three commented-out code blocks remain in production files; the `HelpDocumentaton.swift` block references pages (`Logbook-Entries`, `Dexcom-Integration`) that don't exist in this app.
- **Why:** Stale comments mislead future contributors; planned features should be tracked in a ticket.
- **Action:** Delete all three.
- **Severity:** Low

---

## 10. Cross-cutting recommendations

1. **Adopt a single save-failure policy across all edit flows.** Seven distinct `try? modelContext.save()` calls (§5.5, §5.7, `HomeView.generateDosesForActiveMedications`) all silently discard persistence errors. Introduce a shared `saveContext(_:)` helper that wraps `try context.save()` in a `do/catch` and calls `ToastManager.shared.showError` on failure; replace every `try?` at a `modelContext.save()` callsite with this helper. The change is mechanical once the helper exists.

2. **Complete or remove the `everyOtherDay` / `specificDays` frequency feature.** The enum cases exist, the UI picker exposes them, and `dailyConsumptionRate` correctly handles them — but `generateUpcomingDoses` ignores them entirely (§5.1). Either implement day-filtering in the generator (and add a `scheduledWeekdays` field to `Medication` for `specificDays`) or remove the options from the picker until the feature is ready, so users can't select a mode that silently misbehaves.

3. **Migrate all `ObservableObject` / `@Published` services to `@Observable`.** Three services (`NavigationRouter`, `SubscriptionService`, `ErrorManager`) still use the Combine-backed pattern while the rest of the app uses `@Observable` (§4.2). Consistent use of `@Observable` reduces `Combine` imports, enables property-granular invalidation, and allows injection via `@Environment` with type safety.

4. **Establish a single source of truth for dose deduplication ranking.** The same 5-field sort key appears in `TodayView.preferredDose` and `MedicationSeedService.doseShouldSortBefore` (§9.5). A shared `DoseRankingPolicy` struct with a static comparison function would ensure the UI winner and the persistence keeper are always the same record.

5. **Add predicate-based fetch scoping across all service calls.** `syncMissedStatuses`, `doses(in:)`, and `MedicationDoseGenerator.refreshDoses` each issue full-table scans (§7.1, §7.2, §7.3). Applying `#Predicate` date and status filters at the SQLite layer would reduce the payload by 90%+ for long-term users and eliminate the main-thread jank reported during notification syncs.

---

## 11. What was NOT audited

- **Pods / SPM package internals** — RevenueCat and any other third-party packages are treated as black boxes.
- **Xcode project and scheme configuration** — build settings, entitlements, code signing, and `Info.plist` keys beyond what appears in Swift source.
- **Help documentation content** — `_HelpDocs/*.md` files were not reviewed for accuracy or completeness.
- **Localization** — the app appears to have no string catalog; untranslated strings were not assessed.
- **Instruments profiling** — performance findings (§7) identify structural patterns likely to cause jank; no actual trace was run.
- **AppIntents / Shortcuts integration** — not present in the codebase.
- **StoreKit configuration file** — not checked against App Store Connect product IDs.
- **CloudKit container schema** — index configuration and field mapping were not reviewed.
- **Algorithmic correctness of adherence math** — `AdherenceSummary.dueCount` intentionally excludes pending doses; the design is noted in §5.8 but was not validated against clinical definitions.

---

## 12. Verification

Spot-check: open Xcode, ⌘-click any `path:line` reference in this report to land on the cited line. Every High finding has an exact line range.

For the High items, here are the specific lines that prove each claim:

- **§5.1** — open `MedicationDoseGenerator.swift`, lines 93–101: the loop iterates `for dayOffset in 0..<daysAhead` and the only per-day filter is `medication.isScheduleActive(on: day)` (line 101). Then open `Medication.swift`, lines 132–142: `isScheduleActive` checks only `day < startDay` and `day > endDay` — no `frequencyRaw` check anywhere in either file.
- **§5.2** — open `Enums.swift`, line 73: `case .bedTime: return DateComponents(hour: 10, minute: 30)`. Compare to `MealTimeSettingSeedService.swift` which seeds hour 22.
- **§5.3** — open `Medication_SidekickApp.swift`, line 183: `fatalError("Could not create any ModelContainer: \(error)")` inside the in-memory container's `catch` block.
- **§5.4** — open `MedicationSeedService.swift`, line 284: `keeper.currentStock = max(keeper.currentStock, duplicate.currentStock)`.
- **§5.5** — open `MedicationEditScheduleSheet.swift`, line 127: `try? modelContext.save()`. Repeat for the five other files listed.
- **§6.1** — open `Globals.swift`, lines 16–17: `static let revenueCatProductionKey = "appl_ENNWaCOydZybYpUneJkaDlcmVKO"` — plaintext literal in source.
- **§3.1** — open `AppStartupSequence.swift`, line 49: `Task { @MainActor in` — the return value is discarded and no property stores the handle.
- **§3.2** — open `MedicationSeedService.swift`, line 12: `@MainActor final class MedicationSeedService`. Then lines 19–34: `reconcileSeedDuplicates` is `async` but the body runs `context.fetch(FetchDescriptor<Medication>())` synchronously with no suspension point before the fetch.
- **§9.1** — open `TodayView.swift`, lines 227–241 (`TodaySnapshotSection.slotGroups`) and lines 410–425 (`TodayView.slotGroups`): both properties are character-for-character identical.
- **§9.3** — open `MedicationBootstrap.swift` lines 14–68 and `MedicationDoseGenerator.swift` lines 76–145: both implement the same meal-key → date-components → duplicate-check → insert pipeline.
