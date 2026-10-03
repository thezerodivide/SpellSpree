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
| D-015 | 2026-10-03 | Second-agent review loop: evaluate each recommendation, agree or disagree with reasons | confirmed |
| D-016 | 2026-10-03 | Handoff labels for messages between Claude and GPT | confirmed, including numbering and revision rule |
| D-017 | 2026-10-03 | APPROVED: Step 1, list-then-buy replaces repeat passes | approved by the developer; supersedes spec S-1 / D-001 R1; built as 1.6.0-test.3; first live run succeeded (137 spells, one pass per vendor) |
| D-018 | 2026-10-03 | Step 1 accepted (as a step); the 1.6.0 release was premature and is being withdrawn | acceptance stands; release withdrawn and cleaned up, see addenda |
| D-019 | 2026-10-03 | Step 2 direction changed: the four tier boxes stay; the logic underneath changes | direction recorded; design under discussion; nothing built |
| D-020 | 2026-10-03 | Release 1.6.0 scope: Steps 1-3; each selected range is its own visit | requirement recorded; Steps 2 and 3 not built |
| D-021 | 2026-10-03 | Step 2 design proposal: every 61-70 selection uses the 1-25 vendor | consensus with ChatGPT reached; awaiting the developer's approval |
| D-022 | 2026-10-03 | APPROVED: Step 2, every 61-70 selection uses the 1-25 vendor | approved by the developer; built and simulation-tested; not handed over (live-tested with Step 3) |

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

### D-013 addendum (2026-10-03): the 61-70 vendors are commented out, not deleted (revises R23)

Appended; the entry above is unchanged.

- **Developer, 2026-10-03:** do not delete the code that takes the script to the 61-70 vendors;
  comment it out. If the server ever raises the maximum level to 70 it may put the right spells
  on those vendors, and the developer does not want to code the vendor locations back in.
- **R23 revised (R23a):** the `61-70` box is **not offered**, and the `61-70` vendor entries in
  `VENDOR_DATA` (and the tier name in `TIERS`) are **kept in the source as commented-out
  lines**, with a comment saying why, so re-enabling is uncommenting them. Nothing is deleted.
  This does not change R20-R22 or R24.
- Scope note: this applies to the 61-70 vendor names and the tier entry. How a future 61-70
  range would be bought (its own `Lvl` range, its own vendor) is not designed; it is the
  developer's call if the server changes.
- Not related to, and not an answer to, the seven proposed choices (A-G) in D-014, which are
  still awaiting the developer's reply.

### D-014 addendum (2026-10-03): choice E approved; a gap found while answering a question

Appended; the entry above is unchanged.

- **Approved by the developer, 2026-10-03: choice E** (buy each name at most once per vendor
  visit; no reopen and no repeat passes). **A, B, C, D, F and G are not yet answered** and are
  not approved by this.
- **Developer question:** if the vendor list ordering changes, will that prevent any spell on
  the list from being bought? **AI's answer:** no, because under C each purchase looks the row
  up by exact name immediately before clicking, so row positions do not matter. A spell on the
  built list can still go unbought only if (1) its row has left the vendor list by the time it is
  reached (observed: nine rows left unprompted in 180 s, four of them spells), which choice D skips
  and logs, or (2) it was not on the list when the list was built (a partial list at open, guarded
  by B; or a spell added later, which F only logs).
- **Gap found:** between looking a row up by name and the click there is a short window in which
  the list can shift. The click would then select a different item. C says to check that the
  selection equals the name, but D-014 did not say what to do on a mismatch. The original
  author's comment that selecting index N once bought an unrelated item (from the script's own
  source) shows this class of failure has been seen. The existing post-purchase check (the
  landed scroll must be named like a scroll) does not stop a wrong *purchase*.
- **New proposed choice H (for the developer to approve, change or reject):** verify the selection
  just before Buy, and on a mismatch look the row up and click again, up to a small number of
  tries (the number is an implementation value, not tuned), then skip the item and log why.
  Recommendation: yes. Evidence: the failure mode exists; the cost of a wrong purchase is spent
  currency on an item that is not wanted.

---

## D-015 — Second-agent review loop: evaluate each recommendation, agree or disagree with reasons

**Date:** 2026-10-03 · **Status:** confirmed · **Supersedes:** nothing; applies Development
Protocol section 13 (push back; do not agree to be agreeable) to proposals reviewed by another agent.

### Story

The developer will have another agent review the AI's proposals (first: the list-then-buy design,
D-014, and the open decisions A-K) and make recommendations. The developer asked that the AI not
accept a change simply because the other agent recommended it.

### Requirement

- R25. For each recommendation from the reviewing agent, the AI **evaluates it on the merits and
  either agrees or disagrees**. If it disagrees, it says why, in a form the developer can take back
  to the other agent. The loop repeats until the developer, the AI and the reviewing agent reach
  consensus on every item. *(Developer, 2026-10-03.)*

### Design choices

None beyond R25.

### Implementation choices

- The AI checks any claim it can check against the live logs or the MacroQuest source before
  answering, and says which it checked and which it could not.
- Each round is recorded in the decision log (item, the reviewer's recommendation, the AI's
  position and reasons, status) as an addendum to the decision under review. Nothing is promoted to
  an agreed requirement until the developer says so.
- An item stays open until all three parties agree; the AI does not drop its position without a
  reason, and does not hold it without one.

### Open

- None.

### Not yet verified

- Nothing; this is a process rule.

### Dependencies and shared seams

- First applied to D-014 (items A, B, C, D, F, G, H) and D-013 (items I, J), plus K.

### D-014 review round 1 (2026-10-03): the reviewing agent's recommendations and the AI's positions (D-015)

Appended; earlier text is unchanged. The reviewing agent's output was pasted by the developer.
Nothing here is approved by the developer yet; items marked "agreed" are agreed between the AI
and the reviewing agent only.

