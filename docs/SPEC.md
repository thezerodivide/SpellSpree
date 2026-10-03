# SpellSpree — Specification

What the system must do (Development Protocol §1). This document is the
authoritative source of truth for requirements. Status tags:

- **AGREED** — explicitly approved by the developer.
- **INHERITED** — behavior of the original v1.4 that the baseline carries
  forward. Not yet reviewed or approved as a requirement. Do not treat as agreed.

## 1. Purpose

A MacroQuest Lua script for Project Triune that buys spell and song scrolls from
vendors and scribes them. *(INHERITED, from the original header.)*

## 2. Agreed requirements

- ~~**S-1 (AGREED, D-001 R1).** The scan makes a pass over the merchant list,
  closes and reopens the same vendor, and makes another pass, continuing until no
  spells are found available for purchase on the vendor.~~ **SUPERSEDED by S-6 (D-017,
  2026-10-03).**
- **S-2 (AGREED, D-001 R2).** The multi-pass change must not lose anything the
  original does.
- **S-3 (AGREED, D-004 R10/R11).** The script writes a log file, verbose by
  default in test builds, under the MacroQuest logs directory
  (`spellspree/spellspree_<server>_<character>.log`). The log must let another
  developer reconstruct, without watching the run: build identity, state
  transitions, every command sent to the game with its reason, the observations
  decisions were based on, retry counts and reasons, unexpected transitions,
  failures and why, and the final outcome; and it must say plainly where MQ
  cannot prove an action succeeded. A logging failure must not change what the
  script does. *(Exact file location, rotation, line format and levels are
  implementation detail recorded in D-004, not requirements.)*
- **S-5 (AGREED, D-013 R20-R24; not yet built).** The tier boxes are the level ranges 1-25,
  26-50, 51-60 and 61-65. Selecting a range buys only spells whose `Lvl` is in that range.
  Vendors: 1-25 and 61-65 from the 1-25 vendor (opened once if both are selected), 26-50 from
  the 26-50 vendor, 51-60 from the 51-60 vendor. ~~The 61-70 box is removed.~~ The 61-70 box is not offered and its vendor entries stay in
  the source **commented out, not deleted**, for if the server raises the maximum level (D-013
  addendum, R23a). The 71-80 vendor is out of scope. This supersedes inherited item I-1's tier handling.
- **S-6 (AGREED, D-017; built as 1.6.0-test.3, awaiting a live run).** When a vendor is open the script waits for its visible usable list
  to settle (row count unchanged for 8 polls of 250 ms; at most 15 s, else the vendor is skipped and the
  reason logged), builds a list of its `Spell:` / `Song:` rows once, and buys each name at most once: it
  finds the row by exact name, selects it, verifies the selected name immediately before Buy (up to 3
  selection attempts, never re-clicking Buy), then buys and scribes with the existing logic. There is no
  reopen and no repeat pass. A row that is gone at lookup is skipped and logged. Every built-list entry
  ends with exactly one logged outcome, and a log-only final scan reports new scrolls and lingering rows.
- **S-4 (AGREED, D-003 R9).** Process requirement: before any build is presented
  for manual testing, its logging is reviewed against what that test needs to
  show (see `WORKING_AGREEMENT.md` P-1).

## 3. Inherited behavior (unreviewed)

Described from the baseline source. Each item awaits approval or revision before
it is promoted to a requirement.

- **I-1.** Two entry points: *Shopping Spree* in Plane of Knowledge (tick
  class/tier, it paths to each vendor and works it) and *Buy From Open Vendor* in
  the Bazaar (user opens the vendor; class/tier boxes are ignored).
- **I-2.** Buys items named `Spell: <name>` or `Song: <name>` and no others.
- **I-3.** Requires the merchant's "usable items only" filter on; refuses to
  start otherwise.
- **I-4.** Before each purchase, finds the first free inventory slot (top-level
  slot before bag slots) and uses it as the expected landing spot; stops if none.
- **I-5.** Confirms the purchase by money on hand dropping, locates where the
  scroll landed, right-clicks it to scribe, handles quantity and scribe-confirm
  windows, retries scribing up to 20 times, then waits for the cursor to clear.
- **I-6.** A purchase that stacks onto an existing copy is counted as bought and
  is **not** scribed.
- **I-7.** Stops (or, with "stop when out of money" off, skips) when a spell
  cannot be afforded; stops on a full inventory, an unexpected item on the
  cursor, or a scribe that never completes.
- **I-8.** Refuses to right-click a landed item that is not named like a scroll.
- **I-9.** Spree-level aborts: cursor problems, out of money, full inventory,
  scribe failure end the whole spree; other failures move to the next vendor.
- **I-10.** Stop button halts between steps.

## 4. Open requirement questions

See `PROJECT_LEDGER.md`, Open implementation details. None are decided here.
