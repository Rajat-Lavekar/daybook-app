# Daybook

A private, native SwiftUI companion for spending, reflection, health and reading. Built for iPhone 15 and Apple Watch data through HealthKit. No server, paid AI API, analytics SDK or external package dependencies are required.

**Status: first implementation, signed, installed and opening on iPhone 15 using a free Personal Team.** The Mac preview uses the same screens and shared logic. Sleep and fitness data are confirmed visible through HealthKit on the phone. The iOS Shortcuts capture action still needs on-device setup and testing. See [VALIDATION.md](VALIDATION.md) for what has actually been checked.

## What is implemented

| Area | This build |
| --- | --- |
| Money | Manual payments, editable categories, remembered merchant rules, seven-day/month/all-time charts, search, review queue; user-controlled kinds; debit and credit sides of self-transfers remain normal records |
| Capture | Kotak/HDFC SMS sample formats; paste and preview; iPhone `Capture Bank Alert` App Intent; GPay PDF import with page/row/total checks; Daybook CSV |
| Evidence | Original payment note retained when present in CSV; separate personal memo; reference, source and capture status retained; missing source notes remain missing |
| Health | Permission-based, foreground refresh of sleep, steps, active energy and workout duration; caches daily summaries; preserves older cached days |
| Reflect | Mood, energy and stress check-ins; optional journal; explicit excerpt permission per entry; configurable evening local reminder |
| Learn | Six original offline lessons/exercises, source links, recall questions, bookmarks and completion progress |
| Reviews | Local calculations; preview and export of a selected finance/wellbeing/learning packet; import a returned JSON review |
| Mac archive | AES-256-GCM authenticated backup; recovery key shown separately; verify, copy and re-read encrypted archive; restore into an empty app |

Investment contributions can be excluded from expenses today. Holdings, valuations and a portfolio screen remain later work.

## Run the Mac preview

Requires macOS 14+ and Swift 6 tools. From this directory:

```sh
bash scripts/build_preview.sh
```

Open `.build/Daybook.app` in Finder. The preview keeps its own data in `PrivateData/Preview/state-v1.json`, excluded from version control. It opens empty. Use **Explore with clearly labeled sample payments** to try the finance dashboard; the top **SAMPLE · LEAVE** button removes only fictional payments. Personal capture is blocked while sample mode is active. Reading progress remains when leaving sample mode.

