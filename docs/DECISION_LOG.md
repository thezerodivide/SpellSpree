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
| D-007 | 2026-10-03 | Commit and tag every handed-over build | confirmed |
| D-008 | 2026-10-03 | Docs are always committed and pushed, without asking | confirmed |
| D-009 | 2026-10-03 | Fix: `Run outcome` shows per-vendor and spree totals | implemented in `1.6.0-test.2`; simulation-tested, not live |
| D-010 | 2026-10-03 | Proposal: build the vendor's spell list at open, then buy from it (spikes) | proposal; requirement S-1 unchanged until spike evidence is reviewed |
| D-011 | 2026-10-03 | Operator cues in test runs must not be buried | confirmed |
| D-012 | 2026-10-03 | Problem: spell vendors do not match the level tiers the script offers | problem confirmed by the developer; design question open (see addendum) |
| D-013 | 2026-10-03 | Requirement: tier boxes become level ranges that buy only their own levels | requirement agreed; not built |
| D-014 | 2026-10-03 | Design proposal: list-then-buy replaces repeat passes | proposed; awaiting developer approval per item |

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

### D-006 addendum (2026-10-03): open question resolved by D-007

Appended; the entry above is unchanged. The "how a handed-over build is tied to
an exact commit" question under D-006 Open is resolved by D-007.

---

## D-007 — Commit and tag every handed-over build

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing. Resolves
the open question in D-006.

### Story

With no unique filename per build (D-006 R15), a version string alone cannot
guarantee which code the developer tested: two different working-tree states can
carry the same `VERSION`. The AI suggested committing and tagging each build
before handing it over so a version always names one exact commit. The developer
agreed.

### Requirement

- R16. Before a build is handed over for live testing, it is committed, and the
  commit is tagged with the build's version number. *(Developer, 2026-10-03.)*

### Design choices

- Tag name: `v<VERSION>`, e.g. `v1.6.0-test.1`. *(AI's concrete form of the
  agreed rule; the developer agreed to "tag it with its version number".)*

### Implementation choices

- Annotated tags, pushed to `origin` together with the commits, so the version
  maps to a commit on GitHub and not just on this machine.
- The tag goes on the commit that is handed over (the branch head at handoff),
  which may include docs and tests added after the code change. `VERSION` in
  `spellspree.lua` at that commit equals the tag.
- First application: `v1.6.0-test.1`, on the commit that records this decision.

### Open

- None.

### Not yet verified

- That the developer wants tags pushed (the AI pushed the first one with the
  commits on the reading that a tag only on this machine would not serve its
  purpose).

### Dependencies and shared seams

- Builds on D-005 (SemVer) and D-006 (no unique filename). Shares the handoff
  gate with D-003: a handoff needs both the pre-handoff log review and a tagged
  commit.

### D-001 addendum (2026-10-03): Open item resolved by the developer

Appended; the entry above is unchanged.

