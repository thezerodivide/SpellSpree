# SpellSpree — Decision Log

Append-only (Development Protocol §2). Never edit an earlier entry; add a dated
addendum. Current state lives in `PROJECT_LEDGER.md`, not here.

## Active overrides index

Entries that supersede a specification item. Read this first.

| Entry | Supersedes |
|---|---|
| D-006 | Development Protocol §9, unique-filename-per-test-build clause (this project only) |

## Entry index

| ID | Date | Title | Status |
|---|---|---|---|
| D-001 | 2026-10-03 | Baseline: merged multi-pass build (retrofit, §19) | provisional |
| D-002 | 2026-10-03 | Project governance and repository setup (retrofit, §19) | confirmed |
| D-003 | 2026-10-03 | Pre-handoff log review gate | confirmed |
| D-004 | 2026-10-03 | File logging (first change after baseline) | design approved; implemented in simulation only, not live-tested (see addendum 2026-10-03) |
| D-005 | 2026-10-03 | Versioning: keep v1.5 line, SemVer from now on | confirmed; see addendum 2026-10-03 for the strings |
| D-006 | 2026-10-03 | Test-build numbering agreed; unique filenames no longer required | confirmed; version-to-commit tie open |

---

## D-001 — Baseline: merged multi-pass build (retrofit, §19)

**Date:** 2026-10-03 · **Status:** provisional · **Supersedes:** nothing
**Retrofit:** work was done before the protocol was adopted; recorded now to the
same standard as an in-session decision.

### Story

The original `spellspree.lua` (v1.4, author: Ratlanta) walked the merchant list
once. The developer reported that it often missed spells, and attributed this to
the merchant window re-sorting vendor items mid-purchase (developer's
observation; the mechanism has not been reproduced or logged by us).

The developer edited a copy to make several passes: walk the list, close and
reopen the same vendor, walk again, until a pass finds nothing to buy. On review
(2026-10-03) the edited copy turned out to be derived from an older v1.3 base.
It lacked everything v1.4 added: Bazaar mode and `Song:` scroll support. Editing
the older copy and the original side by side would have silently dropped those.

### Requirement

- R1. Instead of one pass over the merchant list, make a pass, close and reopen
  the same vendor, and make another pass, continuing until no spells are found
  available for purchase on the vendor. *(Developer's stated behavior,
  2026-10-03.)*
- R2. The edits must not lose anything the original does. *(Developer's stated
  constraint.)*

### Design choices

- D1. A "pass" is one traversal of the visible merchant list within one open
  window. A pass that buys at least one spell triggers close, reopen, and another
  pass. Termination is a complete pass that buys zero spells. *(Developer's
  design, as implemented in their edited copy; reviewed, not changed.)*
- D2. The baseline is the v1.4 original with the developer's scan-loop changes
  applied on top, not the reverse.

### Implementation choices

Taken as found in the developer's edited copy (not independently justified by us):

- Enumerate rows with `Window('MerchantWnd').Child('ItemList').Items()` instead
  of `Merchant.Item(N)`.
- Identify items within a pass by `Item.ID()` (name fallback), in a per-pass
  seen-set that is discarded on reopen.
- Row-removal compensation: if the visible row count shrinks, step the index
  back by the number removed so shifted rows are not skipped.
- Reopen sequence: save target ID, close, wait up to ~2 s, re-`/target id`, then
  `/click right target`, wait up to ~5 s, re-verify the usable-only filter.
- `MAX_SCAN_PASSES = 100` as a ceiling. Not tuned (§15).

Choices made by the AI during the merge:

- Kept the v1.4 `isScrollName` gate (`Spell:` and `Song:`) in the post-purchase
  safety check instead of the edited copy's `Spell:`-only match.
- Removed the now-unused `merchantItem` helper.
- Set `VERSION` to `1.5-reorder-passes`. **This is not SemVer** (§9); see Open.
- Added a header comment paragraph describing passes.
- Nothing else was altered. The merge was assembled by splicing line ranges, then
  checked with a LuaJIT syntax/undefined-global check only.

### Open

- Does the usable-only filter actually drop already-scribed spells on reopen?
  R1's termination relies on it. Unverified.
- Is `ItemList.Items()` a reliable row count (no header rows, no nil)? The script
  now hard-stops if it reads nil. Unverified.
- Does `/click right target` reopen the merchant in the Bazaar, where nothing
  else is automated? Unverified.
