REVIEW OF: Step 1 / Decision 14 / Revision 1 / From ChatGPT / 2026-10-03

*(Archived by Claude from text the developer pasted, 2026-10-03. This message arrived before the labelling
convention existed, so the label above is retrofitted; the table below is the reviewer's text as pasted.)*

**Request changes to the proposal as a whole.** Based on the Lua baseline, these are my decisions on each recommendation:

| Decision | Verdict | What would earn approval |
|---|---|---|
| **A** | **Request changes** | Specify the snapshot source. The baseline documents that `Merchant.Item(N)` can disagree with the filtered visible list. Build from the confirmed usable-only list, retain the existing `Spell:`/`Song:` checks, and define duplicate handling. Treat unreadable price as unknown—the baseline documents unreliable zero prices. |
| **B** | **Request changes** | Replace "a few consecutive reads" with explicit polling intervals, stability criteria, and a maximum wait. Specify that readiness failure skips the vendor and logs why. Stable count is a practical heuristic, not proof the list is complete. |
| **C** | **Approve** | Exact-name row lookup followed by the existing click, buy, and scribe path fits the intended change and the baseline's visible-row approach. |
| **D** | **Approve** | Skipping and logging a missing row without retry fits the one-attempt design. |
| **F** | **Request changes** | Compare the final visible scroll list against confirmed purchases and recorded skips. Distinguish failed attempts, deliberate skips, and newly appeared scrolls. Remove A's claim that this detects every spell missing from the initial snapshot; it cannot detect something absent from both reads. |
| **G** | **Approve** | Change the purchase mechanism first, preserving current eligibility; implement level-range controls separately. |
| **H** | **Request changes** | State the selection retry limit and verify the exact expected name immediately before Buy, after intervening waits and bag operations. Retry selection only; skip and log if verification fails. |
| **I** | **Approve** | Inclusive ranges and skipping/logging unreadable levels are clear and appropriate for the later range change. |
| **J** | **Request changes** | Provide evidence for each class's vendor coverage before adopting the Cleric pattern for all 12 classes. The Lua's vendor table establishes destinations, not their actual spell-level coverage. |
| **K** | **Approve** | Keeping existing log rotation is reasonable for this scoped change. |

**E remains approved**, as you instructed.

The changes needed for approval are therefore **A, B, F, H, and J**. None requires abandoning the list-then-buy design.