The Open question "does the usable-only filter drop already-scribed spells on
reopen?" is **resolved: yes**, per the developer's direct in-game observation
("this does indeed behave like that; it's the entire purpose of doing multiple
passes on one vendor"). R1's termination condition therefore rests on a
confirmed behavior, not an assumption. Not recorded by the developer: which
build or vendor it was observed on, so it is a developer-stated fact, not
something a SpellSpree log has shown. Ledger Open item 1 updated accordingly.
The other D-001 Open items (`ItemList.Items()` reliability, Bazaar reopen,
stacked-purchase re-buy) remain open.

### D-004 addendum 2 (2026-10-03): first live run of v1.6.0-test.1

Appended; earlier text is unchanged. Evidence: the developer's live log
(`spellspree_multiclass_Benedict.log`, 3,239 lines, 11:20:43-11:25:33), excerpt in
`docs/evidence/2026-10-03_Benedict_v1.6.0-test.1_excerpt.log`. The developer
stopped the run during vendor 2 on purpose (a multi-vendor PoK run is not needed
for this test).

**D-004 Open questions, now answered by the live log:**
- `MacroQuest.Path('logs')` returned an absolute path
  (`C:\Users\Public\MacroQuest\Logs`); the relative-path branch was not needed.
- `os.execute` mkdir created `Logs/spellspree/`; no failure. (Whether it flashed a
  console window is not in the log; none was reported.)
- Server and character names were readable at load (`multiclass`, `Benedict`).

**Did the log meet the D-003 standard?** Largely yes. It answered the three open
logging questions, the pass structure, each purchase's price/money/landing/scribe,
the batch row removals, the partial row count after reopen, and why the run ended.
It exposed one defect in my logging (ledger Open item 12): `Run outcome` prints
spree-cumulative totals, so vendor 2's line reads `bought=70` although it bought
nothing. That is a gap in the D-003 review I gave at handoff: I read the happy path
and failure paths of a single-vendor simulation and did not examine a second
vendor's outcome line. Recorded as a lesson for the next review: check every line
that restates a counter across vendor boundaries.

**New facts** are in the ledger's confirmed-live section; the two scan problems are
Open items 10 and 11.

### D-001 addendum 2 (2026-10-03): live evidence conflicts with an implementation choice (surfaced, not resolved)

Appended; the entry above is unchanged. Per Development Protocol section 2 this
states the existing decision, the new evidence, and a proposed direction; nothing
is changed until the developer decides.

1. **Existing decision (D-001 Implementation choices, inherited from the
   developer's edited copy):** "Row-removal compensation: if the visible row count
   shrinks, step the index back by the number removed so shifted rows are not
   skipped." As built, after a scribe the code keeps the same index if the count
   fell, i.e. it assumes exactly one row (the scribed one) was removed.
2. **New evidence (live log, Cleric 1-25, vendor 1):** scribed rows are removed from
   the list lazily and in batches. In pass 1 the count fell 153 -> 150 -> 139 ->
   136 -> 134 -> 127 in steps of 3, 11, 3, 2, 7. After `Blessing of Piety` (row 70)
   the count fell by 3, the scan stayed on row 70 and read `Calm`; `Bravery`
   (sorts between them) was never selected in pass 1 and was bought first in pass 2.
   Of the spells bought in passes 2 and 3 (17 and 4), none had been selected in the
   preceding pass. Vendor 1 needed four passes; all 70 spells were bought and
   scribed; the final pass bought zero.
3. **What is and is not harmed:** requirement R1 (repeat passes until a pass buys
   nothing) is **met** and its stop condition is sound (a zero-buy pass scribes
   nothing, so it cannot skip rows). What is violated is efficiency: a clean pass
   was expected to need roughly two passes, not four. No spell was lost.
4. **Proposed direction (not agreed, for the developer to accept, change or
   reject):** treat the index after a scribe by the number of rows actually removed,
   not "keep the index" on any shrink; this is a scan-loop change, one change at a
   time, with the live log lines above as the source of the test's expected values
   (they are in the evidence excerpt). The AI has not designed the exact rule, and
   how the list is actually refreshed (why removal is lazy and batched) is **not**
   established; that is an open question the fix depends on.
5. **Also surfaced (Open item 11):** the row count read right after a reopen was
   partial (13 vs 104) in pass 2. Not a conflict with a decision, but a hazard for
   the "zero-buy pass means done" rule if a pass ever started on a transient 0.

Not verified: the exact cause of the lazy, batched removal; whether the pattern is
the same on other vendors and spell counts; the arithmetic coincidence that the
pass-1 shrinks (3, 11, 3, 2, 7) skip (k-1) rows each = 21 equals the 21 spells
bought in passes 2 and 3 is a consistency check, not a proof.

### D-001 addendum 3 (2026-10-03): developer correction of addendum 2; the conflict is withdrawn

Appended; addendum 2 is unchanged and stays as the record of what the AI said.

The developer corrected the AI's framing of the live evidence: the spells are passed
over because the vendor window changes mid-pass; the Lua reads the list item by item
and cannot prevent that; this is not something the Lua is doing. The AI checked this
against the live log and agrees on the cause: scribed rows leave the list late and in
batches, and a partial list follows a reopen; item order was stable (alphabetical,
passes 3 and 4 read identical sequences; the only inversions were a sort nuance and
the 13 -> 104 rebuild). So the log shows rows shifting, not items reordering relative
to each other; the effect on a row-number walk is the same.

**Effect on addendum 2:** its label ("conflict with an implementation choice") and
its proposed direction (index adjustment by rows removed) are **withdrawn as a
request for change**. The extra passes (four instead of about two on vendor 1) are the
accepted cost of the multi-pass design, which absorbed the shifts: nothing was lost.
The factual observations in addendum 2 stand. Ledger Open item 10 was reframed from
"defect" to "observation, no change requested" in place, with the original struck
through. Open item 11 (partial count after reopen) is unaffected.

**Lesson recorded for the AI:** I presented a design assessment of the developer's
approach as a defect and attached a fix, when the evidence only supported
"the vendor window shifts rows mid-pass and passes absorb it". Next time, state the
observation first and let the developer decide whether it is a problem (Protocol
sections 3 and 13).

---

## D-008 — Docs are always committed and pushed, without asking

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing. Replaces
the AI's habit, in this session, of asking before committing or pushing docs.

### Story

After each docs change the AI asked whether to push, including for plain
record-keeping commits. The developer: docs should always be committed and pushed,
and the AI does not need permission.

### Requirement

- R17. Changes to `docs/` are committed and pushed without asking. *(Developer,
  2026-10-03.)*

### Design choices

- Scope is `docs/` (specification, ledger, decision log, working agreement,
  evidence). Code changes still follow the one-change-at-a-time process, separate
  commits, and the handoff gate (P-1, P-3). Whether code commits may be pushed
  without asking is **not** covered by this decision; so far the developer has
  approved each code push (and P-3 requires the tagged handoff build to be pushed).

### Implementation choices

None.

### Open

- None.

### Not yet verified

- None.

### Dependencies and shared seams

- Shares the push step with D-007 (tagged builds are pushed at handoff).

---

## D-009 — Fix: `Run outcome` shows per-vendor and spree totals

**Date:** 2026-10-03 · **Status:** in progress · **Supersedes:** nothing; corrects
D-004's `logRunOutcome` (ledger Open item 12).

### Story

In the first live log, vendor 2 (Vicar Thiran) bought nothing before the developer
stopped the run, yet its outcome line read
`Run outcome (Nav & Shop "Vicar Thiran"): state=Stopped, ..., bought=70, skipped=0,
spent=756pp 3sp 3cp.` Those figures are vendor 1's. `S.bought`, `S.skipped` and
`S.spentCopper` accumulate across the whole shopping spree by design (they are reset
once at the start of a spree, not per vendor), and `logRunOutcome` printed them
unlabeled, so the line reads as if it were that vendor's result. A reader of the log
could misattribute purchases to the wrong vendor. The AI's pre-handoff log review of
`v1.6.0-test.1` missed it because the simulation ran one vendor only.

### Requirement

- R18. Fix the logging. *(Developer, 2026-10-03: "Obviously we should fix the
  logging.")* The outcome line must not let a reader misattribute totals (D-004
  R10: log the final outcome so it can be read without watching the run).

### Design choices

- The outcome line states this vendor's result and the spree total separately, each
  labelled. *(The developer did not specify wording; this is the AI's choice under
  R18 and is an implementation detail of the log line, not behavior.)*

### Implementation choices

- `This vendor:` = counters now minus a snapshot taken immediately before that
  vendor's run; `Spree total so far:` = the accumulated counters, as before.
- Both callers (`runNavAndShop`, `runBazaarShop`) take the snapshot. In the Bazaar the
  counters are reset first, so both figures are equal there.
- The simulation mock gains a two-vendor Plane of Knowledge scenario so the case that
  slipped through (a second vendor in one spree) is exercised.
- Version `1.6.0-test.2` (R14: each handoff raises the pre-release number).

### Open

- None for this change. Items 11 (partial count after reopen) and 13 (log volume vs
  rotation) are separate and untouched.

### Not yet verified

- Anything live. Simulation only until the developer runs it.

### Dependencies and shared seams

- Same line and same two call sites as D-004's `logRunOutcome`. Test T4 asserts the
  Bazaar outcome line; its expected text changes with the line's format (an
  implementation detail), its requirement (outcome logged with the right purchase
  count) does not.

### D-009 addendum (2026-10-03): implementation and evidence

Appended; the entry above is unchanged.

**Built:** `logRunOutcome(label, before)` now prints
`This vendor: bought=, skipped=, spent=` (counters minus a snapshot taken by
`runCounters()` just before the run) and `Spree total so far: ...` (accumulated), each
labelled. Both callers snapshot first. Behavior is otherwise untouched. `VERSION` is
`1.6.0-test.2` (separate commit, R14).

**Evidence (simulation only; the mock is the AI's model of MQ):**
- New test T11 and mutation 8: a two-vendor Plane of Knowledge spree in which the second
  vendor buys nothing. T11 takes its expected counts from the mock's own per-vendor
  purchase record (3 and 0) and checks both lines carry the right "This vendor" and
  "Spree total so far" figures. The mutation that prints the accumulated totals as the
  vendor's result is caught by T11 alone.
- The same scenario run through the previous build (`v1.6.0-test.1`, from the git tag)
  reproduces the live defect: vendor 2's line read `bought=3`, vendor 1's total. The new
  build reads `This vendor: bought=0 ... Spree total so far: bought=3`.
- T4 (Bazaar outcome line) was changed to look for the new `This vendor: bought=N`
  wording. Its requirement (outcome logged with the right purchase count) is unchanged;
  only the line's format, an implementation detail, moved. The T4 expectation still comes
  from the mock's record, not from the script's output.
- All 11 tests and 9 mutation checks pass. `equivalence_check` (4 Bazaar scenarios) and a
  new old-vs-new run of the two-vendor PoK spree both show identical commands, purchases,
  money and simulated time between `v1.6.0-test.1` and the new build.
- Review of every log line that restates a counter across vendor boundaries (the lesson
  from the first live log): `run start ... bought/skipped so far` is labelled "so far";
  `Run outcome` is now split and labelled; `Purchased (N)` / `Skipped (N)` are printed once,
  at the end of a spree or Bazaar run, and are spree-wide by design. No other line.

**Side effect worth recording:** the Plane of Knowledge path (`/nav id`, `/target npc`,
`/click right target`, the vendor-to-vendor loop) is now exercised in simulation; ledger
Open item 8 is narrowed accordingly.

**Not verified:** anything live. The two-vendor case has only been run in simulation.

---

## D-010 — Proposal: build the vendor's spell list at open, then buy from it (spikes)

**Date:** 2026-10-03 · **Status:** proposal under investigation · **Supersedes:**
nothing yet. **Would supersede** spec S-1 / D-001 R1 (repeat passes with close and
reopen) **if adopted**; S-1 stays in force until the developer decides after seeing
spike results.

### Story

The first live log (v1.6.0-test.1, Cleric 1-25) showed the multi-pass scan working but
costly: four passes for 70 spells, about 389 row reads of which 319 were non-spells, each
read paying a `listselect` plus a wait. The developer's explanation (D-001 addendum 3):
the vendor window shifts rows mid-pass, which the multi-pass design absorbs. The
developer then asked whether the script can (1) read the vendor's list without going
through it item by item, and (2) select an item by name. The AI read the MacroQuest
source (see below) and reported yes to both in principle.

### Requirement

- None changed. **Proposal (developer, 2026-10-03):** "change the mechanism from line by
  line and multiple passes to building a list of available spells on the vendor upon
  opening the vendor, and then purchasing each item in the list from that vendor,"
  which would remove the need for multiple passes. *(A proposal, not yet an agreed
  requirement.)*
- **Agreed (developer, 2026-10-03):** build whatever spikes are needed.

### Design choices

None yet. What adopting the proposal would involve is deliberately not designed until the
spikes answer what the client actually does.

### Implementation choices (spikes)

- Spikes are separate, read-only investigation scripts in `spikes/`, outside the
  SpellSpree build. They never buy, sell or scribe anything. Selecting a row changes only
  what is highlighted and prompts the vendor's price tell.
- `spikes/spellspree_spike.lua`, version `0.1.0-spike.1`. Two modes: a probe, and
  `watch <spell name>` in which the developer buys and scribes ONE spell by hand while the
  spike records how the vendor list reacts. Output goes to the screen and to
  `<logs>/spellspree/spike_<server>_<character>.log`.
- The AI's tag for a handed-over spike: `spike/vendor-<version>` (P-3 says tag
  `v<VERSION>`; that namespace is the SpellSpree build's, so a spike gets its own).

### Source facts the spikes build on (read directly, MacroQuest commit `5f8a6eea`)

- `Window(...).Child('ItemList').List(i,col)` returns the text of row `i`, column `col`
  (1-based); `List('=name,col')` returns the 1-based row index whose cell text matches the
  name (`=` prefix = exact, per `MaybeExactCompare`, `MQ2Inlines.h:488`); `.Items()` is the
  row count (`MQ2WindowType.cpp:549-640`).
- `/notify <window> <list> listselect N` takes a number only (`MQ2Windows.cpp:1272-1283`).
- `Merchant.Items` / `Merchant.Item(n | name)` read the merchant page-handler items;
  `Merchant.SelectItem[name]` is a TLO method that finds the item by name, sets the list's
  current row where column index 1 (0-based) equals the name, and calls `SelectBuySellSlot`
  (`MQ2MerchantType.cpp:70-113, 205-241`).

### Open (what the spikes must answer; none is known)

1. Which `List` column holds the item name in this UI.
2. Does `Merchant.Items` / `Merchant.Item(n)` match the filtered `ItemList` (names, count,
   order), or the vendor's full stock?
3. Does the by-name lookup return the right row, and does a non-`=` lookup match
   prefixes (names like `X` and `X (Enchanted)` exist on these vendors)?
4. Does calling `Merchant.SelectItem` from Lua work (does it need `()`), does it update
   `SelectedItem`, and does it prompt the same price tell as `listselect`?
5. After a spell is bought and scribed, how long does its row linger in the list, and can a
   by-name lookup still find that stale row (watch mode)? This decides whether a
   list-then-buy design needs its own "already bought" guard.
6. How long does reading the whole list take (to compare with about 130 ms per row today)?

### Not yet verified

- Everything under Open. The simulation mock used to test the spike is the AI's model of
  MQ and proves only that the spike runs without error, not what the client does.

### Dependencies and shared seams

- Touches the same scan loop as D-001 (R1, S-1) and the same stale-row behavior recorded in
  the first live log (ledger confirmed-live section). Any adoption is a separate change and
  its own decision entry, one change at a time, with P-1 and P-3 before a live handoff.

### D-010 addendum (2026-10-03): spike built, simulation-checked, ready for a live run

Appended; the entry above is unchanged.

**Built:** `spikes/spellspree_spike.lua`, version `0.1.0-spike.1`, read-only. Probe mode
answers Open questions 1, 2, 3, 4 and 6 in one run at an open vendor; watch mode answers
question 5 while the developer buys and scribes ONE spell by hand. Both write to the chat
and to `<logs>/spellspree/spike_<server>_<character>.log`.

**Checked in simulation only (the mock is the AI's model of MQ):** the spike runs to the
end in both modes without error and its log reads sensibly: it identifies the name column
by selecting three rows and comparing cells with `Merchant.SelectedItem.Name`; reads the
whole list; compares `Merchant.Item(n)` with it; tries exact and non-exact by-name lookups
(including prefix and inner-fragment probes added after reviewing the first simulated log);
calls `Merchant.SelectItem` in both forms (without and with a trailing call) and reports
which one moved the selection and whether it prompted a price tell; and, in watch mode,
timestamps the buy, the scribe, the spellbook slot appearing, and the row leaving the list,
naming the rows that came or went. Two faults found while checking it were in the mock
(a list-box member that returned a bare value instead of a node; an unfiltered/filtered
index model), not in the spike.

**What the spike cannot establish:** it cannot say what is best to do with the answers; it
changes nothing in SpellSpree; and it observes one vendor on one day. It never buys, so it
cannot show how a by-name selection behaves at the moment of purchase. If the probe's
answers look good, a further spike or a build change would be its own decision.

**Handoff review (P-1, applied to a spike):** the live questions are D-010 Open 1-6. Each
has a `RESULT Qn` line, except 5, which is the time-ordered `STATE CHANGE` lines. Failure
paths log why: no merchant open; no readable name column (the cell dump shows what each
column holds); `Merchant.SelectItem` needing a trailing call (both forms tried and logged).

**Not verified:** everything about the live client.

### D-010 addendum 2 (2026-10-03): spike 0.1.0-spike.2, name check in watch mode

Appended; earlier text is unchanged.

The developer pointed out that `Spell: Calm`, the example name in the run instructions,
was already scribed and so no longer on the vendor's list, and chose `Resist Cold`
instead. The AI had written the instructions as "any unscribed spell" but used a name
that was already scribed on this character, and the spike did not check that the name
exists, so a wrong name would have burned a full 90 s watch on nothing.

**Change (spike only, version `0.1.0-spike.2`, tag `spike/vendor-0.1.0-spike.2`):** in
watch mode the spike first looks the name up by exact match; if it is not on the list it
logs `NOT WATCHING`, lists the rows that contain the name as a fragment, and stops without
doing anything. Checked in simulation: a deliberately wrong name stops at once and lists
`Spell: Alpha` as the near match; the normal watch is unchanged.

**Name to use:** `Spell: Resist Cold` is the likely exact string, from the vendor's `Spell:`
naming convention seen in the live log. **Not verified**; if it differs, the spike will say
what the list holds.

### D-010 addendum 3 (2026-10-03): probe results (live, Vicar Thiran, Cleric 26-50)

Appended; earlier text is unchanged. Evidence: the developer's live run of spike
`0.1.0-spike.2` in probe mode; full log in
`docs/evidence/2026-10-03_Benedict_spike-0.1.0-spike.2_probe_VicarThiran.log`. Nothing was
bought or scribed. These are observations of one vendor at one moment.

| Open question | Observed |
|---|---|
| Q1 name column | Column **2** of the list box holds the item name (matched `Merchant.SelectedItem.Name` on rows 1 and 84). Other columns hold small numbers (`--`, `19`, `0`, `8`, `6`, ` 35`); their meaning was not investigated. |
| Row count | `ItemList.Items()` read **168** but only rows 1-167 are readable; row 168 returned nothing, and `listselect 168` left the previous selection in place. So the count was **one too high** here. |
| Q6 speed | The whole visible list (168 rows) was read in **2 ms** with no selecting. For comparison the scan spends about 130 ms per row today. |
| Q2 `Merchant.Item(n)` | **Not the visible list.** `Merchant.Items` read 183, then 182 about 6 s later (unexplained change). Every visible name is present in `Merchant.Item`, but it holds 15 more, among them two `Spell:` entries (`Jolting Blades`, `Foliage Shield`), and only 87 of 168 positions agree. It looks like the vendor's full, unfiltered stock. |
| Q3 by-name lookup | `List('=name,2')` returned the right row each time (first scroll, a non-scroll, and a name that is the start of another). A lookup **without** `=` matches **substrings**: both `Spell: Blessing of Fa` (prefix) and `ll: Blessing of Faith` (inner fragment) returned row 1. `=` with a truncated name returned nothing. A name not on the list returns nothing. |
| Q4 `Merchant.SelectItem` | Works **from Lua, by name, with no trailing call**: `Merchant.SelectItem('=Crysotherium')` changed `SelectedItem` to that item at 0 ms, the list's `SelectedIndex` read 86 (the sweep's row), and it prompted **one price tell**, the same as a `listselect` (control: one tell). |
| Also seen | Vicar Thiran's list is **not alphabetical** (it differs from Vicar Ceraen's). 86 of the 167 readable rows are `Spell:` scrolls. `Spell: Resist Cold` is at row 9, so that is its exact name. |

**Not yet answered:** Q5, how long a scribed spell's row lingers and whether a by-name
lookup still finds the stale row (the watch run). That decides whether a list-then-buy
design needs an "already bought" guard.

**What this does and does not show:** it shows the visible usable list can be read in one
millisecond-scale sweep, and any row can be selected by exact name. It does not show how a
buy-from-the-list design behaves over a whole vendor; stale rows after a scribe are the
unknown that matters. No requirement has changed; S-1 stands.

### D-010 addendum 4 (2026-10-03): watch results (live, Vicar Thiran, `Spell: Resist Cold`) and a correction to addendum 3

Appended; earlier text is unchanged. Evidence: the developer's live run of spike
`0.1.0-spike.2` in watch mode (180 s); log in
`docs/evidence/2026-10-03_Benedict_spike-0.1.0-spike.2_watch_ResistCold.log`. The developer
bought and scribed `Spell: Resist Cold` by hand. Nothing else was bought.

**Timeline (spike clock, ms):** the list held 173 rows at the start, `Resist Cold` at row 9.
The developer's purchase showed as the scroll in inventory at 55,105; the spell in the
spellbook (slot 73) at 56,461 (1.4 s later); the row **left the visible list at 66,737**,
about **10.3 s after the scribe**, together with an unrelated row. Until that moment
`List('=Spell: Resist Cold,2')` kept returning row 9.

**Q5 answered:** a scribed spell's row **lingers for about 10 s** here, and a by-name lookup
**does find the stale row** in that time. `Merchant.Item('=Spell: Resist Cold')` kept finding
the spell for the whole 180 s: it is the unfiltered stock, so scribing never removes it there.

**Unexpected, and the most important observation of the run: the list changed by itself.**
Rows left the visible list at 7,431, 10,909, 40,317, 66,737 (two), 78,143, 143,039, 169,021
and 172,518 ms. The developer bought only `Resist Cold`. Names that left: `Hive Fiend's
Brain (Enchanted)`, `Bonded Loam`, `Fire Arachnid Silk`, `Old Dragon Horn`, and four
**spells nobody bought during the run**: `Spell: Hammer of Requital`, `Spell: Armor of
Faith`, `Spell: Imbue Peridot`, `Spell: Armor of Protection`. `Merchant.Items` fell in step
(188 to 179). Nothing came into the list during the watch. This is direct evidence for the
developer's account that the vendor list changes under a running scan (D-001 addendum 3).
**Cause not known.** The log cannot say whether other characters, other players, another
script, or the server removed those rows. Not asked yet: whether anything else was
using or buying from that vendor during the run.

**Between the probe and the watch the list was also different:** 168 rows at the probe
(11:50), 173 rows at the watch (11:54).

**Correction to addendum 3:** it recorded that `ItemList.Items()` "was one too high" at the
probe (168 vs 167 readable rows). That is **withdrawn as a claim about `Items()`**. In the
watch, `Items()` read 173 and row 173 (`Blue Diamond`) was readable. The probe's mismatch is
better explained by a row leaving the list while the probe was reading it: `Merchant.Items`
also dropped 183 to 182 during that probe. The observation stands (168 read, 167 readable
at that moment); the inference that the count over-reports does not. Ledger Open item 2
corrected accordingly.

**What this says about the proposal (D-010), as observation, not decision:**
- Reading the usable list once at open and selecting each item by exact name does not depend on
  row positions, so shifting rows cannot make it skip a spell. The observed batches and
  spontaneous removals are exactly the thing that does hurt a positional scan.
- Rows can vanish between building the list and reaching an item (by themselves, or after a
  scribe). A name that is no longer found by exact lookup would have to be treated as "not
  available" and skipped, with a log line.
- A stale row can be found by name for about 10 s after scribing. A list-then-buy design
  buys each name once, so this does not matter unless a name is looked up again.
- **Not shown by any spike:** that clicking Buy acts on an item chosen with
  `Merchant.SelectItem`, and how it behaves at the moment of purchase. The spikes never buy. The
  source's `Merchant.Buy` uses the merchant window's selected item
  (`MQ2MerchantType.cpp:115-130`), which `SelectItem` sets, so it is likely, not proven.
- No requirement has changed. S-1 (repeat passes) stands until the developer decides.

---

## D-011 — Operator cues in test runs must not be buried

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing; extends
Development Protocol section 8 (test diagnostics) for runs that need the developer to act.

### Story

Spike `0.1.0-spike.2` in watch mode printed every state change and a heartbeat every 5 s to
the MacroQuest chat window. The one line the developer needed, the cue to buy and scribe
the spell, scrolled out of view within seconds, because the list kept changing and each
change printed lines. The developer had to enlarge the chat window to full height and
scroll up to find the cue, and called the run "near impossible to run as directed."

### Requirement

- R19. When a test run needs the developer to do something (or wait for something), the
  cue to do so must be unmissable and not buried. Anything chat-printed that the developer
  does not need in the moment goes to the log file only. *(Developer, 2026-10-03: "We'll
  need to fix that in the future if you want me to perform commands based upon MQ window
  output.")*

### Design choices

None beyond R19. How a cue is shown (a single printed line near the end, a repeated line,
an on-screen window) is an implementation choice for each run.

### Implementation choices

- For the existing spike: not changed; it has finished its job. Any further spike or build
  that needs an operator action will print only the cue (and a final "done") to chat and
  send everything else to the log file.
- The instructions given to the developer must not assume the developer can see a
  particular line unless the program guarantees it is shown last and stays visible.

### Open

- None.

### Not yet verified

- Nothing live; this is a process rule.

### Dependencies and shared seams

- Applies with P-1 (log review before handoff): a handoff review must also check that any
  operator cue is visible, not just that the log is complete.

### D-010 addendum 5 (2026-10-03): the developer's answers; the list's columns

Appended; earlier text is unchanged.

- **Developer, 2026-10-03:** nothing else was noted using or buying from the vendor during the
  watch run (the cause of the unbought spells leaving the list stays unknown). **The developer
  wants the list-then-buy mechanism** (build the vendor's spell list when the vendor opens,
  buy each item from that list, no repeat passes). This is the proposal in D-010 becoming a
  wanted direction; it is **not yet an agreed requirement**: the AI will write the design for
  the developer to approve first, and S-1 stays in force until a decision entry supersedes it.
- **Developer question: does the vendor list return the level column?** From the probe and
  watch logs: the list has eight columns; column 8 shows ` 35` and ` 40` on spells at a 26-50
  vendor and `--` on a gem, which fits a required-level column, but that is an inference from
  five rows and is not confirmed. Columns 4-7 are confirmed to be the price in
  platinum, gold, silver and copper. Details are in the ledger's confirmed-live section.
- **Design relevance (observation, not decision):** reading the price from the list when it is
  built would give every item's cost before anything is selected, without waiting for the
  vendor's price tell.

---

## D-012 — Problem: spell vendors do not match the level tiers the script offers

**Date:** 2026-10-03 · **Status:** problem recorded (developer-stated); facts being gathered ·
**Supersedes:** nothing. Concerns spec inherited items I-1 (class/tier selection) and the
`TIERS` / `VENDOR_DATA` tables in `spellspree.lua`.

### Story

The script offers four level tiers per class (`1-25`, `26-50`, `51-60`, `61-70`) and maps each
tier to one vendor per class (`VENDOR_DATA`). The developer's account (not verified by the AI):
- The `26-50` and `51-60` vendors hold only spells of those levels.
- The level **61-65** spells are held by the **1-25** vendor.
- So the `61-70` vendor is never needed as the script works today, and selecting `Cleric 1-25`
  buys that vendor's spells outside 1-25 as well (the level 61-65 ones).

Consistent with the live log, but not proof: at Vicar Ceraen (Cleric 1-25) the script bought
70 spells including several priced around 200pp (for example `Armor of the Zealot` 210pp,
`Hand of Virtue` 206pp, `Mark of the Righteous` 208pp), far above the 1-25 spells beside them.
The AI cannot say what level those are; it has no level data for them.

The developer asked whether the vendor list returns a level column because the answer decides
whether the script can buy by level. Known so far: the list has an eighth column that is very
likely the required level (35 and 40 on spells at the 26-50 vendor, `--` on a gem), unconfirmed
(ledger confirmed-live section, D-010 addendum 5).

### Requirement

- None agreed yet. **Developer's stated problem:** a tier selection should not buy spells
  outside the chosen level range. *(Observation and complaint, 2026-10-03; the AI is treating it
  as a problem to solve and has not designed or decided anything. What the correct ranges and
  vendor-to-level mapping should be is not stated.)*

### Design choices

None.

### Implementation choices

- Facts first, by a read-only spike: spike `0.1.0-spike.3` gains a `levels` mode that, at an open
  vendor, reads column 8 for every scroll and prints one chat line of counts per band plus a full
  per-spell list to the log. Run at each of a class's four vendors it answers the open questions
  below and tests whether column 8 is the level (a 26-50 vendor should show only 26-50 values;
  the 1-25 vendor should show 1-25 plus 61-65 if the developer's account is right).
- The same build fixes the chat spam of probe and watch modes (D-011, P-5): chat gets only the
  start, the cue and the end; everything else goes to the log file.

### Open

1. Is column 8 the required level? (The developer can also read the window's header.)
2. Which levels does each vendor hold, per class (the developer says 1-25 holds 61-65; what holds
   66-70, if anything)?
3. What should "select Cleric 1-25" mean once levels are known: buy only spells whose level is
   within 1-25 from the 1-25 vendor, and use another selection to get 61-65 from that same vendor?
   Should the tier boxes and `VENDOR_DATA` change? Not decided; developer's call.
4. Do other classes' vendors follow the same pattern as Cleric's?

### Not yet verified

- Everything above except that the list returns an eighth column.

### Dependencies and shared seams

- Shares the vendor list read and the per-item data with D-010 (list-then-buy): a list built at
  open would carry each row's level, so level filtering fits there. Not a requirement of D-010.

### D-012 addendum (2026-10-03): column header confirmed; developer's account confirmed; levels spike withdrawn

Appended; the entry above is unchanged.

- **Column 8 is the level (confirmed).** The developer sent a screenshot of the vendor window:
  the headers are **Item Name, Qty, platinum, gold, silver, copper, Lvl**, and the row for
  `Spell: Blessing of Faith` reads `--`, 19, 0, 8, 6, 35. So the list's columns 3 to 8 are
  quantity, the four price columns, and required level. This resolves Open question 1 and
  D-010 addendum 5's "unconfirmed" on column 8. (The screenshot is in the conversation, not
  saved in the repo.)
- **The developer's account of the vendors is a confirmed fact.** The developer states it was
  confirmed by buying spells for **14 characters**: the `26-50` and `51-60` vendors hold only
  spells of those levels; the level 61-65 spells are on the `1-25` vendor; so the `61-70` vendor
  is not needed as the script works, and selecting `1-25` buys 61-65 spells too. This replaces
  the entry's "developer-stated, not verified by the AI" with **developer-confirmed from direct
  repeated experience**. The AI still has no level data of its own for those spells.
- **Withdrawn:** the `levels` spike mode the AI proposed under Implementation choices. The
  developer: "We don't need a spike to determine what levels each vendor contains." It was
  never committed or handed over (the unfinished edits were discarded). The chat-spam fix for
  probe and watch modes (D-011) was bundled in the same unfinished edit and is also not built;
  it is not needed unless those modes are run again, and D-011 / P-5 still apply to any future
  run that needs an operator action.
- **Open questions that remain, for the developer:** (2) the exact mapping: which vendor holds
  which level ranges per class, in particular **what the `61-70` vendor holds** (nothing needed?
  levels 66-70?), and whether every class follows the same pattern as Cleric (Open 4, likely
  answered by the 14 characters); (3) what "select a tier" should mean once the level is known.
  Neither is decided. They are being asked one at a time.

### D-012 addendum 2 (2026-10-03): the 61-70 vendor lists nothing usable; a 71-80 vendor exists

Appended; earlier text is unchanged. Evidence: the developer's screenshot, saved as
`docs/evidence/2026-10-03_VicarDiarin_61-70_empty_list.png`.

- **Vicar Diarin, "Cleric Spells 61-70":** the merchant window is open with **"Show only items
  I can use" ticked and the item list empty** (headers visible: Item Name, Qty, price columns,
  Lvl; no rows). This answers D-012 Open question 2 for the 61-70 vendor in the sense the
  developer needs: with the usable-only filter on (the only mode the script runs in), there is
  nothing to buy there for this character. Not shown: what it would list with the filter off,
  or for a character of a different class or level. The developer did not add a comment with
  the screenshot; the AI reads it as the answer to its question and says so.
- **A "Cleric Spells 71-80" vendor** is visible in the same screenshot (its nameplate is cut off
  at the top; the name is not readable and the AI does not guess it). The script's `TIERS` /
  `VENDOR_DATA` have no 71-80 tier. Whether it matters is not known (not asked of the
  developer yet; likely nothing usable at this character's level).

### D-012 addendum 3 (2026-10-03): the AI's reading of the screenshot confirmed

Appended; addendum 2 is unchanged. The developer confirmed the AI's reading: the 61-70
vendor's list appears **empty with "Show only items I can use" selected**. The caveat in
addendum 2 stands (what it lists with the filter off, or for other classes or levels, is not
shown).

---

## D-013 — Requirement: tier boxes become level ranges that buy only their own levels

**Date:** 2026-10-03 · **Status:** requirement agreed; not built · **Supersedes:** spec
inherited item I-1 as far as it concerns the tier boxes and `TIERS` / `VENDOR_DATA`; resolves
D-012's central question.

### Story

D-012: the script's four tiers (`1-25`, `26-50`, `51-60`, `61-70`) do not match what the
vendors hold. The `1-25` vendor also sells the level 61-65 spells, so `Cleric 1-25` buys spells
outside 1-25; the `61-70` vendor lists nothing usable (developer's screenshot, confirmed). The
vendor list has a `Lvl` column (confirmed from the window header), so each spell's level can be
read from the list.

### Requirement (developer, 2026-10-03: "Yes, that matches what I want ... If I select 1-25 but
not 61-65, it should only buy spells that fall within that level range.")

- R20. The tier boxes are **level ranges**: **1-25, 26-50, 51-60, 61-65**.
- R21. Selecting a range buys **only** spells whose `Lvl` is within that range. Selecting 1-25
  without 61-65 buys nothing above level 25 from that vendor.
- R22. The vendor each range is bought from: 1-25 from the **1-25 vendor**; 26-50 from the
  **26-50 vendor**; 51-60 from the **51-60 vendor**; **61-65 from the 1-25 vendor**. If both
  1-25 and 61-65 are selected, that vendor is opened once and both ranges are bought from it.
- R23. The old `61-70` box goes away (its vendor lists nothing usable).
- R24. The **71-80** vendor is out of scope. *(The AI said it stays out of scope unless told
  otherwise; the developer answered "yes, that matches".)*

### Design choices

None beyond R20-R24. How the Lvl is read and compared is part of the list-then-buy design
(D-014) or, if built first, of its own change.

### Implementation choices

None made. Order of work is proposed in D-014 (list-then-buy first, then this).

### Open

- **Assumption, not confirmed:** the AI is treating the Cleric vendor pattern (1-25 vendor also
  holds 61-65; 26-50 and 51-60 hold only their own) as holding for **all 12 classes**. The
  developer confirmed it from 14 characters but did not say which classes. Developer to correct
  if any class differs.
- Boundaries: a spell at exactly level 25, 26, 50, 51, 60, 61 or 65 belongs to the range whose
  numbers include it (inclusive ranges). A spell with an unreadable `Lvl` is not bought and is
  logged (the AI's reading of R21; not discussed).

### Not yet verified

- Nothing live. No level data of the AI's own for any spell.

### Dependencies and shared seams

- Needs the vendor list read (D-010 / D-014) or the per-row read in the current scan; a UI change
  to the class/tier tree; changes `VENDOR_DATA` so the 61-65 range points at the 1-25 vendor.

---

## D-014 — Design proposal: list-then-buy replaces repeat passes

**Date:** 2026-10-03 · **Status:** **proposed; not approved.** Each item below is for the
developer to approve, change or reject on its own (Development Protocol section 17).
**Would supersede** spec S-1 / D-001 R1 (repeat passes) and the D-001 close/reopen design.

### Story

D-001 to D-010: a positional line-by-line scan, repeated until a pass buys nothing, is made
necessary by the vendor list changing under it (batches of rows leaving after scribes; rows
leaving with nobody acting on them; a partial list right after a reopen). Live: vendor 1 took four
passes and about 389 row reads to buy 70 spells. Probes show the whole visible list can be read in
about 2 ms, a row can be found by exact name, and the `Lvl` and price columns are in the list. The
developer wants the vendor's spell list built when the vendor opens and each item bought from it
(D-010 addendum 5).

### Requirement

- **Wanted (developer):** build the list of available spells when the vendor opens; buy each item
  in that list from that vendor; no repeat passes.

### Proposed design choices (each is a separate decision)

| # | Choice | Recommendation | Why / evidence |
|---|---|---|---|
| A | Build the list once when the vendor is open and settled: read every visible row (name col 2, Lvl col 8, price cols 4-7, qty col 3) and keep the scroll rows (`Spell:` / `Song:`). | Yes | Probe: 168 rows read in 2 ms. |
| B | Before building, wait until the row count is the same across a few consecutive reads. | Yes | Observed a partial list (13 then 104 rows) right after a reopen. How long and how many reads are implementation values, not tuned. |
| C | Buy each item by: find its row by exact name now, `listselect` that row, check `SelectedItem` equals the name, then Buy with the existing buy/scribe code. | Yes | Uses the same click path that bought all 70 spells live; only the way the row number is found changes. `Merchant.SelectItem` also worked in the probe, but Buy after it has never been tried. |
| D | If the exact-name lookup finds nothing (the row left the list), skip that item and log it; no retry, no re-read. | Yes | Rows left the list unprompted (nine in 180 s). |
| E | Each name is bought at most once per vendor visit; no close/reopen, no repeat passes. | Yes (this is the developer's proposal) | Removes the stacked-scroll repeat-buy risk (ledger item 4) and the passes. |
| F | After the last item, read the list once more and **only log** any scroll still listed that was not bought (no purchases). | Yes | Cheap diagnostic; makes a surprise visible. |
| G | Order of work: this mechanism first, buying exactly what the script buys today; then the level-range boxes (D-013) as a separate change on top. | Yes | One change at a time; level filtering is simpler on the new structure. |

### Implementation choices (the AI's, not for approval)

- Removes `reopenCurrentMerchantForNextPass`, the pass counter, the per-pass seen-set and the
  row-shift compensation. Keeps the buy, quantity, landing-check and scribe code as it is.
- Log: the built list (count and names), each item's lookup row, the selection check, and every
  skip with its reason, plus the usual outcome line.
- Tests: simulated vendors that reorder, lose rows spontaneously, and keep a stale row for about
  10 s after a scribe; expected values from this entry and the live logs; mutation checks.

### Open

- Whether to adopt `Merchant.SelectItem` instead of C later (not proposed now).
- How the 71-80 vendor and 66-70 spells are handled: out of scope (D-013 R24).

### Not yet verified

- Everything about a build. The mechanism rests on probes that never bought: Buy after a
  by-name lookup and listselect is expected to behave like today's but is unproven until run live.

### Dependencies and shared seams

- Replaces the scan loop of D-001 (S-1). Level filtering (D-013) will use the same list.
