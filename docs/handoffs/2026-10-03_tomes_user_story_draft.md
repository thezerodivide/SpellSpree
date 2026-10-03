*(Archived by Claude from text the developer pasted, 2026-10-03, with the screenshot saved as `docs/evidence/2026-10-03_tome_vendor_list.png`. It is a user-story draft; it authorizes neither implementation nor the investigations.)*

### Discipline tome support in SpellSpree

- **Status:** Draft. UI and release scope are developer-directed. Already-known discipline handling and cross-vendor duplicate handling remain open.
- **Story:** As a SpellSpree user, I want to select discipline-tome shopping for my classes, so SpellSpree can visit their Plane of Knowledge vendors, purchase tomes, and learn the disciplines.
- **Why:** SpellSpree supports spell scrolls and bard songs. Adding discipline tomes brings discipline acquisition into the same shopping workflow.

### Confirmed requirements

1. Each class with tome vendors has a separate checkbox labeled **Discipline Tomes**, within the existing class UI alongside its level-range checkboxes.
2. Classes with tome vendors must appear in that UI, including Berserker, Monk, Rogue, and Warrior.
3. The **Discipline Tomes** selection is independent of the spell-level selections. **Level bounding for tomes is outside this change's scope.**
4. Tome support applies **only to Plane of Knowledge for this release**. Bazaar tome support is outside scope.
5. Selecting Berserker tome shopping visits **both** listed Berserker vendors.
6. Each listed tome receives at most one purchase attempt per vendor visit. Handling duplicates across different vendors remains an open decision.
7. Purchased tomes are right-clicked to learn their disciplines.
8. Tome decisions and outcomes are logged, including purchases, learning results, skips, failures, and stop reasons.
9. Existing spell and song purchasing behavior is preserved.

### Vendor list supplied by Shane

| Class | Vendor |
|---|---|
| Bard | Larquin Julinok |
| Beastlord | Tana Clawguard |
| Berserker | Kurlond Axebringer |
| Berserker | Gaddi Buruca |
| Monk | Beorobin Amondson |
| Paladin | Ulin Velnik |
| Ranger | Keshyk Wardorn |
| Rogue | Blane Darkblade |
| Shadowknight | Zhao V’karin |
| Warrior | Heldin Swordbreaker |

### Observed and reported facts

- Shane reports that discipline-tome names begin with **Tome**. The supplied screenshot shows names beginning with **Tome of**.
- Shane confirms that the merchant's usable-only filter **does not hide tomes for already-known disciplines**.
- Shane confirms that right-clicking a purchased tome learns the discipline.
- The vendor list includes a **Lvl** column with numeric levels for the pictured tomes. Tome level filtering is nevertheless outside scope.
- Zhao's exact name punctuation cannot be determined visually. The supplied comparison notes a database spelling of ``Zhao V`karin``; the exact in-game lookup name remains unverified.

### Acceptance criteria

1. Each listed class has a **Discipline Tomes** checkbox in its class UI.
2. Tome shopping can be selected without selecting a spell-level range.
3. Selecting tome shopping visits that class's listed vendor; Berserker visits both listed vendors.
4. Tome identification uses a verified name rule and does not purchase unrelated merchandise.
5. Spell-level checkbox selections do not impose level bounds on tome purchases.
6. No listed tome receives more than one purchase attempt during a single vendor visit.
7. Purchased tomes are right-clicked, and the script records whether learning completed using a verified completion check.
8. Every tome on the built purchase list receives one recorded outcome, including entries left unattempted when a run stops.
9. Existing spell and song shopping behavior remains unchanged.
10. The Bazaar path remains unchanged.
11. Tests distinguish simulated evidence from live evidence, and document any unverified assumptions.

Acceptance criteria for already-known disciplines and cross-vendor duplicates will be added after those decisions are resolved.

### Open decisions and investigations

**1. Already-known disciplines**

Determine a reliable way to identify disciplines the character already knows. Present the available options and estimates before deciding whether to skip their tomes.

Estimates should distinguish:

- Investigation needed to establish detection behavior.
- Implementation effort.
- Simulation and live verification effort.

Buying without an already-known check is an option to discuss, not approved behavior.

**2. Duplicates between Berserker vendors**

Propose a spike comparing Kurlond Axebringer's and Gaddi Buruca's inventories to establish whether they sell overlapping tomes.

Use the findings to explain the options, costs, and consequences of duplicate handling across both visits. Visiting both vendors is confirmed; cross-vendor deduplication policy is not yet decided.

**3. Exact vendor lookup**

Verify Zhao's exact in-game name rather than choosing punctuation by appearance.

**4. Technical design**

Establish the exact tome-name matching rule, learning-completion check, visit order relative to spell shopping, and any required changes to class detection or selection handling. These remain implementation-design questions.

### Evidence and authorization

- **Source:** Shane's vendor list, screenshot, and answers in this chat.
- **Not established:** Already-known discipline detection, Berserker inventory overlap, Zhao's exact lookup name, and reliable learning-completion detection.
- **Authorization:** This document is a user-story draft. It does not authorize implementation or the proposed investigations.
- **Supersedes:** The earlier draft of this user story in this chat. It does not supersede existing approved SpellSpree decisions.
