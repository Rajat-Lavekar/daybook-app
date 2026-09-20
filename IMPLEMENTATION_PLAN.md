Productivity Builder — implementation plan

Prepared 12 September 2026; implementation checkpoint updated 19 September. The first Daybook implementation now exists; see [README.md](README.md) for implemented scope and [VALIDATION.md](VALIDATION.md) for actual checks. This document retains the broader design and future phases, which should not be read as shipped functionality. Full Xcode is installed; Daybook is signed with the free Personal Team, installed and opening on the user's iPhone. The user has confirmed sleep and fitness data display through HealthKit. Bank-alert integration and detailed Health reconciliation tests remain pending.

**19 September decisions:** the supplied GPay PDF adapter and Kotak/HDFC alert formats are implemented and tested. The GPay sample has no original payment notes. Per your instruction, own-account transfers stay as two normal transactions; automatic pairing or expense exclusion is not part of this implementation. Manual Kind edits remain available. Your connected device reports iPhone 15, iOS 26.6.2.

**Build a private iPhone app whose first useful feature is trustworthy spending tracking.** Add sleep and fitness, a brief daily reflection, a finite reading queue, and on-demand reviews. Prioritize reducing the effort of understanding your day over increasing time spent in the app.

Your confirmed setup is an iPhone 15 on the latest installed iOS version, an Apple Watch Ultra, and predominantly Kotak Mahindra Bank and HDFC Bank for UPI. Record the exact OS build during device testing. Use INR and Asia/Kolkata initially. You prefer automatic collection and would accept roughly three-hour refreshes; manual weekly import alone is not your requested steady-state workflow. Data stays on your devices, and selected summaries go to AI only when you trigger a review. You want an optional archive on this Mac that can reclaim phone storage after verification. No paid Apple membership or cloud instance is required by the proposed v1. Learning level remains unspecified; make it adjustable and start with an intermediate track with prerequisite refreshers.