| Item | Reviewer | AI position | Status |
|---|---|---|---|
| A | Request changes | **Agree** (with one correction to the reviewer's premise, below) | revised as A' |
| B | Request changes | **Agree**, and state values | revised as B' |
| C | Approve | Agree | agreed (AI + reviewer) |
| D | Approve | Agree | agreed (AI + reviewer) |
| E | (approved by developer) | - | **approved by developer** |
| F | Request changes | **Agree**; plus one hazard the reviewer did not mention (stale rows) | revised as F' |
| G | Approve | Agree | agreed (AI + reviewer) |
| H | Request changes | **Agree**, with one clarification | revised as H' |
| I | Approve | Agree | agreed (AI + reviewer) |
| J | Request changes | **Partly disagree**: evidence is needed, but not as a condition of D-014 | reframed as J' |
| K | Approve | Agree (my claim that logging will shrink is an estimate, not measured) | agreed (AI + reviewer) |

**Two errors in the AI's own earlier message, corrected here:**
1. The proposal said a spell missing from the built list is one "the design logs (see F)". F
   cannot do that for a spell absent from both the initial read and the final read. Withdrawn.
2. The proposal said that if a class differs from the Cleric pattern it "would buy the wrong
   spells". Under R21 (buy only spells whose Lvl is in the selected range) that is false: a wrong
   vendor mapping gives **fewer** spells, not wrong ones. Corrected in J'.

**A' (revised).** Source: the visible usable list only (`MerchantWnd` -> `ItemList`), read after the
existing check that the usable-only box is on. Never `Merchant.Item(n)`: the probe showed it is the
unfiltered stock (182 entries vs 168 visible, different order). Keep the existing `Spell:` / `Song:`
name rule. Duplicates: a name is a key; if it appears twice, keep the first, log the others (the
probes found none). Price, quantity and Lvl are read and logged; an unreadable cell is recorded as
unknown and gates nothing in this change (affordability stays as today: price-tell quote plus money
check). *Correction to the reviewer's premise:* the baseline's "price reads 0" refers to the
`Item.Price()` TLO; the list's price cells are a different source and matched the vendor's tell
(Blue Diamond `393/7/4/9` = `393pp 7gp 4sp 9cp`). The request still stands and is adopted.

**B' (revised).** Poll the visible row count every 250 ms. The list is settled when the count is at
least 1 and unchanged for **8 consecutive polls (2 s)**; maximum wait **15 s**. If not settled by
then: skip that vendor and log the counts seen and why. The AI states that a stable count is a
**heuristic**, not proof the list is complete. Evidence for the starting values: after a reopen the
count read 13 and the full list (104) was there within 1.63 s (live log, pass 2); the first open of a
run read the full count at once. The log does not show when in that 1.63 s the count changed, so a
1.5 s window could have been fooled; 2 s is a deliberately larger starting value. **All values are
untuned (Protocol section 15)**; every poll's count is logged so the first live runs can tune them.

**F' (revised).** At the end, read the visible list once. Classify every scroll still listed:
(1) bought and scribed this visit: expected, because its row can linger about **10 s** after the
scribe (observed 10.3 s) and must not be reported as a problem; (2) bought but not scribed
(stacked); (3) attempted and failed (not paid, selection never matched, and so on); (4) deliberately
skipped (row vanished, unaffordable, later: outside the range); (5) in none of those and not on the
built list: **new** since the build. Log the counts and the names for 2-5. It never buys. It cannot
see a spell absent from both reads.

**H' (revised).** Retry limit **3 selection attempts** (untuned). Verify that
`Merchant.SelectedItem.Name` equals the exact expected name **immediately before the Buy click**,
i.e. after the price-tell wait, the money checks and the bag handling (several hundred ms to over a
second in the current flow), not at selection time. On a mismatch redo the exact-name lookup and
click (counting toward the 3). **Never retry the Buy click itself** (a click may have succeeded
unseen; the existing paid check decides). After 3 failed verifications skip the item and log why.
*Clarification to the reviewer:* it is the selection that is retried, never the purchase.

**J' (reframed).** Agreed that the vendor table gives destinations, not coverage, and that evidence
is needed for the 61-65-from-the-1-25-vendor mapping per class. **Disagreed that it blocks D-014**:
D-014 changes the mechanism and buys exactly what is bought today; the mapping matters only for the
later level-range change (D-013). In that change R21 makes a wrong mapping fail safe (fewer spells,
never wrong ones). Evidence to gather: the developer names which classes the 14 characters covered;
and the level-range build logs each vendor's level counts on first visit, so the first live run per
class is itself the evidence.

### D-013 addendum 2 (2026-10-03): evidence for the vendor-level pattern, by class (answers D-014 item J)

Appended; earlier text is unchanged.

**Developer, 2026-10-03:** the vendor-level pattern was tested by buying spells on
**War, Pal, Mnk, Shd, Clr, Nec, Bst, Mag, Shm, Rng, Brd**.

**What that covers, checked by the AI against the script's own class tables** (`CLASS_ORDER` /
`VENDOR_DATA`: 12 classes with spell vendors): covered, **9 of 12**: Paladin, Shadowknight,
Cleric, Necromancer, Beastlord, Magician, Shaman, Ranger, Bard. **Not covered, 3**: **Druid,
Enchanter, Wizard**. War and Mnk are on the developer's list but have no spell vendors in the
script's tables, so they add no evidence about the vendor pattern as the script uses it; the
AI does not know what was bought on them and does not assume.

**Effect on Open item J / D-013 assumption:** the assumption "the Cleric pattern holds for all
12 classes" is now backed by the developer's testing for 9 classes and **unbacked for Druid,
Enchanter and Wizard**. It stays an open item for those three. Because R21 makes a wrong
mapping fail safe (a range buys fewer spells, never wrong ones), the three classes do not block
the design; their evidence will come from the level-range build logging each vendor's level
counts on first visit, or from the developer telling the AI sooner.

### D-013 addendum 3 (2026-10-03): correction to addendum 2 - Wizard and Enchanter were also tested

Appended; addendum 2 is unchanged and stays as the record of what the developer first said.

**Developer, 2026-10-03:** the vendor-level pattern was **also tested on Wizard and Enchanter**.
Covered classes are therefore **11 of the 12** with spell vendors in the script's tables:
Paladin, Shadowknight, Cleric, Necromancer, Beastlord, Magician, Shaman, Ranger, Bard, Wizard,
Enchanter. **Not covered: Druid only** (the developer has not mentioned it; the AI does not
assume). Addendum 2's "not covered: Druid, Enchanter, Wizard" is superseded by this. The reasoning
in addendum 2 is unchanged: Druid does not block the design, because R21 makes a wrong mapping fail
safe, and the level-range build's first-visit level logging (or the developer telling the AI) will
provide Druid's evidence.

---

## D-016 — Handoff labels for messages between Claude and GPT

**Date:** 2026-10-03 · **Status:** confirmed (format); the AI's reading of two details awaits the
developer's confirmation · **Supersedes:** nothing; supports D-015.

### Story

Proposals and reviews now pass between the AI (Claude) and the reviewing agent (GPT) through the
developer. To keep both sides synchronized on which message answers which, the developer asked for a
lightweight label on every such message.

### Requirement (developer, 2026-10-03)

- R26. Every message between Claude and GPT begins with:
  `HANDOFF: Step <n> / Decision <n> / Revision <n> / From <Claude|GPT> / <date>`
  followed, on every revision after the first, by
  `Answering: <label of the message being answered>`.
  Revision 1 has no Answering line (it has not gone to the other side yet). GPT uses the same format.
  The developer's example: `HANDOFF: Step 5 / Decision 17 / Revision 2 / From Claude / 2026-10-01`
  with `Answering: REVIEW OF: Step 5 / Decision 17 / Revision 1 / From Claude / 2026-10-01`.

### Design choices

None beyond R26.

### Implementation choices (the AI's reading; not yet confirmed)

- **Decision** = the decision-log number (D-014 is Decision 14). **Step** = the order of work in D-014
  choice G: Step 1 = list-then-buy, Step 2 = the level-range tier boxes (D-013).
- GPT's review of a Claude message is labelled `REVIEW OF: <the label of the Claude message it
  reviews>` (as in the developer's example), and Claude's next revision quotes that label verbatim on
  its Answering line. The revision number of a review equals the revision it reviews.
- The date is the day the message is written.
- Each message is archived in `docs/handoffs/` named `<date>_step<n>_decision<n>_rev<n>_<from>.md`, so the
  exchange can be re-read from the repository. GPT's messages are archived from text the developer pastes.
- The first exchange (the D-014 proposal and GPT's review of it) predates the convention; the proposal is
  retrofitted as Revision 1 (its content is D-014) and GPT's review is archived as the review of Revision 1.

### Open

- Whether the Step and Decision numbering and the reading of GPT's label above are what the developer
  intends.

### Not yet verified

- Nothing; this is a process rule.

### Dependencies and shared seams

- Applies to every message under D-015 (review loop). First use: Step 1 / Decision 14 / Revision 2.

### D-016 addendum (2026-10-03): the message flow, and a correction to the AI's reading

Appended; the entry above is unchanged.

The developer gave the flow explicitly:
1. `HANDOFF: Step 1 / Decision 1 / Revision 1 / From Claude / <date>` (no Answering line);
2. `REVIEW OF: Step 1 / Decision 1 / Revision 1 / From ChatGPT / <date>`;
3. `HANDOFF: ... / From Claude / <date>` with `Answering: <GPT's review label, repeated exactly>`.