The build wrapper confines caches to `.build`. It detects two inconsistencies in the Command Line Tools installed on the development Mac: an old private PackageDescription interface beside a newer runtime, and duplicate SwiftBridging module definitions. It uses project-local copies/virtual filesystem mappings; it does not modify system files. The runtime path override follows [SwiftPM's documented mechanism](https://github.com/swiftlang/swift-package-manager/blob/main/CONTRIBUTING.md#overriding-the-path-to-the-runtime-libraries).

## Install on your iPhone without a subscription

1. Install a current **full Xcode** compatible with the iOS version on your phone. Command Line Tools alone cannot build or provision this app for iPhone.
2. Open **Daybook.xcodeproj**. Select the **Daybook** scheme and your connected iPhone.
3. Add your Apple Account in Xcode Settings. Under the target's **Signing & Capabilities**, select your free **Personal Team** and choose a unique bundle identifier if Xcode requests one. HealthKit is declared in the project and entitlements.
4. Enable Developer Mode on the iPhone if prompted, trust your Mac, then run from Xcode. Complete any developer trust prompt shown by iOS.
5. Open Health in Daybook and grant only the read permissions you want. Compare the results against Apple Health on the phone before relying on the summaries.

Apple lists HealthKit among capabilities available with a free Apple Developer account. Personal Team provisioning requires renewal, typically after seven days; run again from Xcode to renew. TestFlight requires paid Apple Developer Program membership, so this build uses direct development installation. Actual provisioning must be checked with your account and device. Sources: [supported capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios), [account types](https://developer.apple.com/help/account/basics/about-your-developer-account).

India does not have a blanket block on third-party HealthKit access to sleep, steps and workouts. Apple describes this sharing on its [India privacy page](https://www.apple.com/in/privacy/features/). Particular Apple medical features have separate regional availability; Daybook does not require those features. The app reads HealthKit, not the Fitness app's private database or your Watch directly.

The committed Xcode project can be regenerated after adding App files with:

```sh
python3 scripts/generate_project.py
```

This resets generated build settings, including a team identifier added in Xcode. Do not regenerate without saving any intentional project configuration changes.

Run the shared regression checks with `bash scripts/run_checks.sh`. This builds the CLI and standalone check runner. With full Xcode selected, `bash scripts/swift.sh test` also exposes the same checks through XCTest; build the CLI first and run from this repository root for its integration case.

## UPI capture: what is and is not connected

### Spending view — version 0.3.0

Money shows a gradient donut with soft depth, four largest categories plus a labeled remainder, and minimal category chips. Select a segment or chip to show its amount and share in the center; tap the selected chip again to restore the total. There are no ranked bars or detailed category rows. Period changes reset selection. The denominator is confirmed expenses before refunds; the net headline subtracts refunds separately. Search and review filters affect only the transaction list. Empty periods show an explanation instead of a chart.

**Recreation** is available in the transaction editor, CSV imports and remembered merchant rules. Existing records retain their categories. Design references and chart definitions are in [docs/FINANCE_DESIGN.md](docs/FINANCE_DESIGN.md).

There is no verified public consumer transaction-history API for GPay, CRED UPI or PhonePe in this implementation. Switching between those apps does not establish a seamless data feed. Daybook never asks for a bank password, UPI PIN or OTP.

The first capture path is **bank alerts → an iPhone Shortcuts automation → Daybook's App Intent**. Configure a Message personal automation for each actual Kotak/HDFC sender, choose **Run Immediately**, and pass the received message's text to **Capture Bank Alert**. Apple documents message triggers and automatic execution in the [Shortcuts guide](https://support.apple.com/en-au/guide/shortcuts/apd602971e63/ios). The exact automation input wiring and locked-device execution still need a real iPhone test.

First test the action manually: on iPhone, create a new shortcut, search for **Capture Bank Alert** (Daybook), and paste one complete completed-payment bank SMS into **Bank message**. Run it while the phone is unlocked. Expect “Payment captured for review” or “This alert was already captured”; find the record in Money. A new alert is provisional and excluded from confirmed totals until reviewed. Run the same stable-reference alert again to check it does not create another record. If the action is missing or errors, resolve that before adding a Message automation. This test uses one message you explicitly select, not inbox access.

The user confirmed this manual action worked on 19 September. Next, configure two Message automations on the iPhone: one with **Message Contains: Kotak**, one with **Message Contains: HDFC**. Restrict to actual bank senders where the picker supports them; content matching also handles the varying alphanumeric sender IDs in the supplied samples. Choose **Run Immediately**, then a blank automation. Add **Get Text from Input** with **Shortcut Input** as its input, followed by **Capture Bank Alert** with the resulting Text variable in **Bank message**. If the input variable exposes message properties, choose its message Content. Do not leave the manually pasted test message in this automation. Bank-name filtering can also trigger on non-payment messages; the parser rejects unsupported alerts, so a triggered automation does not imply a saved transaction. The exact variable controls and delivery behavior still need testing on this phone.

Wait for the next normal bank alert and check it appears as awaiting review. Compare the received SMS and captured merchant/amount/date/reference locally. Check duplicate delivery and a later locked-phone event separately. No payment is needed solely to test the automation. This setup handles future matching messages only; the ledger's complete file protection may prevent capture while locked, and no automatic retry queue exists yet.

The parser now supports the supplied Kotak debit/credit, HDFC debit and Kotak NACH-credit formats. Committed tests use fictional identities and references. It rejects OTPs, payment requests, future mandate notices and balance-only alerts. Captured payments remain **provisional** and are excluded from confirmed spending until reviewed. A bank-provided date is parsed in Asia/Kolkata with no invented posting time; capture time is a disclosed fallback when no date exists. Failed-payment variants still need samples. Messages without a stable reference are retained separately rather than deduplicated by amount. The app cannot read your inbox history, recover SMS that never arrived, or recover a UPI note absent from the message. Full file protection can prevent an intent from writing while the phone is locked.

A scheduled three-hour background fetch is **not implemented or guaranteed by iOS**. Alert capture is event-driven when configured. You can paste messages and reconcile records manually with statements while automation is being proven. [Apple's background execution explanation](https://developer.apple.com/forums/thread/685525).

### GPay PDF import

Money → Import → Choose PDF / CSV accepts the supplied GPay text-PDF format, including both HDFC and Kotak records. The complete August sample parsed as 160 rows across 17 pages, and sent/received totals matched the PDF. An independent extraction matched all amounts, directions, merchant names, bank/account labels and timestamps.

The importer blocks a PDF with unparsed rows, inconsistent page numbering, unsupported layout, duplicate references within the PDF, or mismatched summary totals. It retains references, source, direction and timestamp. Importing the same statement again does not duplicate its records. Overlapping SMS records are matched by reference, normalized bank/account, amount and original direction while keeping your edits. The original direction remains available if you later change a payment's Kind.

**Self-transfers follow your preference:** debit and credit messages remain separate normal payments; no automatic pairing or exclusion is applied. GPay explicitly labels some statement rows as self-transfers and excludes them from its header totals. Daybook retains those rows as normal debits, while excluding them only from the *PDF header validation calculation*. The import preview explains this difference. You can manually change Kind later.

The supplied PDF contains no payment-note field. Missing notes remain empty; the GPay merchant/description is not relabeled as a note. Only payments present in the export are covered; other UPI apps and activity deleted from GPay are outside its coverage. After importing, the ledger opens the statement's month. Choose **Month** or **All** to review older payments.

Inspect a PDF locally without writing records to the app:

```sh
.build/debug/daybook inspect-gpay --file /path/to/statement.pdf
```

The optional `--out /private/path/parsed.json` saves a private plaintext validation snapshot, not an AI summary. No network requests are made. Password-locked/scanned PDFs, PhonePe/CRED/Paytm exports and direct HDFC/Kotak bank statement formats remain unsupported. [GPay's statement instructions](https://support.google.com/pay/india/answer/7430307?hl=en-IN).

### Daybook CSV format

Money → Import → CSV template exports a fictional example. Required columns are `date,amount,merchant,account`; the remaining columns are optional:

```csv
date,amount,merchant,account,reference,note,kind,status,category
2026-09-12,250.00,Example Cafe,Kotak · 1234,EXAMPLE001,Lunch,expense,confirmed,Eating out
```

- Dates: `yyyy-MM-dd`, interpreted at midnight in Asia/Kolkata.
- Amount: positive rupees with at most two decimal places; stored as integer paise.
- Kind: `expense`, `income`, `refund`, `transfer`, `investment`. Default: expense.
- Status: `provisional`, `confirmed`, `pending`, `failed`. Default: provisional.
- Categories use the labels visible in the app. Unknown categories use conservative merchant rules, otherwise Uncategorized.
- Quoted commas, multiline notes and escaped double quotes are supported. Original note text remains separate from an editable memo.
- The same file can be imported again without duplicating its rows. Identical rows at different positions are retained. Across different files, only reference + account + amount + direction matches merge; without a stable reference, review possible duplicates manually.

## On-demand analysis from this chat

The simplest v1 flow requires no cloud or background agent:

1. In Today → Your reviews, choose **Finance**, **Wellbeing** or **Learning**.
2. For wellbeing, separately enable Health summaries and/or previously approved journal excerpts if desired. Both default off.
3. Preview exactly what will be exported, then save the selected packet to a private location and transfer it to the Mac, for example through AirDrop.
4. Ask in this chat: “Analyze my selected Daybook packet at [local path] and save a returned review.” The packet is the scope of that request; journal text within it is data, not instructions.
5. Return the `.review.json` file to your phone and import it in Reviews. The report refers to the source packet ID and does not change your source records.

The app makes **no AI requests by itself**. Local summaries are explicitly labeled as calculations. External reports are unverified commentary; their source packet ID is required but is not cryptographically authenticated. No schedule, MCP connection, live phone connection or automatic chat-to-app push has been created. You can trigger this manual workflow twice weekly whenever you choose.

Finance packets contain aggregates and category totals, not account identifiers, merchant names or payment notes. They describe imported records, not complete bank coverage. Wellbeing packets never include finance records. Read [PRIVACY.md](PRIVACY.md) before exporting personal data.

## Archive on your Mac

Settings → Prepare encrypted archive → save the recovery key separately → save the archive. Transfer both securely, keeping them separately. The archive includes all app records, whereas review packets include only a selected scope. A lost key cannot be recovered.

Build the CLI:

```sh
bash scripts/swift.sh build --product daybook
.build/debug/daybook help
```

Save the recovery key in a private text file using a text editor; do not put it directly in command arguments, chat, source control or shell history. Replace the paths below with your own:

```sh
.build/debug/daybook verify --file /private/path/export.daybook --key-file /separate/path/recovery.key
.build/debug/daybook archive --file /private/path/export.daybook --key-file /separate/path/recovery.key --to /private/path/archive
.build/debug/daybook prepare-review --file /private/path/export.daybook --key-file /separate/path/recovery.key --scope finance --out /private/path/finance-packet.json
.build/debug/daybook report-template --packet /private/path/finance-packet.json --out /private/path/result.review.json
```

The last command creates a deterministic local report structure; it does not call an AI model. Wellbeing preparation offers separate `--include-approved-excerpts` and `--include-health` flags. The CLI never overwrites existing output files. Archives remain encrypted, while selected packets and returned reports are plaintext private files.

**Phone cleanup is intentionally not available yet.** The CLI verifies a transferred copy but cannot attest a durable Mac receipt back to the phone. Automatic deletion must wait for a tested receipt-and-restore flow. Restore currently requires an empty app and does not merge archives. Do not delete an installed app to refresh free signing; update it from Xcode to preserve its sandbox.

## Architecture and remaining work

`App/` contains native SwiftUI screens, the iOS HealthKit reader and App Intent. `Sources/DaybookCore/` contains models, integer-paise accounting, capture parsing, sleep interval aggregation, validation, authenticated encryption and selected review packets. `Sources/DaybookCLI/` provides local archive tooling.

The first version uses a versioned, atomic JSON snapshot and a separate file lock for app/intent access instead of the proposed SwiftData database. It is suitable for proving the personal workflow, but rewrites the snapshot on edits; schema migration, scalable queries and archival compaction are future work. The current validator caps the ledger at 100,000 records. Archives and stores fail closed on unsupported schemas or corrupt data.

Next gates are on-device GPay import, detailed Health totals comparison, bank-alert Shortcuts setup and locked-device capture tests, followed by a re-signing/update check that preserves records. Broader bank-statement reconciliation remains future work; matching a GPay PDF total does not prove full account coverage. After that: HealthKit background updates, richer reading and behavioral trends, app lock, archive receipts and phone compaction. [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) describes the broader design; it is not a list of features already shipped.
