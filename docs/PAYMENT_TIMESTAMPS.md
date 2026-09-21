# Payment timestamps

Capture Bank Alert accepts an optional **Message timestamp** (date and time).

- If the incoming Message variable exposes its original timestamp on the user's iPhone, pass that value into Message timestamp. Do not extract dates from the SMS body to populate this field: the bank templates usually contain only a calendar date.
- Availability and the exact Shortcuts property label still need an on-device check. Original SMS sent/received metadata is not available from the text alone, and sending, delivery and bank posting times can differ.
- With no supplied timestamp, alerts whose bank date matches the automation run date in India use run time as a labeled estimate. Existing automations gain this fallback without an additional parameter.
- If the bank date is older/different and no timestamp was supplied, retain the bank date with unknown time. Manually pasted historical SMS also keep date-only precision.
- A supplied message timestamp is used as a complete instant; the original bank date is retained separately even when delivery crosses midnight.
- Stable-reference replays keep the original record and its time, preserving user corrections. Existing records are not retrospectively assigned made-up times.

New records retain time provenance in the ledger. Historical midnight records cannot be repaired without original timing evidence or manual correction. The optional fields remain backward-compatible with existing snapshots and archives.