**Correction:** D-016's "Implementation choices" read GPT's label as quoting the Claude message it
reviews (`... From Claude`). That was wrong. In a review label the "From" field names the **author of
the review (ChatGPT)**; the Step, Decision and Revision numbers are those of the Claude message being
reviewed. Claude's Answering line repeats GPT's label exactly as GPT wrote it. The AI wrote the wrong
form into the two archived messages for D-014 (the retrofitted review of Revision 1, and Revision 2's
Answering line); both were corrected in the same commit as this addendum. The author name is
`ChatGPT` in labels (the developer's wording), not `GPT`.

**Still to confirm with the developer:** (a) the numbering the AI chose (Decision = the decision-log
number; Step = order of work, Step 1 list-then-buy, Step 2 level ranges); (b) the revision number of
Claude's reply. The developer's sketch showed Claude's reply as "Revision 1", but earlier said
Revision 1 has no Answering line and gave "Revision 2" in the first example. The AI is numbering a
reply to a review as the next revision (Revision 2) unless told otherwise.

### D-016 addendum 2 (2026-10-03): numbering and revision rule confirmed

Appended; earlier text is unchanged. **Developer, 2026-10-03, confirming both open points:**
(a) **Decision** = the decision-log number and **Step** = the order of work (Step 1 list-then-buy,
Step 2 level ranges) is correct; (b) **each reply by Claude in the chain increments the revision
number**: Revision 1, then 2, then 3, and so on. A ChatGPT review carries the revision number of
the Claude message it reviews. D-016 is now fully confirmed; nothing remains open under it.

### D-014 review round 2 (2026-10-03): ChatGPT's review of Revision 2 and the AI's positions (Revision 3)

Appended; earlier text is unchanged. Messages archived in `docs/handoffs/`:
`..._rev2_review_from-chatgpt.md` (the review) and `..._rev3_from-claude.md` (the reply).

| Item | ChatGPT (Rev 2) | AI (Rev 3) | State |
|---|---|---|---|
| A' | Approve | Agree | agreed |
| B' | Approve | Agree | agreed |
| C, D, G, I, K | Approve | Agree | agreed |
| E | - | - | approved by the developer |
| F' | Request changes | Agree with all three points | revised as F'' |
| H' | Approve | Agree | agreed |
| J' | Approve for Step 1 | Agree; the all-class assumption stays unapproved for Step 2, Druid settles it | agreed for Step 1 |

**F'' (summary; full wording in Revision 3).** (a) An **outcome ledger**: every built-list entry ends with
exactly one recorded outcome from the script's own records: 1 bought and scribed; 2 bought, scribe not
completed (stacked, scribe failed after the retries, or scroll not located after payment); 3 attempted, not
bought (selection not verified in 3 tries, or no payment observed); 4 deliberately skipped (row vanished,
duplicate name, unaffordable by quote when set to skip, later: outside the range); 5 not attempted because the
run stopped, with the stop reason; 6 no outcome recorded, which should never happen and is logged as an ERROR.
The ledger is logged at the end and when the run stops early, whether or not the vendor window is still open.
(b) A **final scan** while the window is open, log only: scrolls not on the built list (new since the build);
lingering rows of bought-and-scribed entries (expected about 10 s, not a problem); rows still listed for the
other outcomes (informational).

**Why the AI agreed (checked against the code):** the existing early exits (out of money, inventory full,
unexpected cursor item, scribe failure after 20 tries, Stop, merchant closed) leave entries unattempted; a scribe
failure and a paid-but-not-located purchase both happen after money moves; the final scan cannot always run.
No behavior or counter changes: the existing "paid but not located is logged as 'didn't buy' and counted as
skipped" quirk is left as it is; only the new ledger classifies it by what happened.

**Status:** every Step 1 item is agreed between the AI and ChatGPT **except F'', which awaits ChatGPT's
confirmation.** Nothing is built and the developer has not yet issued approval on any item except E.

### D-016 addendum 3 (2026-10-03): how a handoff reply is delivered

Appended; earlier text is unchanged. **Developer, 2026-10-03:** do not put handoff messages in a markdown
code block; the developer uses the reply's copy button to paste. **AI's reading:** because the copy button
copies the whole reply, a reply that carries a handoff contains only the labelled message, as plain text,
beginning with the `HANDOFF:` line, with nothing for the developer mixed in. Anything the developer needs to
be told goes in a separate reply. The already-sent Revision 3 is not reformatted (developer: no need).
Recorded in the working agreement (P-7).

### D-014 review round 3 (2026-10-03): consensus on Step 1 between the AI and ChatGPT

Appended; earlier text is unchanged. ChatGPT's review of Revision 3 is archived in
`docs/handoffs/2026-10-03_step1_decision14_rev3_review_from-chatgpt.md`. **ChatGPT approved F''
and states that every Step 1 proposal is agreed from its review**; final implementation authorization
stays with the developer, and the all-class vendor-coverage assumption stays unapproved for Step 2.

**Consensus (AI and ChatGPT), awaiting the developer's approval, item by item:**
- A' (visible usable list as source; name rule kept; duplicates keep the first; unknown values gate nothing)
- B' (poll every 250 ms; settled = 8 unchanged polls; max wait 15 s; else skip the vendor and log; values untuned)
- C (find the row by exact name, click it, existing buy and scribe path)
- D (row gone at lookup: skip and log, no retry)
- E (each name at most once per visit; no reopen, no repeat passes): **already approved by the developer**
- F'' (outcome ledger for every built-list entry, six outcomes; then a log-only final scan)
- G (this mechanism first, same eligibility as today; level ranges as Step 2)
- H' (3 selection attempts; verify the exact name immediately before Buy; never retry the Buy)
- I (inclusive ranges; unreadable level not bought and logged): applies to Step 2
- J' (Step 1 is not blocked by class coverage; the all-class assumption is **not** approved for Step 2;
  Druid's evidence is the open point)
- K (log rotation unchanged)

**Not approved yet:** nothing here is a requirement until the developer approves it. When approved, a new
decision entry will record the approval and supersede spec S-1 / D-001 R1 for the scan mechanism, the spec
will be updated, and only then is the build started.

### D-013 addendum 4 (2026-10-03): the developer accepts the vendor-level pattern for all 12 classes

Appended; earlier text is unchanged.

**Developer, 2026-10-03:** Druid does not need to be tested. The observations were consistent across all
observed classes, and there is no reason to believe Druid is an outlier.

- **Decision (R27):** the vendor-level pattern (the 1-25 vendor also holds levels 61-65; the 26-50 and
  51-60 vendors hold only their own levels; the 61-70 vendor lists nothing usable) is **accepted for all
  12 classes with spell vendors**, including Druid. The evidence is the developer's buying on 11 of the 12
  (all but Druid); Druid is accepted on the developer's judgment that it is not an outlier, not on a test.
- **Effect:** this resolves D-013's open "assumption, not confirmed" and the Step 2 reservation recorded
  in D-014 review rounds 2 and 3 (ChatGPT: the all-class assumption "remains unapproved for Step 2";
  Druid's inventory "would settle" it). The developer, who owns the risk, has chosen to accept it. The
  worst case, stated for the record: if Druid differs, the 61-65 box (or another range) buys fewer spells
  for that class than expected; R21 prevents it from buying spells outside the selected range.
- **Not changed:** Step 2 is still not built and not yet approved as a build; the developer's approval of the
  Step 1 items (A-K) is still pending. The Step 2 idea of logging each vendor's level counts on first visit
  is kept as ordinary logging (it does not buy or gate anything), not as a condition.

---

## D-017 — APPROVED: Step 1, list-then-buy replaces repeat passes

**Date:** 2026-10-03 · **Status:** approved by the developer; build in progress ·
**SUPERSEDES spec S-1 and D-001 R1 (repeat passes with close and reopen) for the scan mechanism.**
Also supersedes D-001's design choice D1 and the D-001 implementation choices that existed only for
the multi-pass scan (the row-removal compensation, the per-pass seen-set, the reopen sequence,
`MAX_SCAN_PASSES`). What is not superseded: the usable-only requirement, the buy / scribe / landing
logic, the stop conditions, and everything in D-004 to D-009 (logging and the outcome line).

### Story

D-001 to D-016: the vendor window changes under a positional scan, so the scan repeated until a pass
bought nothing. Live: four passes and about 389 row reads for 70 spells; rows left the list in batches
and unprompted. Probes showed the visible list reads in about 2 ms, a row is found by exact name, and
`Lvl` and the price are in the list. The developer wanted the list built at open and each item bought
from it. The AI's design (D-014) was reviewed by ChatGPT over three revisions (archived in
`docs/handoffs/`); the AI and ChatGPT reached consensus.

### Requirement (developer, 2026-10-03: "I approve the decisions as reached by consensus.")

All of these are approved as written in D-014 review rounds 1-3 and Revision 3:

- **A'** Build the list from the **visible usable list only** (`MerchantWnd` -> `ItemList`), read after
  the existing usable-only check; never `Merchant.Item(n)`. Keep the `Spell:` / `Song:` name rule.
  A name that appears twice: keep the first, log the others. Price, quantity and Lvl are read and logged;
  an unreadable value is recorded as unknown and gates nothing (affordability stays as today).
- **B'** Before building, poll the row count every **250 ms**; settled when it is at least 1 and unchanged
  for **8 consecutive polls (2 s)**; maximum wait **15 s**; if not settled, skip that vendor and log why.
  A stable count is a heuristic. Values untuned; every poll logged.
- **C** Buy each item by finding its row by **exact name**, clicking that row, then using the existing
  buy, quantity, landing and scribe code.
- **D** If the row is gone at lookup, skip the item and log it; no retry.
- **E** Each name at most once per vendor visit; no reopen; no repeat passes. *(approved earlier)*
- **F''** (a) An **outcome ledger**: every built-list entry ends with exactly one logged outcome, from the
  script's own records: 1 bought and scribed; 2 bought, scribe not completed (stacked; scribe failed after
  the retries; scroll not located after payment); 3 attempted, not bought (selection not verified in 3
  attempts, or no payment observed); 4 deliberately skipped (row gone at lookup; duplicate name;
  unaffordable by quote when set to skip; in Step 2 outside the range); 5 not attempted because the run
  stopped, with the stop reason; 6 no outcome recorded (should never happen; logged as an ERROR). Logged at
  the end and on any early stop, whether or not the window is open. (b) A **final scan** while the window is
  open, log only, never buys: scrolls not on the built list (new since the build); lingering rows of
  bought-and-scribed entries (expected for about 10 s); rows still listed for outcomes 2-5 (informational).
