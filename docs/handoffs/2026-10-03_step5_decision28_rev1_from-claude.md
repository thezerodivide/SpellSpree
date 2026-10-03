HANDOFF: Step 5 / Decision 28 / Revision 1 / From Claude / 2026-10-03

**Subject:** Step 5 of the SpellSpree work: the log file must follow the character that is playing (decision log D-028). This is a design proposal. Nothing is built and no test is written yet. Per D-027, once you and I reach consensus on every item the build starts, using the TDD process of D-024 with your guardrails. Please review each item (agree, or disagree with the reason). If you need context I have not given, ask questions and give no verdicts.

## 1. Context (observed facts, each with its source)
- The log file name is built from the server and the character name: `spellspree_<server>_<character>.log` (`logResolvePath`). The path is resolved on the first write and then kept in `LOG.path` for the rest of the session; it is never resolved again.
- Live evidence (the developer's test of `1.6.0-test.4`, 2026-10-03): the script was started as Benedict at 14:45 (startup line `character=Benedict`). The developer then switched to another character, Ididnotbuffher, in the same client and ran an Enchanter run. The script kept running: the elapsed-time column is continuous (+2,451,815 ms at the end of that run, no new startup lines). The whole Enchanter run (15:11:30 to 15:25:50, 6,044 lines) is therefore in `spellspree_multiclass_Benedict.log`, and no file exists for Ididnotbuffher. The developer first read this as "logging failed completely"; the data was all there, under the wrong name.
- Consequence: after a character switch in the same session, nothing in the log says which character a run belonged to. The run was attributed only by the developer's memory and by an inference from the spells (a Shaman spell was "bought and scribed" on the first character and still offered to the second).
- The developer's decision: "that is a real gap, that needs fixed."
- Existing rules that bound the design: logging must never change what the script does (every write is inside `pcall`; the first failure turns file logging off and says so once); the Development Protocol logging standard (P-1: the log must carry what a reviewer needs without a rerun); rotation checks run every 100 writes.

## 2. Proposed design items (each is a separate decision)

**A. Identity is re-read at run boundaries.** A function `logSyncIdentity()` reads the server and the character name (the same two reads `logResolvePath` uses) and compares them with the identity the current file was resolved for. It is called (1) in the main loop immediately before a run is dispatched (`runShoppingSpree` and `runBazaarShop`), and (2) in the button handlers just before the `User pressed Run Shopping Spree` / `User pressed Buy From Open Vendor` line is written, so that line lands in the right file. The identity is not checked on every log write (a run writes thousands of lines; two TLO reads each would be wasted).

**B. When the identity changed.** In order: (1) one line goes to the OLD file: `identity changed: <server>/<old> -> <server>/<new>; continuing in <new path>`; (2) `LOG.path` is cleared and `LOG.writes` reset to 0, so the next write resolves the new path and the rotation check runs on the new file; (3) the NEW file starts with a session header: the same observations the startup block writes (build, source, path resolution, log file, environment: zone, character, server, class, merchantOpen; the known-limits statement), marked `continued session` and giving the load time offset (the elapsed-time column continues from the script's load). The startup block becomes a function used both at load and here, so the two cannot drift apart. (4) One INFO line, written to the window and the file, says `Logging to a new file for <character>: <path>`.

**C. Unreadable identity.** If the server or the character reads as unavailable at a sync, the current file is kept and one OBS line records that the identity was unreadable. The script never switches to a file named for an unreadable value. Startup behavior is unchanged. If the first resolution at load used an unreadable value, a later readable identity does switch.

**D. Attribution inside the run.** The existing `run start` observation line gains `character=` and `server=`, so a run can be attributed from its own lines even if a file were ever mis-named.

**E. Containment.** `logSyncIdentity` runs inside `pcall`. A failure never stops or alters a run. A failure to create the new path uses the existing `logFail` (file logging off, one window notice). A switch in the middle of a run is not handled: the identity is checked at boundaries only, and the next boundary notes the change.

**F. What does not change.** Purchases, the ledger, the window log (apart from the one line in B4), rotation size and cadence, and the log line format. The existing log files are not rewritten; the Enchanter run of 2026-10-03 stays in the Benedict file, with a note in the decision log saying it belongs to Ididnotbuffher.

**G. Alternative considered and not proposed.** Put the character name into every log line instead of switching files. It keeps one file but makes every line longer, changes the format the existing tests parse, and still leaves two characters' runs interleaved in one file named for the first. Switching files matches how the developer reads the logs (one file per character).

**H. Delivery.** I propose it ships as `1.6.0-test.5`, tagged after the pre-handoff log review (P-1, P-3). Whether `1.6.0` includes it is the developer's call; nothing here creates `1.6.0`.

**I. TDD plan (D-024, P-9), in order.**
1. Mock additions (behavior-neutral for existing tests): the character name and the server can change at a set simulated time; the Run button can be pressed a second time at a set time. Each gets a row in `docs/MOCK_MODEL.md`, classified ASSUMED. The live evidence above shows the script surviving a character switch, but the character name read after the switch was never logged, so the new name's exact reads are not observed.
2. Write the tests first, each labelled REQ/CHAR and NEW/REGRESSION with the expected pass or fail at each stage written beforehand (D-025 F''). Tests: a switch between two runs puts the second run's lines (its range lines, ledger, outcome line) in the new character's file and none in the old; the old file ends with the `identity changed` line and the new file starts with the session header and the `continued session` marker; the `User pressed` line of the second run is in the new file; no switch when the identity is unchanged (one file, no extra header); an unreadable identity keeps the file and logs the OBS line; a switch to the same character name on a different server also switches; the rotation counter is reset (the new file's first write runs the rotation check); `run start` carries the character and server; a logging failure on the new path leaves the run's purchases unchanged; existing log-format tests still pass.
3. Unit tests through the hook for the pure parts (building the file name from server and character; deciding whether an identity differs), exported and added to the wrapper's expected exports with the missing-export red run first.
4. Targeted mutations (guardrail 7), expected failing tests written before the run: never syncing; syncing at run start only (the `User pressed` line misfiled); not clearing `LOG.path`; not resetting `LOG.writes`; not writing the `identity changed` line; switching on an unreadable identity; the header not marked `continued session`.
5. The Step 1, 2, 3, logging and unit suites still pass; the source difference is limited to the logging code and the two call sites.
6. Approval evidence is three statements (guardrail 8): what was tested, what passed, what still needs a live run (the developer switches characters in one client and confirms two files). Simulation and live stay separate.

## 3. Points where I would like your judgment
1. Items A: are the two check points (before a run is dispatched, and at the run buttons) enough, or is there another path that writes a run's lines under an old identity (for example the Stop button, or Re-detect)?
2. Item C: refusing to switch on an unreadable identity keeps a possibly wrong file for a while. Is that the better failure, compared with writing to a file named for an unreadable value?
3. Item E: handling a switch only at run boundaries leaves a mid-run switch misfiled. Is that acceptable, given a character swap mid-run would also break the run itself?
4. Does the test plan in I cover the requirement, or is a requirement untested? Is there an adverse scenario I should keep that I have not named?

## 4. What I am asking of you
Please review A to I: for each, agree, or disagree with the reason, and answer the four points in section 3.
