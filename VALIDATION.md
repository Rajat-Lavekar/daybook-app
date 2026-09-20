# Validation log

## Automated checks

Run `bash scripts/run_checks.sh` from the repository root. The standalone runner and XCTest wrapper share the same regression cases. Full Xcode is needed for the XCTest wrapper; Command Line Tools can run the standalone checks. The suite covers exact paise, expense exclusions, stable-reference deduplication, repeated imports, note preservation, CSV quoting/invalid rows, provisional SMS capture, authenticated archive round-trips/tampering, review scope isolation, sleep overlap and midnight handling, corrupt-store preservation, concurrent writers, and the archive/review CLI workflow.

**12 September 2026:** all 13 standalone regression checks passed using Swift 6.1.2 on this Mac. The CLI archive test verified a saved encrypted copy, refusal to overwrite, scoped packet generation, returned-report parsing, preservation of the input archive and private file permissions. The 20-writer test preserved all records.

The native Mac preview built successfully. The project and app plists passed `plutil -lint`. Initial `swift test` could not run because this Command Line Tools installation has no XCTest; this is not reported as an XCTest pass. iOS code behind platform conditions has not been compiled against an iOS SDK here.

Mac UI checks: sample dashboard and chart, five-tab navigation, payment editor, saved memo search, Health unavailable state, reflection form, offline library and complete lesson display. Sample payments remain explicitly labeled. No personal bank or Health data was used. The Mac locked before the final Reviews UI inspection; the archive/review logic was verified by the CLI regression case, but that does not validate the system file pickers or reminder permissions.

## 19 September 2026 — bank imports and iOS build

All **19 standalone regression checks passed**. The same cases passed through XCTest (one wrapper test, zero failures) using full Xcode 26.6. New cases cover the supplied Kotak/HDFC message formats with fictional identifiers, bank-reported dates, incoming payments, NACH credits, rejection of future mandates, PDF structure/totals checks, and repeat imports after manual category, memo and Kind changes. Debit and credit sides of an own-account transfer remain two ordinary records, per the user's preference.

The supplied August GPay statement parsed through Apple's PDFKit: **17 pages, 160 transactions, zero issues, matching statement totals**. An independent Python/pypdf extraction compared every reference/account, amount, direction, merchant and timestamp against the native parser; all 160 records matched. GPay excludes two explicit self-transfer rows from its Sent header; the app retains those as normal debits and explains the difference. This PDF contains no original payment-note field. Validation artifacts remain in ignored `private-data/import-validation`; actual identifiers are absent from source and test fixtures. The live Mac preview ledger still contains only its eight demo records.

The Mac app built and its system file picker successfully opened the actual PDF. The import preview displayed 160 parsed, zero rejected, matching totals, the self-transfer explanation and a collapsed transaction preview. Importing into the live ledger was not exercised with personal data.

A full **unsigned iPhone build succeeded** with the iOS 26.5 SDK, including HealthKit compilation and App Intents metadata extraction. The iOS simulator build also succeeded, installed, and launched; its native ledger screen was observed. This supersedes the earlier SDK limitation above. This is not a signed installation or an on-device integration test.

Xcode detects the wired iPhone 15 on iOS 26.6.2. Pairing completed and the free Personal Team is selected. After the user enabled Developer Mode, device services confirmed it enabled; the device-targeted **signed build succeeded** and `devicectl` confirmed **Daybook installed on the physical iPhone**. The embedded profile includes this device and HealthKit, with expiration 26 September 2026 at 08:13:36 UTC (13:43:36 IST). Initial launch was denied with a signing/entitlement/profile-trust error. After completing profile trust, the user confirmed **“Daybook opens”** on the phone. Installation and first launch therefore passed. HealthKit data access was subsequently confirmed below; Shortcuts execution still requires its own checks.

**Health refresh follow-up:** the first on-device refresh reported “No data available for the specified predicate.” The statistics-query adapter incorrectly threw on HealthKit's `errorNoData`, aborting the whole refresh when one day/type had no readable samples. Version 0.2.1 (build 3) maps only that specific error to an unavailable value and continues; other query errors remain visible. The signed iPhone update build passed. CLI and Xcode update attempts reported interrupted connections; the user also observed the phone repeatedly disappearing from Finder. A subsequent exact-bundle query confirmed **version 0.2.1, build 3 is installed**. Remote launch still lost its connection, so the user tested Health directly on the phone and confirmed: “I can see the sleep data now, and also the fitness data.” The empty-day fix and basic HealthKit read/display workflow therefore passed on the actual iPhone. This confirms availability in the user's India setup with free Personal Team signing; exact agreement with Apple Health totals, denied permissions and other edge cases are still unverified. No app uninstall or data-container replacement was performed.

## Required iPhone checks — pending

**GPay import follow-up:** after being directed to select the supplied statement in Money → Import, the user confirmed the data is visible on the phone. The basic on-device import/display flow is confirmed; exact phone totals and repeat-import behavior have not yet been independently checked on the device.

**Shortcuts action follow-up:** the user ran Daybook's Capture Bank Alert action manually with a selected bank message and confirmed it worked. Action discovery and foreground capture passed. This does not yet confirm incoming-message trigger wiring, repeat delivery or locked-phone capture.

