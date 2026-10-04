REVIEW OF: Step 6 / Decision 30 / Revision 2 / From ChatGPT / 2026-10-03

*(Archived by Claude from text the developer pasted, 2026-10-03. The "For Shane" part is a plain-English summary for the developer.)*

**For Claude**

The answers provide enough context for review. **Approve A, B, C, E, G, H, I, and J. Request changes to D, F, and K.**

| Item | Verdict | Review |
|---|---|---|
| **A** | **Approve** | Class-map additions, independent tome selection, tome-only class controls, and visit counting are explicit. Existing class selections do not unexpectedly opt into tome purchases. |
| **B** | **Approve** | Required visit kind separates scroll and tome behavior. Tomes remain unrestricted by level; Bazaar remains scroll-only. |
| **C** | **Approve** | The exact `Tome of ` rule is supported by the supplied observations and excludes unrelated merchandise. |
| **D** | **Request changes** | Log explicit scan/read exceptions separately from empty slots. Validate by-name results as positive slot numbers. Define how ambiguous normalized matches are handled if encountered; do not classify a tome as known from an ambiguous key. |
| **E** | **Approve** | Exact item names and recording immediately when Buy is sent provide a clear run-wide purchase limit. Entries that never reached Buy may be reconsidered at another vendor. |
| **F** | **Request changes** | Address the learning-state and whole-spree stop issues below. |
| **G** | **Approve** | Reusing outcome identities with tome-specific display labels avoids unnecessary new categories. |
| **H** | **Approve** | The proposed observations explain known checks, exclusions, purchases, and learning results. |
| **I** | **Approve** | Preserve existing scroll, range, Bazaar, and character-log behavior. |
| **J** | **Approve** | A `1.7.0-test.N` feature build is appropriate; final release authorization remains separate. |
| **K** | **Request changes** | Add tests for the revised safeguards below. |

**F: two changes needed**

1. **An expected tome on the cursor is not sufficient evidence that its discipline is already known.** The baseline explicitly allows transient cursor movement during learning. Treat that state as pending while observing the bounded learning window. Recover it as already-known only with corroborating evidence, such as the associated rejection message or a validated known-discipline lookup. Otherwise stop with an unresolved learning outcome rather than claiming "already known." Recheck immediately before recovery that the expected tome remains on the cursor.

2. **Make tome safety failures stop the entire shopping spree.** The existing `isSpreeAbortingReason` recognizes cursor, money, inventory, and scribe-failure wording. Your proposed "Unexpected item where a tome should be" and tome-learning failure reasons may not match it. Explicitly cover these failures so the script cannot stop one visit and then navigate to another vendor.

**K: add scenarios demonstrating**

- A successful learn that briefly moves the tome through the cursor is not classified as already-known.
- Missing/unreadable item-count results never establish learning success.
- An expected cursor tome without corroboration produces an unresolved outcome.
- Tome learning failure and misplaced-item failure prevent subsequent vendor visits.
- Known-scan exceptions, nonpositive by-name results, and ambiguous normalized matches are handled as specified.

**Judgment points**

- **Diversive Strike:** Approve the stated fallback of one purchase attempt per run with unresolved identity logged. An alias must be supported by server data before being added; the spelling inference alone is insufficient.
- **Cursor recovery:** Bounded `/autoinventory` recovery is suitable for the first test build once F's corroboration requirement is addressed. Its effect remains live-unverified.
- **Ledger labels:** Approve substitution.
- **Visit order:** Approve spell visits first and the larger Berserker vendor first.
- **Coverage:** The additional scenarios above close the identified gaps.

**For Shane**

The UI, vendor routing, and one-purchase-attempt-per-tome rule are agreed.

The remaining concern is learning safety: a tome briefly appearing on the cursor must not be mistaken for an already-known discipline. Also, a failed tome-learning operation must stop the whole shopping spree, rather than allowing it to continue to another vendor.

The unresolved Diversive Strike fallback is explicitly accepted as potentially costing one unnecessary tome purchase per run. We will not treat its suspected discipline identity as established.

Consensus has not yet been reached.
