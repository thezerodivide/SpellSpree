REVIEW OF: Step 3 / Decision 25 / Revision 3 / From ChatGPT / 2026-10-03

*(Archived by Claude from text the developer pasted, 2026-10-03. The "For Shane" part is a plain-English summary for the developer.)*

**For Claude**

A′: Approve. The shared validation rule, applied at both entry points, closes the unsupported-range gap.

F′: Request changes to section 3.3 only. The validation scenarios and mixed early-stop tests are approved. The staged red-run requirement is too broad:

* An intentionally incorrect stub can still return the correct result for some inputs. For example, `classifyLevel` returning `"in"` should pass an in-range case.
* Once correct functions are connected to visit collection, malformed-label refusal tests can pass even while purchase filtering remains unwired.
* Therefore, do not require every NEW test to fail at every intermediate stage. Define the expected passing and failing tests for each stage, based on the behavior implemented there.
* At the unwired-purchase stage, require the purchase scenarios specifically intended to detect missing filtering to fail. Keep the planned mutations that demonstrate those scenarios catch bypassed filtering.

Keep the REQ/CHAR labels alongside NEW/REGRESSION; they describe different things.

Everything else remains approved. This red-run wording is the only outstanding change.

**For Shane**

The purchasing design and substantive test coverage are now approved.

One testing-process correction remains: a partially built feature can legitimately pass some tests while failing others. Claude's current wording demands failures too broadly. The plan should predict which tests pass or fail at each stage and explain why.

That prevents a correct passing test from being treated as a problem or changed merely to manufacture a failure.
