HANDOFF: Step 2 / Decision 21 / Revision 1 / From Claude / 2026-10-03

**Subject:** Step 2 of the SpellSpree 1.6.0 release: every 61-70 selection uses that class's 1-25 vendor (decision log D-021). Nothing is built. The developer approves each item below separately after you and I agree; your review is requested item by item (agree, or disagree with the reason).

## 1. Context (confirmed facts and agreed requirements)
- 1.6.0 = Step 1 (list-then-buy, done and accepted as a step) + Step 2 (this) + Step 3 (purchases bounded by the selected level range, designed separately). Developer, D-020 R31.
- The script's tier boxes are 1-25, 26-50, 51-60 and 61-70, one set per class. The UI stays unchanged (D-019 R29).
- Developer-confirmed from buying on 11 of 12 spell classes and accepted for all 12: the 1-25 vendor also sells the level 61-65 spells, the 26-50 and 51-60 vendors sell only their own levels, and the 61-70 vendor lists nothing usable (its window is empty with the usable-only box ticked).
- Developer, R34: each selected range is its own visit. With all four ticked the flow is vendor 1, vendor 2, vendor 3, then vendor 1 again; the second visit to vendor 1 is accepted.
- Developer: keep all the old 61-70 code, commented out, in case the server changes where the spells are (D-020 addendum 2). Bazaar is a separate later pass and is untouched.
- Code today: `collectSelectedVendors()` loops classes then tiers and makes one visit per ticked tier, with a single lookup line, `VENDOR_DATA[className][tier]`, to choose the vendor. `VENDOR_DATA` has four names per class (one per tier).

## 2. Proposed design items (each is a separate decision)

**A. A mapping table sits between the ticked tier and the vendor.** `TIER_VENDOR = { ['1-25']='1-25', ['26-50']='26-50', ['51-60']='51-60', ['61-70']='1-25' }`, and `collectSelectedVendors` looks the vendor up as `VENDOR_DATA[className][TIER_VENDOR[tier]]`. A tier with no mapping entry is skipped, as a missing vendor name is today.

**B. The old 61-70 code is commented out in place, not deleted.** In each class line of `VENDOR_DATA` the `['61-70'] = '<name>'` entry is wrapped in an inline block comment (`--[[ ... ]]`) so the name stays where it was. The old lookup line is kept as a comment beside the new one, and the old `['61-70']='61-70'` mapping entry is kept as a comment in `TIER_VENDOR`, with a short note saying why and how to restore them (remove the comment markers and change the mapping entry). The `'61-70'` tier stays in `TIERS`, so the UI is unchanged.

**C. One visit per ticked tier; visits are not merged (R34).** Order stays class, then tier. All four ticked gives vendor 1, vendor 2, vendor 3, vendor 1. The second visit to a vendor goes through the same navigate, target and open steps as any visit (a second run over the same vendors worked live).

**D. The visit label says when the vendor tier differs from the ticked tier.** For example `--- Vendor 4/4: Vicar Ceraen (Cleric 61-70, bought from the 1-25 vendor) ---`. Other visits read as today.

**E. Nothing else changes in Step 2.** Until Step 3 adds the level bound, a 61-70 visit buys whatever the 1-25 vendor still lists, exactly as a 1-25 visit does. The buy, scribe, ledger and logging code, the UI and the Bazaar path are untouched.

**F. Testing and handoff.** Simulation tests for the visit order and labels (all four ticked; only 61-70 ticked; 1-25 plus 61-70), a check that the old 61-70 vendor is never targeted, a check that the 12 old 61-70 names are still in the source inside comment markers, and mutation checks (for example, reverting the mapping must fail the visit-order test). Step 2 is committed and simulation-tested but is not handed over for a live test by itself, because a 61-70 visit would re-buy the 1-25 vendor's list until Step 3. Steps 2 and 3 are handed over together as `1.6.0-test.4`, unless the developer asks for a live test of Step 2 alone.

## 3. Points where I would like your judgment
1. Item B keeps the old code as comments (the developer's instruction). Is inline `--[[ ]]` the right form, or would you rather the old names move to a separate commented block? My reason for inline: each name stays on its class line, so restoring is local and nothing can drift out of sync.
2. Item F defers the live test of Step 2 to the Step 3 handoff. Do you see a reason to live-test Step 2 alone?
3. Anything in A to F that conflicts with the agreed requirements in section 1.

## 4. What I am asking of you
Please review A to F: for each, agree, or disagree with the reason. If a recommendation depends on a fact I have not shown, say what evidence would settle it.
