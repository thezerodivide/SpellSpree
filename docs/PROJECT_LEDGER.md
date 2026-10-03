# SpellSpree — Project Ledger

Current state only (Development Protocol §11). History and rationale are in
`DECISION_LOG.md`. Corrections are struck through with a note, not erased.

Last reviewed end to end: 2026-10-03 (§18).
Baseline: commit `f6c29f4`, referred to as **v1.5.0** (that commit's file still says `1.5-reorder-passes`).
Current: `1.6.0-test.1` on local `main` (D-004 file logging, D-005 version). Simulation-tested only; **not pushed** to GitHub and not yet live-tested.

## Resolved behavior

Only behavior the developer has explicitly agreed.

- Make a pass over the merchant list, close and reopen the same vendor, and make
  another pass, until no spells are found available for purchase. *(D-001 R1)*
- The merged build must not lose anything the original does. *(D-001 R2)*
- Stay on the v1.5 version line; use SemVer from now on; the baseline counts as 1.5.0. *(D-005 R12, R13 and addendum)*
- Test builds raise the pre-release number each handoff; the file stays `spellspree.lua`, no unique filename per build. *(D-006 R14, R15)*

Inherited behavior of the original (Bazaar mode, `Song:` scrolls, PoK vendor
walk, buy-and-scribe loop, usable-only filter requirement, stop conditions) is
**not** listed here: it has not been separately reviewed and agreed. It is
described in `SPEC.md` as inherited and unreviewed.

## Confirmed live/system facts

Established by evidence we hold. Nothing here has been established by a live
test of the merged build.

*From source inspection of `spellspree.lua` (baseline):*

- It logs only to the ImGui window and to chat via `print`. It writes no file;
  there is no log under `macroquest\logs\spellspree\` (§8). *(Searched for
  `io.open`/log paths; none.)*
- The window title contains `VERSION` (`'SpellSpree v' .. VERSION`).
- ~~It logs only to the ImGui window and to chat; no file.~~ **Superseded by D-004
  (2026-10-03):** the working tree now also writes
  `<MQ logs>/spellspree/spellspree_<server>_<character>.log`. Not yet live-tested.
- Pass termination is `S.bought - passBoughtStart == 0` at the end of the visible
  list. `S.bought` is also incremented for a purchase that stacks onto an
  existing copy, which is deliberately not scribed.

*From MacroQuest source (checkout `Documents\MacroQuest\macroquest`, commit `5f8a6eea`), D-004 addendum:*

- `mq.cmdf` = `string.format` then the same execute path as `mq.cmd`
  (`lua_MQBindings.cpp` `command_format`, lines 194-209).
- `mq.configDir` and `mq.gettime()` (ms, steady clock) exist
  (`lua_MQBindings.cpp:527, 56-62`).
- `MacroQuest.Path('logs')` is `internal_paths::Logs`
  (`MQ2MacroQuestType.cpp:123-127`), compiled-in default is the relative string
  `"Logs"` (`MQ2Globals.cpp:100`). No Lua binding exposes the logs path.

*Simulation evidence only (mock MQ; not live):* `test/test_logging.lua` (10 tests,
8 mutation checks) passes; `test/equivalence_check.lua` shows the logging build
sends identical commands, buys identical items and takes identical simulated time
as the pre-logging baseline in four scenarios.

*Claimed by the original author in code comments, not verified by us:*

- `Merchant.Item(N)` indexing can diverge from the visible list when the
  usable-only filter is on.
- `mq.event` chat patterns never fired in the author's testing, so verification
  uses TLO reads.
- `Item.Price()` always reads 0; `Item.Spell` is unreliable for scroll detection.
- Spell scrolls stack on this server.
- The merchant client can reject right-click scribes for several seconds after a
  purchase.

## Open implementation details

1. **Does the usable-only filter drop already-scribed spells on reopen?** Pass
   termination depends on it. Smallest test: scribe one spell from a vendor,
   close and reopen, see whether its row is gone (developer, in game).
2. **Is `ItemList.Items()` reliable?** The build hard-stops if it reads nil.
3. **Does `/click right target` reopen the merchant in the Bazaar?**
4. **Stacked-purchase re-buy.** Hypothesis from code reading: a purchase that
   stacks onto an unscribed copy keeps its row, counts as bought, forces another
   pass, and is bought again until `MAX_SCAN_PASSES`. Not observed. Scope of any
   fix is undecided. The developer has described only the stacked case; whether
   skipped-for-money or failed purchases should be handled is **not** agreed.
5. ~~**Build identity.**~~ **Resolved (D-005, D-006).** Baseline = 1.5.0; the
   logging build is `1.6.0-test.1`; test builds raise the pre-release number per
   handoff; no unique filename needed (supersedes Protocol §9 filename clause for
   this project). **Still open:** how a handed-over build is tied to an exact
   commit (AI suggestion in D-006: commit and tag each handed-over build).
6. ~~File logging to `macroquest\logs\spellspree\` (§8) is absent.~~ **Built,
   awaiting live confirmation (D-004).** Remaining live questions: what
   `MacroQuest.Path('logs')` returns in the client (relative `"Logs"` vs
   absolute); whether `os.execute` mkdir works without a console flash in this
   MQ Lua environment; whether character/server names are readable at load.
   The first live log answers all three (`log path resolution:` line).
7. **Testability split (§20)** of the pass/dedupe logic from the MQ binding is
   not yet designed.
8. **Plane of Knowledge path not simulated.** `runNavAndShop`'s `/nav`, `/target
   npc`, `/click` conversions to `sendCmd` are verified by static reading only.
9. **Repo housekeeping:** README, licence, `.gitignore`, `.gitattributes` not
   decided.

## Out of scope

Nothing has been explicitly declared out of scope yet.

## Deferred, with revisit triggers (§3)

- Handling skipped-for-money or failed purchases across passes. Revisit if a live
  log shows them forcing extra passes.

## How to run the checks

From the repo root, with LuaJIT:

```
luajit test/test_logging.lua
luajit test/equivalence_check.lua <pre-change baseline .lua> spellspree.lua
```

Both run `spellspree.lua` against `test/mock_mq.lua`, a model of MacroQuest. They
are **simulation only** (Development Protocol §10): they prove nothing about live
behavior.