- Does a purchase that stacks onto an existing unscribed copy get re-bought on
  every pass? Traced from the code only (the code counts it as bought without
  scribing, and R1's pass test is `S.bought` increasing). Not observed live.
- Was the developer's edited copy live-tested, and with what result? Not known to
  the AI.

### Not yet verified (do not describe as confirmed)

- Any live behavior of the merged build. No in-game test has been run on it.
- That the merge matches the original in all code outside the scan loop. Checked
  by reading and a diff of selected regions, not by a line-by-line diff.
- That R1 fixes the missed-spells problem. The cause is the developer's
  hypothesis.

### Dependencies and shared seams

- Shares the pass-termination test with the stacked-purchase question above. Any
  fix for that touches the same `boughtThisPass` counter. See ledger Open.
- Shares `VERSION` with D-002's build-identity expectations (§9).

---

## D-002 — Project governance and repository setup (retrofit, §19)

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing

### Story

SpellSpree was the work of its original author (Ratlanta). On 2026-10-03 the
original author agreed in Discord to hand over active development to the
developer ("yep, all yours"), per a screenshot supplied by the developer.

### Requirement

- R3. The Development Protocol
  (`MQClaudeTestBridge\docs\Development_Protocol.txt`) governs this project.
- R4. Documents live in `docs/` in the repo.
- R5. "Sibling project" means a project the developer owns. TAC is a reference
  project, not a sibling. `triune.lua` is part of TAC.
- R6. Only the merged build is committed as the baseline; the original and the
  edited copy are not committed.
- R7. The script keeps the filename `spellspree.lua`.
- R8. Repository: `https://github.com/thezerodivide/SpellSpree` (public). The
  baseline is pushed to `main`.

### Design choices

- The sibling list lives in `docs/WORKING_AGREEMENT.md`.

### Implementation choices

- Baseline commit `f6c29f4`, authored under the developer's configured git
  identity. It was amended once before the first push to rename the file from
  `spellspree_updated.lua` to `spellspree.lua`; nothing had been pushed before
  the amend.
- Original and edited copies remain untracked in the working tree, with no
  `.gitignore`.

### Open

- Build-identity scheme (unique filename per test build vs. R7's fixed
  `spellspree.lua`). §9 wants unique filenames for materially different test
  builds. See ledger Open.
- Ownership and licensing notes for the repo (README, licence) have not been
  discussed.

### Not yet verified

- That the original author's agreement covers licensing or redistribution; only
  the handover of development was seen.

### Dependencies and shared seams

- R7 interacts with protocol §9 (build identity) and D-001's `VERSION` choice.

---

## D-003 — Pre-handoff log review gate

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing; adds to
Development Protocol §8 and §10 for this project.

### Story

Live tests of this script need the developer in game, on a vendor, spending
real in-game currency, and some conditions are not cheap to recreate (a vendor
that reorders mid-purchase, a spell that stacks onto an existing scroll). A live
test whose log turns out to be missing the one fact needed to explain the result
costs the developer a full rerun. The protocol already requires inspecting a
representative log (§8) and asking whether diagnostics would explain an
unexpected failure (§10); the developer asked for that check to be an explicit,
named step so it cannot be skipped.

### Requirement

- R9. Before anything is presented to the developer for manual tests, the logging
  is reviewed to ensure it contains everything needed, so the developer does not
  have to rerun a manual test. This is part of the process before handoff.
  *(Developer, 2026-10-03.)*

### Design choices

- The gate is recorded as **P-1** in `WORKING_AGREEMENT.md`, so it is visible to
  any session that reads the working agreement.

### Implementation choices

Proposed by the AI; **not yet approved by the developer**. Treat as provisional
until the developer says otherwise:

- The review states, per handoff, (a) the specific questions the live test is
  meant to answer, (b) for each question, the log line(s) that would answer it,
  (c) for each plausible failure of the test, the log line(s) that would
  distinguish an operator/configuration mistake from a code defect (§8), and (d)
  anything the log cannot establish, said plainly. A question with no answering
  log line blocks handoff.
- The result appears in the handoff message so the developer can see it was done.

### Open

- Whether the same gate should be proposed upstream to the Development Protocol
  document. That document lives in another repository; this entry changes only
  SpellSpree. Developer's call.

### Not yet verified

- That the procedure above is the review the developer has in mind; only R9 is
  confirmed.

### Dependencies and shared seams

- Depends on the logging work (next change) existing, since it reviews that
  logging. Shares the §10 handoff gate with every future build.

---

## D-004 — File logging (first change after baseline)

**Date:** 2026-10-03 · **Status:** design approved by developer; implementation
choices provisional · **Supersedes:** nothing. Closes ledger Open item 6 when
built and accepted.

### Story

The baseline writes no log file. Its `logLine` narration goes to the ImGui
window and to chat only, and the 400-line in-memory buffer scrolls away. After a
live run on a vendor there is nothing on disk to say what the script did, why,
or where the evidence ends. Development Protocol §8 requires per-project logs
under `macroquest\logs\<luaname>\`. The developer's sibling PTAutoRoute already
has a working append-only logger (`lua/PTAR/PTARLog.lua`) and the project's
`mq.configDir` / `mq.gettime` use is visible in `lua/PTAR.lua`.

### Requirement

- R10. Logging follows the Development Protocol §8 standard: reconstruct build
  identity, state transitions, commands/actions attempted (with reason),
  observations used in decisions, retry counts and reasons, unexpected
  transitions, failures and why, and final outcome; state plainly where MQ
  cannot prove an action succeeded. *(Developer: "use the protocol's logging
  standard", 2026-10-03.)*
- R11. Test builds log verbosely by default (protocol §8).
- R9 (D-003) applies: the logging is reviewed against the live-test questions
  before handoff.

### Design choices (approved by developer, 2026-10-03)

- Log file: `<MQ logs dir>/spellspree/spellspree_<server>_<character>.log`,
  appended, rotated at 4 MB to `.old` (as PTAutoRoute does).
- Line format follows PTAutoRoute for cross-project consistency:
  `date time | +ms | version | LEVEL | message`.
- Existing `logLine` narration is also written to the file.
- Every `mq.cmd`/`mq.cmdf` goes through one wrapper that logs the command and
  its reason before sending it.
- Decision inputs are logged as observations: row counts per pass, selected item
  name and ID, money before/after a buy, expected and actual landing slot, scribe
  attempt results, reopen steps with their checked outcomes.
- Startup logs build identity, character, server, zone, and the resolved log
  path. MQ's inability to confirm `/notify` and `/click` is stated in the log.
- This change is logging only. `VERSION` and the file-name question are not
  touched (ledger Open item 5).

### Implementation choices (AI; not separately approved)

- Logs directory from `mq.TLO.MacroQuest.Path('logs')` (read from MQ source:
  `src/main/datatypes/MQ2MacroQuestType.cpp:123-127`), not derived from
  `configDir`'s parent as PTAutoRoute does. If the value is not absolute it is
  joined to `MacroQuest.Path('root')`. If neither works the script keeps running
  with the in-window log only and says so, once, in the window.
- Directory creation via `os.execute` mkdir, as PTAutoRoute does.
- Levels: `INFO`, `WARN`, `ERROR` (from `logLine`'s color), `CMD` (command sent),
  `OBS` (observation), `DEBUG` (existing `dbgLine`; file always, window only
  when `DEBUG` is true).
- Run-level errors are caught with `xpcall` plus a traceback instead of bare
  `pcall`, so a script error leaves a stack in the log.
- Each log call is wrapped so a logging failure can never alter run behavior.
- A simulation harness (`test/`) drives the script against a mock MQ so a
  representative log can be generated and inspected before handoff. It is
  simulation only (see Not yet verified).

### Open

- Does `MacroQuest.Path('logs')` return an absolute path in a live client, or
  the relative default `"Logs"` seen in `MQ2Globals.cpp:100`? Handled either way;
  the log records which, so the first live log answers it.
- Does `os.execute` mkdir work (and not flash a console window) inside SpellSpree's
  MQ Lua environment? PTAutoRoute relies on it; not observed here.
- Are `EverQuest.Server` and `Me.CleanName` readable at script load, before
  character data settles? Fallback name `unknown` is used if not.

### Not yet verified

- Anything about live behavior. The harness mocks MQ; mock behavior is the AI's
  model of MQ and may be wrong in ways that matter.
- That the log answers every live-test question: that is the D-003 review, done
  at handoff, not here.

### Dependencies and shared seams

- Shares every `mq.cmd` call site and the scan loop with D-001's multi-pass code;
  wrapping commands must not change their order or timing.
- Shares `VERSION` with ledger Open item 5 (printed in every line; not changed).
- Depends on D-003 (review gate) for handoff.

### D-004 addendum (2026-10-03): implementation status and evidence

Appended; the entry above is unchanged.

**What was built:** the file logger (`logWriteFile`, `logResolvePath`, `logObs`,
`sendCmd`, `logRunOutcome`) and instrumentation of every command site and the
decision points listed under Design choices, in `spellspree.lua`. 19 command
call sites now go through `sendCmd`. Run-level errors use `xpcall` with a
traceback. `VERSION` was **not** changed, as agreed.

**Confirmed from MQ source while building (read directly, MacroQuest checkout
at `Documents\MacroQuest\macroquest`, commit `5f8a6eea`):**
- `mq.cmdf` is `string.format` followed by the same execute path as `mq.cmd`
  (`src/plugins/lua/bindings/lua_MQBindings.cpp` `command_format`, lines
  194-209), so wrapping commands as `string.format` + `mq.cmd` is equivalent.
- `mq.configDir` and `mq.gettime()` exist (`lua_MQBindings.cpp:527, 56-62`).
- `MacroQuest.Path('logs')` returns `internal_paths::Logs`
  (`src/main/datatypes/MQ2MacroQuestType.cpp:123-127`); its compiled-in default
  is the relative string `"Logs"` (`src/main/MQ2Globals.cpp:100`). No Lua binding
  exposes the logs path directly.

**Evidence (simulation only):**
- `test/test_logging.lua`: 10 requirement-level tests, each citing D-004/R10 or
  the mock's own record for its expected value, all passing; 8 mutation checks,
  each caught by exactly the test(s) named for it. In the first run two
  mutations were wrongly specified (one made T6 fail legitimately because T6
  checks scribe clicks are logged; one dropped the message text and broke
  everything); the mutations were corrected, the tests were not changed.
- `test/equivalence_check.lua`: the pre-logging baseline and the logging build,
  run through four simulated scenarios, send identical commands in identical
  order, buy identical items, end with identical money and identical simulated
  elapsed time. The first run reported time differences; cause was the harness
  ending runs on a line only the new build prints, not the script. Harness
  fixed to end on a line both print; commands/purchases were already identical.
- A representative happy-path log and the failure-path logs (unaffordable
  spells; rejected scribes) were read in full by the AI as a receiving
  developer.

**Not verified / not exercised:**
- Anything live. The mock is the AI's model of MQ.
- The Plane of Knowledge path (`/nav`, `/target npc`, `runNavAndShop`) is not
  simulated; its `sendCmd` conversions are checked by static reading and the
  syntax/undefined-global check only.
- `mq.event` handlers (price-quote `dbgLine` output) are not exercised; the mock
  does not fire events.
- Open items 1-3 under D-004 (live `Path('logs')` value, `os.execute` mkdir
  behavior, character data readable at load) remain open.
- The log file has Windows CRLF line endings (the script appends in text mode);
  not considered a defect, noted so a reader is not surprised.

**Build identity risk (needs a decision, not made here):** this build and
baseline `f6c29f4` both report `v1.5-reorder-passes`. The log and window title
therefore cannot distinguish them (Development Protocol section 9). The
developer agreed to leave `VERSION` alone for this change; whether to give
test builds a SemVer pre-release identity now is a separate decision (ledger
Open item 5).

---

## D-005 — Versioning: keep v1.5 line, SemVer from now on

**Date:** 2026-10-03 · **Status:** requirement confirmed; exact version strings
open · **Supersedes:** nothing. Partly resolves ledger Open item 5 (the
version half; the unique-filename half is still open).

### Story

The baseline reports `VERSION = '1.5-reorder-passes'`. That string came from the
merge (D-001), not from the developer, and `1.5` alone is not a Semantic
Versioning 2.0.0 version (SemVer needs MAJOR.MINOR.PATCH). Development Protocol
§9 requires SemVer, with pre-release identifiers (e.g. `0.3.0-test.4`) for
builds that have not earned release status. The logging build (D-004) carries
the same string as the baseline, so the two cannot be told apart.

### Requirement

- R12. The project stays on the **v1.5** version line it is on now. *(Developer,
  2026-10-03: "keep the current versioning (v1.5)".)*
- R13. **SemVer from now on.** *(Developer, 2026-10-03.)*

### Design choices

None yet beyond R12/R13.

### Implementation choices

None made. In particular the AI has **not** changed `VERSION`.

### Open

- What exactly the string is. Two readings of R12 are both possible and the AI
  has not picked one: (a) the baseline counts as `1.5.0` and new builds move on
  from there (e.g. `1.5.1-test.1` or `1.6.0-test.1`); (b) `1.5-reorder-passes`
  is kept verbatim for the existing build and SemVer starts with the next one.
  Which pre-release builds exist, and how the logging build is numbered, is the
  developer's decision.
- Whether the existing `1.5-reorder-passes` string should be retroactively
  described as `1.5.0` in the docs. No docs have been changed to say so.
- Unique filename per test build vs. the fixed name `spellspree.lua` (R7, D-002)
  is unaffected and still open.

### Not yet verified

- That `VERSION` is used anywhere that assumes a particular shape (it appears in
  the window title and every log line; the AI has not found parsing of it).

### Dependencies and shared seams

- Shares `VERSION` with D-001, D-002 (R7) and D-004 (every log line prints it).

### D-005 addendum (2026-10-03): reading (a) chosen

Appended; the entry above is unchanged.

The developer chose reading **(a)**: the baseline counts as `1.5.0`, and new
builds move on from it. The AI had suggested `1.6.0-test.1` for the logging build
(a new feature, hence a minor bump, and a pre-release identifier because it has
not been live-tested). The developer's answer was "a"; the AI took that to
include the suggested number and said so, so it was **not** separately approved
as a number and the developer may still change it.

**Applied:** `VERSION = '1.6.0-test.1'` in `spellspree.lua` (previously
`1.5-reorder-passes`). The window title and every log line show it. The
`test/` checks read `VERSION` from the source and were re-run: all pass.

**Effect on earlier entries (they are not rewritten):** the baseline commit
`f6c29f4` still contains the string `1.5-reorder-passes`; going forward it is
referred to as `1.5.0`. The "build identity risk" in the D-004 addendum is
resolved by this: the logging build and the baseline now report different
versions.

**Still open:** the unique-filename-per-test-build rule (§9) against the fixed
name `spellspree.lua` (R7); what the next test build is numbered (`-test.2`
after any further change handed over for live testing; the AI proposes to
increment the pre-release number on each handoff and to bump MINOR/PATCH only
when a change is accepted, pending the developer's agreement).

---

## D-006 — Test-build numbering agreed; unique filenames no longer required

**Date:** 2026-10-03 · **Status:** confirmed; one implementation question open ·
**SUPERSEDES** Development Protocol §9, the clause requiring a unique filename
per test build (for this project only). Resolves ledger Open item 5 and closes
the D-002/D-005 "unique filename vs. fixed `spellspree.lua`" question.

### Story

Protocol §9 asks for a unique filename per test build so the developer can
confirm which build is being tested. SpellSpree is now on GitHub and uses
SemVer (D-005). The developer's view: with SemVer and a git repository, the
filename no longer needs to carry build identity. The script's name also matters
operationally (`/lua run spellspree`), which D-002 R7 had already fixed as
`spellspree.lua`.

### Requirement

- R14. Test builds are numbered by raising the pre-release number on each
  build handed over (`1.6.0-test.1`, `-test.2`, ...); MINOR/PATCH are bumped only
  when a change is accepted. *(AI proposal in D-005 addendum; developer: "agreed",
  2026-10-03.)*
- R15. A unique filename per build is **not** required. The file stays
  `spellspree.lua`. Build identity is the SemVer string in `VERSION` (window
  title and every log line) together with the git history. *(Developer,
  2026-10-03.)*

### Design choices

None beyond R14/R15.

### Implementation choices

None made. Still required by §9 and unaffected: the window title and the log
carry the same build identity (D-004 already does this).

### Open

- Two different working-tree states can carry the same `VERSION` if edits are
  made without bumping it. How a handed-over build is tied to an exact commit is
  not decided. AI suggestion, not agreed: commit every build before handing it
  over and tag it with its version (e.g. `v1.6.0-test.2`); the developer's call.

### Not yet verified

- Nothing live depends on this decision.

### Dependencies and shared seams

- Supersedes the filename half of D-002 Open and ledger Open item 5; builds on
  D-005. Shares `VERSION` with D-004 (printed in every log line).
