# Medication Sidekick: redesign progress

Last updated: 2026-11-07. Everything below is merged and pushed. `main` = `origin/main` = `3e96729`.

## Done

**Navigation**
- Sliding sidebar removed. Bottom tab bar with three tabs: **Home**, **Medicines**, **More**.
- Each tab has its own navigation stack, so pushing a detail screen keeps the tab bar.
- `NavigationRouter` holds the selected tab and one path per tab. `.home` and `.medications` routes select their tab. Notification taps go to Home (dose reminders) or Medicines (refill reminders).
- More tab holds Meal Times, Settings, Help and About (About is a sheet).

**Home** (the old Today screen was folded in and deleted)
- Hero: progress ring ("11/12 TAKEN") with a compact Due / Later / Missed list beside it. White text sits on solid teal.
- Card: status line ("All caught up for now" / "2 doses need attention" / "1 dose overdue"), up to 3 doses needing action (name, amount, time, red when overdue), then the week as mini bars.
- Week bars are also the **day picker**: tap Mon to today to see that day's doses; tapping scrolls to the list. Future days are disabled.
- Dose list under the card, grouped by meal ("Breakfast · 7:00 AM"). Tap to take, swipe right to take/undo, swipe left to skip, long-press to skip.
- Pull to refresh; counts refresh every minute (due becomes overdue on its own).
- CloudKit duplicate dose rows are collapsed in the hero counts and the pill.

**Floating pill** (iOS 26 tab bar bottom accessory)
- Shows the earliest due/overdue dose with a black **Taken** button, "+N more" if several, or "Next . 12:00 PM" when nothing is due yet. Hidden when nothing is left today.
- Same take logic as the list rows (stock deduction, toast, notification resync).
- Shows on all three tabs.

**Medicines tab**
- List / Schedule switch under the nav bar (hidden when you have no medications).
- Schedule = timeline ordered by clock time, labelled by linked meal, with dose amount and days; rows open the medication. It falls back to built-in meal times so no medication can go missing.
- Old Schedules screen and its route removed.

**Other**
- Today renamed to Home (tab, title, house icon, code names).
- Tab bar tint is teal.

## Test on device (tick as you go)
- [ ] Taken from the pill: dose is marked, pill moves to the next dose, toast appears
- [ ] Pill when everything is done: it disappears
- [ ] Pill collapses into the tab bar when you scroll
- [ ] Swipe right on a dose: take / undo
- [ ] Swipe left on a dose: skip / undo skip. Long-press skip also works
- [ ] Tap each day bar, Mon to today: header and list change, view scrolls to the list
- [ ] Edit a dose on a past day (take/undo) and see the bars update
- [ ] Leave the app open past a dose time: due/overdue counts change without reopening
- [ ] Tap a dose reminder notification: lands on Home
- [ ] Tap a refill reminder notification: lands on Medicines
- [ ] Medicines > Schedule: rows open the medication, back button returns to the Schedule view
- [ ] Add / share / delete a medication (free-tier limit and paywall still trigger)
- [ ] First-launch paywall prompt still appears once
- [ ] More tab: Meal Times, Settings, Help, About all open and go back
- [ ] Dark mode (hero, card, pill, week bars)
- [ ] Large Dynamic Type (ring scales; card and rows do not clip)
- [ ] VoiceOver on the hero, card, day bars and pill
- [ ] Empty state: no medications, and a day with no doses
- [ ] Second device on the same iCloud account: no inflated counts from duplicates

## Known gaps / to do
- **Help pages are out of date.** `_HelpDocs/Home.md`, `Today.md`, `Getting-Started.md` still mention the sidebar menu, the Today screen and the Daily Status card. The `MS_IPH_TodayView*` images are the old UI. Needs new screenshots and a rewrite.
- **App Store screenshots/listing** (and any marketing copy) show the old UI.
- **No tests for the new logic.** `HomeSummary` and `DosePillState` are pure, so they're easy to unit test (due/overdue/later, dedup, week fractions, day rollover).
- **Pill on every tab** is a choice; could be limited to Home.
- Optional: Missed count turns a warm colour when above zero; brighten nothing else for now.
- Hero stats only show Due / Later / Missed. There is no streak (not decided).
- Past-day bars look empty if the app has no history for those days.
- `Claude outputs/medication-sidekick-ideas.html` is untracked and unreviewed.