- **G** This mechanism first, buying exactly what is bought today; the level-range boxes (D-013) are a
  separate Step 2.
- **H'** Up to **3 selection attempts** per entry; verify `Merchant.SelectedItem.Name` equals the exact
  expected name **immediately before the Buy click**; on a mismatch redo lookup and click (counts toward
  the 3); **never retry the Buy click**; after 3 failed verifications skip and log why.
- **I** (Step 2) Ranges inclusive; a spell whose level cannot be read is not bought and is logged.
- **J'** Class coverage does not block Step 1; the developer accepts the vendor-level pattern for all 12
  classes (D-013 addendum 4).
- **K** Log rotation unchanged.

### Design choices

As above. Nothing else is decided here.

### Implementation choices (the AI's; recorded so they can be questioned)

- The skip and failure counters shown in the window (`S.skipped`, `S.skippedNames`) keep their existing
  meaning (unaffordable, no payment, not located after payment). A row that vanished (D) or a selection that
  could not be verified is **not** added to them; it appears in the ledger instead.
- A vendor whose list does not settle is reported as a stop with reason `Vendor list did not settle`, which
  the spree does not treat as fatal, so the spree moves to the next vendor.
- The old close/reopen code, the pass counter, the seen-set and the row-shift compensation are removed.
- The version of this build is `1.6.0-test.3` (D-006: the 1.6.0 changes are not yet accepted).

### Open

- Step 2 (level ranges) is approved as a requirement (D-013) but its build is not started; it begins after
  Step 1 is accepted. The 61-70 vendor entries stay commented out (D-013 R23a).

### Not yet verified

- Everything live. The mechanism rests on probes that never bought: Buy after an exact-name lookup and a row
  click is expected to behave like today's, and is unproven until a live run.

### Dependencies and shared seams

- Replaces the scan loop of D-001. Keeps D-004 logging, D-009's outcome line. Step 2 (D-013) builds on the
  list this step creates.

### D-017 addendum (2026-10-03): the build, `1.6.0-test.3`, and its evidence

Appended; the entry above is unchanged.

