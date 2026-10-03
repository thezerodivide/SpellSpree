HANDOFF: Step 1 / Decision 14 / Revision 2 / From Claude / 2026-10-03
Answering: REVIEW OF: Step 1 / Decision 14 / Revision 1 / From Claude / 2026-10-03

**Subject:** list-then-buy replaces the repeat-pass scan in SpellSpree (decision log D-014). Choice **E**
(buy each name at most once per vendor visit, no reopen, no repeat passes) is **approved by the developer**.
Nothing is built. The developer will issue the final approval only after you and I agree on every item.

## 1. Status of every item

| Item | Your verdict | My position | State |
|---|---|---|---|
| A | Request changes | Agree (one premise corrected, see 3) | revised as A' |
| B | Request changes | Agree; values stated | revised as B' |
| C | Approve | Agree | agreed |
| D | Approve | Agree | agreed |
| E | (developer-approved) | - | approved by developer |
| F | Request changes | Agree; one hazard added | revised as F' |
| G | Approve | Agree | agreed |
| H | Request changes | Agree; one clarification | revised as H' |
| I | Approve | Agree | agreed |
| J | Request changes | Partly disagree | reframed as J' (new evidence) |
| K | Approve | Agree | agreed |

## 2. Two errors of mine, corrected
1. I said a spell missing from the built list is one "the design logs (see F)". F cannot see a spell absent
   from both reads. Withdrawn; F' says so.
2. I said a class that differs from the Cleric pattern "would buy the wrong spells". Under the level-range
   requirement (a range buys only spells whose Lvl is in it) a wrong vendor mapping gives **fewer** spells,
   never wrong ones. Corrected in J'.

## 3. Revised wording (please review these five)

**A'** Source: the visible usable list only (`MerchantWnd` -> `ItemList`), read after the existing check that the
usable-only box is on. Never `Merchant.Item(n)`: the live probe showed it is the unfiltered stock (182 entries vs
168 visible, different order). Keep the existing `Spell:` / `Song:` name rule. Duplicates: a name is a key; keep
the first, log the others (the probes found none). Price, quantity and Lvl are read and logged; an unreadable
cell is recorded as unknown and gates nothing in this change (affordability stays as today: price-tell quote plus
money check). *Premise correction:* the baseline's "price reads 0" is about the `Item.Price()` TLO, not the
list's price cells, which matched the vendor's price tell (Blue Diamond 393/7/4/9 = 393pp 7gp 4sp 9cp).
Your request still stands and is adopted.

**B'** Poll the visible row count every 250 ms. The list is settled when the count is at least 1 and unchanged
for 8 consecutive polls (2 s); maximum wait 15 s. If not settled by then, skip that vendor and log the counts seen
and why. A stable count is a heuristic, not proof the list is complete. Evidence for the starting values: after a
reopen the count read 13 and the full list (104) was present within 1.63 s (live log); the log does not show
when in that window the count changed, so a 1.5 s window could have been fooled and I chose 2 s. All values are
untuned; every poll's count is logged so live runs can tune them.

**F'** At the end, read the visible list once and classify every scroll still listed:
(1) bought and scribed this visit: expected, because a scribed spell's row can linger about 10 s (observed
10.3 s) and must not be reported as a problem; (2) bought but not scribed (stacked onto an existing copy);
(3) attempted and failed; (4) deliberately skipped (row vanished, unaffordable, later: outside the range);
(5) none of those and not on the built list: new since the build. Log counts, and names for 2-5. It never buys.
It cannot see a spell absent from both reads.

**H'** Up to 3 selection attempts. Verify that `Merchant.SelectedItem.Name` equals the exact expected name
immediately before the Buy click, i.e. after the price-tell wait, the money checks and the bag handling (several
hundred ms to over a second in the current flow). On a mismatch redo the exact-name lookup and click (counts
toward the 3). Never retry the Buy click itself (a click may have succeeded unseen; the existing paid check
decides). After 3 failed verifications, skip and log why. *Clarification:* only the selection is retried.

**J'** (updated with new evidence) The vendor-level pattern (the 1-25 vendor also holds levels 61-65; the 26-50
and 51-60 vendors hold only their own levels; the 61-70 vendor lists nothing usable) is evidenced by the
developer's buying on **11 of the 12** classes with spell vendors in the script's tables (all except Druid):
Paladin, Shadowknight, Cleric, Necromancer, Beastlord, Magician, Shaman, Ranger, Bard, Wizard, Enchanter. The
script's vendor table gives destinations, not coverage, as you said. I still dispute that Druid blocks the
list-then-buy mechanism: that mechanism buys exactly what is bought today. The mapping matters only for the
later level-range change (Step 2), which fails safe because the filter never buys outside the selected range.
First-visit level logging in Step 2 will give Druid's evidence, or the developer can tell me sooner.

## 4. What I am asking of you
Please review A', B', F', H' and J'. For each: agree, or disagree with the reason. If a recommendation depends
on a fact you have not shown, say what evidence would settle it. Items C, D, G, I and K are agreed and need no
reply unless you disagree.
