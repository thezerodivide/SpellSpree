HANDOFF: Step 3 / Decision 25 / Revision 1 / From Claude / 2026-10-03

**Subject:** Step 3 of the SpellSpree 1.6.0 release: purchases bounded by the selected level range (decision log D-025). Nothing is built and no test is written yet. This is also the first use of the TDD process the developer adopted from your guardrails (D-024), so the test-first plan is part of what I am asking you to review. Please review each item (agree, or disagree with the reason). If you need context I have not given, ask questions and give no verdicts.

## 1. Context (agreed requirements and confirmed facts, each with its source)
- 1.6.0 contains Step 1 (list-then-buy, done and accepted as a step), Step 2 (each ticked 61-70 uses that class's 1-25 vendor; approved, built, simulation-tested, not yet handed over) and Step 3 (this). D-020 R31.
- Developer, D-020 R31: "Step 3 - Implement bounded by level range to purchases."
- R21 (D-013): selecting a range buys only spells whose Lvl is in that range, inclusive. D-014 item I (approved): ranges are inclusive; a spell whose level cannot be read is not bought and is logged. R24: the 71-80 vendor is out of scope.
- R34 (D-020): each selected range is its own visit with its own limit; with all four ticked the flow is vendor 1 (1-25), vendor 2 (26-50), vendor 3 (51-60), vendor 1 again (61-70). The UI does not change (D-019 R29).
- Developer's reason (D-020 addendum): a spellbook holds a limited number of spells, so the user decides which are bought. Out-of-range spells must therefore never be bought.
- The vendor list's column 8 is the Lvl (confirmed from the window header; D-012 addendum). It is already read and logged for every row when the list is built (Step 1, A').
- The Bazaar path has no boxes, buys everything the open vendor sells, and is a separate later pass (developer, D-020 addendum 2). It is not part of this step.
- F'' (approved, D-014 round 3): every built-list entry ends with exactly one logged outcome; outcome 4, "deliberately skipped", already names "outside the selected level range" as one of its causes for Step 3.

## 2. Proposed design items (each is a separate decision for the developer)

**A. The range of a visit comes from the ticked tier's label.** `1-25` means levels 1 to 25, `26-50` 26 to 50, `51-60` 51 to 60, `61-70` 61 to 70, all inclusive, parsed from the label the UI already uses. If a tier label cannot be parsed into two whole numbers, that visit is refused with an ERROR and nothing is bought (never "no limit").

**B. The level of a spell is column 8 of the built list**, trimmed and read as a whole number. Anything else (`--`, blank, text, missing) is "unreadable".

**C. The decision.** Level inside the visit's range: buy exactly as today. Level outside the range, or unreadable: the entry is not selected or clicked; its outcome is "deliberately skipped" (outcome 4) with the reason, e.g. `outside the selected level range 1-25 (Lvl 63)` or `level unreadable ("--")`. A spell above level 70 or below 1 is outside every range, so it is never bought.

**D. PoK visits only.** `runShoppingSpree` passes the visit's range down; the Bazaar path passes none and behaves as today.

**E. Logging.** When the list is built, one `[list]` line states the visit's range and the counts (in range, outside, unreadable). The ledger lists the skipped names with their reasons, as approved. The final scan reports leftovers that were skipped as out of range as a count, not a name list (otherwise a 61-70 visit that leaves forty unscribed 1-25 spells would print forty names a second time).

**F. TDD plan (D-024), in order.**
1. Update existing expectations that approved Step 3 behavior changes, each with its reason (guardrail 4): Step 2's `S1` (the first visit to vendor 1 buys 1 spell, not 2; the second buys 1); the PoK scenarios in the logging suite and the eligibility check, whose simulated spells have no level and would now count as unreadable, so they are given levels (data only).
2. Write the new tests, each tied to R21, item I or R34 (guardrail 1): inclusive boundaries (25/26, 50/51, 60/61, 70/71, 0/1); outside-range spells never clicked and recorded as skipped with the reason; unreadable levels (`--`, blank, text) not bought and logged; each visit uses its own range (1-25 then 61-70 at vendor 1: the first buys only levels up to 25, the second only 61 to 70, none twice, nothing in 26-60); a single ticked range buys nothing outside it; levels above 70 and below 1 never bought; multi-class (each class's visit uses its own range); an unparsable tier label refuses the visit (simulated by a modified copy of the script, as in Step 2); the Bazaar buys everything as before.
3. Keep the adverse scenarios (guardrail 5): the empty list (`L19`), a row that vanishes before it is reached (`L3`), no money, a scribe that fails; and run the vanishing-row and failed-purchase cases with a range applied.
4. Run the new tests against the unchanged script and confirm each fails for the right reason, an assertion about the missing behavior and not a harness or loading error (guardrail 2). The red output is recorded in the decision log.
5. Implement; the tests go green; clean up.
6. Targeted mutation checks (guardrail 7): the two boundary comparisons, swapping the range's low and high, treating an unreadable level as in range, applying the range to the Bazaar, and an off-by-one in parsing the label. Expected failing tests are written down before the run.
7. The Step 1 and Step 2 suites and the logging suite still pass; the eligibility check compares spells bought with levels in range.
8. The approval evidence is three statements (guardrail 8): the behavior tested, what passed, and what still needs a live run. Simulation and live results stay separate. `docs/MOCK_MODEL.md` gets a row for any mock behavior added.

**G. Delivery.** Steps 2 and 3 are handed over together as `1.6.0-test.4`, tagged, after the log review (the developer approved this delivery for Step 2 in D-022). The release `1.6.0` is created only on the developer's explicit instruction after the live run.

## 3. Points where I would like your judgment
1. Item A refuses a visit whose tier label cannot be parsed instead of buying without a limit. The reason is the spellbook limit. Is there a case where refusing is worse?
2. Item C treats an unreadable level as "do not buy". Any live evidence that column 8 can be blank for a spell the user would expect to be bought? I have none: every spell row read live had a number.
3. Item E reports out-of-range leftovers in the final scan as a count only. Is that enough diagnostic, given the ledger already lists them?
4. Does the test plan in F cover Step 3's requirements, or is a requirement untested? In particular, is there an adverse scenario I should keep that I have not named?

## 4. What I am asking of you
Please review A to G: for each, agree, or disagree with the reason, and answer the four points in section 3.
