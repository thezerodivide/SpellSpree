-- Unit tests for the directly testable pieces of spellspree.lua (decision log D-026; hook design items A and B, wrapper C'').
-- Run from the repo root:  luajit test/test_units.lua
--
-- SIMULATION ONLY. These load the real script with stubs (test/unit.lua) and call individual functions. They say nothing about the
-- live client; the script starting normally with the hook present is a live check (D-026 Delivery).
--
-- Each test is labelled REQ (an approved decision requires the behavior; the decision is cited) or CHAR (characterization: it records
-- what existing code does, with the wording of the code as the only source, so it is a regression net, not a specification).
-- Expected values are written from those sources, never by running the script and pasting its output.
--
-- After the baseline run, each MUTATION breaks the script on purpose; exactly the tests named for it must fail (the sets below were
-- written before the first run).
package.path = 'test/?.lua;' .. package.path
local U = require('unit')

local SCRIPT = os.getenv('SPELLSPREE_SCRIPT') or 'spellspree.lua'   -- the stage-0 red runs use the script as it was before the change under test
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\units'
local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function writeAll(path, s) local f = assert(io.open(path, 'wb')); f:write(s); f:close() end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
mkdir(TMP)
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')

local function eq(got, want, what)
    if got ~= want then error(string.format('%s: got %s, expected %s', what, tostring(got), tostring(want)), 0) end
