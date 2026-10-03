# SpellSpree — What the simulation mock models, and how we know

`test/mock_mq.lua` is a **model** of MacroQuest and the EverQuest vendor window. It is not the game. A passing simulation says
the script does what a decision says *against this model*. This table (decision log D-024, guardrail 6) records, for each thing
the mock does, whether it comes from live evidence, from MacroQuest's source, or from the AI's assumption, so a reader can see
how far a passing test can be trusted.

Classes:
- **LIVE** — observed in a live log or screenshot supplied by the developer (evidence files in `docs/evidence/`).
- **SOURCE** — read directly from MacroQuest source (file and line in the decision log addenda).
- **ASSUMED** — the AI's model; never observed, or taken from a comment in the original script, not from our logs.
- **DIFFERS** — known to differ from the live client; the mock is simpler or wrong in this respect on purpose or by omission.

Maintenance rule: when the mock gains a behavior, add a row here in the same commit. When live evidence confirms or contradicts
an ASSUMED row, change its class and cite the evidence.

| # | Mock behavior | Class | Evidence / note |
|---|---|---|---|
| 1 | The vendor list has 8 columns: icon, name, Qty, platinum, gold, silver, copper, Lvl; `List('row,col')` returns the cell text | LIVE | D-012 addendum (screenshot of the window header); spike probe log |
| 2 | An exact-name lookup (`List('=name,2')`) returns the first row with that name; a missing name returns nothing | LIVE | spike probe, D-010 addendum 3 |
| 3 | A lookup **without** `=` matches by prefix | DIFFERS | live matches **substrings** (a prefix and an inner fragment both matched). The script always uses the exact form, so no test depends on this |
| 4 | `ItemList.Items()` is the visible row count; a row number past the count returns nothing | LIVE | probe and watch logs (row 168 unreadable when the count read 168 during a removal) |
| 5 | `Merchant.Items` / `Merchant.Item(n)` is the vendor's full, unfiltered stock | LIVE (set), DIFFERS (order) | probe: 182 vs 168 visible, in a different order; the mock keeps the same order. The script does not use it |
| 6 | `Merchant.SelectItem(name)` selects by name at once | LIVE | probe. The script does not use it |
| 7 | `/notify ... ItemList listselect N` selects visible row N and `Merchant.SelectedItem` reads it back at once | LIVE | 137/137 selections verified on the first attempt (D-017 addendum 2) |
| 8 | Clicking Buy deducts the price immediately and puts the scroll in the first free bag slot | LIVE (outcome), DIFFERS (timing) | 137/137 paid; live payment often took several polls (only 21 of 137 on the first) |
| 9 | The quantity window never opens | DIFFERS | live: it opened for 136 of 137 purchases |
| 10 | No scribe-confirmation window ever opens | LIVE | 0 of 137 live |
| 11 | Right-clicking a scroll removes it and records the spell as known | LIVE | scribes took one attempt, once two (`Spell: Resolution`) |
| 12 | `scribeRejectFirst`: the first N scribe clicks are ignored | LIVE (occurs), ASSUMED (count) | the original author's comment says three rejections in a row; we saw one second attempt |
| 13 | Scribed rows leave the visible list: never / at once (`liveRefresh`) / after N ms (`staleMs`) | ASSUMED (shape) of a LIVE-confirmed variability | live: about 10 s in the one-spell watch, in batches in the old multi-pass run, all at once (Thiran) or not at all (Delin) in the `1.6.0-test.3` run |
| 14 | Closing and reopening a vendor rebuilds the visible list without already-scribed spells | LIVE | developer statement; the second spree found no scrolls left |
| 15 | `partialAtOpen`: the count is small, then jumps to the full list | LIVE (occurs), ASSUMED (shape) | 13 then 104 within 1.63 s; 96 then 172 within about 0.57 s. Live shape (one jump or several) is not known |
| 16 | `neverSettles`: the count alternates every poll | ASSUMED | never observed |
| 17 | Rows vanish or appear at set times (`events`) | LIVE (occurs), ASSUMED (timing) | the watch run: 9 rows left in 180 s, none arrived; Thiran had 84 then 85 non-scroll rows |
| 18 | `misselect`: a click selects a different row | ASSUMED | never observed in our logs; the original script's comment only |
| 19 | `driftOnce`: the selection moves shortly after it is made | ASSUMED | never observed |
| 20 | `reorderAfterBuy`: the list rotates after each buy | ASSUMED | live showed rows leaving, not items trading places (D-001 addendum 3). A stress model, not an observation |
| 21 | Duplicate names in the list | ASSUMED | the probes found none |
| 22 | `stackOnExisting`: a bought scroll stacks onto an existing copy | ASSUMED | the original author says it happens; never seen in our logs |
| 23 | The vendor's price tell | DIFFERS | the mock fires no chat events, so no price quote is ever on file; live: a tell for every item |
| 24 | Money is in copper, split into pp/gp/sp/cp for the TLOs; default prices are 100 copper | LIVE (split), DIFFERS (scale) | live prices run from copper to hundreds of platinum |
| 25 | Inventory: bag 1 is open with 10 slots; packs 2-10 hold loose non-container items; a scroll lands in the first free bag-1 slot | ASSUMED / DIFFERS | live: scrolls landed in a top-level slot (`main inventory slot 7`); the mock never exercises that path |
| 26 | `/nav id` completes instantly; `/target npc "=name"` targets a spawn that exists; `/click right target` opens its merchant | LIVE (outcome), DIFFERS (timing) | live navigation took 1-30 s |
| 27 | A vendor with no rows at all returns count 0 | LIVE | Vicar Diarin's empty list (screenshot) |
| 28 | The Inventory window reports the class abbreviations (`classes`); the usable-only button reads checked | LIVE (consistent) | class detection and the filter check worked live |
| 29 | `MacroQuest.Path('logs')` is absolute; server and character names are readable | LIVE | D-004 addendum 2 |
| 30 | The ImGui frame is drawn on every `mq.delay`; a button or checkbox is "clicked" once by its label | ASSUMED | a driver for the tests, not a model of ImGui |
| 31 | Simulated time advances only when the script calls `mq.delay` | ASSUMED | |
| 32 | The cursor is always empty | ASSUMED | live: empty throughout the runs read so far |
| 33 | `selectDelay`: a click on a row takes effect only after a set time, the selection stays where it was meanwhile, and a late landing replaces whatever is selected at that moment | ASSUMED | never observed live; every live selection checked so far was already in place by the first read (the logs show the selection check passing at the first poll). A stress model for the adverse case (D-024 Open, approved by the developer 2026-10-03) |
| 34 | `levelText`: column 8 returns raw text chosen by the test (padded, blank, `--`, words, decimals, negatives); `false` makes the cell missing (the TLO returns nil for a row that exists) | ASSUMED | the live logs show only numbers (a padded number, and `--` for non-spell rows), so no blank or missing Lvl cell for a spell was ever observed (D-025) |

How to read a passing test: rows marked DIFFERS or ASSUMED are where a pass proves least. Live runs remain the only evidence for
those.
