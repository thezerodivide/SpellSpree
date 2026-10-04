REVIEW OF: Step 6 / Decision 30 / Revision 1 / From ChatGPT / 2026-10-03

*(Archived by Claude from text the developer pasted, 2026-10-03. The "For Shane" part is a plain-English summary for the developer.)*

**For Claude**

I have read the current `spellspree.lua` supplied by Shane. No more baseline code needs to be pasted. Before verdicts on A–K, please answer these design questions:

1. **Class mapping and UI:** `ABBR_TO_FULLNAME` currently excludes Warrior, Monk, Rogue, and Berserker, although their abbreviations are recognized earlier. Confirm the required additions. Define whether the parent class checkbox includes Discipline Tomes, including its checked state for tome-only classes.
2. **Known-list completeness:** How will the scan distinguish zero known disciplines from failed reads? What happens with partial reads, the 60-empty-slot stopping rule, or reaching the 400-slot limit?
3. **Normalization:** Have the observed tome and discipline names been checked for collisions under removal of all non-alphanumeric characters? Explain the identity rules separately for known-discipline matching and purchase deduplication.
4. **Cross-vendor attempts:** E records bought or known tomes, but does not explicitly cover failed purchase attempts. Define whether a tome can be attempted again at the second Berserker vendor after failed payment, selection failure, a vanished row, or an affordability skip. State when the run-wide record is updated.
5. **Landed-item verification:** The baseline warns on an exact-name mismatch and proceeds if the landed item is a scroll. Define what the tome path does if a different tome lands in the expected slot.
6. **Learning completion and event timing:** The baseline treats a missing or differently named slot item as scribed, then records that outcome even if the cursor remains occupied. Explain how the tome path distinguishes consumption from an already-known tome moving onto the cursor before recording an outcome. Include event processing, delayed or absent messages, and association of the message with the current attempt.
7. **Cursor recovery:** Before `/autoinventory`, how will the script verify that the cursor holds the expected tome? Specify the recovery wait, Stop handling, and behavior when recovery fails.
8. **Diversive Strike:** Can the offered server data establish what it teaches? Describe the investigation needed before choosing an alias, skipping it, or buying an unresolved tome. Buying it despite unresolved identity is still a proposed decision.

Please distinguish observed evidence from assumptions. These are context questions, not approval decisions.

**For Shane**

The current file supplied the baseline, so Claude only needs to explain the proposed safeguards. The main unresolved risks are repeat purchases across vendors and mistaking a tome moved onto the cursor for a learned discipline.

Consensus has not yet been reached, so Step 6 is not approved.
