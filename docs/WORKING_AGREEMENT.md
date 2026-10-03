# SpellSpree — Working Agreement

This project follows the development protocol at
`C:\Users\legal\source\repos\MQClaudeTestBridge\docs\Development_Protocol.txt`
(Development Protocol, §1–§22). That document governs process. This file holds
the project-specific parts the protocol asks each project to keep.

Document set (all in `docs/`):

| Document | Job | Status |
|---|---|---|
| `WORKING_AGREEMENT.md` | Process pointer, sibling-project list (§21) | this file |
| `SPEC.md` | What the system must do | started 2026-10-03; agreed requirements S-1, S-2 only, rest inherited/unreviewed |
| `PROJECT_LEDGER.md` | Current state: resolved behavior, confirmed facts, open details, out of scope (§11) | started 2026-10-03 |
| `DECISION_LOG.md` | Append-only history and rationale (§2) | started 2026-10-03; D-001, D-002 (retrofits), D-003 |

## Project-specific process additions

These add to the Development Protocol for this project only.

- **P-1. Pre-handoff log review (developer, 2026-10-03; D-003).** Before any
  build is presented for manual (live, in-game) testing, the logging must be
  reviewed against what that specific test needs to prove, so the developer does
  not have to rerun a manual test because the log was missing something. The
  review is a separate step from the §8 "inspect a representative log" check and
  is part of the §10 handoff gate: a build is not ready for handoff until it has
  been done and its result stated in the handoff message. Procedure is in
  `DECISION_LOG.md` D-003.
- **P-2. Build identity (developer, 2026-10-03; D-005, D-006).** SemVer in
  `VERSION`, shown in the window title and every log line, plus git history. The
  Development Protocol §9 requirement of a unique filename per test build does
  **not** apply to this project (**supersedes §9, filename clause**); the file is
  always `spellspree.lua`. Test builds raise the pre-release number on each
  handoff (`1.6.0-test.1`, `-test.2`, ...); MINOR/PATCH change only when a change
  is accepted.
- **P-3. Commit and tag every handed-over build (developer, 2026-10-03; D-007).**
  Before a build is handed over for live testing it is committed and the commit
  is tagged `v<VERSION>` (annotated, pushed). Handoff therefore needs: the P-1
  log review, and a tagged commit whose `VERSION` equals the tag.
- **P-4. Docs are always committed and pushed (developer, 2026-10-03; D-008).**
  Changes under `docs/` are committed and pushed without asking permission. This
  covers docs only; code follows the one-change-at-a-time process and P-1/P-3.
- **P-5. Operator cues must not be buried (developer, 2026-10-03; D-011).** If a run needs
  the developer to act or wait, the cue is unmissable and the chat window is not spammed:
  chat gets only the cue and a final "done"; everything else goes to the log file. The P-1
  handoff review checks this too.
- **P-6. Second-agent review loop (developer, 2026-10-03; D-015).** When another agent reviews
  a proposal, the AI evaluates each recommendation on its merits and agrees or disagrees, with
  reasons the developer can take back to that agent. It does not accept a change because it was
  recommended. Rounds repeat until all parties agree; each round is recorded in the decision log.
- **P-7. Handoff labels (developer, 2026-10-03; D-016).** Every message between Claude and GPT starts
  with `HANDOFF: Step <n> / Decision <n> / Revision <n> / From <Claude|GPT> / <date>`, plus
  `Answering: <label of the message answered>` on every revision after the first. Messages are archived
  in `docs/handoffs/`.
  Flow: Claude `HANDOFF: ... / From Claude / <date>`; ChatGPT `REVIEW OF: ... / From ChatGPT / <date>`
  (From = the author; numbers are those of the Claude message reviewed); Claude's reply `HANDOFF: ... /
  From Claude / <date>` with `Answering: <ChatGPT's REVIEW OF label, repeated exactly>`.
  Numbering confirmed: Decision = the decision-log number; Step = order of work; each Claude reply in
  the chain increments the revision number.

## Sibling projects (Development Protocol §21)

The developer's other projects on the same platform (MacroQuest Lua, Project
Triune). Consult before designing a new mechanism; add to it as related
projects come up. Notes below are taken from each project's README as read on
2026-10-03, not from its source — read the source directly (§4) before relying
on any of them for a specific behavior.

| Project | What it covers (per its README) |
|---|---|
| [PTAAPlanner](https://github.com/thezerodivide/PTAAPlanner) | AA planning GUI plus native Lua AA purchasing: prioritized purchase lists, safety checks, queued manual purchases, saved lists, import/export, diagnostic logging. |
| [PTAutoRoute](https://github.com/thezerodivide/PTAutoRoute) | Records and plays back dungeon routes (nav, ground drops, water crossings, doors) by orchestrating TAC and MQ2Nav. Editor/Runner split; pauses around combat; always-on diagnostic logging. |
| [AutoInvAutoDZAdd](https://github.com/thezerodivide/AutoInvAutoDZAdd) | Tell-triggered group invites and DZ adds, guild-roster handling via `/outputfile guild`, per-character/server settings, ImGui plus slash commands. |
| [PTItemEvolver](https://github.com/thezerodivide/PTItemEvolver) | Queues items for Base → Enchanted → Legendary evolution; moves/stages/restores worn and bag items; persists queue per character/server; TAC coordination. |
| [PTDeathRecovery](https://github.com/thezerodivide/PTDeathRecovery) | Detects death, returns from the Bazaar to the expedition, verifies TAC is running. README states it verifies command results rather than assuming success from having sent them. |

"Sibling" means a project the developer owns. Projects the developer does not
own are not siblings.

### Reference projects

Not owned by the developer. Treated as external components: read their source
directly and cite it (§4); do not rely on summaries.

| Project | Notes |
|---|---|
| [Triune Auto Combat (TAC)](https://github.com/gennro/TriuneAutocombat) | Reference project for Project Triune. Repo owner: gennro. |

MacroQuest and MQ2Nav are likewise external components (§4), not siblings.

### Prior-art notes for SpellSpree

- None of the five READMEs mentions merchant windows, vendor purchasing, or
  scribing. Whether any of them contains reusable code for those (inventory
  slot handling in PTItemEvolver is the closest by description) is **unknown**
  until their source is read.
- SpellSpree's own source says its class detection was "ported from
  triune.lua's own detectClasses()". ~~Open: is `triune.lua` a sibling
  project?~~ **Resolved (developer, 2026-10-03):** `triune.lua` is part of TAC,
  i.e. a reference project, not a sibling. SpellSpree's ported
  `detectClasses()` therefore derives from external source; per §4, any
  further reliance on it should be checked against the TAC source directly.
- ~~Open: has anything already solved a vendor close/reopen or merchant-list
  re-enumeration problem?~~ **Resolved (developer, 2026-10-03):** No. There is
  no known prior art; the mechanism is new to this project.