- Verify re-signing/update preserves phone records before the current profile expires. Initial signed build, installation, profile trust and launch passed on iPhone 15/iOS 26.6.2.
- Compare displayed steps, active energy and sleep against Apple Health; basic permission/read/display is confirmed. Check sleep across midnight, naps and multiple sources. Try denied access and no records.
- Extend the successful manual Capture Bank Alert check to both banks' debit/credit/failure variants and repeat delivery; exact fixture coverage on the phone remains unrecorded.
- Verify the Message automation provides the expected message text. Test foreground, background, locked phone, reboot, renewal of free signing, delayed delivery and duplicate delivery. Record missed captures; do not assume three-hour or always-on execution.
- Confirm manually classified transfers/investment contributions, failed payments, refunds and duplicate evidence have the expected totals. Own-account debit/credit rows remain ordinary transactions unless the user edits their Kind.
- Test Files import/export, recovery-key copy, encrypted restore into an empty installation and a malformed/wrong-key archive. Confirm an existing store is not replaced.
- Schedule a local reminder at a near-future time; check notification permission denial and Focus behavior.
- Try large text, small display, VoiceOver, keyboard and screen rotation constraints. Mac preview inspection does not substitute for this.

## Not currently available

Bank/UPI API sync; historical SMS inbox access; export adapters other than the tested GPay PDF and Daybook CSV; complete bank-account reconciliation; guaranteed background refresh; automatic chat execution; investment valuations; verified receipt-based phone cleanup.

## 21 September 2026 — expense design and Recreation (0.3.0 / build 4)

- Reviewed Copilot category views and Monarch report designs; rationale and metric contract are recorded in `docs/FINANCE_DESIGN.md`.
- Added a compact category composition chart, directly labeled ranked share bars, a separate net-expense headline and spent/refunded/received amounts. Category selection filters confirmed expense records and scrolls to that list; clearing selection restores the full list. Category chart calculations continue to use the existing tested finance summary, including manual transfer classifications and provisional exclusions.
- Added Recreation without changing existing raw category values or automatically reclassifying payments. New regression coverage imports Recreation from CSV, archives/restores it and a merchant rule, repeats the import without adding duplicates, and verifies the category amount.
- **20/20 standalone regression checks passed.** Mac preview, iOS simulator and signed generic iPhone builds passed. The shared XCTest wrapper was not separately rerun for this change.
- Inspected the native Mac chart, legend and ranked bars using fictional sample records. In the iPhone simulator, verified the summary at phone width, the Groceries drill-down (2 matching records), filter clearing, Recreation in the editor, saving it on a fictional payment, and updated chart/ledger amounts. Empty-period Mac state was also checked. Large Dynamic Type and VoiceOver interaction require further device QA.
- The physical iPhone was unavailable at the build checkpoint. Version 0.3.0 is built but is not yet confirmed installed on the user's phone. No personal financial or Health data was fetched for design QA.

### Donut refinement — 21 September 2026
- Replaced detailed ranked category rows with a thicker gradient donut, soft shadow and category-name chips, per user preference.
- Mac preview build and iOS Simulator build passed (`.build/donut-preview.log`, `.build/donut-ios-build.log`). Simulator launched successfully with fictional data; top of chart displayed. Simulator scrolling did not respond to automation, so full-card visual inspection was completed in the native Mac preview.
- Native Mac preview verified full chart, chip selection (Groceries ₹2,075 / 35.7%), dimming, deselection restoring ₹5,806, and unchanged eight-record ledger. Empty weekly period also checked. Direct touch-sector selection on iPhone remains to be manually checked.
- Earlier 20/20 finance regression checks remain applicable; this refinement changes presentation only. No physical-phone installation. The earlier signed device artifact predates this refinement and must be rebuilt at batch deployment.

### Repository migration — 21 September 2026
- Migrated the project to `daybook-app`; verified all 43 copied files against the original, including ignored local data. The original directory remains as a backup.
- Fresh builds from the new path: 20/20 standalone regression checks passed; native Mac preview built successfully with its data directory pointing to the new repository.
- private-data, build products, SwiftPM state and personal Xcode state remain ignored and are excluded from the initial source commit. No physical-phone deployment was performed.

### Check-in keyboard and app icon — 21 September 2026 (0.3.0 / build 5)
- Saving a reflection clears keyboard focus before saving; iOS also offers a keyboard Done button and interactive scroll dismissal. Saved text fields stay disabled until a new check-in starts.
- Today's Check in shortcut now pushes onto its navigation stack instead of switching tabs, providing native Back navigation. The Reflect tab remains a root screen navigated via tabs.
- Added original, reproducible book-and-leaf icon artwork and an iOS app-icon asset catalog. Preserved signing settings and updated the project generator to include assets.
- Mac preview and iOS simulator builds passed. Simulator verification with a fictional entry: software keyboard visible before Save, absent after Save, saved entry displayed, Back returned to Today. New icon visibly rendered on the simulator Home Screen.
- Edge-swipe automation did not produce a gesture; native back swipe and keyboard Done need a physical-phone check. No phone installation performed.

### Return navigation — 21 September 2026
- Today's Money and Health shortcuts now push onto the current navigation stack rather than switching tabs. Removed the unused tab binding from TodayView.
- Native Back returns to the originating screen; check-ins, readings and reviews already use this behavior. Sheets retain their existing Cancel/Done return actions. Top-level tab selection remains standard tab navigation, not browser-style history.
- Mac and iOS simulator builds passed. Simulator verified Today → Money → Back → Today and Today → Health → Back → Today. Physical edge-swipe verification remains pending; no phone deployment.