**Built (`spellspree.lua`):** `waitForListToSettle` (B'), `buildSpellList` (A'), `rowForName` and `selectEntry`
(C, H'), `processEntry` (the existing buy, landing and scribe logic, restructured so each exit records an outcome),
the outcome ledger `setOutcome` / `markRemainingNotAttempted` / `logLedger` (F''a), `finalScan` (F''b), and a
rewritten `runSpellSpree`. Removed: `reopenCurrentMerchantForNextPass`, the pass counter, the per-pass seen-set, the
row-shift compensation, `MAX_SCAN_PASSES`, and `merchantSelectedItemKey`. The window's `Skipped` counter keeps its
old meaning (see D-017 implementation choices). Version `1.6.0-test.3` (separate commit).

**Evidence, simulation only (the mock models MacroQuest and the vendor window from what the live logs showed):**
- `test/test_listthenbuy.lua`: 18 tests (L1-L18), each citing the D-017 item it comes from, with expected values
  taken from D-017 or from the mock's own record (purchases, Buy clicks, commands), all passing; 9 mutation checks,
  each caught by exactly the tests predicted in advance (the predictions were written before the first run). The
  scenarios: a vendor that reorders after every buy; a row that vanishes before it is reached; a partial list at
  open; a list that never settles; a click that selects the wrong row once and three times; a selection that drifts
  before Buy; names where one is the start of another; running out of money; the user's Stop; a scribe that never
  completes; a purchase that stacks; rows that linger 10 s after a scribe; a scroll that appears after the build; a
  duplicate name.
- `test/test_logging.lua` (11 tests, 9 mutations) still passes on this build.
- `test/eligibility_check.lua`: the previous tagged build (`v1.6.0-test.2`) and this one buy the **same set** of
  scrolls and leave the same money in five simulated scenarios (reorder after every buy; rows leave at once; a
  scribe rejected twice; no money; a two-vendor Plane of Knowledge spree). This is the check for choice G (eligibility
  unchanged). `test/equivalence_check.lua` (identical commands and timing) is for logging-only changes and is no
  longer applicable to this build.
- Log review by the AI as a receiving developer: the happy path, the vanish, drift and out-of-money logs. One
  mistake of the AI's during that review, recorded for honesty: the first vanish log it read showed `LEDGER DEFECT`;
  that was the output of the last mutation (mutation runs overwrite the scenario logs), not of the real build. The
  real build's log was re-read after adding a baseline-only mode to the test runner; it records
  `deliberately skipped -- row gone at lookup`. The mutant's log did show that the "no outcome recorded" detector works.

**Not verified:** anything live. In particular: that an exact-name lookup plus a click selects the right row on the
live client, that Buy after it works as it did after the old click, how long the live list takes to settle (the 2 s
window and 15 s maximum are untuned), and what the vendor does while the run is in progress.

**What the first live log will let the developer and the AI read (D-003 review):** every selection line gives the
row the exact-name lookup found and the row the entry had at build time (a difference is a reorder, observed);
every settle poll gives its count; every entry gives its outcome and reason; the final scan reports new and lingering
rows. What the log cannot show: whether a scribe really happened (it is inferred from the scroll leaving its slot),
and anything about a vendor the run did not reach.

### D-017 addendum 2 (2026-10-03): the first live run of `1.6.0-test.3`

Appended; earlier text is unchanged. Evidence: the developer's live log (the v1.6.0-test.3 run, 12:53:24-12:59:38);
excerpt in `docs/evidence/2026-10-03_Benedict_v1.6.0-test.3_ClericThiran-Delin_excerpt.log`. The developer ran
Cleric 26-50 and 51-60 on Benedict, then ran the same two vendors again.

**Result.** Vicar Thiran (26-50): 172 rows, **88 scrolls built, 88 bought and scribed**, 1,340pp 6gp 4sp 6cp, in one
pass. Vicar Delin (51-60): 137 rows, **49 scrolls built, 49 bought and scribed**, 2,400pp 5sp 6cp, in one pass. Total
**137 spells, 3,740pp 7gp 2cp, 0 skipped, 0 failed, no ERROR line, no ledger defect.** Both outcome lines read
correctly (`This vendor` against `Spree total so far`; D-009's fix confirmed live). **The second spree found no scrolls
at either vendor** (Thiran 85 rows, Delin 88 rows, both with 0 scrolls), which confirms nothing was left behind.

**What the run confirmed live (D-017 Not yet verified):**
- Exact-name lookup, a row click, and Buy work on the live client: 137 of 137 selections verified on the first
  attempt, 137 of 137 purchases paid, 137 of 137 scrolls found in the expected slot on the first read, all scribed.
- The vendor's price tell arrived for every one of the 137 items (`none received`: 0).
- The quantity window opened for 136 of 137 purchases; the scribe-confirmation window never appeared.
- The settle wait did real work: at Thiran the first reads were **96 rows, then 172 within about 0.57 s**. A list built
  from the first read would have missed 76 rows.
- Speed: 2.41 s per spell at Thiran and 2.62 s at Delin, with no repeat passes (the earlier multi-pass run took about
  3.5 s per spell over four passes at a different vendor, so this is not a controlled comparison).
- One scribe (`Spell: Resolution`) needed a second attempt, the known case of the client rejecting the first
  right-click.

**What this run did NOT exercise live (simulation-only so far):** the vendor reordering or rows vanishing during
the run: **all 137 exact-name lookups returned the same row the entry had when the list was built**, so no row shifted
at any point. The retry paths (selection attempts 2 and 3; a mismatch just before Buy), the skip of a vanished row, a
stacked purchase, every stop path and the ledger categories other than "bought and scribed", and a list that does
not settle. The design handles those in the simulation; this run neither confirms nor refutes them live.

**Observations that qualify earlier facts:**
- *Scribed rows leaving the list.* D-010 addendum 4 recorded about 10 s from the one-spell watch. Here, Thiran's 88
  scribed rows were all gone by the final scan (0 still listed) while Delin's 49 were all still listed (49), and in both
  runs no row left during the purchasing (no lookup shifted). So when the list drops scribed rows varies; the 10 s
  figure does not generalize. It does not affect the build, which never relies on it.
- *The settle window is longer in practice than its nominal 2 s.* Polls were 280 to 460 ms apart (250 ms delay plus
  overhead), so 8 polls took 1.9 s to 3.3 s. Untuned values; no change proposed (Protocol section 15: a bare
  observation is not grounds to change a value).
- Thiran had 84 non-scroll rows at the first run's final scan and 85 at the second run: one non-scroll row appeared
  between the runs.

**Status:** simulation-tested and now live-run once with a clean result. Acceptance is the developer's decision
(D-006: a change is accepted before the version drops its `-test`). Step 2 (D-013) has not started.

---

## D-018 — Step 1 accepted; released as 1.6.0

**Date:** 2026-10-03 · **Status:** accepted by the developer · **Supersedes:** nothing.

### Story
`1.6.0-test.3` (list-then-buy, D-017) ran live on Cleric 26-50 and 51-60: 137 spells in one pass per vendor, nothing
skipped or failed, and a second run found nothing left (D-017 addendum 2).

### Requirement (developer, 2026-10-03: "I accept step 1.")
- R28. Step 1 is accepted. Under D-006 an accepted change drops the pre-release suffix: the accepted code is
  version **1.6.0**.

### Design choices / Implementation choices
- The only code change from `v1.6.0-test.3` is the `VERSION` string (`'1.6.0-test.3'` -> `'1.6.0'`), checked by diff.
  Both simulation suites were re-run on it and pass. Tagged `v1.6.0` (D-007), pushed.
- The developer's installed copy still says `1.6.0-test.3` until it is replaced; the code is identical.

### Open / Not yet verified
- Open: Step 2 (D-013, now D-019). Not verified live: the paths listed under D-017 addendum 2 as not exercised.

### Dependencies and shared seams
- Closes D-017. Step 2 builds on the list Step 1 creates.

---

## D-019 — Step 2 direction changed: the four tier boxes stay; the logic underneath changes

**Date:** 2026-10-03 · **Status:** direction recorded; design under discussion; nothing built ·
**Revises D-013 R20, R22, R23 and R23a** (D-013 is otherwise unchanged and still the problem statement).

### Story
D-013 recorded the developer's requirement that a tier box buy only spells in its own level range, and the AI
proposed changing the boxes to 1-25, 26-50, 51-60 and 61-65 and dropping 61-70. While Step 1 was being released the
developer corrected that: the current UI still fits the use case; that no 66-70 spells exist in the game does not make
the 61-70 selection wrong; what has to change is the logic underneath the selection.

### Requirement (developer, 2026-10-03)
- **R29 (replaces R20 and R23).** The tier boxes stay as they are: **1-25, 26-50, 51-60, 61-70**. No UI change.
- **R21 stands.** Selecting a range buys only spells whose Lvl is in that range (inclusive, D-014 item I).
- **R30 (replaces R22).** Which vendor a selected range is bought from changes underneath: **61-70 is bought from the
  1-25 vendor** (where the 61-65 spells are); 1-25, 26-50 and 51-60 are bought from their own vendors as before. If
  both 1-25 and 61-70 are ticked, that vendor is visited once and both ranges are bought from it (D-013 R22's
  one-visit rule stays).
- R24 stands (the 71-80 vendor is out of scope).
- **R23a is revised, not dropped.** Its purpose, not having to code the 61-70 vendor locations back in if the server
  extends the maximum level, still holds. The way to keep it under R29/R30 is a design choice not yet made (see D-019
  Open).

### Design choices
None made.

### Implementation choices
None made. Nothing is built.

### Open
- How the 61-70 vendor names are kept (they are in `VENDOR_DATA` today and would no longer be visited under R30).
- Whether the Bazaar path (no boxes, buys what the open vendor sells) stays unchanged.
- Everything about the filter and the ledger wording; to be designed, then reviewed through the ChatGPT loop (D-015),
  then approved by the developer before any build.

### Not yet verified
- The vendor-level facts are the developer's, confirmed on 11 of 12 classes and accepted for all 12 (D-013 addenda).

### Dependencies and shared seams
- Builds on D-017's built list (the Lvl column is already read and logged). Supersedes the box set in spec S-5 as
  recorded; S-5 is updated in place.

### D-018 addendum (2026-10-03): the 1.6.0 release was premature

Appended; the entry above is unchanged.

**Developer, 2026-10-03:** "We're not ready for the 1.6.0 release. We still need to implement the bounded by level
range purchases. Or was that part of what we just did?"

- **Answer:** no. Step 1 (D-017) replaced the scan mechanism and reads and logs each spell's `Lvl` but buys exactly what
  the old script bought (D-014 choice G, checked by `eligibility_check`). Level-bounded purchasing is Step 2 (D-013,
  D-019) and is **not built**.
- **What the AI got wrong:** in its message asking for acceptance it said that accepting Step 1 would drop the `-test`
  from the version (D-006). The developer replied "I accept step 1"; the AI took that as agreement to release. The
  developer meant accepting Step 1 as a step, not a release. D-018 R28 ("accepted, so version 1.6.0") was the AI's
  reading and is **withdrawn**. The AI created and pushed the tag `v1.6.0` and a commit setting `VERSION = '1.6.0'`.
- **What stands:** Step 1 is accepted as a step. The release version `1.6.0` is reserved for when the change the
  developer considers one release is complete, i.e. after Step 2 is built, tested, run live and accepted.
- **Cleanup proposed to the developer (not yet done, because deleting a published tag is outward-facing):** delete the
  tag `v1.6.0` locally and on GitHub; set `VERSION` back to `'1.6.0-test.3'` (the code is identical to that tag) in a new
  commit. The next handed-over build is `1.6.0-test.4` with its own tag (D-006, D-007).
- **Lesson recorded:** do not infer a release from an acceptance. A release, a tag, or any version change that is
  more than the build under test needs its own explicit go-ahead.

---

## D-020 — Release 1.6.0 scope: Steps 1-3; each selected range is its own visit

**Date:** 2026-10-03 · **Status:** requirement recorded; Steps 2 and 3 not built · **Supersedes:** the numbering of
steps in D-014 choice G and D-016 (Step 2 was "the level-range boxes"); **D-013 R22's "opened once if both are
selected" and the matching sentence of D-019 R30** (replaced by R34 below). Builds on D-018's addendum.

### Story
After the premature 1.6.0 release (D-018 addendum) the developer restated what the release must contain, and in doing
so settled how the level bounding works when several ranges are selected.

### Requirement (developer, 2026-10-03)
- **R31.** The **1.6.0 release contains Steps 1, 2 and 3**:
  - **Step 1: completed** (list-then-buy; D-017; accepted as a step in D-018).
  - **Step 2:** change the logic so each **61-70 selection uses the 1-25 spell vendor** for each class.
  - **Step 3:** implement **purchases bounded by the selected level range**.
- **R34.** With all four ranges selected the flow is: visit and buy from vendor 1 (range 1-25), vendor 2 (26-50),
  vendor 3 (51-60), then **vendor 1 a second time** (range 61-70). The developer accepts the second visit to vendor 1.
  **Each selected range is its own visit with its own level limit; visits are not merged.**
- R21 stands (a range buys only spells whose Lvl is in it, inclusive). R24 stands (71-80 out of scope). The UI does not
  change (D-019 R29).
- R23a's purpose stands (the 61-70 vendor locations are not lost); how they are kept is still a design choice.

### Design choices
None made yet. Steps 2 and 3 each need a design, review through the ChatGPT loop (D-015), and the developer's
approval before they are built; one change at a time.

### Implementation choices
Step numbering for handoff labels from now on: **Step 1** list-then-buy, **Step 2** the 61-70 -> 1-25 vendor mapping,
**Step 3** the level-bounded purchases. The earlier handoff files under Step 1 / Decision 14 are unaffected.

### Open
- The cleanup of the premature `v1.6.0` tag and `VERSION = '1.6.0'` (D-018 addendum) awaits the developer's go-ahead;
  with R31 the release now needs Steps 2 and 3, so the tag is still premature.
- The Step 2 and Step 3 designs (the AI's proposals are in the discussion that followed this entry).

### Not yet verified
- Nothing live. Steps 2 and 3 are not built.

### Dependencies and shared seams
- Step 3 depends on Step 1's built list (the Lvl column is already read and logged) and, for the 61-70 visit, on
  Step 2's mapping.

### D-020 addendum (2026-10-03): why the bounding must be strict; question 2 answered

Appended; the entry above is unchanged.

**Developer, 2026-10-03:** "Yeah, we're doing it that way specifically because there's a maximum number of scribed
spells in a spellbook. We want to let the user determine which spells are purchased."

- **Rationale recorded (developer):** a spellbook holds a limited number of scribed spells, so the user must be the one
  who decides which spells are bought. This is why a tier box buys only its own levels (R21) and why the 61-70 box
  goes to the 1-25 vendor and buys only 61-70.
- **Consequences for the design, as the AI reads them (not new requirements):** anything outside the ticked ranges is
  never bought, including a spell whose level cannot be read (D-014 item I) and any spell above level 70; and the
  approved ledger wording (out-of-range scrolls are "deliberately skipped") keeps each skipped spell visible in the log.
- **Answered:** the AI's question 2 (out-of-range spells appear in the ledger as skipped) is answered "yes", on this
  reasoning. Not yet answered: question 1 (keep the 61-70 vendor names untouched in `VENDOR_DATA` and repoint only the
  mapping), question 3 (the Bazaar path stays unfiltered) and question 4 (withdraw the premature `v1.6.0` tag).
- **Observation raised for the developer, not a request:** the Bazaar path (D-017 spec I-1, unchanged since the
  baseline) buys every scroll the open vendor sells and ignores the boxes. With the same spellbook limit that can fill
  the book, so the "user decides" principle does not currently reach it. Whether that should change is the developer's
  call; the AI has proposed no change.

### D-018 addendum 2 (2026-10-03): the premature release was withdrawn

Appended; earlier text is unchanged. **Developer, 2026-10-03: "Yes, you may."** Done: the tag `v1.6.0` was deleted locally
and on GitHub, and `VERSION` was set back to `'1.6.0-test.3'` in a new commit (`5348aea`). A diff of `spellspree.lua`
against the tested tag `v1.6.0-test.3` is empty, so the code is the one that ran live. The next handed-over build, which
will contain Step 2, is `1.6.0-test.4` with its own tag (D-006, D-007). The release `1.6.0` is created only when Steps
1-3 are complete and the developer says so (D-020 R31).

### D-020 addendum 2 (2026-10-03): the developer's answers to the three open questions

Appended; earlier text is unchanged.

1. **Step 2, the 61-70 code (replaces the AI's proposal to leave the names untouched).** **Developer: "Keep all the old
   61-70 code, just comment it out in case the server changes where the spells are located."** So Step 2 **comments out the
   old 61-70 code and does not delete it**: the `'61-70'` vendor names in `VENDOR_DATA` and the old lookup
   (`VENDOR_DATA[class][tier]` for the 61-70 tier) stay in the source as commented-out lines with a note on why and how to
   restore them, and the new logic sends every 61-70 selection to the 1-25 vendor. This is the literal form of D-013 R23a.
2. **Bazaar.** **Developer: "Bazaar is its own separate pass. We're focusing on PoK for now."** The Bazaar path is
   unchanged and out of scope for this release; any bounding there is a later, separate piece of work. (This also answers
   the observation about the spellbook limit: it is acknowledged and deferred.)
3. **The premature tag.** Withdrawn, see D-018 addendum 2.

**Status:** the Step 2 and Step 3 designs can now be written. Each still needs the ChatGPT review loop (D-015) and the
developer's approval before it is built.

---

## D-021 — Step 2 design proposal: every 61-70 selection uses the 1-25 vendor

**Date:** 2026-10-03 · **Status:** **proposed; not approved.** Each item A-F is for the developer to approve, change or
reject on its own (Protocol section 17), after review by ChatGPT (D-015). **Would implement** D-020 R31 (Step 2), D-019
R30 and R34 (each selected range is its own visit), and D-020 addendum 2 (keep the old 61-70 code, commented out).

### Story
D-013 to D-020: the `61-70` vendor lists nothing usable, the level 61-65 spells are on the `1-25` vendor, so the script
should send every 61-70 selection to the 1-25 vendor. The developer wants the tier boxes and UI unchanged, each selected
range to be its own visit, and the old 61-70 code kept as comments in case the server moves the spells. Today
`collectSelectedVendors()` makes one visit per ticked tier with one lookup line, `VENDOR_DATA[className][tier]`.

### Requirement (agreed earlier; this step implements it)
- R31 Step 2: each 61-70 selection uses the 1-25 vendor for each class. R34: each selected range is its own visit (all
  four ticked: vendor 1, 2, 3, then 1 again). D-019 R29: no UI change. D-020 addendum 2: keep the old 61-70 code,
  commented out; Bazaar untouched.

### Design choices (the developer approves each separately)
- **A.** A `TIER_VENDOR` mapping (`1-25`->`1-25`, `26-50`->`26-50`, `51-60`->`51-60`, `61-70`->`1-25`); the vendor lookup
  goes through it; a tier with no mapping is skipped as a missing name is today.
- **B.** The old 61-70 code is **commented out in place, not deleted**: the `['61-70']` name in each `VENDOR_DATA` class
  line wrapped in an inline `--[[ ]]` block comment; the old lookup line and the old `['61-70']='61-70'` mapping entry
  kept as comments with a note on how to restore them; `'61-70'` stays in `TIERS` (UI unchanged).
- **C.** One visit per ticked tier, not merged; order class then tier; all four ticked = vendor 1, 2, 3, 1.
- **D.** The visit label notes when the vendor tier differs from the ticked tier ("Cleric 61-70, bought from the 1-25
  vendor").
- **E.** Nothing else changes: a 61-70 visit buys what the 1-25 vendor still lists, until Step 3 adds the level bound.
- **F.** Simulation tests (visit order and labels for all four ticked, only 61-70, and 1-25 plus 61-70; the old 61-70
  vendor never targeted; the 12 old names still in the source inside comment markers) with mutation checks; Step 2 is not
  handed over for a live test alone, Steps 2 and 3 go together as `1.6.0-test.4`, unless the developer asks otherwise.

### Implementation choices (the AI's)
- The old names stay on their class lines (inline comments) so restoring is local. The mock gains a way to open a class's
  tree and tick one tier box, so a single-tier spree can be simulated.

### Open
- The ChatGPT review (handoff Step 2 / Decision 21 / Revision 1, archived in `docs/handoffs/`) and the developer's
  approval of A-F.

### Not yet verified
- Everything: nothing is built. The visit behavior rests on a second run over the same vendors having worked live.

### Dependencies and shared seams
- Step 3 (the level bound) builds on the second visit this step creates; Step 1's list-then-buy is untouched.

### D-021 review round 1 (2026-10-03): ChatGPT's review of Revision 1 and the AI's positions (Revision 2)

Appended; earlier text is unchanged. Archived in `docs/handoffs/`: `..._step2_decision21_rev1_review_from-chatgpt.md`
and `..._step2_decision21_rev2_from-claude.md`.

ChatGPT asked the developer to confirm three decisions it had not seen (all-class routing of 61-70 to the 1-25 vendor
including Druid; separate visits per tier; old entries kept as comments and Steps 2 and 3 delivered together). The AI
supplied the developer's exact words and dates from this log (D-020 R31 and R34, D-020 addendum 2, D-013 addendum 4) and
**corrected one point**: delivering Steps 2 and 3 together for live testing is the AI's proposal, not a developer
instruction; the developer has said only that 1.6.0 contains Steps 1-3.

| Item | ChatGPT | AI | State |
|---|---|---|---|
| A | Request changes (log a missing mapping) | Agree | A' |
| B | Request changes (restore note must replace the active mapping) | Agree | B' |
| C | Request changes (confirm separate visits) | Confirmation quoted | pending ChatGPT's confirmation |
| D | Request changes ("using", not "bought from") | Agree | D' |
| E | Approve | Agree | agreed |
| F | Request changes (multi-class test; correct the "re-buy" claim; confirm delivery) | Agree; delivery stays a proposal | F' |

**Revised items:** A' (WARN on a missing mapping, no silent skip); B' (the restoration note says to delete the active
`['61-70']='1-25'` entry and un-comment the old one so exactly one `['61-70']` entry is active; inline `--[[ ]]` kept);
D' (`... (Cleric 61-70, using the 1-25 vendor)`, logged before any purchase); F' (adds a Cleric plus Wizard class-routing
case, a missing-mapping case and the source check; the "would re-buy" claim is replaced by the accurate limitation that
Step 2 does not enforce the selected range). The AI's own inaccuracy ("would re-buy") is acknowledged here.

**Status:** awaiting ChatGPT's review of Revision 2, then the developer's per-item approval. Nothing is built.

### D-015 addendum (2026-10-03): ChatGPT gives no recommendations when it needs context

Appended; earlier text is unchanged. **Developer, 2026-10-03:** the developer corrected ChatGPT so that it does not give
recommendations when it needs more context or has questions; its output in that case is informational for the AI.
Effect on the loop: a ChatGPT message that asks for confirmation or context is read as questions to answer (with sourced
facts, quoting the developer's recorded words and dates), not as verdicts to weigh. When ChatGPT does give verdicts they
are treated as considered positions under R25 (agree or disagree with reasons). The review of D-021 Revision 1 was such a
mixed message: it asked for confirmations and also gave verdicts; the AI answered both in Revision 2.

### D-021 review round 2 (2026-10-03): consensus on Step 2 between the AI and ChatGPT

Appended; earlier text is unchanged. ChatGPT's review of Revision 2 is archived in
`docs/handoffs/2026-10-03_step2_decision21_rev2_review_from-chatgpt.md`: **it approved A', B', C, D', E and F'** and states
every Step 2 item is agreed from its review; final authorization stays with the developer; Druid routing is "accepted by
your decision" and is not tested evidence.

**Consensus (AI and ChatGPT), awaiting the developer's approval item by item:**
- **A'** A `TIER_VENDOR` mapping (`1-25`->`1-25`, `26-50`->`26-50`, `51-60`->`51-60`, `61-70`->`1-25`); the vendor lookup goes
  through it; a tier or class with no mapping or vendor name logs a WARN naming the class and tier and skips that visit.
- **B'** The old 61-70 code is commented out in place, not deleted: inline `--[[ ]]` around the `['61-70']` names in
  `VENDOR_DATA`; the old lookup line and the old `['61-70']='61-70'` mapping entry kept as comments; a restoration note that
  says to delete the active `['61-70']='1-25'` entry and un-comment the old one so exactly one `['61-70']` entry is active;
  `'61-70'` stays in `TIERS` (UI unchanged).
- **C** One visit per ticked tier, not merged; class then tier order; all four ticked = vendor 1, 2, 3, 1.
- **D'** The visit label reads `(Cleric 61-70, using the 1-25 vendor)`, logged before any purchase.
- **E** Nothing else changes in Step 2.
- **F' (tests)** Simulation tests: all four ticked; only 61-70; 1-25 plus 61-70; a Cleric plus Wizard class-routing case; a
  missing-mapping case; the source check (12 old names present inside comment markers, exactly one active `['61-70']`
  entry); mutation checks. Limitation stated accurately: Step 2 does not enforce the selected level range.
- **F' (delivery)** Step 2 is committed and simulation-tested, and is live-tested together with Step 3 as `1.6.0-test.4`,
  not alone. **This is the AI's recommendation; ChatGPT agrees there is no demonstrated need to test Step 2 alone. The
  developer has not yet decided it.**

Nothing is a requirement until the developer approves it. On approval a new entry records it, then Step 2 is built.

---

## D-022 — APPROVED: Step 2, every 61-70 selection uses the 1-25 vendor

**Date:** 2026-10-03 · **Status:** approved by the developer; build in progress · **Supersedes:** the `61-70` tier -> `61-70`
vendor routing in `collectSelectedVendors` (the old code is kept as comments, not deleted); D-021's "proposed" status.

### Story
D-013 to D-021: the 61-70 vendor lists nothing usable and the level 61-65 spells are on the 1-25 vendor, so every 61-70
selection must use the 1-25 vendor, as its own visit, with the old 61-70 code kept in case the server changes. The design
was reviewed by ChatGPT over two revisions (archived in `docs/handoffs/`) and agreed.

### Requirement (developer, 2026-10-03: "I approve the decisions as reached by consensus.")
All of D-021 review round 2's items, as written there:
- **A'** `TIER_VENDOR` mapping (`61-70` -> `1-25`; the others map to themselves); the lookup goes through it; a missing
  mapping or vendor name logs a WARN naming the class and tier and skips that visit.
- **B'** The old 61-70 code commented out in place, not deleted (inline `--[[ ]]` on the `VENDOR_DATA` names; the old
  lookup line and old mapping entry kept as comments; a restoration note saying to delete the active `['61-70']='1-25'`
  entry and un-comment the old one so exactly one `['61-70']` entry is active); `'61-70'` stays in `TIERS`; UI unchanged.
- **C** One visit per ticked tier, not merged; class then tier; all four ticked = vendor 1, 2, 3, 1.
- **D'** The visit label reads `(Cleric 61-70, using the 1-25 vendor)`, logged before any purchase.
- **E** Nothing else changes in Step 2.
- **F' (tests)** Simulation tests (all four ticked; only 61-70; 1-25 plus 61-70; Cleric plus Wizard routing; missing
  mapping; source check) with mutation checks.
- **F' (delivery)** Step 2 is committed and simulation-tested, and is **live-tested together with Step 3 as `1.6.0-test.4`,
  not alone.** The developer approved this delivery.

### Design choices / Implementation choices
As above. The version stays `1.6.0-test.3` until a build is handed over; Step 2 alone is not tagged (it is not handed over).
Existing tests that assumed one visit per vendor in a four-tier spree change with the approved behavior (R34): a Cleric spree
now visits `Vicar Ceraen` twice, so `T11` in `test/test_logging.lua` expects two outcome lines for it; recorded in the
build's addendum.

### Open
- Step 3 (the level bound) is next: its own design, ChatGPT review, developer approval.

### Not yet verified
- Everything live. Step 2's second visit to a vendor relies on a second run over the same vendors having worked live.

### Dependencies and shared seams
- Step 3 builds on the second visit this step creates.

### D-022 addendum (2026-10-03): Step 2 built; evidence

Appended; the entry above is unchanged.

**Built (`spellspree.lua`):** a `TIER_VENDOR` table (`61-70` -> `1-25`, the others to themselves) with the old
`['61-70']='61-70'` entry kept beside it as a comment and a restoration note (delete the active `['61-70']='1-25'` entry and
un-comment the old one so exactly one is active); the 12 `['61-70']` vendor names in `VENDOR_DATA` wrapped in inline
`--[[ ]]` comments in place, with an explanatory comment above the table; `collectSelectedVendors` looks the vendor up
through the mapping, keeps the old lookup as a comment, and logs a WARN naming the class and tier instead of skipping
silently when a mapping or vendor name is missing; the visit label says `using the <tier> vendor` when the vendor tier
differs from the ticked tier. `TIERS`, the UI, the Bazaar path and all buying code are untouched. `VERSION` stays
`1.6.0-test.3`; Step 2 is not handed over and is not tagged (D-022 delivery: live-tested with Step 3 as `1.6.0-test.4`).

**Evidence, simulation only:**
- `test/test_step2.lua`: 8 tests (S1-S8), each citing D-022 / D-021 / D-020 R34, all passing; 5 mutation checks, each caught by
  the tests predicted. Cases: four Cleric tiers ticked (vendor 1, 2, 3, then 1 again, old 61-70 vendor never targeted, two
  separate outcome lines for vendor 1, the second visit bought 0); only 61-70; 1-25 plus 61-70 (two visits, not merged);
  Cleric plus Wizard (each class's own 1-25 vendor, in class order); the visit labels; a missing mapping (WARN, no visit);
  the source check (12 old names kept inside comments, no active 61-70 vendor entry, exactly one active mapping, restoration
  note present); every spell bought exactly once.
- Two of my mutation predictions were incomplete and were corrected, not the tests: mutation 1 also fails S6 (that test
  simulates a missing mapping by deleting the active 61-70 line, which the mutation had already changed) and mutation 4
  also fails S8 (Vicar Delin is never visited, so its spell is never bought).
- The Step 1 suite (18 tests, 9 mutations) and the logging suite (11 tests, 9 mutations) pass. `eligibility_check` against
  `v1.6.0-test.3`: the same set of spells bought and the same money left in all five scenarios.
- **One existing test changed with the approved behavior:** `T11` in `test/test_logging.lua` assumed one visit per vendor in a
  four-tier Cleric spree; under R34 `Vicar Ceraen` is visited twice, so it now expects two outcome lines for it (the first
  bought 3, the second 0, spree total 3). Its purpose (an outcome line must not report another vendor's totals) is unchanged.
- Log review: the four-visit flow reads `Vendor 4/4: Vicar Ceraen (Cleric 61-70, using the 1-25 vendor)`; the multi-class
  case reads `Vicar Ceraen (Cleric 61-70, ...)` then `Channeler Olaemos (Wizard 61-70, ...)`.

**An observation the log review surfaced (no change made):** in an early version of the test the fourth visit ended
`Stopped, reason="Vendor list did not settle"`. Cause: the simulated vendor had no rows left after everything was bought,
and the approved settle rule (D-017 B': "at least 1 row, unchanged for 8 polls") never treats an empty list as settled, so
the visit waits the full 15 s and reports "did not settle". Every live vendor so far also sold non-scroll items, so its
list was never empty, and the old 61-70 vendors (the empty ones) are no longer visited; so this has not happened live. The
simulated vendors now also sell a non-scroll item, as live vendors do. Recorded in the ledger as an open observation; the
rule is an approved item and was not changed.

**Not verified:** everything live. The second visit to the same vendor within one spree has run live only as a separate
second spree.

### D-022 addendum 2 (2026-10-03): a gap in the tests, found by the developer's questions, closed

Appended; earlier text is unchanged. The developer asked how the suites run, whether the mutation checks change the real Lua,
and whether the completely empty vendor was kept as a test after non-scroll items were added to the mocks.

- **How the suites run (answer, from the code):** every suite loads the real `spellspree.lua` with `loadfile` and runs it with
  `mq` and `ImGui` replaced by `test/mock_mq.lua` through `package.preload` (`test/sim_run.lua`); no test contains a second
  implementation of the script's logic. Mutation checks read the real source text, replace one exact string (the target must be
  found exactly once or the check is reported as failed), write the result to a temporary file, and run the same tests against
  that file; the real `spellspree.lua` is not modified. Two kinds of test do not execute the script: `S7` in
  `test/test_step2.lua` reads the source text (a deliberately static check that the old 61-70 code is commented out, not deleted),
  and `S6` runs a modified copy of the script to simulate a configuration error. The eligibility check compares two real builds.
- **The gap (the AI's):** when non-scroll items were added to the test vendors (so the fourth visit did not stop on an empty
  list), the completely empty vendor was **not** kept as a test. The 15-second timeout was covered only by `L5`, which uses a
  list whose count keeps changing, not an empty one. So the empty-list behavior recorded in ledger item 16 had no test.
- **Closed:** `L19` in `test/test_listthenbuy.lua` runs a vendor with no rows at all and checks that the visit stops after about
  15 s with `state=Stopped` and the reason `Vendor list did not settle`, buying nothing, and that the polls read `count=0`. It
  documents the approved behavior (D-017 B' says "at least 1 row") and does not endorse it. A new mutation (accepting 0 rows as
  settled) is caught by `L19` alone, as predicted; the existing "never gives up within 15 s" mutation now also fails `L19`
  (it measures the same maximum), and `L10`'s ledger check now skips both scenarios that build no list.
- Counts now: `test_listthenbuy.lua` 19 tests and 10 mutation checks; `test_step2.lua` 8 and 5; `test_logging.lua` 11 and 9.
