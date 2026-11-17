# Version numbers

This mirrors Financial Sidekick's versioning setup (see that project's `versionNumber.md`). Set up 2026-11-17, replacing the stale `_set-version-bump.sh`/`agvtool` approach referenced in `CLAUDE.md` (that script never actually existed in this project).

Version numbers come from one file, `Config.xcconfig`, in the project root.

```
VERSION = 1.8
BUILD_NUMBER = 2026111701
```

- **`VERSION`** is the marketing version shown in the App Store. Edit it by hand.
- **`BUILD_NUMBER`** is the build number, `YYYYMMDDNN` (today's date plus a two-digit counter). Never edit it by hand: `version.sh` rewrites it on every Archive.

## How it is wired

- `Config.xcconfig` is the base configuration file for the **Medication Sidekick** app target, Debug and Release (not the Tests target).
- `MARKETING_VERSION = $(VERSION)` and `CURRENT_PROJECT_VERSION = $(BUILD_NUMBER)` on that target. Do not hard-code values in Build Settings; a hard-coded value overrides the file.
- `Config.xcconfig` is not part of the target's Copy Bundle Resources phase, so it is not shipped inside the app. If Xcode adds it there again, remove it.

## Build number format

`BUILD_NUMBER` is `YYYYMMDDNN`: today's date plus a two-digit counter, padded to two digits so a tenth build (`…1710`) can't outrank the next day's first build. The limit is 99 builds a day.

## When the number changes

Only on **Product > Archive**. The "Medication Sidekick" scheme's Archive pre-action runs:

```
cd "$SRCROOT"
source version.sh
```

with "Provide build settings from" set to the Medication Sidekick app target (required — otherwise `$SRCROOT` is empty and the script fails). Debug runs, simulator builds and `xcodebuild build`/`test` do not change the number.

## `version.sh`

It reads the `BUILD_NUMBER` line in `Config.xcconfig`, compares its date to today, and either adds one to the counter or resets it to `01`.

## Two machines

The project folder is synced between machines, but `Config.xcconfig` must also be committed and pushed after each archive — otherwise the other machine can start from an older build number and repeat or go below one already uploaded.
