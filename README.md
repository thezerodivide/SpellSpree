# SpellSpree

**Buy and scribe every spell scroll you can use, vendor after vendor, with one click.**

SpellSpree is a [MacroQuest](https://www.macroquest.org/) Lua script for the **Project Triune** EverQuest server. In the Plane of Knowledge it walks to each class spell vendor, buys the spells in the level ranges you picked, scribes them into your spellbook, and moves on to the next vendor. In the Bazaar it does the same for a vendor you open yourself.

**Current version: 1.6.0**

## Credits

- **Original author:** @Heeby, from the Project Triune Discord. Heeby wrote SpellSpree, and the script's name, idea and purchase flow are theirs.
- **Updates after v1.4:** TheZeroDivide ([github.com/thezerodivide](https://github.com/thezerodivide)), who took over development with the original author's permission.

## What you need

- A working MacroQuest install with Lua and ImGui (the same one you use for other Lua scripts on Project Triune).
- **MQ2Nav with a navmesh for the Plane of Knowledge.** The Plane of Knowledge run uses `/nav` to walk to each vendor. (The Bazaar has no navmesh, so there you walk to the vendor yourself.)
- A character whose class has Plane of Knowledge spell vendors: Cleric, Bard, Enchanter, Wizard, Shadowknight, Necromancer, Shaman, Druid, Magician, Ranger, Paladin or Beastlord. Characters with several classes (like Project Triune's multiclass characters) see every class they have.
- Enough platinum, and free inventory space. Scrolls land in your bags before they are scribed.
- Windows. The script creates its log folder with a Windows command.

## Install

1. Copy `spellspree.lua` into the `lua` folder of your MacroQuest install (for example `C:\Users\Public\MacroQuest\lua\`).
2. In game, type:

   ```
   /lua run spellspree
   ```

   A window titled **SpellSpree v1.6.0** opens. To close the script, close the window or type `/lua stop spellspree`.

## Quick start: the Plane of Knowledge

1. Stand anywhere in the Plane of Knowledge. The window says **Plane of Knowledge (1-70)** and lists the classes it detected on your character. If it missed one, press **Re-detect**.
2. Tick what you want to buy:
   - The box next to a class name ticks all four level ranges for that class.
   - Click the little arrow next to a class to choose individual ranges: **1-25**, **26-50**, **51-60**, **61-70**.
3. The big button shows how many vendor visits you chose: **Run Shopping Spree (N selected)**. Press it.
4. SpellSpree walks to each vendor in turn, opens their window, buys the spells that match, scribes them, closes the window and goes on to the next. A line in the log tells you what happened at every step.
5. The **Stop** button ends the run at the next safe point. When the run finishes, the log shows what was bought and what was skipped.

While it runs, keep the mouse out of the SpellSpree window. If it is over the window, the script waits and tells you to move it into the game world, because a click on the window does not reach the game.

## Level ranges: what each box really buys

Each ticked range is its own visit, and it buys **only spells whose level is inside that range** (both ends included). A spell outside the range is never selected or clicked. It is listed in the log as "deliberately skipped", with the reason.

Why this matters: your spellbook only holds so many spells. Ticking only the ranges you want lets you decide which spells you buy.

One thing to know about **61-70**: the spells for levels 61 to 65 are sold by each class's **1-25 vendor**, not by a separate 61-70 vendor. So ticking **61-70** sends SpellSpree to the 1-25 vendor, and it buys only the level 61-70 spells there. If you tick both 1-25 and 61-70, the same vendor is visited twice, once for each range. That is normal.

## The Bazaar

There is no navmesh in the Bazaar, so nothing is automatic up to the merchant.

1. Walk to the spell vendor and open their merchant window yourself.
2. Press **Buy From Open Vendor**.

SpellSpree buys **every** spell scroll that vendor will sell you. The class and range boxes are ignored, and there is no level limit, because you already chose the vendor by opening it. Make sure your spellbook has room.

## Options

- **Stop when out of money (uncheck to skip and keep shopping).** On by default. With it on, the run stops when it cannot afford the next spell. With it off, it skips what it cannot afford and carries on.
- **Re-detect** looks at your character's classes again (use it after switching characters or classes).
- **Clear Log** clears the log shown in the window. It does not touch the log file.

## What it does with each vendor

For each vendor it:

1. Makes sure the merchant window's "show only items I can use" filter is on.
2. Waits for the vendor's list to settle, then reads it **once** into a list of the spell scrolls it will consider (it also handles bard "Song:" scrolls).
3. Skips every spell outside the level range you picked, and records why.
4. Buys each remaining spell exactly once: it finds the spell by its exact name, selects it, checks that the right item is selected just before pressing Buy, confirms the quantity window if one opens, and waits until your money actually drops.
5. Scribes the scroll where it landed, and confirms the scribe prompt if one opens.
6. Closes the vendor and writes a summary for that visit.

Every spell on the list ends with exactly one recorded outcome: bought and scribed, bought but not scribed, attempted but not bought, deliberately skipped, or not attempted because the run stopped.

It stops cleanly, and tells you why, if your money runs out (when that option is on), your inventory fills up, something sticks on your cursor, the merchant window closes unexpectedly, or you press Stop.

Because scribed spells disappear from the vendor's usable list, running a vendor again after it has been bought simply finds nothing new.

## Before you run it

- Have free bag space. Leave the bags open once they pop up. Closing one mid-run can make a purchase look like it failed.
- Make sure your spellbook has room for what you ticked. SpellSpree does not choose spells for you: that is what the range boxes are for.
- Don't use the vendor or move items while it runs.

## The log file

SpellSpree writes a detailed log for every run, so a problem can be diagnosed afterwards without repeating it.

- **Where:** your MacroQuest `Logs` folder, in a `spellspree` subfolder: `spellspree_<server>_<character>.log`.
- **It follows your character.** If you switch characters while the script keeps running, the log switches to a new file for the new character, and the old file records the change.
- **What is in it:** the build version, every command it sent and why, what it read from the game, the list it built for each vendor, one outcome per spell, and a summary per visit.
- **Size:** when a log passes 4 MB it is renamed to `.old` and a fresh file starts.

If something goes wrong, send the log file when you ask for help.

## Troubleshooting

| What you see | What it means |
|---|---|
| `No vendors selected -- check at least one class/tier box first.` | Nothing is ticked. Tick at least one box. |
| `No free inventory space anywhere -- make room before running this.` | Free a slot and run it again. |
| `Mouse is over the SpellSpree window -- move it into the game world so the click actually registers.` | Move the mouse off the SpellSpree window. |
| `No merchant window open -- walk up to the spell vendor and open it first.` | Bazaar button: open the vendor's window first. |
| `Not in the Bazaar -- this button is for working a merchant you opened there yourself.` | The Bazaar button only works in the Bazaar. In the Plane of Knowledge, use **Run Shopping Spree**. |
| `"Usable items only" not confirmed on` | The script could not confirm the vendor window's usable-items filter. Turn that checkbox on yourself and try again. |
| `The vendor list did not settle ...` | The vendor's list kept changing. That vendor was skipped rather than buying from a possibly partial list. Run it again. |
| `Invalid level range ...` or `No level range ...` | A range was not valid, so nothing was bought. This should not happen in normal use; send the log. |
| `File logging is OFF: ...` | The log file could not be written. The run itself is unaffected; the window log still works. |

## Known limits

- Plane of Knowledge vendors are hand-verified for levels 1 to 70. Levels above 70 are not covered.
- The Bazaar run has no level limit and no navigation.
- A level 1-25 run on a character that already has those spells buys nothing, and the log says so.
- The vendor names are kept in the script. If the server moves a vendor, edit the vendor table at the top of `spellspree.lua`.

## For developers

- The decisions behind the project are in [`docs/`](docs/): the decision log, the project ledger, the specification and the working agreement.
- The test suites run against a model of MacroQuest, not the live client, using LuaJIT: `luajit test/test_units.lua`, `test_step3.lua`, `test_step2.lua`, `test_listthenbuy.lua`, `test_logging.lua`, `test_logswitch.lua`. They show how the script behaves against that model; live runs are the evidence for the real game.
