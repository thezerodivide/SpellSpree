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

local SCRIPT = 'spellspree.lua'
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

    -- ---- Step 3 (D-025). `kind` is REQ/CHAR; `new` marks behavior that does not exist before Step 3; `st[n]` is the result expected at
    -- red-run stage n (D-025 F''), written before the stage was run: 0 = no new exports, 1 = wrong stubs (parseTierRange returns nil,
    -- classifyLevel returns "in", validateRange accepts everything), 2 and 3 = correct functions.
    { id = 'U17', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
      src = 'D-025 A\': the four real tier labels parse to their inclusive ranges, and a label whose endpoints are equal is a valid range',
      fn = function(u)
          local function chk(label, lo, hi)
              local a, b = u.parseTierRange(label)
              eq(a, lo, label .. ' low'); eq(b, hi, label .. ' high')
          end
          chk('1-25', 1, 25); chk('26-50', 26, 50); chk('51-60', 51, 60); chk('61-70', 61, 70)
          chk('25-25', 25, 25); chk('1-70', 1, 70)
      end },

    { id = 'U18', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'pass', [2] = 'pass', [3] = 'pass' },
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

    { id = 'U19', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'pass', [2] = 'pass', [3] = 'pass' },
      src = 'D-025 A\' (Revision 3): validateRange accepts a table whose low and high are whole numbers with 1 <= low <= high <= 70',
      fn = function(u)
          for _, r in ipairs({ { low = 1, high = 25 }, { low = 61, high = 70 }, { low = 25, high = 25 }, { low = 1, high = 70 } }) do
              eq((u.validateRange(r)), true, r.low .. '-' .. r.high .. ' is valid')
          end
      end },

    { id = 'U20', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
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

    { id = 'U21', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'pass', [2] = 'pass', [3] = 'pass' },
      src = 'D-025 B / R21: levels inside the range, inclusive of both endpoints, are "in" (padded text counts: " 25 " and a tab)',
      fn = function(u)
          for _, c in ipairs({ { '1', 1, 25 }, { '25', 1, 25 }, { '26', 26, 50 }, { '50', 26, 50 }, { '51', 51, 60 }, { '60', 51, 60 },
              { '61', 61, 70 }, { '70', 61, 70 }, { ' 25 ', 1, 25 }, { '\t25', 1, 25 }, { ' 25', 1, 25 }, { '007', 1, 25 } }) do
              eq((u.classifyLevel(c[1], c[2], c[3])), 'in', string.format('%q in %d-%d', c[1], c[2], c[3]))
          end
      end },

    { id = 'U22', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
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

    { id = 'U23', kind = 'REQ', new = true, extra = EXTRA3, st = { [0] = 'fail', [1] = 'fail', [2] = 'pass', [3] = 'pass' },
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
            if t.id == 'U13' or t.id == 'U14' or t.id == 'U15' or t.id == 'U16' then
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
