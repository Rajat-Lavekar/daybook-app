# Daybook

A local-first iPhone app for tracking spending, health, daily reflections and learning. Built with SwiftUI, Swift Charts and HealthKit. No backend or external package dependencies required.

## Features

- **Money:** expense charts, editable categories, GPay PDF/CSV imports and bank-alert capture through Shortcuts.
- **Health:** sleep, steps, active energy and workouts from Apple Health.
- **Reflect:** mood check-ins, journaling and optional reminders.
- **Learn:** offline CS lessons, bookmarks and recall exercises.
- **Data:** encrypted backups and manually exported review summaries.

## Getting started

Requires Xcode with Swift 6, iOS 17+ for the iPhone app, or macOS 14+ for the preview.

### iPhone

1. Open `Daybook.xcodeproj` and select the **Daybook** scheme.
2. Select your signing team under **Signing & Capabilities**; set a unique bundle identifier if needed.
3. Choose your connected iPhone, enable Developer Mode if prompted, and run.

### Mac preview

```sh
bash scripts/build_preview.sh
open .build/Daybook.app
```

### Tests

```sh
bash scripts/run_checks.sh
```

## Project structure

```text
App/                   SwiftUI screens and Apple integrations
Sources/DaybookCore/    Models, importers, accounting and storage
Sources/DaybookCLI/     Local archive and review tools
Tests/                 Shared regression checks
scripts/               Build and project utilities
```

## Privacy

Personal data stays local unless explicitly exported. Keep statements, extracts and preview data in the Git-ignored `PrivateData/` folder. The app does not access SMS history or sync directly with banks; bank-alert capture requires a user-configured Shortcut.

See [Privacy](PRIVACY.md), [Validation status](VALIDATION.md) and [Finance design](docs/FINANCE_DESIGN.md) for details.