## Parked: schedule redesign ("times with a linked meal")
Decisions so far:
- A dose linked to a meal always follows that meal's time (no per-dose switch).
- No before/after offsets.
- Migration of existing data is fine.

Finding: the current model already behaves like "linked meal follows the setting". The only real gaps are (1) clock-time doses with no meal and (2) the Home list grouping by meal instead of time. Recommended **light** approach: an optional list of custom times next to the meal list, no migration. Confirm whether anything else is needed (every-8-hours, two doses at one meal) before starting.

Note: "As needed" in your simulator data was just the dosage text, not the As Needed frequency. The Frequency picker still lists "As Needed". Unknown whether you use it.

## Release housekeeping
- Version bump: `bash _set-version-bump.sh`. The build number in `project.pbxproj` was already bumped (20261031.18.02).
- Deployment target is iOS 26.0. `tabViewBottomAccessory(isEnabled:)` is 26.1+, so on 26.0 the accessory is only attached while a dose is pending.
- GitHub history was force-replaced on 2026-11-07 (old tip was `9198e2f`, "Bump version to 1.7...").

## Design decisions and preferences (so another session does not redo them)
- Keep the **original single progress ring** in the Home hero. The segmented per-dose ring was tried and rejected (still in git history as `7aeeebe`); do not propose it again.
- The part that resembled the reference app was the **ring + stacked big numbers**, not the card. Only the stats block was changed, to the compact Due / Later / Missed list. The card was also redesigned (status line, doses needing action, week bars).
- White hero text must stay on solid teal; the gradient only fades below the hero, under the card.
- Work was done step by step with the user confirming each step: tab bar, Home hero/card, pill, fold in Today, schedule view.
- The GitHub `main` history was force-replaced once with explicit approval. A normal push is fine now.
- The old Today / Home help pages and App Store screenshots still show the old UI.

## Dose times (added 2026-11-07)
- The old "When to Take" section is replaced by one shared **"Dose Times"** control (`DoseTimesSection`), used by the Add, Edit and Edit Schedule screens.
- It is a list of dose times. Each row has a **meal type picker** and an **editable time**; "Add Dose Time" adds a row, the minus button removes one.
- The time **follows the chosen meal's time from Meal Times by default**; changing it pins that medication's dose to your own time. "Reset" (or setting it back to the meal's time) returns to following the meal.
- Limit: one dose per meal type per medication (the stored fields are unchanged). Two doses with the same meal type, or a dose with no meal, would need a bigger data change.
- New field `Medication.mealTimeOverridesRaw: [String]` ("breakfast=08:30"). It is additive, but the **CloudKit production schema must be deployed before release**.
- Used by the dose generator, the retime pass, the Schedule timeline (now grouped by real reminder time) and the medication detail screen. Deleting a meal also drops its overrides.
- Not yet device-tested: changing a reminder time then confirming existing future doses move; changing a Meal Times time for a medication that has an override (it should NOT move).

## Times of Day (renamed from meal types, 2026-11-07)
- Defaults are now **Morning, Noon, Evening, Night, As Needed**. The first four reuse the original keys (`breakfast`, `lunch`, `dinner`, `bedTime`), so existing medications, doses and history are untouched; only the names changed.
- Existing installs: the four are renamed **in place**, and only if the name is still the old default (a name you chose yourself is left alone). `asNeeded` is added. Pre-Breakfast and Supper are left as they were (delete them in Times of Day if unwanted; deleting cleans up medications that use them).
- **As Needed is only a label** here. It has a time (12:00 PM, editable) and behaves like any other scheduled type. The separate "As Needed" frequency option is unchanged.
- Wording: Meal Times -> **Times of Day** (More tab, screen titles), "Meal type" -> time of day in the dose picker. The help page is still titled "Meal Times".
- Built-in fallback names (`MealTime` enum) match: Morning / Noon / Evening / Night / As Needed.

## Time zone setting (changed 2026-11-07)
- "Adjust for Travel" is now **Advanced > "Keep home time zone"**, off by default, on the Add, Edit and Edit Schedule screens (`HomeTimeZoneSection`).
- It is the **same setting shown the other way round** (`followsDeviceTimeZone`): Keep home time zone ON = followsDeviceTimeZone false. No data change.
- ON: dose times stay on the home time zone when you travel (for interval-critical medications such as an antibiotic every 8 hours). OFF: dose times follow the phone, so 8:00 AM stays 8:00 AM wherever you are.
- The group opens by itself when the medication already keeps its home time zone. List and detail wording updated to match.
