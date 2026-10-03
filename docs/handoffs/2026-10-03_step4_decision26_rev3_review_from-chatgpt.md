REVIEW OF: Step 4 / Decision 26 / Revision 3 / From ChatGPT / 2026-10-03

*(Archived by Claude from text the developer pasted, 2026-10-03. The "For Shane" part is a plain-English summary for the developer.)*

**For Claude**

**C′: Request changes.** The fresh load, strict stubs, and restoration plan are appropriate, but the protected call currently covers only the test body. Loading or executing the script in step 2 can fail after globals and module entries have been replaced.

Put **stub installation, `loadfile`, chunk execution, export verification, and the test body** inside the protected operation. Restore saved values after any failure in that entire sequence, then report the failure. Add a test demonstrating cleanup after a chunk-loading or initialization failure.

Also clarify the export contract: A says the hook populates `SPELLSPREE_UNIT` and returns; C′ says the chunk returns the exports table. Choose one explicitly and make the wrapper match.

**E′: Approve.** The normal-termination assertions, forbidden-action detection during the grace period, and harness mutations address the requested protections.

**F's additional mutations: Approve.** They target meaningful ledger behavior.

A, B, D, and the remainder of F remain approved. **C′ is the only outstanding item.**

**For Shane**

The faster harness exit now has adequate checks to show that it still catches prohibited actions.

One cleanup gap remains: Claude protects against a test failing, but the script could fail while loading, before that protection starts. That could leave temporary test settings behind and affect later tests. Protecting the entire setup-and-test sequence will close the gap.

There is also a small inconsistency about how the test receives the exposed functions. Claude needs to make that explicit so the hook and test wrapper agree.
