# SpellSpree 1.6.0 — Release Notes

**Release date:** 2026-10-03
**Compared with:** v1.4 (the last version by the original author, @Heeby)

SpellSpree 1.6.0 changes how spells are found and bought, so it no longer misses spells. It also lets you choose which level ranges to buy, and it writes a detailed log of every run.

From this release on, versions follow [Semantic Versioning](https://semver.org/).

## Highlights

- **No more missed spells.** SpellSpree reads the vendor's list once and buys each spell by its exact name. It no longer scans the list row by row, so the vendor window re-sorting itself mid-purchase can no longer make it skip spells.
- **Level ranges are respected.** Each range you tick (1-25, 26-50, 51-60, 61-70) buys only spells whose level is inside that range. Spells outside it are never touched. Your spellbook has limited room, so you decide what to buy.
- **A log you can read.** Every run writes a detailed log file with the reason for every decision, and every spell ends with one recorded outcome.
- **The log follows your character.** If you switch characters while the script is running, the log switches to a file for the new character.

## What's new since v1.4

### Buying

- **List first, then buy.** When a vendor opens, SpellSpree waits for the list to settle, reads it once, and then buys each spell by looking it up by its exact name. Each spell is bought at most once per visit. There is no reopening the vendor and no repeat passes.
- **Safer purchases.** Just before pressing Buy, it checks that the item selected is the one it means to buy. If the selection moved, it selects the spell again (up to three attempts in all). It never presses Buy a second time for the same spell.
- **Exact-name lookup.** Each spell is found by its exact name, so spells with similar names (such as "Fear" and "Fear of the Dead") are told apart.
- **An unsettled list is not trusted.** If a vendor's list keeps changing, that vendor is skipped with a message instead of buying from a possibly partial list.
- **Invalid ranges are refused.** If a range is not valid (for example, outside levels 1 to 70), that visit is refused with an error and nothing is bought. It is never treated as "no limit".
- **Level ranges (Plane of Knowledge).** Each ticked range is its own visit and buys only spells whose level is inside it (both ends included). A spell whose level cannot be read is not bought. The Bazaar button is unchanged: it buys everything the open vendor sells.
- **61-70 uses the 1-25 vendor.** The server sells the level 61-65 spells at each class's 1-25 vendor, so ticking 61-70 now goes there. The old 61-70 vendor names are kept in the script as comments, in case the server moves those spells. If you tick both 1-25 and 61-70, that vendor is visited twice, once per range.

### Logging

- **A log file for every run,** in your MacroQuest `Logs\spellspree` folder, named `spellspree_<server>_<character>.log`. It records the build version, each command sent and why, what was read from the game, the list built for each vendor, and a summary per visit. Logs over 4 MB are renamed to `.old`.
- **One outcome per spell.** Every spell on a vendor's list ends as one of: bought and scribed; bought but scribe not completed; attempted but not bought; deliberately skipped (with the reason, such as "outside the selected level range 1-25 (Lvl 63)"); not attempted because the run stopped. A count and the names are logged at the end of each visit.
- **The log follows the character.** After a character switch in the same session, the log moves to a new file for the new character. The old file records the change, and the new file starts with a header marked "continued session". Records written between runs follow the character too, and a run stays in one file.
- **The log tells you who ran.** Each run's start line records the character and server.
- **A summary for every visit.** Each visit ends with an outcome line giving that visit's totals (bought, skipped, platinum spent) and the running total for the whole spree.

## Carried over from v1.4

These work as they did in v1.4:
- **Plane of Knowledge run:** tick the classes and ranges, press **Run Shopping Spree**, and it walks to each vendor, opens them, buys, scribes and moves on.
- **Bazaar run:** open the vendor yourself and press **Buy From Open Vendor**.
- Spell scrolls ("Spell:") and bard songs ("Song:") are both handled.
- The merchant's "show only items I can use" filter is turned on and checked.
- It finds the first open inventory slot, handles the quantity window, scribes the scroll and confirms the scribe prompt.
- It stops cleanly, and tells you why, if you run out of money (or skips and continues, if you uncheck the option), your inventory fills up, something sticks on your cursor, the merchant window closes, or you press **Stop**.
- The same window, the same boxes and the same buttons.

## Upgrading

1. Replace `spellspree.lua` in your MacroQuest `lua` folder with the new file.
2. Run it as before: `/lua run spellspree`. The window title shows **SpellSpree v1.6.0**.

Things you may notice:
- **Ticking 1-25 no longer buys the level 61-65 spells** that the 1-25 vendor also sells. Tick 61-70 for those.
- **Old logs stay as they are.** New runs write to the files described above.
- **No settings to migrate.** The only option is the "Stop when out of money" checkbox.

## Known limits

- **Bazaar:** there is no navmesh, so you walk to the vendor and open it yourself. It buys everything the vendor sells and has no level limit. It is unchanged in this release and will get its own update later.
- **Levels:** the Plane of Knowledge vendors are covered for levels 1 to 70. Levels above 70 are not.
- **Vendor names** are hand-verified and kept in the script. If the server moves a vendor, edit the vendor table at the top of `spellspree.lua`.
- **Not exercised in a live run:** stopping partway through a visit, a vendor level cell that is not a number, and switching characters in the middle of a run. These are covered by the project's simulated tests only.

## Testing

- **Live:** full runs on Project Triune with Shaman, Enchanter and Cleric characters, including a character switch in one running client. Every purchase was inside its visit's range, every skipped spell was outside it, no skipped spell was selected, and no spell was bought twice.
- **Simulated:** six test suites run the real script against a model of MacroQuest, including deliberate-fault checks that prove each test can fail. A simulation shows only how the script behaves against the model, so the live runs above are the evidence for the real game.

## Credits

- **Original author:** @Heeby, from the Project Triune Discord.
- **Updates after v1.4:** TheZeroDivide ([github.com/thezerodivide](https://github.com/thezerodivide)).