**There is no verified seamless transaction-and-note feed from any of your three UPI apps.** I did not find a documented public consumer history API for GPay, PhonePe, or CRED in the official material reviewed. This is a research finding, not proof that no private partnership exists. Payment acceptance APIs must not be mistaken for authorization to read a customer's complete payment history. For example, Google's documented UPI integration is for merchant payment initiation. [Google's integration documentation](https://developers.google.com/pay/india/api/android/in-app-payments).

| App/source | Verified capability | Payment note/message | Decision for this app |
| --- | --- | --- | --- |
| Google Pay | Official instructions describe downloading and sharing a transaction-history PDF. Google also documents a separate Takeout export. | Neither source establishes that every India UPI note, tag, or conversation message survives export. Test actual files. | First export to test among your existing apps. A weekly import is feasible if the format parses reliably. |
| PhonePe | Official consumer pages document transaction history. | Bulk export with notes and a public consumer history API were not established. | Keep usable through bank imports; inspect an actual export before adding a dedicated adapter. |
| CRED UPI | Official UPI material documents the payment service and ecosystem responsibilities. | A supported history-and-note export/API was not established. | Same bank-import fallback; no dependency on an undocumented API. |
| Paytm, optional trial | Official FAQ documents Excel or PDF UPI statements. | Note/remark columns and their completeness still require a real sample. | Promising for easier parsing if you want to try another app. Do not switch all payments before the note test passes. |
| Your bank's statement | To be verified for your particular banks and account types. It can provide the account-ledger view across UPI apps. | Bank narration may differ from the original payment note; chat messages should not be assumed present. | Reconciliation source for bank-funded UPI. Credit-card UPI and UPI Lite need separate coverage. |

Sources for the table: [GPay statements](https://support.google.com/pay/india/answer/7430307?hl=en-IN), [Google Pay Takeout](https://support.google.com/googlepay/answer/9015738?hl=en-GB), [PhonePe consumer payments](https://www.phonepe.com/payments/), [CRED UPI FAQ](https://cred.club/upi-faqs), [Paytm export FAQ](https://paytm.com/faqs/upi/how-to-download-paytm-upi-statement). The GPay history documentation explicitly limits its history to payments made through Google Pay.

**Recommendation: keep your current UPI apps and test Kotak/HDFC bank-alert capture first.** Bank-funded UPI capture should follow the funding account, regardless of which payment app initiated it. Use a GPay export to test historical data and payment-note enrichment. Paytm's Excel export is an optional comparison if missing notes remain a problem; it does not justify switching all payments yet. Neither export route is an automatic API connection.

“Message tagged with a payment” can mean the transaction remark entered before paying, an app-private category/tag, or a separate conversation message. The parser must preserve those separately. A missing note stays missing; it is never reconstructed from a merchant name. Your app will also offer a private memo field. Sensitive personal annotations should go there because a payment remark may be visible to the recipient.

Use event-driven bank-alert capture for the intended daily experience, with imports for history, reconciliation, and missed alerts. Prototype these routes before committing to the full finance UI:

1. **Statement import:** share a supported PDF/CSV/Excel file to the app or select it in Files. Parse locally, preview, resolve issues, then commit. Implement the first adapter against the actual sample rather than promising support for arbitrary statements.
2. **Shared transaction receipt:** share a receipt, screenshot, or text when it contains useful notes. Use text extraction first and on-device OCR where needed. Require review of uncertain amounts, dates, and references. This supplements an existing transaction when it can be matched.
3. **Primary automation candidate: bank-SMS Shortcuts.** Configure separate Kotak and HDFC personal automations for known bank senders and transaction phrases, pass each received message to an app action, and save a provisional transaction. Apple documents message triggers and automatic execution. Test the exact iOS version, sender IDs, permission prompts, locked-phone behavior, and bank templates. This captures new matching messages after setup, not a historical inbox import. Notes absent from the SMS remain absent. If the app action cannot persist while locked, explicitly measure the gap and test a protected local queue before accepting this route. [Message triggers](https://support.apple.com/en-bn/guide/shortcuts/apdd711f9dff/ios), [automatic execution](https://support.apple.com/en-au/guide/shortcuts/apd602971e63/ios).
4. **Later bank/Account Aggregator integration:** investigate only if import effort is unacceptable and a provider explicitly supports this personal use case. The normal AA ecosystem involves regulated financial information users; it is not a generic personal API key. AA self-use provisions also do not automatically authorize forwarding data to our app. Coverage, onboarding, cost, consent scope, narration, and permitted downstream processing must be checked with a provider. [Sahamati FAQ](https://sahamati.org.in/faq/), [AA self-use consent](https://sahamati.org.in/aa-fair-use-template-library/ct019-self-use-consent-on-aa-apps/).

Do not base the product on scraping payment apps, private endpoints, broad access to other apps' notifications, or collecting banking passwords/UPI PINs. The proposed iPhone automation interface is the user-configured Shortcut. An email-triggered Shortcut can supplement missing SMS alerts if your banks send suitable email and the message content is available to the action. Broad mailbox access is unnecessary for the initial release.

Kotak documents SMS/email alerts and downloadable statements; HDFC documents configurable SMS/email InstaAlerts. These pages do not establish that your accounts send every small UPI payment or preserve its original note. The proof of concept must compare small/large debits, incoming payments, refunds, and different UPI apps against bank records. Alert thresholds, templates, delays, sender changes, and account-specific charges are unresolved until checked; do not apply an old published threshold to your account as a current fact. [Kotak alerts](https://www.kotak.com/content/dam/Kotak/Customer-Service/Important-Customer-Information/convenience-banking-guide/convenience-banking-guide.pdf), [Kotak statement access](https://www.kotak.com/content/dam/Kotak/sitemap-nb-2.pdf), [HDFC InstaAlerts](https://www.hdfc.bank.in/ways-to-bank/digital-banking/phone-banking/instaalerts).

**A three-hour polling interval does not solve missing access to transactions.** An ordinary iOS app cannot promise exact recurring background execution, and no personal transaction API has been verified here. Prefer capturing an alert when it arrives, then refresh the app's calculations on launch and on best-effort background opportunities. A timed Shortcut may process an existing local capture queue; it cannot manufacture missing SMS, scan payment apps, or unlock an inaccessible data source. Treat three hours as a desired freshness target, never a guaranteed service level. Show “last captured,” “last processed,” and “reconciled through” separately. [Apple's background execution limits](https://developer.apple.com/forums/thread/685525).

**The first milestone is a data-access experiment with a clear pass/fail result.** Use redacted samples for development; preserve formats and consistent pseudonymous references. Do not commit real statements or journals to this repository.

| Experiment | Method | Pass condition / resulting decision |
| --- | --- | --- |
| Notes survive export | Compare 10–20 existing payments with known notes against a GPay export; optionally repeat with Paytm. Include merchant, person-to-person, and unannotated payments. | Required fields and notes visible in source survive import exactly. Record any unavailable fields. If notes fail, choose private in-app memos or receipt enrichment explicitly. |
| Account coverage | Reconcile a short period of app payments with the corresponding bank statement. Include refunds and own-account transfers if available. | Explain every mismatch; identify whether UPI Lite or credit-card payments require another source. |
| Shortcut reliability | Observe normal payments for 3–7 days, including locked phone, offline phone, restart, and changed sender/template where practical. Do not make unnecessary payments just for testing. | Report capture rate, latency, omissions, and duplicate rate. It remains supplemental until the observed reliability is acceptable. |
| Health availability | On your phone, request only selected types and compare returned records with Health. | Show real available sleep/activity data; missing types render as unavailable. |
| Free installation | Build with an Xcode Personal Team and launch on your iPhone 15. Test HealthKit, App Intents, and extensions. | Confirm actual provisioning; perform an update/re-sign test without deleting data and document the weekly renewal process. |
| Laptop archive | Transfer a synthetic archive to this Mac, restore it, then simulate an interrupted transfer. | Only verified records become eligible for phone eviction; an interrupted archive loses nothing. |

If seamless sync is a hard requirement and none of the tested access routes satisfies it, that blocks the finance feature as specified. The result should be an honest integration decision before building extensive dashboards.

**Use five navigation tabs: Today, Money, Health, Reflect, and Learn.** Reviews live on Today and in the relevant sections. Settings contains import sources, permissions, notification times, privacy, backup, and data deletion.

| Surface | What opens first | Main actions |
| --- | --- | --- |
| Today | Spending this week with coverage status, last night's available sleep, one reading, and one reflection action | Review uncategorized payments, continue reading, check in, run a review |
| Money | Current-month spending, refunds, category bars, and recent transactions | Import, search, correct categories, split a purchase, add a private memo, set optional budgets |
| Health | Sleep duration/consistency and activity trends, each with last sync and source | Select Health permissions, refresh, add a manual entry |
| Reflect | A short check-in or tonight's journal | Record mood/energy/stress, write, read a short exercise, revisit a review |
| Learn | One recommended reading and two alternatives | Read offline content, bookmark, answer a recall question, choose easier/deeper material |

The home screen should never display a complete-looking spending total without naming its coverage, for example “GPay imports through 10 Sep; other sources pending.” Use Dynamic Type, VoiceOver labels, sufficient contrast, dark mode, and large touch targets. Show empty states and source errors clearly. Avoid streak penalties, infinite feeds, guilt-driven copy, and an opaque overall productivity score.

**Money is the first complete vertical slice.** The flow is source → extraction → normalization → matching → review → ledger → categories → charts. Imports should remain useful without AI or a network connection.

Store money as integer paise, retain source dates and timezone/precision, and preserve immutable source observations. A normalized transaction may have several observations: a bank posting, an SMS, and an app receipt. Imported evidence and your edits are separate so re-importing never erases a correction.

| Record | Essential fields |
| --- | --- |
| Account | Internal ID, display name, bank, masked suffix, account/funding type, currency, source coverage |
| Import batch | ID, source kind, local file hash, parser version, covered date range, row counts, errors, commit/rollback status |
| Source observation | Batch/row reference, source transaction ID, UPI reference when present, amount, direction, event date/precision, status, counterparty, raw narration, original payment note, original app tag, extraction confidence |
| Transaction | ID, account, amount, currency, occurred/posted dates, direction, normalized status, funding rail, merchant alias, category, review state, linked observations, refund/transfer links |
| Allocation and rule | Transaction splits, expense/transfer/investment classification, category, personal share, private memo, rule priority, user override, change history |
| Daily health summary | Day/timezone, metric/unit, value or missing state, source identifiers, coverage, last query time, derivation version |
| Check-in / journal | Timestamp, optional mood/energy/stress/focus scales, optional context tags and text, user corrections, sharing exclusions |
| Reading / progress | Title, track, level, prerequisites, duration, canonical URL, author, verified date, original summary/body, content rights, bookmark/progress, recall result |
| Review packet / report | Scope, date window, source revision, freshness, exclusions, evidence IDs, aggregate metrics, output, model/prompt version where relevant, job state |

Match duplicates first using validated source/account/reference combinations; UPI reference conventions vary. Cross-source matching uses verified reference IDs plus amount, direction, and account. Same-amount/time/merchant matches without a reliable ID are suggestions for review, never silent merges. A repeated import must add zero duplicate transactions. Rollback removes that batch's observations and only removes canonical records that no remaining evidence or user entry supports.

Use these accounting rules from the beginning:

- Finalized expense allocations count toward spending. Pending/unknown payments and alert-only provisional entries are shown separately; failed payments do not count as purchases.
- Show gross expense, linked refunds, and net expense separately. Income is a separate flow, not automatically subtracted from expenditure.
- Records manually classified as transfers or investment contributions are excluded from consumption spending. Own-account debit/credit records remain ordinary transactions by default, per the 19 September preference; do not automatically pair or exclude them.
- Distinguish a credit-card repayment from the underlying purchase. Do not count both when card transactions are imported.
- For UPI Lite/wallets, avoid counting both the top-up and individual purchases. If purchase-level coverage is absent, show the unresolved funded amount rather than inventing categories.
- Support splits and reimbursements. A reimbursement offsets a shared expense only after the user links it; an arbitrary incoming payment is not assumed to be a refund.
- Store posting date and original purchase link for refunds. Default period cash-flow reporting uses posting date; original-purchase views can show adjusted cost. Label the difference.

Start categories with groceries, eating out, transport, shopping, bills, rent, subscriptions, health, learning, travel, gifts, and uncategorized. Transfers and investment funding are transaction classes. Allow your own categories.

Categorization order: your transaction override → your merchant/category rules → conservative merchant/narration mapping → optional AI suggestion → uncategorized. Corrections can become reusable rules. “AMAZON” is not sufficient evidence of what was bought; ambiguous vendors and transfers to people should remain reviewable.

The first charts are category bars, daily/weekly spending, month-to-date versus the same elapsed period last month, merchant totals, and recurring-payment candidates. Every chart must drill down to its contributing transactions. Optional budget bars show a user-chosen target and remaining amount. Missing source coverage and category confidence travel into every review.

**Health integration is feasible through Apple's HealthKit.** Request read access only to the chosen types: sleep samples, steps, walking/running distance, active energy, and workouts; add resting heart rate or HRV only if you want them. Health, Sleep, and Fitness contribute relevant records to the shared health store; there is no need to scrape their screens. Availability depends on what your devices/apps record, and not every UI feature or proprietary score in Apple's apps is necessarily exposed. [HealthKit](https://developer.apple.com/documentation/healthkit), [sleep sample type](https://developer.apple.com/documentation/HealthKit/HKCategoryTypeIdentifier/sleepAnalysis).

**India is not a blanket blocker for the planned HealthKit integration.** Apple's India privacy page explicitly describes third-party health/fitness apps sharing data through HealthKit with user control. Apple's India Health page describes Watch sleep tracking and activity data. Some individual medical features and services have region, device, or software restrictions, which are separate from reading available sleep/steps/workout records. Fitness+ subscriptions and hospital Health Records integrations are not dependencies of this app. This conclusion is based on Apple's published India documentation; confirm actual samples on your iPhone 15 and Watch Ultra in the free-signed prototype. [Apple India: HealthKit privacy](https://www.apple.com/in/privacy/features/), [Apple India: Health](https://www.apple.com/in/health/), [regional feature availability](https://www.apple.com/in/watchos/feature-availability/).

Use `HKHealthStore.isHealthDataAvailable()` before requesting permissions and handle device-management restrictions and empty results. The Mac companion imports the phone's exports; it must not assume it can query the iPhone's HealthKit store or obtain the same data directly through native macOS HealthKit. [Apple's availability documentation](https://developer.apple.com/documentation/HealthKit/HKHealthStore/isHealthDataAvailable()).

Apple Watch can record estimated sleep stages when worn during sleep. Without a compatible source, use manual sleep entries and whatever activity data your phone records; do not turn a configured bedtime into measured sleep. [Apple Watch sleep tracking](https://support.apple.com/en-gb/guide/watch/apd830528336/26/watchos/26).

Refresh on launch and manual pull-to-refresh; add observer queries with anchored incremental reads and deletion handling. Background delivery is best effort, and Health data may be inaccessible while the phone is locked. HealthKit deliberately hides whether read permission was denied, so “no accessible data” must not be presented as a definite permission diagnosis or zero activity. [Background delivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)), [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

Reconcile overlapping sources: deduplicate sample identifiers, use appropriate HealthKit aggregate queries, and resolve conflicting sleep intervals according to a visible source preference. Never add phone and watch steps blindly. Keep in-bed, awake, and asleep durations distinct. Assign overnight sleep to the wake date for daily comparisons, preserve timezone metadata, keep naps separate, and handle travel/daylight-saving transitions.

Begin with sleep duration, bedtime/wake-time consistency, steps, and workout frequency. These are descriptive wellness views; no invented diagnostic sleep/readiness score. Health-derived data, including summaries, must remain within a clearly disclosed health/fitness purpose. Any third-party processing needs an appropriate design and explicit permission; the general finance analysis path should not receive HealthKit data. [Apple's HealthKit privacy requirements](https://developer.apple.com/documentation/healthkit/protecting-user-privacy).

**Reflection should take roughly two minutes a day.** Start with a configurable morning energy check and an evening journal, with an optional midday check-in. Let the user skip, snooze, or disable any prompt. Respect quiet hours and Focus; lock-screen notifications contain neutral text, never financial amounts or journal excerpts.

Suggested prompts are “How is your energy right now?”, “What is taking most of your attention?”, and, in the evening, “What helped today?”, “What felt difficult?”, and “What is one small change for tomorrow?” Use stable optional 1–5 scales for mood, stress, energy, and focus. Tags such as work, social, rest, exercise, and money worries are self-reported context. User ratings remain authoritative over inferred sentiment.

Provide 1–3 minute original readings with a short exercise and source link: noticing thoughts, grounding attention, breaking a task into a small action, reflecting on values, and responding to yourself with less judgment. Start from [WHO's Doing What Matters in Times of Stress](https://www.who.int/publications/i/item/9789240003927) and [NHS guidance on reframing thoughts](https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/self-help-cbt-techniques/reframing-unhelpful-thoughts/). Use original summaries or properly licensed adaptations, not copied chapters.

A sample card: “When a day feels wasted, separate the events from the conclusion. Write down what actually happened, then the label you gave the day. Try a more specific description, such as ‘I was interrupted twice and finished one task.’ Choose one small next action. You do not have to force a positive interpretation.” This is a brief reflection exercise, not a diagnosis or treatment claim.

The app should let you correct interpretations and exclude entries from analysis. Do not infer psychiatric diagnoses, personality labels, or hidden motives from payments or journaling. If an entry explicitly signals immediate danger, interrupt routine coaching with a supportive route to human help; do not market the app as emergency monitoring. Any region-specific help details should be verified before release.

**The learning section should make useful reading the easiest next action.** Default to three finite choices per day, a resume button, and a Home Screen reading widget later. Begin with 20 original lessons of about 400–700 words, each with a concept, example, limitation, source, and one recall question. Cache original/licensed lessons offline; open external full articles at their source rather than republishing them without permission.

| Track | Proposed progression | Initial source anchors |
| --- | --- | --- |
| Systems / CS | HTTP and caching → indexes and transactions → queues and idempotency → replication and consistency → consensus → design exercises | [MIT distributed systems course](https://pdos.csail.mit.edu/6.824/) for the distributed-systems portion; fetch targeted primary sources when writing other lessons |
| Blockchain | Accounts and transactions → signatures and gas → EVM execution → consensus/finality → rollups → security assumptions | [Ethereum developer documentation](https://ethereum.org/developers/docs/) |
| DeFi | Constant-product AMMs → price impact and slippage → LP returns and loss → lending and liquidation → oracle design → MEV | [Uniswap protocol concepts](https://developers.uniswap.org/docs/get-started/concepts/how-uniswap-works); add verified protocol-specific sources per lesson |

An initial week could cover transaction idempotency, database indexes, Ethereum transaction lifecycle, AMM price impact, caching tradeoffs, a protocol walkthrough, and a short review. Adjust to your current level; this is a suggested curriculum, not an assessment of your knowledge. Offer simpler/deeper versions and resurface weak recall items after roughly 1, 3, and 7 days. Measure usefulness and recall, not scroll time.

**Twice-weekly analysis should return a small, evidence-backed report.** The user starts it with an in-app button or a request such as “Review the last seven days and send the findings to my app.” A suggested Wednesday/Sunday habit is optional; this plan does not create a recurring automation.

The pipeline is:

1. Select the date range and scope. Show which sources are fresh, incomplete, or excluded.
2. Produce deterministic aggregates locally: spending by category/merchant, coverage, self-reported ratings, journal excerpts only if selected, and learning progress. Keep health-enabled wellness analysis in its permitted scope.
3. Build a versioned review packet with evidence identifiers, timestamps, definitions, and missing-data counts. Remove account numbers, UPI IDs, and unnecessary identifying details before any external processing.
4. Generate a report from those facts. The model writes explanations and proposals; it does not invent ledger totals, facts about your day, or causal explanations.
5. Validate schema, references, numerical consistency, scope, and unsupported claims. If validation or AI processing fails, return the deterministic summary with an honest error state.
6. Store the report in the app. You can accept one experiment, reject a finding, or mark it irrelevant. The next review checks the experiment's outcome without assuming causality.

Each report contains at most three observations, one question worth considering, one small experiment, and one relevant reading. A finding includes its period, evidence links, data coverage, and uncertainty. “Dining spending rose by ₹X across Y transactions” can be computed. “Stress caused your purchases” cannot be inferred from a small observational dataset.

Initially show descriptive summaries. Only surface repeated wellness associations after a configurable minimum amount of paired data (starting design: 14 paired days within 28 days, with at least five observations in each compared group). These are product thresholds to reduce noisy output, not statistical guarantees. Show group counts, missing days, and plausible alternative explanations. Avoid searching hundreds of relationships and reporting whichever looks strongest. A same-week prior baseline must have comparable coverage.

**Your Mac will be the v1 archive and analysis bridge; no cloud server is needed.** The phone owns current collection. A small companion process on this Mac receives explicitly synced data and stores an encrypted archive outside the source repository and any cloud-synced folder. Local deterministic code prepares a selected summary; only that summary and approved excerpts become visible to the model when you ask for a review. Archiving all chosen app records onto your Mac is distinct from uploading all of them to this chat.

Start with an encrypted archive file sent through AirDrop or Finder file transfer and a matching report-import flow. Add paired local-network transfer for convenience: same network, Mac awake, explicit local-network permission, device pairing, and an authenticated encrypted channel. Prototype TLS/device identity handling without relying on paid Associated Domains, CloudKit, or push capabilities. The phone initiates transfer while active; the Mac cannot assume it can open a server inside a suspended iPhone app. Transfer resumes by batch/chunk after disconnection. When the Mac is unavailable, collection continues locally.

Add a local command-line interface and then, if useful, an MCP server running as a local process. Codex documents local STDIO MCP servers, so a public endpoint is unnecessary for this desktop workflow. [Codex local MCP support](https://developers.openai.com/codex/mcp/).

A request here such as “Sync what is available, archive it, review the last seven days, and return the report” checks the latest local archive/phone connection, prepares the selected summary, analyzes it, and saves the report for the phone. If the phone is locked, offline, or not running the transfer flow, the operation reports that fresh sync is pending. You may need to open the app and tap “Sync to Mac.” The phone imports the saved report on its next connection. A remote cloud instance is only a later convenience for away-from-home access and availability; it does not remove iOS access limits.

**Archive before eviction, and make retries safe.** Export a versioned snapshot with record IDs/revisions, attachments, counts, checksums, and a manifest. The Mac writes it to a temporary location, verifies every file, opens/restores the data, checks counts and finance totals, and atomically commits the archive. Only then does it return an authenticated receipt identifying the exact archived revisions. The phone removes only those acknowledged revisions, never newer edits or unsynced records. Retry and acknowledgment loss are idempotent. Test disk-full, lost acknowledgment, interrupted transfer, wrong archive key, and partial restoration.

Proposed retention: keep the latest 90 days of detail, all recent reviews, historical aggregates, and small deduplication/archive indexes on the phone. Archive heavy receipt PDFs/images first; transaction text and journals may consume relatively little space. Keep a seven-day recoverable eviction queue before final local cleanup, and require a second verified backup of the Mac archive before evicting irreplaceable originals. The storage screen shows measured recoverable bytes and archive status. Retain source fingerprints so a later statement import does not resurrect duplicate archived transactions. Older detail is available when the Mac reconnects; offline charts clearly state when only aggregates are cached.

Deleting the app's cached HealthKit samples only reclaims this app's space; it does not delete Apple Health or Watch source history. The v1 app requests read-only HealthKit access and never removes that source history. Archive/analysis actions remain scoped separately: asking for a review alone never starts cleanup. An explicit combined archive-and-cleanup request or a user-configured retention policy invokes the verified archive flow.

| Proposed bridge operation | Purpose and limit |
| --- | --- |
| `get_data_status` | Return available packet dates, source coverage, and permitted scopes without raw entries. |
| `get_review_packet` | Read one permitted, versioned packet for the requested period. No arbitrary database queries. |
| `save_review` | Validate and save a report referencing that packet. Cannot alter payments, journals, or permissions. |
| `get_review_status` | Return a job's state/result and distinguish queued, running, failed, and completed. |
| `get_sync_status` | Return Mac/phone connectivity, latest archive revision, and pending sync state. |
| `verify_archive` | Verify a local archive and return a receipt plus eligible revisions; no phone deletion. |

Use scoped authentication, bounded date windows, idempotency keys, packet revisions, expiry, and audit metadata. Reject writes based on unauthorized or deleted packets. Source text, journal entries, and reading content are data, never instructions granting tools new privileges. A chat request to analyze should not authorize deleting or editing source records.

A separate in-app “Analyze” button can call a server-side AI service through the same packet/report contract. That is an API-backed execution path, distinct from this chat doing the reasoning. Keep API keys out of the app binary, bound input/output and retries, and choose a model after measuring cost and quality on representative packets. OpenAI's API data controls state that API content is not used for training by default; ordinary abuse-monitoring retention may still apply, and `store:false` is not a guarantee of zero retention. Chat product controls must be checked separately. [API data controls](https://developers.openai.com/api/docs/guides/your-data).

If you require all processing to stay on your devices, retain deterministic analytics and curated readings and evaluate an on-device model separately. Do not promise equivalent deep analysis or silently use a cloud fallback.

**Use a native SwiftUI app for the initial implementation.** This is the recommended engineering choice for a personal iPhone app with HealthKit, local notifications, document sharing, and Shortcuts. There is no existing web or mobile code to preserve. Reconsider a cross-platform framework if Android becomes a real requirement.

| Layer | Proposed implementation |
| --- | --- |
| UI | SwiftUI, native navigation, Swift Charts; target iOS 17+ initially, subject to your device |
| Local persistence | SwiftData with explicit migration versions, transactional import service, and separate raw-observation/canonical models; disable automatic CloudKit sync initially |
| Import | PDFKit text extraction, Vision OCR fallback, CSV parser, and a narrowly scoped Excel parser if the Paytm trial warrants it |
| Apple integrations | HealthKit, UserNotifications, Share Extension/App Group inbox, App Intents for import/check-in/review actions |
| Core calculations | Pure Swift functions for parsing, reconciliation, spend calculations, and health aggregation; independent of UI and AI |
| Mac companion | Local archive importer/exporter plus a small TypeScript CLI/MCP adapter; encrypted storage and a durable report outbox; paired encrypted LAN transfer after the file workflow works |
| Content | Versioned original lesson/exercise bundles with source and rights metadata; downloadable updates later |
| Tests | Swift Testing/XCTest for money/import/aggregation invariants; device tests for HealthKit, Shortcuts, sharing, permissions, and signing |

Organize the code into app features (Today, Money, Health, Reflect, Learn), core domain/calculation modules, storage, and adapters. Keep provider parsers replaceable. Avoid a microservice architecture, vector database, or autonomous multi-agent pipeline for this one-user app.

Protect local files using iOS Data Protection and store secrets in Keychain. Offer Face ID app lock, conceal sensitive app-switcher previews, and keep sensitive text out of logs. Use a minimal App Group import inbox rather than sharing the entire database with extensions. A Shortcut may need to queue work until unlock; preserve confidentiality rather than quietly weakening storage protection for background execution.

Provide an encrypted user-controlled backup/export and restore flow, with a documented recovery secret. Keep derived HealthKit caches out of general cloud backups by default and re-query the health store on restore. Review actual backup behavior on a device before promising that data stays exclusively on the phone. Deleting an app-created entry, imported batch, or review must remove associated derived artifacts and queued packets as appropriate. Explain that deleting a derived health cache does not delete source records in Apple Health. Test migrations and restore before relying on the app for ongoing records.

The Mac archive and model-visible review packet have separate access boundaries. Avoid printing raw archived financial/health/journal records into terminal or tool output. Mac code computes aggregates and exposes only the selected review scope. If a hosted relay is added later, its default payload should be approved packets/reports rather than the full archive, with explicit expiry and deletion behavior. TLS and encrypted server storage do not make model-processed content end-to-end encrypted; do not claim otherwise.

**Start with free Xcode Personal Team installation on your own iPhone.** Apple's current iOS capability table lists HealthKit, App Groups, Background Modes, and Data Protection for the free Apple Developer account column. I verified the rendered table because the text-only search result omitted its checkmarks. HealthKit itself is therefore not a reason to buy membership. Verify the actual app's signing and entitlements in Phase 0. Free provisioning expires after seven days, so document a rebuild/reinstall update from your Mac that preserves the existing app container. The app may stop opening or collecting through its own actions after expiry until renewed. [Free account capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios), [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

Avoid v1 dependencies on remote push notifications, Sign in with Apple, CloudKit, Associated Domains, or a separately entitled Siri integration. Use local reminders, explicit device pairing, document imports, and tested App Intents/Shortcuts actions. These choices do not remove platform scheduling limits. A PWA would avoid weekly signing for basic finance/journal/reading views but cannot directly replace native HealthKit; reconsider it only if weekly renewal is unacceptable and health import through an explicitly tested Shortcut/file workflow is acceptable.

TestFlight remains an optional paid convenience if weekly re-signing becomes a practical blocker to reliable collection. It requires the developer program; a public App Store release is unnecessary. Apple lists membership at US$99 per year with regional pricing, and TestFlight builds expire after 90 days. Do not enroll or purchase it as part of v1 by default. [Membership](https://developer.apple.com/programs/enroll/), [TestFlight](https://developer.apple.com/testflight/), [build expiration](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses).

**Deliver in small releases, with finance usable before the rest is complete.** The following are planning estimates for one focused developer with AI assistance, not delivery commitments. Actual export quality, signing, device testing, and your decisions may change the schedule.

| Phase | Estimated effort | Concrete deliverable and exit condition |
| --- | --- | --- |
| 0. Feasibility | 2–3 days, plus 3–7 days of passive alert observation | Kotak/HDFC field and coverage tests, note export test, India/device HealthKit proof, free signing and update path verified |
| 1. Foundation | 2–3 days | Running native app, local storage, navigation, privacy settings, synthetic demo mode, one supported import entry point |
| 2. Automatic capture | 3–5 days | Kotak/HDFC SMS adapters and tested personal Shortcuts, email supplementation only if needed; provisional entries, failure visibility, and capture coverage measured |
| 3. Spending MVP | 5–7 days | Proven app/bank export adapters for history and reconciliation; review, deduplication, categories, search, charts, backup/restore; known totals reconcile |
| 4. Health | 3–5 days | Real sleep/activity data, source-aware aggregation, manual fallback, last-sync and missing-data states |
| 5. Reflection and learning | 4–6 days | Configurable check-ins, journal, initial exercises and 20 lessons, reading progress and recall; useful offline |
| 6. Mac archive and transfer | 4–6 days | Encrypted archives, resumable transfer, verified receipts, restore checks, safe phone retention/eviction, and report outbox |
| 7. On-demand reviews | 2–4 days | Local summary preparation and CLI/MCP review/save path; scope/freshness/evidence validation; no required paid API service |
| 8. Personal beta reliability | 2–3 days | Device acceptance checks, migration/restore, accessibility, weekly free-signing update walkthrough, and signing-expiry recovery |
| Later. Investments | Separate scope | Manual holdings and transaction tracking after the spending workflow is established |

This is roughly 12–18 working days for the finance release including automatic-capture work, and 27–42 working days for the broader app, approximately 6–9 working weeks excluding setup delays. These estimates include the added Mac archive/restore workflow. If a capture experiment fails, stop and agree on an acceptable input route rather than calling manual imports automatic sync.

Investment tracking later should support asset class, symbol/identifier, platform/account, currency, units, buy/sell dates, cost, fees, and dated manual valuations. Keep contributions separate from expenses. Begin with allocation and cost-versus-value views; add returns only when cash-flow history is complete enough to compute them correctly. Live quotes, brokerage logins, wallet signing, trading, tax calculations, and investment recommendations are separate future decisions.

| Acceptance area | Required evidence before depending on the feature |
| --- | --- |
| Finance accuracy | Every supported fixture row is imported or explicitly rejected; amounts/directions/dates match; import totals reconcile to source records; known note text survives exactly |
| Finance edge cases | Re-import and overlapping imports do not inflate totals; pending→success updates, failed/reversed payments, own transfers, reimbursements, credit repayment, and UPI Lite coverage are exercised |
| Categorization | User edits survive re-import; ambiguous payments remain reviewable; every chart total matches its transaction drill-down |
| Health | Device records match expected date/unit/source treatment; overlapping sleep and phone/watch records do not inflate totals; missing data, deletion, lock, and revocation scenarios behave safely |
| Data durability | Interrupted imports roll back cleanly; an encrypted backup restores on a clean install; schema migration preserves notes and allocations |
| Archive and retention | Interrupted transfer, disk-full, stale receipt, acknowledgment loss, concurrent edits, and re-import after archiving lose no records; cleanup is restricted to verified eligible revisions |
| Free signing | A weekly provisioning renewal preserves app records; expiry fails visibly and post-renewal collection resumes without duplication |
| Reviews | Evidence and numbers validate; stale/incomplete packets are labeled; sparse-data cases avoid strong conclusions; retries do not create duplicate reports; source text cannot override tool policy |
| Personal usefulness | After two weeks, aim for under five minutes of weekly money cleanup and roughly two minutes of daily reflection; adjust these targets after observing your actual workflow |

The recommended v1 adds no Apple membership, cloud-instance, or separate model-API requirement. It uses your existing iPhone, Watch, Mac, and this Codex workflow; your existing service usage limits still apply. Free signing has a weekly maintenance cost in time. Bank alert charges, if any, depend on your account; do not subscribe to paid alerts without checking. Paid TestFlight convenience, a hosted relay, and a standalone in-app AI API are optional later decisions. Choose a usage budget and inspect actual provider pricing before enabling any of them.

The next executable step is Phase 0: inspect 2–3 representative redacted transaction alerts per bank and a GPay statement containing a known payment note; verify small-payment coverage, free installation, and actual HealthKit records on your devices. Preserve date/amount/reference structure in test samples while replacing personal identifiers consistently. The first end-to-end build should then be: capture/import → review → categorized ledger → expenditure chart → install on your phone, followed by a verified Mac archive.
