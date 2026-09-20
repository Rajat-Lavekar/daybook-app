# Money view design — 21 September 2026

## References reviewed
- Copilot Categories: https://help.copilot.money/en/articles/9504513-categories-tab-overview — ranked category rows, direct amounts and category drill-down.
- Monarch Reports: https://help.monarch.com/hc/en-us/articles/21846787088916-Using-Reports — category donut, percentage/amount labels and breakdown/trend separation.
- Monarch report examples: https://www.monarch.com/saved-reports-and-more — spending bars, category composition and Sankey.

## Decision and chart contract
Native SwiftUI / Swift Charts inside the existing iPhone Money tab. The user prefers the Monarch-inspired donut and explicitly rejected the detailed Copilot-style ranked rows. The chart shows four largest categories and a labeled remainder, with a thicker ring, rounded sectors, per-sector gradients and a soft shadow. It stays circular and front-facing so perspective does not distort shares. Gradients are an explicit user preference.

Only category names appear in compact chips. Selecting a segment or chip displays its amount and share in the center and dims the other segments. Tapping the selected chip restores the total. Period or category-data changes reset selection. Selection does not filter or scroll the ledger. Search and review filters affect only the transaction list.

Denominator: confirmed expenses before refunds in the selected period. Refunds reduce the separate net headline. Provisional, failed, pending, transfer and investment records are excluded. Own-account records remain ordinary debit/credit unless manually reclassified. No budget targets or month-over-month claims are inferred from incomplete imports. Empty periods have no fabricated chart.

Four muted composition colors and a neutral remainder have no budget-status semantics. Category names and accessible amount/share labels supplement color. Preview with fictional data only.

Recreation is an additive Codable category supported by the editor, CSV import, archive and merchant rules. Existing records are not silently reclassified.

## Deployment deferred
The user likes Monarch's refreshed reports: https://www.monarch.com/blog/monarch-brand-refresh#improvements-to-reports-and-recurring-8bb139f2f381
Keep version 0.3.0 changes local and deploy together later. Do not install this iteration on the physical phone.
