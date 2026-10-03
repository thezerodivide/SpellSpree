# SpellSpree — Project Ledger

Current state only (Development Protocol §11). History and rationale are in
`DECISION_LOG.md`. Corrections are struck through with a note, not erased.

Last reviewed end to end: 2026-10-03 (§18).
Baseline: commit `f6c29f4`, referred to as **v1.5.0** (that commit's file still says `1.5-reorder-passes`).
Current: `1.6.0-test.2` (D-009 outcome-line fix on top of `1.6.0-test.1` file logging), tagged `v1.6.0-test.2` and pushed. Simulation-tested; `1.6.0-test.1` has run live once.

## Where we left off (after the outcome-line fix, 2026-10-03)

- State: `v1.6.0-test.2` (tag `v1.6.0-test.2`, pushed): D-009 fixes the `Run outcome` line (item 12). Simulation-tested only. `1.6.0-test.1` had its first live run (vendor 1, Cleric 1-25): 70 spells in four passes, nothing lost; vendor 2's outcome line was the bug now fixed.
- Handoff review (P-1) for `1.6.0-test.2` is in the handoff message; the live check is: run a PoK spree over two or more vendors and read each vendor's `Run outcome` line (`This vendor` vs `Spree total so far`).
- Open, developer's call: items 11 (partial row count after reopen) and 13 (log volume vs rotation). Item 10 is reframed (no change requested). Items 3 and 4 (Bazaar reopen, stacked re-buy) have not occurred live yet.

## Resolved behavior

Only behavior the developer has explicitly agreed.

- Make a pass over the merchant list, close and reopen the same vendor, and make
  another pass, until no spells are found available for purchase. *(D-001 R1)*
- The merged build must not lose anything the original does. *(D-001 R2)*
- Stay on the v1.5 version line; use SemVer from now on; the baseline counts as 1.5.0. *(D-005 R12, R13 and addendum)*
- Test builds raise the pre-release number each handoff; the file stays `spellspree.lua`, no unique filename per build. *(D-006 R14, R15)*
- Every handed-over build is committed and tagged `v<VERSION>` first. *(D-007 R16)*

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

*Confirmed live by the developer (direct in-game observation, not from a log of this
build):*

- With the merchant's usable-only filter on, closing and reopening the vendor
  rebuilds the list without spells already scribed. *(Stated 2026-10-03; which build
  and vendor it was seen on were not given.)*

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

*Confirmed from the first live log (`v1.6.0-test.1`, character Benedict, 2026-10-03; excerpt in `docs/evidence/2026-10-03_Benedict_v1.6.0-test.1_excerpt.log`, full file on the developer's machine):*

- `MacroQuest.Path('logs')` returns an **absolute** path (`C:\Users\Public\MacroQuest\Logs`); `os.execute` mkdir worked; server (`multiclass`) and character names were readable at load. The log file was created as designed.
- `mq.event` price-quote events **do fire**: 402 `[price quote]` lines; all 70 spell purchases had a quote on file before buying. (The original author's comment that events never fired is not true for this one.) Quotes for non-spell items arrive keyed `the <name>`, which does not match the selected name; irrelevant for spells (keyed `Spell: <name>`).
- A merchant with the usable-only filter on lists many non-spell items: 153 rows for Vicar Ceraen (Cleric 1-25), 319 of 389 row encounters were non-spells.
- The scribe-confirmation window never appeared (70 of 70 purchases). The quantity window appeared on 69 of 70 purchases; the run handled both cases.
- All 70 purchases: money dropped on the first poll and the scroll read in the expected slot on the first poll. No skips, no failures.
- **Scribed rows are removed from the list lazily and in batches, not one per scribe.** Pass 1 of vendor 1: row count 153 held through three scribes, then dropped 153 -> 150 -> 139 -> 136 -> 134 -> 127 in steps of 3, 11, 3, 2, 7 while 49 spells were bought. At the end of pass 1 the list still showed 127 rows, though a fresh list had 104.
- **A single pass misses spells.** Vendor 1 took four passes: pass 1 bought 49, pass 2 bought 17, pass 3 bought 4, pass 4 bought 0 (done). 70 purchased, 0 skipped, 756pp 3sp 3cp, about 4 minutes. None of the 17 spells bought in pass 2, nor the 4 bought in pass 3, had been selected at all in pass 1.
- **The row count read immediately after a reopen can be partial.** Pass 2 reopened with 13 visible rows; after its first purchase the count read 104. Passes 3 and 4 reopened with 87 and 83 rows.
- The Stop button works mid-vendor: `User pressed Stop` -> `Stopped by user` -> outcome line -> merchant closed.
- Logging volume: about 1.7 KB per second of run (3,239 lines / 487 KB in 4m50s).

*Not exercised in that run:* a purchase that stacks onto an existing copy (Open item 4), the Bazaar (Open item 3), a long multi-vendor spree, a failed scribe.

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

1. ~~Does the usable-only filter drop already-scribed spells on reopen?~~
   **Resolved, 2026-10-03 (developer, from direct in-game observation):** yes. This is
   the reason for making multiple passes on one vendor. See the confirmed facts.
2. **Is `ItemList.Items()` reliable?** The build hard-stops if it reads nil. First
   live log: it never read nil, and its counts were consistent with what the scan
   then selected (pass 4 read all 83 rows with no unreadable selection). Two
   caveats: it can be **partial right after a reopen** (13 then 104; see item 11),
   and the log cannot show whether it under-reports against the vendor's true row
   count. Not fully settled.
3. **Does `/click right target` reopen the merchant in the Bazaar?** It reopened the merchant three times in PoK (live log, vendor 1). Bazaar not yet tried.
4. **Stacked-purchase re-buy.** Hypothesis from code reading: a purchase that
   stacks onto an unscribed copy keeps its row, counts as bought, forces another
   pass, and is bought again until `MAX_SCAN_PASSES`. Not observed (no stacked
   purchase occurred in the first live run). Scope of any
   fix is undecided. The developer has described only the stacked case; whether
   skipped-for-money or failed purchases should be handled is **not** agreed.
5. ~~**Build identity.**~~ **Resolved (D-005, D-006).** Baseline = 1.5.0; the
   logging build is `1.6.0-test.1`; test builds raise the pre-release number per
   handoff; no unique filename needed (supersedes Protocol §9 filename clause for
   this project). The build-to-commit tie is resolved by D-007: each handed-over
   build is committed and tagged `v<VERSION>`.
6. ~~File logging to `macroquest\logs\spellspree\` (§8) is absent.~~ **Built and
   live-confirmed (D-004, first live log 2026-10-03):** `Path('logs')` is absolute,
   mkdir worked, names readable. Still unknown: whether `os.execute` mkdir flashes
   a console window (the developer has not reported one).
7. **Testability split (§20)** of the pass/dedupe logic from the MQ binding is
   not yet designed.
8. ~~Plane of Knowledge path not simulated.~~ **Now simulated (D-009):** a two-vendor
   spree runs through `/nav`, `/target npc` and `/click` against the mock. Still simulation
   only; the live PoK path has run once (vendor 1) and logged as expected.
9. **Repo housekeeping:** README, licence, `.gitignore`, `.gitattributes` not
   decided.
10. ~~**DEFECT (D-001 implementation): the scan skips spells...**~~ **Reframed,
    developer correction 2026-10-03: this is the vendor window's behavior, the very
    problem the multi-pass design exists to absorb, not a defect.** Observed (live
    log, vendor 1): while the scan walks the list by row number, the vendor window
    changes under it. Scribed rows disappear late and in batches (153 -> 150 -> 139
    -> 136 -> 134 -> 127 in steps of 3, 11, 3, 2, 7), so rows shift relative to the
    cursor; a row from pass 2's first purchase vanished about 5 s later with no scribe
    at that moment, and `Elysium Bone Powder` was read twice as a result (the seen-set
    flagged it). Item order itself did **not** change: it stayed alphabetical, passes 3
    and 4 read identical sequences, and the only inversions were a sort nuance
    (`Ward Undead`/`Ward of Vie`) and the 13 -> 104 list rebuild after reopen. Result:
    pass 1 never selected 21 spells that passes 2 and 3 then bought; vendor 1 took four
    passes; **nothing was lost** (a zero-buy pass cannot skip). **No change requested;
    the extra passes are the accepted cost of the design (S-1).** The AI's earlier
    suggestion (adjust the index by the number of rows actually removed) stays
    unagreed and is not planned. See D-001 addendum 3.
11. **HAZARD (D-001 implementation): row count read right after a reopen can be
    partial.** Pass 2 started with 13 rows when the full list was 104. It did no harm
    here because the first row read was a spell and the count is re-read each
    iteration, but a transient 0 (or a small count) at the start of a pass would end
    that pass at once, and a new pass with zero purchases is read as "scan complete".
    Not observed to cause a wrong finish. No fix designed or agreed.
12. ~~**DEFECT (D-004, my logging): `Run outcome` shows spree-cumulative totals.**~~
    **Fixed in `1.6.0-test.2` (D-009), simulation-tested only.** Vendor 2 of the first live
    run (bought nothing) had printed vendor 1's totals (`bought=70`). The line now gives
    `This vendor:` and `Spree total so far:` separately. Needs a live two-vendor run to
    confirm; the developer's PoK runs will show it.
13. **Log volume vs rotation.** About 1.7 KB/s verbose. At the 4 MB rotation limit that
    is about 40 minutes of running; rotation keeps only one `.old`, so a long
    multi-vendor spree would lose its earliest part. Whether that matters, and what to
    do, is the developer's call; not observed to happen.

14. **PROPOSAL under investigation (D-010):** build the vendor's spell list when it opens
    and buy from that list, instead of line-by-line multiple passes. Not an agreed
    requirement; S-1 stands. Blocked on spike results. Spike built: `spikes/spellspree_spike.lua`
    `0.1.0-spike.1` (tag `spike/vendor-0.1.0-spike.1`), simulation-checked only; awaiting a
    live run by the developer (probe, then `watch` with one hand-bought spell). Questions
    are D-010 Open 1-6.

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