end
local function fresh(u) u.LOG.disabled = true; u.S.log = {} end
local function logTexts(u) local t = {}; for _, e in ipairs(u.S.log) do t[#t + 1] = e.text end; return t end
local function hasLine(u, plain)
    for _, t in ipairs(logTexts(u)) do if t:find(plain, 1, true) then return true, t end end
    return false
end

-- known-bad scripts for the wrapper's cleanup tests
local BAD = {
    syntax  = { path = TMP .. '\\bad_syntax.lua', text = 'local x = = 1\n', want = 'load failed' },
    initerr = { path = TMP .. '\\bad_init.lua', text = "local mq = require('mq')\nerror('boom before the hook')\n", want = 'boom before the hook' },
    nohook  = { path = TMP .. '\\bad_nohook.lua', text = "local mq = require('mq')\nreturn\n", want = 'did not expose parseClassLine' },
}
for _, b in pairs(BAD) do writeAll(b.path, b.text) end

-- Runs withUnitFn on each bad script and reports every way the process was NOT left as found. Restores state itself afterwards, so
-- a defective wrapper cannot corrupt the rest of the run.
local function cleanupProblems(withUnitFn, realScript)
    local problems = {}
    for _, key in ipairs({ 'syntax', 'initerr', 'nohook' }) do
        local b = BAD[key]
        local before = U.save()
        local ok, err = pcall(withUnitFn, b.path, function() end)
        local leaked = {}
        if rawget(_G, 'SPELLSPREE_UNIT') ~= before.hook then leaked[#leaked + 1] = 'SPELLSPREE_UNIT' end
        if _G.print ~= before.print then leaked[#leaked + 1] = 'print' end
        for _, m in ipairs({ 'mq', 'ImGui' }) do
            if package.loaded[m] ~= before.loaded[m] then leaked[#leaked + 1] = 'package.loaded.' .. m end
            if package.preload[m] ~= before.preload[m] then leaked[#leaked + 1] = 'package.preload.' .. m end
        end
        U.restore(before)
        if ok then problems[#problems + 1] = key .. ': no error was raised'
        elseif not tostring(err):find(b.want, 1, true) then problems[#problems + 1] = key .. ': the error does not name the cause (' .. tostring(err) .. ')' end
        if #leaked > 0 then problems[#problems + 1] = key .. ': left behind ' .. table.concat(leaked, ', ') end
        local ok2, err2 = pcall(U.withUnit, realScript, function(u) eq(type(u.formatCoin), 'function', 'formatCoin') end)
        if not ok2 then problems[#problems + 1] = key .. ': a following load of the real script failed (' .. tostring(err2) .. ')' end
        U.restore(before)
    end
    return problems
end

local OUT = { SCRIBED = 'bought and scribed', SKIPPED = 'deliberately skipped', STOP = 'not attempted because the run stopped',
    NONE = 'NO OUTCOME RECORDED' }

local EXTRA3 = { { 'parseTierRange', 'function' }, { 'validateRange', 'function' }, { 'classifyLevel', 'function' } }
local EXTRA6 = { { 'isTomeName', 'function' }, { 'tomeDiscipline', 'function' }, { 'normalizeDiscipline', 'function' }, { 'validSlotNumber', 'function' },
    { 'buildKnownIndex', 'function' }, { 'tomeKnownVerdict', 'function' }, { 'learnState', 'function' }, { 'scanKnownDisciplines', 'function' },
    { 'recoverKnownTome', 'function' } }
local EXTRA5 = { { 'logSyncIdentity', 'function' }, { 'logWriteFile', 'function' }, { 'logLine', 'function' }, { 'logObs', 'function' }, { 'logFail', 'function' },
    { 'logUnavailable', 'function' }, { 'logIdentityKeyFor', 'function' } }

-- ---- helpers for the identity tests (D-028): a controllable MacroQuest (clock, TLO tree) and real files in a temp directory
local SYNC_TMP = TMP .. '\\sync'
local function mkdirPath(p) os.execute('mkdir "' .. p .. '" >nul 2>nul') end
local function nilNode()
    return setmetatable({}, { __call = function() return nil end, __index = function() return nilNode() end })
end
local function newSyncEnv(tag)
    local dir = SYNC_TMP .. '\\' .. tag
    os.execute('if exist "' .. dir .. '" rmdir /s /q "' .. dir .. '"')
    mkdirPath(SYNC_TMP); mkdirPath(dir)
    local env = { clock = 1000, server = 'SimServer', char = 'Simtest', dir = dir, logs = dir, root = dir, reads = { server = 0, char = 0 } }
    local TLO = setmetatable({
        EverQuest = { Server = function()
            env.reads.server = env.reads.server + 1
            if env.readFn then return env.readFn('server', env.reads.server) end
            return env.server
        end },
        Me = setmetatable({ CleanName = function()
            env.reads.char = env.reads.char + 1
            if env.readFn then return env.readFn('char', env.reads.char) end
            return env.char
        end }, { __index = function() return nilNode() end }),
        MacroQuest = { Path = function(n) return function() if n == 'logs' then return env.logs end return env.root end end },
    }, { __index = function() return nilNode() end })
    env.mq = { gettime = function() return env.clock end, TLO = TLO }
    return env
end
local function readLinesOf(path)
    local f = io.open(path, 'rb')
    if not f then return {} end
    local lines = {}
    for l in f:lines() do lines[#lines + 1] = (l:gsub('\r$', '')) end
    f:close()
    return lines
end
local function countContaining(lines, plain)
    local n = 0
    for _, l in ipairs(lines) do if l:find(plain, 1, true) then n = n + 1 end end
    return n
end
local function countTexts(log, plain)
    local n = 0
    for _, e in ipairs(log) do if tostring(e.text):find(plain, 1, true) then n = n + 1 end end
    return n
end
local function listDir(d) return d end
local function sizeOfAll(dir)
    local total = 0
    local p = io.popen('dir /b /a-d "' .. dir .. '" 2>nul')
    if p then
        for name in p:lines() do
            local f = io.open(dir .. '\\' .. name, 'rb')
            if f then total = total + f:seek('end'); f:close() end
        end
        p:close()
    end
    return total
end

local TESTS = {
    { id = 'U1', kind = 'CHAR', src = 'formatCoin splits copper into pp/gp/sp/cp, omits zero parts, adds thousands commas, and shows 0cp for zero',
      fn = function(u)
          eq(u.formatCoin(0), '0cp', 'zero')
          eq(u.formatCoin(1000), '1pp', '1000')
          eq(u.formatCoin(1234567), '1,234pp 5gp 6sp 7cp', '1234567')
          eq(u.formatCoin(1000000), '1,000pp', '1000000')
          eq(u.formatCoin(105), '1gp 5cp', '105')
      end },

    { id = 'U2', kind = 'CHAR', src = 'formatCoin rounds a fractional copper amount to the nearest copper (99.6 is 1gp, 99.4 is 99cp)',
      fn = function(u)
          eq(u.formatCoin(99.6), '1gp', '99.6')
          eq(u.formatCoin(99.4), '9sp 9cp', '99.4')
      end },

    { id = 'U3', kind = 'CHAR', src = 'withCommas groups digits in threes, handles negatives, and treats nil as 0',
      fn = function(u)
          eq(u.withCommas(999), '999', '999')
          eq(u.withCommas(1000), '1,000', '1000')
          eq(u.withCommas(1000000), '1,000,000', '1000000')
          eq(u.withCommas(-1234), '-1,234', '-1234')
          eq(u.withCommas(nil), '0', 'nil')
      end },

    { id = 'U4', kind = 'CHAR', src = 'formatCoinPPOnly rounds platinum UP so any remainder still shows as at least 1pp (comment above the function)',
      fn = function(u)
          eq(u.formatCoinPPOnly(0), '0pp', '0')
          eq(u.formatCoinPPOnly(1), '1pp', '1')
          eq(u.formatCoinPPOnly(1000), '1pp', '1000')
          eq(u.formatCoinPPOnly(1001), '2pp', '1001')
          eq(u.formatCoinPPOnly(2500000), '2,500pp', '2500000')
      end },

    { id = 'U5', kind = 'CHAR', src = 'parseCopperFromText sums every "<number> <denomination>" pair (confirmed live tell wording: 159 platinum 2 gold 1 silver 9 copper) and returns nil when none is present',
      fn = function(u)
          eq(u.parseCopperFromText("That'll be 159 platinum 2 gold 1 silver 9 copper per Spell: X."), 159219, 'live wording')
          eq(u.parseCopperFromText('1pp 4gp'), 1400, 'abbreviations')
          eq(u.parseCopperFromText('nothing to see'), nil, 'no coin')
          eq(u.parseCopperFromText(nil), nil, 'nil')
      end },

    { id = 'U6', kind = 'REQ', src = 'D-014 A\': a scroll name is "Spell: " or "Song: " at the start, with the space; anything else (no space, not at the start, nil) is not a scroll',
      fn = function(u)
          eq(u.isScrollName('Spell: Calm'), true, 'Spell: Calm')
          eq(u.isScrollName('Song: Chant of Battle'), true, 'Song:')
          eq(u.isScrollName('Spell:Calm'), false, 'no space')
          eq(u.isScrollName('Tome of Spell: Calm'), false, 'not at the start')
          eq(u.isScrollName('Pickled Cat Food'), false, 'ordinary item')
          eq(u.isScrollName(nil), false, 'nil')
      end },

    { id = 'U7', kind = 'CHAR', src = 'parseClassLine maps a class display line to the short class name, ignoring a leading level number, and returns nil for level lines, NULL and unknown text',
      fn = function(u)
          eq(u.parseClassLine('Cleric'), 'Clr', 'Cleric')
          eq(u.parseClassLine('3 Wizard'), 'Wiz', 'leading number')
          eq(u.parseClassLine('Shadow Knight'), 'SK', 'two words')
          eq(u.parseClassLine('Level 5'), nil, 'level line')
          eq(u.parseClassLine('NULL'), nil, 'NULL')
          eq(u.parseClassLine('Bogus'), nil, 'unknown')
          eq(u.parseClassLine(''), nil, 'empty')
      end },

    { id = 'U8', kind = 'REQ', src = 'D-017 F\'\': setOutcome records the outcome and its detail on the entry',
      fn = function(u)
          fresh(u)
          local e = { name = 'Alpha' }
          u.setOutcome(e, u.OUTCOME.SKIPPED, 'row gone at lookup')
          eq(e.outcome, OUT.SKIPPED, 'outcome'); eq(e.detail, 'row gone at lookup', 'detail')
      end },

    { id = 'U9', kind = 'REQ', src = 'D-017 F\'\': a second outcome for the same entry is ignored (the first is kept) and logged as a LEDGER DEFECT naming the entry',
      fn = function(u)
          fresh(u)
          local e = { name = 'Alpha' }
          u.setOutcome(e, u.OUTCOME.SCRIBED)
          u.setOutcome(e, u.OUTCOME.SKIPPED, 'later')
          eq(e.outcome, OUT.SCRIBED, 'kept outcome')
          eq(hasLine(u, 'LEDGER DEFECT: an outcome was recorded twice for "Alpha"'), true, 'defect line')
      end },

    { id = 'U10', kind = 'REQ', src = 'D-017 F\'\' outcome 5: markRemainingNotAttempted marks only entries from the given index on that have no outcome yet, records the reason, and logs no defect',
      fn = function(u)
          fresh(u)
          local es = { { name = 'A' }, { name = 'B' }, { name = 'C', outcome = OUT.SCRIBED }, { name = 'D' } }
          u.markRemainingNotAttempted(es, 2, 'Out of money')
          eq(es[1].outcome, nil, 'before the index')
          eq(es[2].outcome, OUT.STOP, 'B'); eq(es[2].detail, 'Out of money', 'B detail')
          eq(es[3].outcome, OUT.SCRIBED, 'C keeps its outcome')
          eq(es[4].outcome, OUT.STOP, 'D')
          eq(hasLine(u, 'LEDGER DEFECT'), false, 'no defect line')
          u.markRemainingNotAttempted(es, 9, 'x')   -- an index past the end changes nothing
          eq(es[1].outcome, nil, 'still untouched')
      end },

    { id = 'U11', kind = 'REQ', src = 'D-017 F\'\': logLedger logs a count for every outcome (in the fixed order) and names, with details, for every outcome except the first',
      fn = function(u)
          fresh(u)
          local es = { { name = 'A', outcome = OUT.SCRIBED }, { name = 'B', outcome = OUT.SKIPPED, detail = 'row gone at lookup' },
              { name = 'C', outcome = OUT.STOP, detail = 'Out of money' }, { name = 'D', outcome = OUT.SCRIBED } }
          u.logLedger(es)
          local ok, line = hasLine(u, 'Outcome ledger (4 built-list entries):')
          eq(ok, true, 'counts line present')
          eq(line, 'Outcome ledger (4 built-list entries): bought and scribed=2; bought, scribe not completed=0; attempted, not bought=0; deliberately skipped=1; not attempted because the run stopped=1; NO OUTCOME RECORDED=0.', 'counts line')
          eq(hasLine(u, '  deliberately skipped (1): B (row gone at lookup)'), true, 'skipped names')
          eq(hasLine(u, '  not attempted because the run stopped (1): C (Out of money)'), true, 'not attempted names')
          eq(hasLine(u, '  bought and scribed ('), false, 'the first outcome lists no names')
      end },

    { id = 'U12', kind = 'REQ', src = 'D-017 F\'\' (ledger item "an entry with no outcome is a defect"): an entry that ends with no outcome is logged as a LEDGER DEFECT, is given NO OUTCOME RECORDED and is listed under it',
      fn = function(u)
          fresh(u)
          local es = { { name = 'A', outcome = OUT.SCRIBED }, { name = 'Orphan' } }
          u.logLedger(es)
          eq(hasLine(u, 'LEDGER DEFECT: "Orphan" ended with no recorded outcome.'), true, 'defect line')
          eq(es[2].outcome, OUT.NONE, 'orphan outcome')
          eq(hasLine(u, '  NO OUTCOME RECORDED (1): Orphan (no outcome was recorded)'), true, 'listed')
      end },

    { id = 'U13', kind = 'REQ', src = 'D-026 B and C\'\': the hook exposes every piece the unit tests use, with the right types',
      fn = function()
          for name, ty in pairs(U.EXPECTED) do
              U.withUnit(SCRIPT, function(u) eq(type(u[name]), ty, name) end)
          end
      end },

    { id = 'U14', kind = 'REQ', src = 'D-026 C\'\': the stubs are strict (any use of an unlisted mq field raises an error naming it; mq.gettime works)',
      fn = function()
          U.withUnit(SCRIPT, function()
              local mq = require('mq')
              eq(mq.gettime(), 0, 'gettime')
              local ok, err = pcall(function() return mq.TLO end)
              eq(ok, false, 'mq.TLO is refused')
              eq(tostring(err):find('unexpected use of mq.TLO', 1, true) ~= nil, true, 'the error names mq.TLO (' .. tostring(err) .. ')')
              local ok2, err2 = pcall(function() return require('ImGui').Begin end)
              eq(ok2, false, 'ImGui.Begin is refused')
              eq(tostring(err2):find('unexpected use of ImGui.Begin', 1, true) ~= nil, true, 'the error names ImGui.Begin')
          end)
      end },

    { id = 'U15', kind = 'REQ', src = 'D-026 C\'\': the wrapper restores everything and raises a named error after a syntax error, an initialization error and a missing export; the real script still loads afterwards',
      fn = function()
          local problems = cleanupProblems(U.withUnit, SCRIPT)
          if #problems > 0 then error(table.concat(problems, '; '), 0) end
      end },

    -- ---- Step 3 (D-025; its red-run stage tables were `st[n]` and are retired now that Step 3 is built). `kind` is REQ/CHAR; `new` marks behavior that did not exist before Step 3; at red-run stage n (D-025 F''), written before the stage was run: 0 = no new exports, 1 = wrong stubs (parseTierRange returns nil,
    -- classifyLevel returns "in", validateRange accepts everything), 2 and 3 = correct functions.
    { id = 'U17', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 A\': the four real tier labels parse to their inclusive ranges, and a label whose endpoints are equal is a valid range',
      fn = function(u)
          local function chk(label, lo, hi)
              local a, b = u.parseTierRange(label)
              eq(a, lo, label .. ' low'); eq(b, hi, label .. ' high')
          end
          chk('1-25', 1, 25); chk('26-50', 26, 50); chk('51-60', 51, 60); chk('61-70', 61, 70)
          chk('25-25', 25, 25); chk('1-70', 1, 70)
      end },

    { id = 'U18', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 A\' (Revision 3): a label that does not parse, or parses outside 1-70, or has reversed endpoints, gives nil and a reason',
      fn = function(u)
          for _, bad in ipairs({ 'abc', '61-', '-70', '', '1-80', '0-25', '26-71', '25-1', '1-25x', ' 1-25', '1 -25', '1.5-25', '1-2-3' }) do
              local lo, why = u.parseTierRange(bad)
              eq(lo, nil, '"' .. bad .. '" must not parse')
              eq(type(why), 'string', '"' .. bad .. '" gives a reason')
          end
          eq((u.parseTierRange(nil)), nil, 'nil label')
          eq((u.parseTierRange(25)), nil, 'a number is not a label')
      end },

    { id = 'U19', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 A\' (Revision 3): validateRange accepts a table whose low and high are whole numbers with 1 <= low <= high <= 70',
      fn = function(u)
          for _, r in ipairs({ { low = 1, high = 25 }, { low = 61, high = 70 }, { low = 25, high = 25 }, { low = 1, high = 70 } }) do
              eq((u.validateRange(r)), true, r.low .. '-' .. r.high .. ' is valid')
          end
      end },

    { id = 'U20', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 A\' (Revision 3): validateRange refuses reversed endpoints, an endpoint outside 1-70, non-integers, text, missing fields and non-tables, with a reason',
      fn = function(u)
          local bad = { { low = 25, high = 1 }, { low = 0, high = 25 }, { low = 1, high = 71 }, { low = 1, high = 80 }, { low = -5, high = 10 },
              { low = 1.5, high = 25 }, { low = 1, high = 25.5 }, { low = '1', high = 25 }, { low = 1 }, { high = 25 }, {}, 'x', 25, true }
          for i, r in ipairs(bad) do
              local ok, why = u.validateRange(r)
              eq(ok, false, 'bad range #' .. i .. ' must be refused')
              eq(type(why), 'string', 'bad range #' .. i .. ' gives a reason')
          end
          eq((u.validateRange(nil)), false, 'nil')
      end },

    { id = 'U21', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 B / R21: levels inside the range, inclusive of both endpoints, are "in" (padded text counts: " 25 " and a tab)',
      fn = function(u)
          for _, c in ipairs({ { '1', 1, 25 }, { '25', 1, 25 }, { '26', 26, 50 }, { '50', 26, 50 }, { '51', 51, 60 }, { '60', 51, 60 },
              { '61', 61, 70 }, { '70', 61, 70 }, { ' 25 ', 1, 25 }, { '\t25', 1, 25 }, { ' 25', 1, 25 }, { '007', 1, 25 } }) do
              eq((u.classifyLevel(c[1], c[2], c[3])), 'in', string.format('%q in %d-%d', c[1], c[2], c[3]))
          end
      end },

    { id = 'U22', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 B / R21 / R34: levels just outside a range, above 70, below 1, zero and negative are "outside", with the reason naming the range and the level',
      fn = function(u)
          for _, c in ipairs({ { '0', 1, 25 }, { '26', 1, 25 }, { '25', 26, 50 }, { '51', 26, 50 }, { '50', 51, 60 }, { '61', 51, 60 },
              { '60', 61, 70 }, { '71', 61, 70 }, { '0', 61, 70 }, { '-3', 1, 25 }, { '99', 1, 70 }, { '99999999999999999999', 1, 70 } }) do
              local v = u.classifyLevel(c[1], c[2], c[3])
              eq(v, 'outside', string.format('%q vs %d-%d', c[1], c[2], c[3]))
          end
          local _, why = u.classifyLevel('63', 1, 25)
          eq(why, 'outside the selected level range 1-25 (Lvl 63)', 'reason text')
      end },

    { id = 'U23', kind = 'REQ', new = true, extra = EXTRA3,
      src = 'D-025 B / D-014 item I: text that is not a whole number (blank, --, words, decimals, trailing characters, embedded spaces, nil) is "unreadable", with the trimmed text in the reason',
      fn = function(u)
          for _, t in ipairs({ '', '   ', '--', 'abc', '25x', '2 5', '25.5', '1e1', '+5' }) do
              local v = u.classifyLevel(t, 1, 70)
              eq(v, 'unreadable', string.format('%q', t))
          end
          eq((u.classifyLevel(nil, 1, 70)), 'unreadable', 'nil')
          local _, why = u.classifyLevel('--', 1, 25)
          eq(why, 'level unreadable ("--")', 'reason for --')
          _, why = u.classifyLevel('  ', 1, 25)
          eq(why, 'level unreadable ("")', 'reason for blank')
          _, why = u.classifyLevel(nil, 1, 25)
          eq(why, 'level unreadable (no value)', 'reason for a missing cell')
      end },

    -- ---- Step 5 (D-028): the log follows the character. `st[n]` is the expected result at red-run stage n, written before the stage
    -- was run: 0 = unchanged script (nothing exported); 1 = the new functions exposed as wrong stubs, nothing wired (logSyncIdentity does
    -- nothing, logUnavailable says false, logIdentityKeyFor says 'x'); 2 = the functions correct but nothing calls them from
    -- logWriteFile or the run paths (logFail already idempotent); 3 = the full build. `own` = the test builds its own stubs and calls
    -- withUnit itself.
    { id = 'U24', kind = 'REQ', new = true, extra = EXTRA5,
      src = 'D-028 C / Revision 2 section 2: an identity value is unavailable when it is nil, "n/a", "NULL" or empty after trimming; ordinary names are available',
      fn = function(u)
          for _, v in ipairs({ 'n/a', 'NULL', '', '   ', '\t' }) do eq(u.logUnavailable(v), true, string.format('%q', v)) end
          eq(u.logUnavailable(nil), true, 'nil')
          for _, v in ipairs({ 'Benedict', 'multiclass', 'A b', 'null', 'na' }) do eq(u.logUnavailable(v), false, string.format('%q', v)) end
      end },

    { id = 'U25', kind = 'REQ', new = true, extra = EXTRA5,
      src = 'D-028 A\' (Revision 3 section 2) / Revision 2 section 2: the destination key is the sanitized server and character, as the file name uses them; names that sanitize alike share a key, different names do not',
      fn = function(u)
          eq(u.logIdentityKeyFor('multiclass', 'Benedict'), 'multiclass_Benedict', 'plain')
          eq(u.logIdentityKeyFor('multiclass', 'A b'), u.logIdentityKeyFor('multiclass', 'A_b'), 'a space and an underscore share a key')
          eq(u.logIdentityKeyFor('multiclass', 'A.b'), 'multiclass_A_b', 'a dot becomes an underscore')
          eq(u.logIdentityKeyFor('multiclass', 'Benedict') ~= u.logIdentityKeyFor('multiclass', 'Ididnotbuffher'), true, 'different characters')
          eq(u.logIdentityKeyFor('serverA', 'Benedict') ~= u.logIdentityKeyFor('serverB', 'Benedict'), true, 'different servers')
      end },

    { id = 'U26', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 B / B\': a forced sync after the character changed writes the transition line to the old file, then a session header marked "continued session" and a "Logging to a new file" notice to the new file; the counter is reset; nothing from before is moved',
      fn = function()
          local env = newSyncEnv('u26')
          U.withUnit(SCRIPT, function(u)
              u.logLine('first record', nil); u.logLine('second record', nil)
              local oldPath = u.LOG.path
              local writesBefore = u.LOG.writes
              env.char = 'Other'; env.clock = env.clock + 10
              u.logSyncIdentity(true)
              local oldLines, newLines = readLinesOf(oldPath), readLinesOf(u.LOG.path)
              eq(u.LOG.path ~= oldPath, true, 'the path changed')
              eq(u.LOG.path:find('spellspree_SimServer_Other.log', 1, true) ~= nil, true, 'the new file is named for Other')
              local last = oldLines[#oldLines]
              eq(last:find('identity changed: SimServer/Simtest -> SimServer/Other; continuing in ' .. u.LOG.path:gsub('%-', '%%-'), 1) ~= nil or last:find('identity changed: SimServer/Simtest -> SimServer/Other', 1, true) ~= nil, true, 'the old file ends with the transition line: ' .. tostring(last))
              eq(countContaining(oldLines, 'continued session'), 0, 'no header in the old file')
              eq(countContaining(newLines, 'continued session'), 1, 'one continued session header in the new file')
              eq(newLines[1]:find('continued session', 1, true) ~= nil, true, 'the new file starts with the header: ' .. tostring(newLines[1]))
              local envLines = 0
              for _, l in ipairs(newLines) do if l:find('environment at switch:', 1, true) and l:find('character=Other', 1, true) then envLines = envLines + 1 end end
              eq(envLines, 1, 'the header has one environment line naming the new character')
              eq(newLines[#newLines]:find('Logging to a new file for Other: ', 1, true) ~= nil, true, 'the notice is the last line: ' .. tostring(newLines[#newLines]))
              eq(countContaining(newLines, 'first record'), 0, 'earlier records are not copied')
              eq(u.LOG.writes < writesBefore + 3 + #newLines, true, 'the counter was reset (now ' .. u.LOG.writes .. ', lines in the new file ' .. #newLines .. ')')
              eq(u.LOG.writes, #newLines, 'writes since the reset equal the new file\'s lines')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U27', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 A\' / I\'\': a raw identity that differs but sanitizes to the same file writes the identity-change record and a continued session header to the SAME file, with no file switch, no notice, and the counter not reset (the new lines increment it normally)',
      fn = function()
          local env = newSyncEnv('u27'); env.char = 'A_b'
          U.withUnit(SCRIPT, function(u)
              u.logLine('before', nil)
              local path, writesBefore = u.LOG.path, u.LOG.writes
              local linesBefore = #readLinesOf(path)
              env.char = 'A b'; env.clock = env.clock + 10
              u.logSyncIdentity(true)
              eq(u.LOG.path, path, 'same file')
              local lines = readLinesOf(path)
              eq(countContaining(lines, 'identity changed: SimServer/A_b -> SimServer/A b'), 1, 'one identity-change record')
              eq(countContaining(lines, 'continued session'), 1, 'one continued session header')
              eq(countContaining(lines, 'Logging to a new file'), 0, 'no new-file notice')
              eq(u.LOG.writes, writesBefore + (#lines - linesBefore), 'the counter grew by exactly the lines written')
              eq(u.LOG.identity.char, 'A b', 'the new raw identity is stored')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U28', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 B\' / A\': one sync reads the server and the character once each and uses that one snapshot for the transition text, the file name, the stored identity and the header; the sync does not start a nested sync from its own writes',
      fn = function()
          local env = newSyncEnv('u28')
          -- the first read after the switch time returns Other, every later read returns Third: a second read would show
          env.readFn = function(kind, n)
              if kind == 'server' then return 'SimServer' end
              if not env.switched then return 'Simtest' end
              env.afterSwitchReads = (env.afterSwitchReads or 0) + 1
              return env.afterSwitchReads == 1 and 'Other' or 'Third'
          end
          U.withUnit(SCRIPT, function(u)
              u.logLine('before', nil)
              local oldPath = u.LOG.path
              env.switched = true; env.clock = env.clock + 10
              local charBefore = env.reads.char
              u.logSyncIdentity(true)
              eq(env.reads.char - charBefore, 1, 'the character was read once during the sync (header and path use the snapshot)')
              eq(u.LOG.path:find('_Other.log', 1, true) ~= nil, true, 'the file is named from the snapshot: ' .. tostring(u.LOG.path))
              local newLines = readLinesOf(u.LOG.path)
              local envLines = 0
              for _, l in ipairs(newLines) do if l:find('environment at switch:', 1, true) and l:find('character=Other', 1, true) then envLines = envLines + 1 end end
              eq(envLines, 1, 'the header environment line shows the snapshot')
              eq(countContaining(newLines, 'log path resolution:') == 1 and countContaining(newLines, 'server=SimServer, character=Other') == 1, true, 'the resolution line uses the snapshot too')
              eq(countContaining(newLines, 'Third'), 0, 'no later read leaked into the new file')
              local oldLines = readLinesOf(oldPath)
              eq(countContaining(oldLines, 'identity changed: SimServer/Simtest -> SimServer/Other'), 1, 'one transition line, from the snapshot')
              eq(u.LOG.identity.char, 'Other', 'stored identity is the snapshot')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U29', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 C: an unavailable identity keeps the current file and writes one OBS line (not one per sync); once it is readable and differs, the file switches',
      fn = function()
          local env = newSyncEnv('u29')
          U.withUnit(SCRIPT, function(u)
              u.logLine('before', nil)
              local path = u.LOG.path
              env.char = 'NULL'
              for i = 1, 3 do env.clock = env.clock + 3000; u.logSyncIdentity(false) end
              eq(u.LOG.path, path, 'the file is kept')
              eq(countContaining(readLinesOf(path), 'identity unreadable'), 1, 'one OBS line for three unreadable syncs')
              eq(u.LOG.disabled, false, 'logging stays on')
              env.char = 'Other'; env.clock = env.clock + 3000
              u.logSyncIdentity(false)
              eq(u.LOG.path ~= path, true, 'switched once readable')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U30', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 E / I\'\': a failed transition write, an unresolvable new destination, a failed header write and an unexpected exception each leave logging disabled, both guards cleared, exactly one failure notice and no success notice; a later sync writes nothing',
      fn = function()
          local cases = {
              { name = 'the old-file transition write fails', prep = function(env, u) os.remove(u.LOG.path); mkdirPath(u.LOG.path) end },
              { name = 'the new destination cannot be resolved', prep = function(env, u) env.logs = env.dir .. '\\bad"dir' end },
              { name = 'the header write fails', prep = function(env, u) mkdirPath(env.dir .. '\\spellspree\\spellspree_SimServer_Other.log') end },
              { name = 'an unexpected exception inside the sync', prep = function(env, u) u.LOG.identity = 5 end },
          }
          for i, c in ipairs(cases) do
              local env = newSyncEnv('u30_' .. i)
              U.withUnit(SCRIPT, function(u)
                  u.logLine('before', nil)
                  c.prep(env, u)
                  env.char = 'Other'; env.clock = env.clock + 3000
                  u.logSyncIdentity(true)
                  local label = c.name .. ': '
                  eq(u.LOG.disabled, true, label .. 'logging is off')
                  eq(u.LOG.syncing, false, label .. 'LOG.syncing cleared')
                  eq(u.LOG.hold or false, false, label .. 'LOG.hold cleared')
                  eq(countTexts(u.S.log, 'File logging is OFF'), 1, label .. 'exactly one failure notice')
                  eq(countTexts(u.S.log, 'Logging to a new file'), 0, label .. 'no success notice')
                  local files = listDir(env.dir .. '\\spellspree')
                  local sizeBefore = sizeOfAll(env.dir .. '\\spellspree')
                  env.clock = env.clock + 3000
                  u.logSyncIdentity(true); u.logLine('after', nil)
                  eq(sizeOfAll(env.dir .. '\\spellspree'), sizeBefore, label .. 'a later sync and record write nothing to any file')
                  eq(u.LOG.disabled, true, label .. 'logging stays off')
              end, EXTRA5, { mq = env.mq })
          end
      end },

    { id = 'U31', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 A\' (Revision 2 section 4): an unforced sync acts at most once every 2,000 ms of mq.gettime(); a forced sync ignores the interval',
      fn = function()
          local env = newSyncEnv('u31')
          U.withUnit(SCRIPT, function(u)
              u.logLine('before', nil)
              local path = u.LOG.path
              env.clock = env.clock + 3000; u.logSyncIdentity(false)       -- takes the reading, no change
              env.char = 'Other'
              env.clock = env.clock + 1500; u.logSyncIdentity(false)
              eq(u.LOG.path, path, 'within 2,000 ms of the last sync: no action')
              env.clock = env.clock + 600; u.logSyncIdentity(false)
              eq(u.LOG.path ~= path, true, 'after the interval: the switch happens')
              local second = u.LOG.path
              env.char = 'Third'; env.clock = env.clock + 10; u.logSyncIdentity(false)
              eq(u.LOG.path, second, 'inside the interval again: no action')
              u.logSyncIdentity(true)
              eq(u.LOG.path ~= second, true, 'a forced sync ignores the interval')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U32', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 E\'\': while a run holds the file, detection continues but routing stays pinned: one note per distinct observed identity (observed, original, "records stay"); once the hold is cleared a forced sync switches',
      fn = function()
          local env = newSyncEnv('u32')
          U.withUnit(SCRIPT, function(u)
              u.logLine('run record', nil)
              local path = u.LOG.path
              u.LOG.hold = true
              env.char = 'Other'
              env.clock = env.clock + 3000; u.logSyncIdentity(false)
              env.clock = env.clock + 3000; u.logSyncIdentity(false)       -- same observed identity again: no second note
              eq(u.LOG.path, path, 'routing stays pinned during the hold')
              local lines = readLinesOf(path)
              eq(countContaining(lines, 'identity differs during a run'), 1, 'one note for the observed identity')
              local note = nil
              for _, l in ipairs(lines) do if l:find('identity differs during a run', 1, true) then note = l end end
              eq(note:find('SimServer/Other', 1, true) ~= nil and note:find('SimServer/Simtest', 1, true) ~= nil and note:find('records stay', 1, true) ~= nil, true, 'the note names both identities and says records stay: ' .. tostring(note))
              env.char = 'Third'
              env.clock = env.clock + 3000; u.logSyncIdentity(false)
              eq(countContaining(readLinesOf(path), 'identity differs during a run'), 2, 'a different observed identity gets its own note')
              u.LOG.hold = false
              u.logSyncIdentity(true)
              eq(u.LOG.path ~= path, true, 'after the hold: the forced sync switches')
              eq(u.LOG.path:find('_Third.log', 1, true) ~= nil, true, 'to the identity in force')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U33', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = 'D-028 A\' (Revision 2 section 4): every record passes logWriteFile, which runs the throttled sync first, so a record written after the interval goes to the new file and the transition record to the old one',
      fn = function()
          local env = newSyncEnv('u33')
          U.withUnit(SCRIPT, function(u)
              u.logLine('before', nil)
              local oldPath = u.LOG.path
              env.char = 'Other'; env.clock = env.clock + 3000
              u.logLine('after the switch', nil)
              eq(u.LOG.path ~= oldPath, true, 'the record triggered the sync')
              eq(countContaining(readLinesOf(u.LOG.path), 'after the switch'), 1, 'the record is in the new file')
              eq(countContaining(readLinesOf(oldPath), 'after the switch'), 0, 'and not in the old')
              eq(countContaining(readLinesOf(oldPath), 'identity changed'), 1, 'the transition record is in the old')
          end, EXTRA5, { mq = env.mq })
      end },

    { id = 'U35', kind = 'REQ', new = true, own = true, extra = EXTRA5,
      src = "D-028 A' (the recursion guard): with the throttle shut off, so that nothing but LOG.syncing stops a nested sync, a switch still writes the transition line, the header and the notice exactly once each. Added after the mutation runs showed the throttle hides the guard in the other tests",
      fn = function()
          local copy = TMP .. '\\throttle0.lua'
          local text = readAll(SCRIPT):gsub('\r\n', '\n')   -- the script under test (a mutant when a mutation is being checked)
          local at = text:find('LOG_SYNC_EVERY_MS = 2000', 1, true)
          if at then
              local f = assert(io.open(copy, 'wb')); f:write(text:sub(1, at - 1) .. 'LOG_SYNC_EVERY_MS = 0' .. text:sub(at + #'LOG_SYNC_EVERY_MS = 2000')); f:close()
          else
              copy = SCRIPT -- before the build there is no interval to change; the missing exports fail the test
          end
          local env = newSyncEnv('u35')
          local real = SCRIPT
          SCRIPT = copy
          local ok, err = pcall(function()
              U.withUnit(copy, function(u)
                  u.logLine('before', nil)
                  local oldPath = u.LOG.path
                  env.char = 'Other'; env.clock = env.clock + 10
                  local before = env.reads.char
                  u.logSyncIdentity(true)
                  eq(env.reads.char - before, 1, 'one read of the character in the whole sync')
                  eq(countContaining(readLinesOf(oldPath), 'identity changed'), 1, 'one transition line')
                  local newLines = readLinesOf(u.LOG.path)
                  eq(countContaining(newLines, 'continued session'), 1, 'one header')
                  eq(countContaining(newLines, 'Logging to a new file'), 1, 'one notice')
                  eq(u.LOG.syncing, false, 'the guard is released')
              end, EXTRA5, { mq = env.mq })
          end)
          SCRIPT = real
          if not ok then error(err, 0) end
      end },

    { id = 'U34', kind = 'REQ', new = true, extra = EXTRA5,
      src = 'D-028 B\' (Revision 3 section 3): logFail is idempotent: the first call turns file logging off and writes one window notice; a second call writes nothing',
      fn = function(u)
          u.S.log = {}
          u.logFail('first reason')
          u.logFail('second reason')
          eq(u.LOG.disabled, true, 'disabled')
          eq(countTexts(u.S.log, 'File logging is OFF'), 1, 'one notice')
          eq(countTexts(u.S.log, 'second reason'), 0, 'the second reason is not reported')
      end },

    -- ---- Step 6 (D-030): discipline tomes. `st[n]` is the expected result at red-run stage n, written before the stage was run: 0 = unchanged script (nothing
    -- exported); 1 = the new functions exposed as wrong stubs (isTomeName false, tomeDiscipline nil, normalizeDiscipline '', validSlotNumber nil,
    -- buildKnownIndex {}, tomeKnownVerdict 'unknown', learnState 'insufficient', scanKnownDisciplines empty, recoverKnownTome 'failed'); 2 = the functions correct but
    -- nothing calls them; 3 = the full build.
    { id = 'U36', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 C: a row is a tome only if its name begins exactly "Tome of " (case-sensitive, from the start) with something after it; scrolls, near-misses and non-strings are not',
      fn = function(u)
          for _, n in ipairs({ 'Tome of Bellow', 'Tome of Inner Flame Discipline', 'Tome of Diversive Strike', 'Tome of A' }) do eq(u.isTomeName(n), true, n) end
          for _, n in ipairs({ 'Spell: Calm', 'Song: Chant', 'tome of bellow', 'Tome Of Bellow', ' Tome of Bellow', 'Tome ofBellow', 'Tome of', 'Tome of ', 'Tome of   ',
              'Tomes of Lore', 'Spell: Tome of Bellow', 'A Tome of Bellow', '' }) do eq(u.isTomeName(n), false, string.format('%q', n)) end
          eq(u.isTomeName(nil), false, 'nil'); eq(u.isTomeName(5), false, 'a number')
      end },

    { id = 'U37', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D: the discipline a tome names is its name without "Tome of ", trimmed; nil for anything that is not a tome',
      fn = function(u)
          eq(u.tomeDiscipline('Tome of Bellow'), 'Bellow', 'Bellow')
          eq(u.tomeDiscipline('Tome of Inner Flame Discipline'), 'Inner Flame Discipline', 'Inner Flame')
          eq(u.tomeDiscipline('Tome of  Spaced  '), 'Spaced', 'trimmed')
          eq(u.tomeDiscipline('Spell: Calm'), nil, 'a scroll')
          eq(u.tomeDiscipline(nil), nil, 'nil')
      end },

    { id = 'U38', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D / Revision 2 answer 3: a discipline name is normalized by lower-casing and removing every character outside a-z and 0-9 (so Inner Flame and Innerflame agree)',
      fn = function(u)
          eq(u.normalizeDiscipline('Inner Flame Discipline'), 'innerflamediscipline', 'Inner Flame')
          eq(u.normalizeDiscipline('Innerflame Discipline'), 'innerflamediscipline', 'Innerflame')
          eq(u.normalizeDiscipline('Stone Stance Discipline'), u.normalizeDiscipline('Stonestance Discipline'), 'Stone Stance')
          eq(u.normalizeDiscipline("Champion's Aura"), 'championsaura', 'apostrophe')
          eq(u.normalizeDiscipline('Zhao V`karin'), 'zhaovkarin', 'backtick')
          eq(u.normalizeDiscipline(nil), '', 'nil')
          eq(u.normalizeDiscipline('Bellow') ~= u.normalizeDiscipline('Bellow of the Mastruq'), true, 'different names stay different')
      end },

    { id = 'U39', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D\' (Revision 3): a by-name result counts only as a positive whole slot number; nil, empty, NULL, zero, negative, fractions, text and non-numbers do not',
      fn = function(u)
          eq(u.validSlotNumber(5), 5, '5'); eq(u.validSlotNumber('23'), 23, '"23"'); eq(u.validSlotNumber(40), 40, '40')
          for _, v in ipairs({ 0, -1, 2.5, '', 'NULL', 'abc', '1e', true, false, '0', '-3', '2.5' }) do eq(u.validSlotNumber(v), nil, tostring(v)) end
          eq(u.validSlotNumber(nil), nil, 'nil'); eq(u.validSlotNumber({}), nil, 'a table')
      end },

    { id = 'U40', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D\' : the known list is indexed by normalized name; two distinct raw names that normalize alike share a key (ambiguous), the same raw name twice does not',
      fn = function(u)
          local ix = u.buildKnownIndex({ 'Bellow', 'Innerflame Discipline', 'Foo Bar', 'FooBar', 'Bellow' })
          eq(#(ix['bellow'] or {}), 1, 'a repeated name is one entry')
          eq(#(ix['innerflamediscipline'] or {}), 1, 'Innerflame')
          eq(#(ix['foobar'] or {}), 2, 'two distinct names share a key')
          eq(ix['nothere'], nil, 'an unknown key')
      end },

    { id = 'U41', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D\' : a tome is known if the list matches unambiguously, or the exact by-name lookup gave a positive slot; an ambiguous list match alone is never known; an alias is used only when given',
      fn = function(u)
          local ix = u.buildKnownIndex({ 'Bellow', 'Innerflame Discipline', 'Foo Bar', 'FooBar', 'Divertive Strike' })
          local v, via = u.tomeKnownVerdict('Bellow', ix, nil); eq(v, 'known', 'list match'); eq(via, 'list', 'via the list')
          v = u.tomeKnownVerdict('Inner Flame Discipline', ix, nil); eq(v, 'known', 'normalized match')
          v, via = u.tomeKnownVerdict('Fearless Discipline', ix, 7); eq(v, 'known', 'by-name positive'); eq(via, 'by-name', 'via the by-name lookup')
          v = u.tomeKnownVerdict('Fearless Discipline', ix, 0); eq(v, 'unknown', 'by-name zero')
          v = u.tomeKnownVerdict('Fearless Discipline', ix, nil); eq(v, 'unknown', 'no match at all')
          v = u.tomeKnownVerdict('Foo-Bar', ix, nil); eq(v, 'ambiguous', 'ambiguous list match is not known')
          v, via = u.tomeKnownVerdict('Foo-Bar', ix, 3); eq(v, 'known', 'ambiguous list, but a positive exact by-name result'); eq(via, 'by-name', 'via by-name')
          v = u.tomeKnownVerdict('Diversive Strike', ix, nil); eq(v, 'unknown', 'no alias is configured')
          v = u.tomeKnownVerdict('Diversive Strike', ix, nil, { ['Diversive Strike'] = 'Divertive Strike' }); eq(v, 'known', 'a given alias is used')
      end },

    { id = 'U42', kind = 'REQ', new = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 F\'\' : the learn state is decided from the slot, the cursor and the count against the original baseline: cursor first, then the slot, then the count',
      fn = function(u)
          local T = 'Tome of Bellow'
          local function st(o) return u.learnState(o, 2, T) end
          eq(st({ cursorName = 'Mystery Bone', slotName = T, count = 2 }), 'cursor-other', 'something else on the cursor')
          eq(st({ cursorName = T, slotName = nil, count = 2 }), 'pending', 'the tome on the cursor')
          eq(st({ cursorName = T, slotName = nil, count = nil }), 'pending', 'pending even when the count is unreadable')
          eq(st({ slotName = T, count = 2 }), 'clickable', 'the tome still in the slot, cursor empty')
          eq(st({ slotName = T, count = nil }), 'clickable', 'clickable even when the count is unreadable')
          eq(st({ slotName = nil, count = 1 }), 'learned', 'slot empty, cursor empty, count n0-1')
          eq(st({ slotName = 'Tome of Other', count = 1 }), 'learned', 'a different item in the slot, count n0-1')
          eq(st({ slotName = nil, count = 2 }), 'insufficient', 'slot empty but the count did not drop')
          eq(st({ slotName = nil, count = nil }), 'insufficient', 'an unreadable count never establishes learning')
          eq(st({ slotName = nil, count = 'x' }), 'insufficient', 'a non-number count')
          eq(st({ slotName = nil, count = 0 }), 'insufficient', 'count below n0-1 is not accepted as learned')
          eq(st({ slotName = nil, count = 1.5 }), 'insufficient', 'a fractional count')
      end },

    { id = 'U43', kind = 'REQ', new = true, own = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 D\' / Revision 2 answer 2: the known scan stops after 60 empty slots (no count available), counts raising reads and empty slots separately, records the last filled slot, honors Me.CombatAbilityCount, and reports hitting the 400-slot limit',
      fn = function()
          local function scan(slots, opts)
              opts = opts or {}
              local reads = 0
              local TLO = setmetatable({
                  Me = setmetatable({
                      CombatAbilityCount = opts.count and function() return opts.count end or nil,
                      CombatAbility = function(i)
                          reads = reads + 1
                          if opts.errors and opts.errors[i] then error('read error') end
                          local nm = slots[i]
                          if not nm then return nilNode() end
                          if opts.nameViaCall then return setmetatable({}, { __call = function() return nm end, __index = function() return nil end }) end
                          return setmetatable({ Name = function() return nm end }, { __call = function() return nm end })
                      end,
                  }, { __index = function() return nilNode() end }),
              }, { __index = function() return nilNode() end })
              local out
              U.withUnit(SCRIPT, function(u) out = u.scanKnownDisciplines() end, EXTRA6, { mq = { TLO = TLO } })
              return out, reads
          end
          local slots = {}
          for i = 1, 40 do slots[i] = 'Disc ' .. i end
          slots[7] = nil                                                   -- one gap, as observed
          local r, reads = scan(slots)
          eq(#r.names, 39, 'names found'); eq(r.lastSlot, 40, 'last filled slot'); eq(r.ended, 'empty-run', 'ended by the empty run')
          eq(r.emptySlots >= 60, true, 'the 60 empty slots after slot 40 are counted'); eq(r.readErrors, 0, 'no read errors'); eq(reads, 100, 'stopped 60 empties after the last filled slot (40 + 60)')
          r = scan(slots, { errors = { [3] = true, [4] = true } })
          eq(r.readErrors, 2, 'two raising reads counted apart'); eq(#r.names, 37, 'the other names are still read')
          r, reads = scan(slots, { count = 5 })
          eq(reads, 5, 'with a count available only that many slots are read'); eq(r.ended, 'count', 'ended by the count'); eq(#r.names, 5, 'five names')
          local full = {}
          for i = 1, 400 do full[i] = 'D' .. i end
          r = scan(full)
          eq(r.ended, 'limit', 'the 400-slot limit is reported'); eq(#r.names, 400, 'all 400 read')
          r = scan({ 'Via Call' }, { nameViaCall = true })
          eq(r.names[1], 'Via Call', 'a name read by calling the node when .Name is empty')
      end },

    { id = 'U44', kind = 'REQ', new = true, own = true, extra = EXTRA6, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-030 F\' / Revision 3 section 3.1: recovery re-reads the cursor and needs the exact tome there, needs a free slot, sends /autoinventory once and polls up to 10 times for an empty cursor',
      fn = function()
          local function run(cursorSeq, freeSlot)
              local cmds, polls = {}, 0
              local reads = 0
              local cursor = setmetatable({}, {
                  __call = function() reads = reads + 1; local v = cursorSeq(reads, #cmds); return v end,
                  __index = function(_, k) if k == 'Name' then return function() return cursorSeq(reads, #cmds) end end end,
              })
              local mqStub = {
                  TLO = setmetatable({ Cursor = cursor }, { __index = function() return nilNode() end }),
                  cmd = function(c) cmds[#cmds + 1] = c end, cmdf = function(f, ...) cmds[#cmds + 1] = string.format(f, ...) end,
                  delay = function() polls = polls + 1 end, doevents = function() end,
              }
              local result, detail
              U.withUnit(SCRIPT, function(u)
                  u.LOG.disabled = true
                  result, detail = u.recoverKnownTome('Tome of Bellow', function() return freeSlot and 1 or nil end)
              end, EXTRA6, { mq = mqStub })
              return result, detail, cmds, polls
          end
          local T = 'Tome of Bellow'
          local r, _, cmds = run(function(_, sent) if sent == 0 then return T end return nil end, true)
          eq(r, 'recovered', 'the cursor empties after the command'); eq(#cmds, 1, 'one command'); eq(cmds[1], '/autoinventory', 'the command')
          r, _, cmds = run(function() return nil end, true)
          eq(r, 'changed', 'the cursor was already empty at the recheck'); eq(#cmds, 0, 'no command is sent')
          r, _, cmds = run(function() return 'Mystery Bone' end, true)
          eq(r, 'changed', 'something else on the cursor'); eq(#cmds, 0, 'no command is sent')
          r, _, cmds = run(function() return T end, false)
          eq(r, 'no-room', 'no free slot'); eq(#cmds, 0, 'no command is sent')
          local r2, _, cmds2, polls = run(function() return T end, true)
          eq(r2, 'failed', 'the cursor never empties'); eq(#cmds2, 1, 'one command only'); eq(polls, 10, 'ten polls of 200 ms')
      end },

    { id = 'U16', kind = 'REQ', src = 'D-026 C\'\': a failing test body also leaves the process as found',
      fn = function()
          local before = U.save()
          local ok, err = pcall(U.withUnit, SCRIPT, function() error('body failure', 0) end)
          local clean = rawget(_G, 'SPELLSPREE_UNIT') == nil and _G.print == before.print and package.loaded.mq == before.loaded.mq
          U.restore(before)
          eq(ok, false, 'the failure is re-raised'); eq(err, 'body failure', 'the original error')
          eq(clean, true, 'state restored')
      end },
}

-- run the whole suite against a script path; returns { id = {pass=, msg=} }
local function evaluate(script)
    local res = {}
    for _, t in ipairs(TESTS) do
        local ok, err = pcall(function()
            if t.id == 'U13' or t.id == 'U14' or t.id == 'U15' or t.id == 'U16' or t.own then
                -- these call U.withUnit(SCRIPT, ...) themselves; point them at the script under test
                local real = SCRIPT
                SCRIPT = script
                local ok2, e2 = pcall(t.fn)
                SCRIPT = real
                if not ok2 then error(e2, 0) end
            else
                U.withUnit(script, t.fn, t.extra)
            end
        end)
        res[t.id] = { pass = ok, msg = (not ok) and tostring(err) or nil }
    end
    return res
end

-- exactly the named tests must fail for each deliberate defect (written before the first run)
local MUTATIONS = {
    { name = 'formatCoin no longer rounds to the nearest copper', fails = { 'U2' },
      from = 'copper = math.floor((tonumber(copper) or 0) + 0.5)', to = 'copper = math.floor((tonumber(copper) or 0))' },
    { name = 'the "Spell:" prefix no longer requires the space', fails = { 'U6' },
      from = "{ '^Spell:%s', '^Song:%s' }", to = "{ '^Spell:', '^Song:%s' }" },
    { name = 'an entry with no outcome is no longer detected by logLedger', fails = { 'U12' },
      from = '        if not e.outcome then\n            logLine(string.format(\'LEDGER DEFECT: "%s" ended', to = '        if false then\n            logLine(string.format(\'LEDGER DEFECT: "%s" ended' },
    { name = 'a second outcome overwrites the first', fails = { 'U9' },
      from = '    if entry.outcome then\n        logLine(string.format(\'LEDGER DEFECT: an outcome was recorded twice', to = '    if false then\n        logLine(string.format(\'LEDGER DEFECT: an outcome was recorded twice' },
    { name = 'the ledger counts line reports 0 for every outcome', fails = { 'U11' },
      from = "string.format('%s=%d', o, #groups[o])", to = "string.format('%s=%d', o, 0)" },
    -- Step 3 (D-025): sets written before the first run
    { name = 'a level at the low end of a range is no longer in range', fails = { 'U21' },
      from = "if n >= low and n <= high then", to = "if n > low and n <= high then" },
    { name = 'a level at the high end of a range is no longer in range', fails = { 'U21' },
      from = "if n >= low and n <= high then", to = "if n >= low and n < high then" },
    { name = 'unreadable text is treated as in range', fails = { 'U23' },
      from = "    return 'unreadable', string.format('level unreadable (\"%s\")', trimmed)", to = "    return 'in', ''" },
    { name = 'surrounding whitespace is no longer trimmed from the level text', fails = { 'U21', 'U23' },
      from = "local trimmed = tostring(levelText):match('^%s*(.-)%s*$')", to = "local trimmed = tostring(levelText)" },
    { name = 'the 1-70 bound is dropped from validateRange', fails = { 'U18', 'U20' },
      from = "if low < RANGE_MIN or high > RANGE_MAX then return false, string.format(", to = "if false then return false, string.format(" },
    { name = 'reversed endpoints are accepted by validateRange', fails = { 'U18', 'U20' },
      from = "    if low > high then return false, 'low is above high' end\n", to = "" },
    { name = 'off by one in the label parse (low + 1)', fails = { 'U17', 'U18' },
      from = "local range = { low = tonumber(a), high = tonumber(b) }", to = "local range = { low = tonumber(a) + 1, high = tonumber(b) }" },
    -- Step 5 (D-028): sets written before the first run
    { name = "logSyncIdentity never syncs", fails = { 'U26', 'U27', 'U28', 'U29', 'U30', 'U31', 'U32', 'U33', 'U35' },
      from = "    if LOG.syncing or LOG.disabled or not LOG.path then return end\n    local now = logClockMs()",
      to = "    do return end\n    local now = logClockMs()" },
    { name = "LOG.path is not cleared on a switch", fails = { 'U26', 'U28', 'U29', 'U30', 'U31', 'U32', 'U33' },
      from = "            LOG.path, LOG.identityKey, LOG.writes = nil, nil, 0",
      to = "            LOG.identityKey, LOG.writes = nil, 0" },
    { name = "LOG.writes is not reset on a switch", fails = { 'U26' },
      from = "            LOG.path, LOG.identityKey, LOG.writes = nil, nil, 0",
      to = "            LOG.path, LOG.identityKey = nil, nil" },
    { name = "the identity-changed line is not written", fails = { 'U26', 'U27', 'U28', 'U30', 'U33', 'U35' },
      from = "        logObs(string.format('identity changed: %s/%s -> %s/%s; %s',",
      to = "        local _ = (string.format('identity changed: %s/%s -> %s/%s; %s'," },
    { name = "an unreadable identity is not recognised (the script switches on it)", fails = { 'U29' },
      from = "        if logUnavailable(server) or logUnavailable(char) then",
      to = "        if false then" },
    { name = "the new file header is not marked as a continued session", fails = { 'U26', 'U27', 'U35' },
      from = "'session start (continued session): build=v%s source=%s load offset=+%dms'",
      to = "'session start: build=v%s source=%s load offset=+%dms'" },
    { name = "there is no recursion guard", fails = { 'U35' },
      from = "    if LOG.syncing or LOG.disabled or not LOG.path then return end",
      to = "    if LOG.disabled or not LOG.path then return end" },
    { name = "the destination is decided on the raw identity only (the same file is treated as a switch)", fails = { 'U27' },
      from = "        local sameFile = (key == LOG.identityKey)",
      to = "        local sameFile = false" },
    { name = "the path resolution reads the identity again instead of using the snapshot", fails = { 'U28', 'U35' },
      from = "    local snap = LOG.pendingIdentity\n",
      to = "    local snap = nil\n" },
    { name = "the success notice is written even after a failure", fails = { 'U30' },
      from = "        if not LOG.disabled and not sameFile then\n            logLine(string.format('Logging to a new file",
      to = "        if not sameFile then\n            logLine(string.format('Logging to a new file" },
    { name = "logFail is not idempotent", fails = { 'U34' },
      from = "    if LOG.disabled then return end -- D-028 B': one failure notice, however many failures follow\n",
      to = "" },
    { name = "detection is suppressed while a run holds the file", fails = { 'U32' },
      from = "        if LOG.hold then\n            local id = server",
      to = "        if LOG.hold then\n            do return end\n            local id = server" },
    { name = "logWriteFile no longer runs the throttled sync", fails = { 'U33' },
      from = "    -- D-028 A': the character may have changed since the last record; the sync is throttled and guarded against re-entry\n    logSyncIdentity(false)\n    if LOG.disabled then return end\n",
      to = "" },
    { name = 'markRemainingNotAttempted no longer skips entries that already have an outcome', fails = { 'U10' },
      from = 'if not entries[i].outcome then setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason) end', to = 'setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason)' },
}

local failures = 0
local function report(label, ok, detail)
    print(string.format('%-6s %s%s', ok and 'PASS' or 'FAIL', label, detail and (' -- ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

print('=== baseline: spellspree.lua through the unit-test hook ===')
local base = evaluate(SCRIPT)
for _, t in ipairs(TESTS) do report(t.id .. ' [' .. t.kind .. '] ' .. t.src, base[t.id].pass, base[t.id].msg) end

if arg[1] == 'stage' then
    -- D-025 F'': compare each new test's result with the result expected at this red-run stage (written before the run)
    local stage = tonumber(arg[2])
    local mismatches = 0
    for _, t in ipairs(TESTS) do
        if t.st then
            local got = base[t.id].pass and 'pass' or 'fail'
            local want = t.st[stage]
            local same = got == want
            if not same then mismatches = mismatches + 1 end
            print(string.format('%-4s %s expected %s, got %s%s', same and 'OK' or 'DIFF', t.id, want, got, (got == 'fail' and base[t.id].msg) and (' -- ' .. base[t.id].msg:sub(1, 140)) or ''))
        elseif not base[t.id].pass then
            mismatches = mismatches + 1
            print('DIFF ' .. t.id .. ' (an existing test) expected pass, got fail -- ' .. tostring(base[t.id].msg))
        end
    end
    print(string.format('\nstage %d: %d mismatch(es) against the expected table', stage, mismatches))
    os.exit(mismatches == 0 and 0 or 1)
end

if arg[1] == 'baseline' then
    print(string.format('\n%s: %d failure(s) (baseline only, mutations skipped)', failures == 0 and 'ALL OK' or 'NOT OK', failures))
    os.exit(failures == 0 and 0 or 1)
end

print('\n=== mutation checks: each broken build must fail exactly its named test(s) ===')
for i, m in ipairs(MUTATIONS) do
    local at = SOURCE:find(m.from, 1, true)
    if not at or SOURCE:find(m.from, at + 1, true) then
        report('mutation ' .. i .. ' ' .. m.name, false, 'mutation target not found exactly once in source')
    else
        local path = TMP .. '\\mutant_' .. i .. '.lua'
        writeAll(path, SOURCE:sub(1, at - 1) .. m.to .. SOURCE:sub(at + #m.from))
        local res = evaluate(path)
        local expected = {}
        for _, id in ipairs(m.fails) do expected[id] = true end
        local problems = {}
        for _, t in ipairs(TESTS) do
            local failed = not res[t.id].pass
            if expected[t.id] and not failed then problems[#problems + 1] = t.id .. ' should have failed but passed' end
            if not expected[t.id] and failed then problems[#problems + 1] = t.id .. ' failed unexpectedly (' .. tostring(res[t.id].msg) .. ')' end
        end
        report('mutation ' .. i .. ' ' .. m.name, #problems == 0, #problems > 0 and table.concat(problems, '; ') or ('caught by ' .. table.concat(m.fails, ',')))
    end
end

-- wrapper mutation (D-026 C''): a wrapper that loads and runs the chunk outside the protected call must fail the cleanup cases
do
    local weak = U.new('load-outside')
    local problems = cleanupProblems(weak, SCRIPT)
    local sawSyntax, sawInit = false, false
    for _, p in ipairs(problems) do
        if p:find('^syntax: left behind') then sawSyntax = true end
        if p:find('^initerr: left behind') then sawInit = true end
    end
    report('wrapper mutation: loading and running the chunk outside the protected call', sawSyntax and sawInit,
        (sawSyntax and sawInit) and 'caught by the syntax-error and initialization-error cases (U15)' or ('problems seen: ' .. table.concat(problems, '; ')))
end

print(string.format('\n%s: %d failure(s)', failures == 0 and 'ALL OK' or 'NOT OK', failures))
os.exit(failures == 0 and 0 or 1)
