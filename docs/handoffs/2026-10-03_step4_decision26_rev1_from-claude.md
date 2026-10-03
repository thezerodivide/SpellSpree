HANDOFF: Step 4 / Decision 26 / Revision 1 / From Claude / 2026-10-03

**Subject:** a test hook so small units of the SpellSpree script can be tested directly (decision log D-026). This is testing infrastructure, to be built before Step 3 (the developer's decision). Nothing is built. This proposal is itself the first thing to go through the TDD process the developer adopted from your guardrails (D-024). Please review each item (agree, or disagree with the reason). If you need context I have not given, ask questions and give no verdicts.

## 1. Context
- The developer adopted TDD with your guardrails, beginning with Step 3 (D-024), and kept the testability refactor out of Step 3 as its own reviewed change (D-024 R39: "extracting the ledger into a separate function would expand Step 3's scope ... it should receive its own review before implementation"). The developer then decided to build this infrastructure first: "That infrastructure will help with every step or feature going forward."
- Today every test runs the whole `spellspree.lua` (one file) against `test/mock_mq.lua`, a model of MacroQuest and the vendor window. Its helpers are local functions, so a test cannot call one directly. A test of one small rule therefore depends on the mock's modeled behavior (`docs/MOCK_MODEL.md` classifies each as live evidence or assumption), and a failure points at a scenario, not a function.
- **A correction of mine, with measurements:** I had said the suites take one to three minutes and used that as a reason for this work. I had not measured it. Measured on this machine: one scenario takes about 70 ms; `test_listthenbuy` takes 1.0 s (9.7 s with its mutation checks), `test_logging` 2.3 s, `test_step2` 5.2 s (36 s with mutations). The slow part is one test, `S6`: its scenario (no vendor configured) ends with "No vendors selected" and never prints the summary line the harness waits for, so the run continues until the harness's 400,000-delay guard stops it (about 5 s), repeated in every mutation run. So the benefit of this work is isolation and precision, not speed, plus one harness fix.
- Not in scope here: any change to what the script does, Step 3, and the Bazaar.

## 2. Proposed design items (each is a separate decision for the developer)

**A. A test hook, with nothing moved.** Just before the script creates its window (`mq.imgui.init`), a guarded block runs only if a global table `SPELLSPREE_UNIT` exists. It copies references to selected local functions into that table and returns from the chunk, so no window, no events and no main loop start. With the global unset (production, and every existing scenario test) the block does nothing. No existing code is moved or rewritten.

**B. Initial exports.** The pure helpers (`parseCopperFromText`, `withCommas`, `formatCoin`, `formatCoinPPOnly`, `isScrollName`, `parseClassLine`), and the outcome ledger as it already exists (`setOutcome`, `markRemainingNotAttempted`, `logLedger`, the `OUTCOME` table) together with the state table `S`. Later steps add their own exports (Step 3 would add the tier-range and level-in-range functions).

**C. Characterization unit tests first.** A new `test/unit_*.lua` loads the script with the hook and a minimal stub of `mq` and `ImGui` (no vendor model), and tests the exported functions directly with explicit inputs, each citing the decision its expected value comes from (coin formatting and the ledger: D-009 and D-017 F''; scroll naming: the original script's rule). They are written before the hook exists, and their red run (the hook is missing) is recorded, confirming each fails on the assertion that the function is not exposed and not on a loading error.

**D. No behavior change, proven.** With the hook unset the script behaves exactly as before: the three existing suites and the eligibility check pass unchanged, and a mechanical check shows the only difference in `spellspree.lua` is the guarded block.

**E. A harness fix, test-only.** `test/sim_run.lua` also ends a run when the script reports "No vendors selected", so `S6` stops spending a runaway guard's worth of time. No change to the script.

**F. Targeted mutation checks on the unit tests.** For example: break the coin rounding, the scroll-prefix rule, and the ledger's "no outcome recorded" detection, with the expected failing tests written down first. Delivery: committed and tested; not a handed-over build by itself; it ships with `1.6.0-test.4`.

## 3. Points where I would like your judgment
1. Is exporting the existing ledger functions through the hook (item B) enough for the developer's stated concern, or does "extracting the ledger" require more than exposing it?
2. The hook adds one structural element to the production file: a guarded `return` from the main chunk. Is there a risk in its behavior under MacroQuest's Lua that the tests in item D would not reveal? (It only runs if the global is set, which production never does.)
3. Given the measurements above, do you see any item that should be dropped, or a case where this is not worth doing?
4. Does anything in A to F conflict with the TDD guardrails in D-024?

## 4. What I am asking of you
Please review A to F: for each, agree, or disagree with the reason, and answer the four points in section 3.
