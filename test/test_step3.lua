-- Tests for Step 3, purchases bounded by the selected level range (decision log D-025; design items A'-G, F'' test plan).
-- Run from the repo root:  luajit test/test_step3.lua            (baseline, then mutation checks)
--                          luajit test/test_step3.lua baseline   (baseline only)
--                          luajit test/test_step3.lua stage N    (compare with the expected results of red-run stage N, D-025 F'')
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, a model of MacroQuest and the vendor window. A pass proves the
-- script does what D-025 says against that model; it proves nothing about the live client (the live check is part of the combined
-- 1.6.0-test.4 delivery).
--
-- Labels (D-025 F''): each test is REQ or CHAR (is the expected value required by a decision, or does it only record existing behavior)
-- and NEW or REGRESSION (does it prove behavior that does not exist before Step 3, or preserve behavior that exists). `st[n]` is the
-- result expected at red-run stage n, written before that stage was run: 0 = unchanged script; 1 = new functions exposed as wrong stubs,
-- nothing wired; 2 = correct functions wired into visit collection and the range passed down, runSpellSpree not yet validating or
-- filtering; 3 = the full build. A correct passing test is never changed to make it fail.
--
-- Expected values come from the decision texts (R21, D-014 item I, R34, D-025) and from the mock's own record of what the script did
-- (sim.purchases, sim.buyClicks, sim.selectClicks, sim.cmds), never from running the script and pasting its output.
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = 'spellspree.lua'
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\step3'
local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')
local LOGNAME = 'spellspree_SimServer_Simtest.log'
mkdir(TMP)

-- ---------------------------------------------------------------- stock
-- Every Cleric vendor (and the Wizard's 1-25 vendor) sells the same stock, so that each visit's range decides what is bought. The levels
-- sit on both sides of every boundary: 0/1, 25/26, 50/51, 60/61, 70/71.
local function sp(name, level, extra)
    local o = { name = name, price = 100, level = level }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
local function stock()
    return { sp('B00', 0), sp('B01', 1), sp('B25', 25), sp('B26', 26), sp('B50', 50), sp('B51', 51), sp('B60', 60), sp('B61', 61), sp('B70', 70), sp('B71', 71) }
end
local function vendorsWith(spells)
    local function v(list) return { nonSpells = { 'Pickled Cat Food' }, spells = list } end
    return {
        ['Vicar Ceraen'] = v(spells()), ['Vicar Thiran'] = v(spells()), ['Vicar Delin'] = v(spells()), ['Vicar Diarin'] = v({}),
        ['Channeler Olaemos'] = v(spells()), ['Channeler Alyrianne'] = v({}),
    }
end
local function unreadableStock()
    return { sp('U_dash', nil), sp('U_blank', nil, { levelText = '' }), sp('U_word', nil, { levelText = 'abc' }), sp('U_missing', nil, { levelText = false }),
        sp('U_pad', nil, { levelText = ' 25 ' }), sp('U_trail', nil, { levelText = '25x' }), sp('E1', 10) }
end
-- eligible (E), outside (X) and unreadable (U) entries interleaved, for the early-stop scenarios (range 1-25)
local function mixedStock()
    return { sp('E1', 10), sp('X1', 63), sp('E2', 11), sp('U1', nil), sp('E3', 12), sp('X2', 30), sp('E4', 13), sp('E5', 14) }
end

-- the mock marks an event as done on the opts table it was given, so every run needs its own copy (a shared table made T16's event fire
-- only in the first run of the process; found by the mutation runs)
local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end

local function pok(extra, spells)
    return function(dir)
        local extra = deepcopy(extra)
        local o = { logsRaw = dir, rootRaw = dir, zone = 'poknowledge', clickPrefix = 'Run Shopping Spree', classes = { 'CLR' },
            openTrees = { Cleric = true }, vendors = vendorsWith(spells or stock) }
        for k, v in pairs(extra) do o[k] = v end
        return o
    end
end

local SCENARIOS = {
    r1     = pok({ ticks = { '1-25##Cleric' } }),
    r2     = pok({ ticks = { '26-50##Cleric' } }),
    r3     = pok({ ticks = { '51-60##Cleric' } }),
    r4     = pok({ ticks = { '61-70##Cleric' } }),
    all4   = pok({ ticks = { '##class_Cleric' } }),
    unread = pok({ ticks = { '1-25##Cleric' } }, unreadableStock),
    multi  = pok({ classes = { 'CLR', 'WIZ' }, openTrees = { Cleric = true, Wizard = true }, ticks = { '1-25##Cleric', '61-70##Wizard' } }),
    stopmoney = pok({ ticks = { '1-25##Cleric' }, money = 250 }, mixedStock),
    stopbtn   = pok({ ticks = { '1-25##Cleric' }, stopAtMs = 5000 }, mixedStock),
    vanish    = pok({ ticks = { '1-25##Cleric' }, events = { { atMs = 4300, kind = 'vanish', name = 'Spell: E4' } } }, mixedStock),
    scribefail = pok({ ticks = { '1-25##Cleric' }, scribeRejectFirst = 99 }, mixedStock),
    -- the Bazaar path: no zone, the "Buy From Open Vendor" button, no range, so everything (even odd levels) is bought
    bazaar = function(dir)
        local spells = stock()
        spells[#spells + 1] = sp('U_dash', nil)
        spells[#spells + 1] = sp('U_word', nil, { levelText = 'abc' })
        return { logsRaw = dir, rootRaw = dir, nonSpells = { 'Pickled Cat Food' }, spells = spells }
    end,
}

local function runScenario(script, name, mk)
    local dir = TMP .. '\\' .. name
    mkdir(dir)
    os.remove(dir .. '\\spellspree\\' .. LOGNAME)
    local sim = R.run(script, mk(dir))
    return { sim = sim, lines = R.readLines(dir .. '\\spellspree\\' .. LOGNAME) or {} }
end
local function runAll(script)
    local out = {}
    for name, mk in pairs(SCENARIOS) do out[name] = runScenario(script, name, mk) end
    return out
end

-- Runs a scenario on a modified copy of the script. `transform` changes the script text (it receives the text of the script under test).
local function runModified(tag, scenario, transform, adjust)
    local path = TMP .. '\\' .. tag .. '.lua'
    local f = assert(io.open(path, 'wb')); f:write(transform(SOURCE)); f:close()
    return runScenario(path, tag, function(dir)
        local o = SCENARIOS[scenario](dir)
        if adjust then adjust(o) end
        return o
    end)
end
local function replaceOnce(src, from, to)
    local at = src:find(from, 1, true)
    assert(at and not src:find(from, at + 1, true), 'transform target not found exactly once: ' .. from)
    return src:sub(1, at - 1) .. to .. src:sub(at + #from)
end
-- replaces the runSpellSpree(...) call inside runNavAndShop (the call is `runSpellSpree()` before Step 3 and `runSpellSpree(range)` after)
local function replaceSpreeCall(src, newCall)
    local a = src:find('local function runNavAndShop', 1, true)
    local b = a and src:find('\nlocal function ', a + 10, true)
    assert(a and b, 'runNavAndShop not found')
    local body, n = src:sub(a, b):gsub('runSpellSpree%b()', function() return newCall end)
    assert(n == 1, 'expected exactly one runSpellSpree call in runNavAndShop, found ' .. n)
    return src:sub(1, a - 1) .. body .. src:sub(b + 1)
end

-- ---------------------------------------------------------------- helpers
local function grep(lines, plain)
    local hits = {}
    for _, l in ipairs(lines or {}) do if l:find(plain, 1, true) then hits[#hits + 1] = l end end
    return hits
end
local function count(list, pred) local n = 0; for _, v in ipairs(list) do if pred(v) then n = n + 1 end end; return n end
local function cmdCount(sim, prefix) return count(sim.cmds, function(c) return c:sub(1, #prefix) == prefix end) end
local function setOf(list) local s = {}; for _, v in ipairs(list) do s[v] = (s[v] or 0) + 1 end; return s end
local function names(list) local t = {}; for _, n in ipairs(list) do t[#t + 1] = 'Spell: ' .. n end; return t end
local function show(t) return '[' .. table.concat(t, ', ') .. ']' end

-- the spells bought are exactly `want`, each once (the mock's own record)
local function boughtExactly(sim, want)
    local got = setOf(sim.purchases)
    local wantSet = setOf(names(want))
    for n in pairs(wantSet) do if got[n] ~= 1 then return false, string.format('"%s" was bought %d time(s), expected 1', n, got[n] or 0) end end
    for n, c in pairs(got) do if not wantSet[n] then return false, string.format('"%s" was bought (%d time(s)) but is not in %s', n, c, show(want)) end end
    return true
end
-- no select click and no Buy click ever landed on these
local function neverTouched(sim, list)
    for _, n in ipairs(names(list)) do
        if sim.selectClicks[n] or sim.buyClicks[n] then return false, string.format('"%s" was selected %s time(s) / Buy-clicked %s time(s)', n, tostring(sim.selectClicks[n] or 0), tostring(sim.buyClicks[n] or 0)) end
    end
    return true
end
local function all(...)
    for _, r in ipairs({ ... }) do
        local ok, why = r[1], r[2]
        if not ok then return false, why end
    end
    return true
end

local OUT_SCRIBED, OUT_NOSCRIBE, OUT_NOTBOUGHT, OUT_SKIPPED, OUT_STOP =
    'bought and scribed', 'bought, scribe not completed', 'attempted, not bought', 'deliberately skipped', 'not attempted because the run stopped'
-- the last ledger of the run's log: N, { label = count }
local function ledger(lines)
    local n, counts
    for _, l in ipairs(lines) do
        local a, rest = l:match('Outcome ledger %((%d+) built%-list entries%): (.-)%.$')
        if a then
            n, counts = tonumber(a), {}
            for label, c in rest:gmatch('([^;=]+)=(%d+)') do counts[(label:gsub('^%s+', ''))] = tonumber(c) end
        end
    end
    return n, counts
end
local function ledgerLine(lines, label, n)
    for _, l in ipairs(lines) do if l:find(string.format('  %s (%d): ', label, n), 1, true) then return l end end
end

-- the refusal checks for a visit that must buy nothing and must be refused by range validation (not by a missing vendor mapping)
local function refusedByRange(r, reasonText, mustName, visited)
    local errs = grep(r.lines, '| ERROR ')
    local found
    for _, l in ipairs(errs) do
        if l:find(reasonText, 1, true) then
            local okAll = true
            for _, m in ipairs(mustName) do if not l:find(m, 1, true) then okAll = false end end
            if okAll then found = l end
        end
    end
    local sim = r.sim
    local problems = {}
    if not found then problems[#problems + 1] = 'no ERROR line with "' .. reasonText .. '" naming ' .. table.concat(mustName, ' and ') end
    if #grep(r.lines, 'No vendor is configured') ~= 0 then problems[#problems + 1] = 'the refusal came from the missing-vendor-mapping check, not from range validation' end
    if next(sim.buyClicks) then problems[#problems + 1] = 'a Buy click was sent' end
    if next(sim.selectClicks) then problems[#problems + 1] = 'a select click was sent' end
    if #sim.purchases ~= 0 then problems[#problems + 1] = #sim.purchases .. ' purchase(s) were made' end
    if not visited then
        if cmdCount(sim, '/nav') ~= 0 or cmdCount(sim, '/target npc') ~= 0 then problems[#problems + 1] = 'the script navigated or targeted a vendor' end
    end
    if not sim.ok then problems[#problems + 1] = 'the script chunk did not finish: ' .. tostring(sim.runErr) end
    if sim.endedBy == 'guard' or sim.endedBy == 'error' then problems[#problems + 1] = 'the run did not end normally (endedBy=' .. tostring(sim.endedBy) .. ')' end
    if #problems > 0 then return false, table.concat(problems, '; ') end
    return true
end

local function tierTransform(from, to, mapFrom, mapTo)
    return function(src)
        src = replaceOnce(src, "local TIERS = { '1-25', '26-50', '51-60', '61-70' }", to)
        return replaceOnce(src, mapFrom, mapTo)
    end
end

local MIXED_SKIPS = { 'Spell: X1 (outside the selected level range 1-25 (Lvl 63))', 'Spell: U1 (level unreadable ("--"))', 'Spell: X2 (outside the selected level range 1-25 (Lvl 30))' }
-- `purchaseSkips` is the list of names the EXISTING purchase-time logic skips and counts (here: the first unaffordable item in the
-- out-of-money scenario, see the not-paid branch of processEntry that increments S.skipped); the range skips must never be among them.
-- (My first version of this check expected 0 for the money scenario, a mistake about existing behavior found at Stage 3; the value now
-- comes from that code, not from the run.)
local function mixedCommon(r, purchaseSkips)
    purchaseSkips = purchaseSkips or {}
    -- the preclassified skips keep their reasons, are never selected or clicked, and are not in the skipped counter or its names
    local line = ledgerLine(r.lines, OUT_SKIPPED, 3) or ledgerLine(r.lines, OUT_SKIPPED, 4)
    if not line then return false, 'no "deliberately skipped" ledger line' end
    for _, want in ipairs(MIXED_SKIPS) do
        if not line:find(want, 1, true) then return false, 'the skipped line lacks: ' .. want end
    end
    local ok, why = neverTouched(r.sim, { 'X1', 'U1', 'X2' })
    if not ok then return false, why end
    if #grep(r.lines, 'LEDGER DEFECT') ~= 0 then return false, 'a LEDGER DEFECT was logged' end
    local o = grep(r.lines, 'Run outcome (Nav & Shop "Vicar Ceraen")')
    local want = 'skipped=' .. #purchaseSkips .. ','
    if #o ~= 1 or not o[1]:find(want, 1, true) then return false, 'the run outcome line should report ' .. want .. ' ' .. tostring(o[1]) end
    local summary = (#purchaseSkips == 0) and 'Skipped (0): none' or ('Skipped (' .. #purchaseSkips .. '): ' .. table.concat(purchaseSkips, ', '))
    if #grep(r.lines, summary) ~= 1 then return false, 'the final Skipped summary should be "' .. summary .. '"' end
    return true
end

-- ---------------------------------------------------------------- tests
local function T(id, kind, label, st, src, fn) return { id = id, kind = kind, new = label == 'NEW', label = label, st = st, src = src, fn = fn } end
local F, P = 'fail', 'pass'
local FFFP = { [0] = F, [1] = F, [2] = F, [3] = P }
local ALLP = { [0] = P, [1] = P, [2] = P, [3] = P }

local TESTS = {
    T('T1', 'REQ', 'NEW', FFFP, 'R21 / R34: a 1-25 visit buys exactly levels 1 and 25 and never selects or clicks levels 0, 26, 50, 51, 60, 61, 70, 71',
      function(c) return all({ boughtExactly(c.r1.sim, { 'B01', 'B25' }) }, { neverTouched(c.r1.sim, { 'B00', 'B26', 'B50', 'B51', 'B60', 'B61', 'B70', 'B71' }) }) end),

    T('T2', 'REQ', 'NEW', FFFP, 'R21 / R34: a 26-50 visit buys exactly levels 26 and 50 (the endpoints) and nothing at 25 or 51',
      function(c) return all({ boughtExactly(c.r2.sim, { 'B26', 'B50' }) }, { neverTouched(c.r2.sim, { 'B00', 'B01', 'B25', 'B51', 'B60', 'B61', 'B70', 'B71' }) }) end),

    T('T3', 'REQ', 'NEW', FFFP, 'R21 / R34: a 51-60 visit buys exactly levels 51 and 60 and nothing at 50 or 61',
      function(c) return all({ boughtExactly(c.r3.sim, { 'B51', 'B60' }) }, { neverTouched(c.r3.sim, { 'B00', 'B01', 'B25', 'B26', 'B50', 'B61', 'B70', 'B71' }) }) end),

    T('T4', 'REQ', 'NEW', FFFP, 'R21 / R34: a 61-70 visit buys exactly levels 61 and 70 and nothing at 60 or 71; levels 0 and above 70 are never bought',
      function(c) return all({ boughtExactly(c.r4.sim, { 'B61', 'B70' }) }, { neverTouched(c.r4.sim, { 'B00', 'B01', 'B25', 'B26', 'B50', 'B51', 'B60', 'B71' }) }) end),

    T('T5', 'REQ', 'NEW', FFFP, 'R34: with all four ranges ticked each visit buys only its own range (1-25 then 61-70 at the same vendor): 8 spells, each once, nothing in 0 or above 70, 2 bought per visit',
      function(c)
          local r = c.all4
          local ok, why = all({ boughtExactly(r.sim, { 'B01', 'B25', 'B26', 'B50', 'B51', 'B60', 'B61', 'B70' }) }, { neverTouched(r.sim, { 'B00', 'B71' }) })
          if not ok then return false, why end
          local outs = grep(r.lines, 'Run outcome (Nav & Shop')
          if #outs ~= 4 then return false, 'expected 4 visits, saw ' .. #outs end
          for i, l in ipairs(outs) do if not l:find('This vendor: bought=2,', 1, true) then return false, 'visit ' .. i .. ' did not buy exactly 2: ' .. l end end
          return true
      end),

    T('T6', 'REQ', 'NEW', FFFP, 'D-014 item I / D-025 B: unreadable levels (--, blank, words, a missing cell, trailing characters) are not bought, never selected, and each is logged with its raw text; a padded " 25 " is read as 25 and bought',
      function(c)
          local r = c.unread
          local ok, why = all({ boughtExactly(r.sim, { 'U_pad', 'E1' }) }, { neverTouched(r.sim, { 'U_dash', 'U_blank', 'U_word', 'U_missing', 'U_trail' }) })
          if not ok then return false, why end
          local line = ledgerLine(r.lines, OUT_SKIPPED, 5)
          if not line then return false, 'no "deliberately skipped (5)" ledger line' end
          for _, want in ipairs({ 'U_dash (level unreadable ("--"))', 'U_blank (level unreadable (""))', 'U_word (level unreadable ("abc"))',
              'U_missing (level unreadable (no value))', 'U_trail (level unreadable ("25x"))' }) do
              if not line:find(want, 1, true) then return false, 'the skipped line lacks: ' .. want end
          end
          return true
      end),

    T('T7', 'REQ', 'NEW', FFFP, 'R34: a multi-class selection applies each class\'s own range at its own vendor (Cleric 1-25 at Vicar Ceraen, Wizard 61-70 at Channeler Olaemos)',
      function(c)
          local r = c.multi
          local ok, why = boughtExactly(r.sim, { 'B01', 'B25', 'B61', 'B70' })
          if not ok then return false, why end
          local at = r.sim.purchasesByVendor
          local function sameSet(got, want)
              local g, w = setOf(got or {}), setOf(names(want))
              for n in pairs(w) do if g[n] ~= 1 then return false end end
              for n in pairs(g) do if not w[n] then return false end end
              return true
          end
          if not sameSet(at['Vicar Ceraen'], { 'B01', 'B25' }) then return false, 'Vicar Ceraen sold ' .. show(at['Vicar Ceraen'] or {}) end
          if not sameSet(at['Channeler Olaemos'], { 'B61', 'B70' }) then return false, 'Channeler Olaemos sold ' .. show(at['Channeler Olaemos'] or {}) end
          return true
      end),

    T('T8', 'REQ', 'NEW', { [0] = F, [1] = F, [2] = P, [3] = P }, 'D-025 A\' (Revision 3): a ticked tier whose label parses outside 1-70 ("61-80", vendor mapping intact) is refused with an ERROR naming the class, the label and the reason, and nothing is navigated to, targeted or bought; the missing-mapping WARN is not what stopped it',
      function()
          local r = runModified('label8061', 'r4', function(src)
              src = replaceOnce(src, "local TIERS = { '1-25', '26-50', '51-60', '61-70' }", "local TIERS = { '1-25', '26-50', '51-60', '61-80' }")
              return replaceOnce(src, "    ['61-70'] = '1-25',\n", "    ['61-80'] = '1-25',\n")
          end, function(o) o.ticks = { '61-80##Cleric' } end)
          return refusedByRange(r, 'Invalid level range', { 'Cleric', '61-80' }, false)
      end),

    T('T9', 'REQ', 'NEW', { [0] = F, [1] = F, [2] = P, [3] = P }, 'D-025 A\': a ticked tier whose label does not parse at all ("abc", mapping intact) is refused the same way, with an ERROR naming it',
      function()
          local path = TMP .. '\\labelabc.lua'
          local src = replaceOnce(SOURCE, "local TIERS = { '1-25', '26-50', '51-60', '61-70' }", "local TIERS = { '1-25', 'abc', '51-60', '61-70' }")
          src = replaceOnce(src, "    ['26-50'] = '26-50',\n", "    ['abc'] = '26-50',\n")
          local f = assert(io.open(path, 'wb')); f:write(src); f:close()
          return refusedByRange(runScenario(path, 'labelabc', function(dir)
              local o = SCENARIOS.r2(dir); o.ticks = { 'abc##Cleric' }; return o
          end), 'Invalid level range', { 'Cleric', 'abc' }, false)
      end),

    T('T10', 'REQ', 'NEW', FFFP, 'D-025 D: runSpellSpree called with no range (a caller that forgot to pass it) is refused before the list is read: ERROR "No level range", nothing selected or bought',
      function()
          local r = runModified('noarg', 'r1', function(src) return replaceSpreeCall(src, 'runSpellSpree()') end)
          return refusedByRange(r, 'No level range', { 'No level range' }, true)
      end),

    T('T11', 'REQ', 'NEW', FFFP, 'D-025 A\' / D: runSpellSpree called with a range whose endpoints are reversed is refused: ERROR "Invalid level range", nothing selected or bought',
      function()
          local r = runModified('reversed', 'r1', function(src) return replaceSpreeCall(src, "runSpellSpree({ low = 25, high = 1, label = '25-1' })") end)
          return refusedByRange(r, 'Invalid level range', { 'Invalid level range' }, true)
      end),

    T('T12', 'REQ', 'NEW', FFFP, 'D-025 A\' (Revision 3): runSpellSpree called with a range that reaches above 70 (1-80) is refused: ERROR "Invalid level range", nothing selected or bought',
      function()
          local r = runModified('high80', 'r1', function(src) return replaceSpreeCall(src, "runSpellSpree({ low = 1, high = 80, label = '1-80' })") end)
          return refusedByRange(r, 'Invalid level range', { 'Invalid level range' }, true)
      end),

    T('T13', 'CHAR', 'REGRESSION', ALLP, 'D-025 D / spec: the Bazaar path has no range and buys every scroll the open vendor sells, whatever its level text (0, 71, --, words)',
      function(c)
          local r = c.bazaar
          return boughtExactly(r.sim, { 'B00', 'B01', 'B25', 'B26', 'B50', 'B51', 'B60', 'B61', 'B70', 'B71', 'U_dash', 'U_word' })
      end),

    T('T14', 'REQ', 'NEW', FFFP, 'D-025 C / F\'\' outcomes 3-5: out of money partway through a mixed list: 2 bought, 2 attempted not bought, 1 not attempted; the 3 preclassified skips keep their reasons, are never touched, and are not in the Skipped counter or names',
      function(c)
          local r = c.stopmoney
          local n, counts = ledger(r.lines)
          if n ~= 8 then return false, 'expected 8 built-list entries, saw ' .. tostring(n) end
          if counts[OUT_SCRIBED] ~= 2 or counts[OUT_NOTBOUGHT] ~= 2 or counts[OUT_STOP] ~= 1 or counts[OUT_SKIPPED] ~= 3 then
              return false, string.format('counts: scribed=%s not bought=%s not attempted=%s skipped=%s (expected 2/2/1/3)', tostring(counts[OUT_SCRIBED]), tostring(counts[OUT_NOTBOUGHT]), tostring(counts[OUT_STOP]), tostring(counts[OUT_SKIPPED]))
          end
          local stopLine = ledgerLine(r.lines, OUT_STOP, 1)
          if not stopLine or not stopLine:find('Spell: E5 (Probably not enough money', 1, true) then return false, 'E5 should be not attempted with the stop reason: ' .. tostring(stopLine) end
          return mixedCommon(r, { 'Spell: E3' })
      end),

    T('T15', 'REQ', 'NEW', FFFP, 'D-025 C / F\'\' outcome 5: the Stop button partway through a mixed list: bought entries before it, eligible entries after it "not attempted: Stopped by user", the 3 preclassified skips keep their reasons; the ledger adds up',
      function(c)
          local r = c.stopbtn
          local n, counts = ledger(r.lines)
          if n ~= 8 then return false, 'expected 8 built-list entries, saw ' .. tostring(n) end
          if (counts[OUT_SCRIBED] or 0) < 1 then return false, 'nothing was bought before the stop (the stop time no longer falls partway)' end
          if (counts[OUT_STOP] or 0) < 1 then return false, 'nothing was left not attempted (the stop time no longer falls partway)' end
          if counts[OUT_SKIPPED] ~= 3 then return false, 'expected 3 skipped, saw ' .. tostring(counts[OUT_SKIPPED]) end
          local sum = 0; for _, v in pairs(counts) do sum = sum + v end
          if sum ~= n then return false, 'the counts add up to ' .. sum .. ', not ' .. n end
          local stopLine = ledgerLine(r.lines, OUT_STOP, counts[OUT_STOP])
          if not stopLine or not stopLine:find('(Stopped by user)', 1, true) then return false, 'the not-attempted entries should carry "Stopped by user": ' .. tostring(stopLine) end
          if stopLine:find('Spell: X', 1, true) or stopLine:find('Spell: U', 1, true) then return false, 'a preclassified entry was relabelled "not attempted"' end
          return mixedCommon(r)
      end),

    T('T16', 'REQ', 'NEW', FFFP, 'D-017 D with a range applied: an eligible row that vanishes before it is reached is "deliberately skipped: row gone at lookup", the other eligible entries are bought, the 3 preclassified skips keep their reasons',
      function(c)
          local r = c.vanish
          local n, counts = ledger(r.lines)
          if n ~= 8 then return false, 'expected 8 built-list entries, saw ' .. tostring(n) end
          if counts[OUT_SCRIBED] ~= 4 or counts[OUT_SKIPPED] ~= 4 then
              return false, string.format('counts: scribed=%s skipped=%s (expected 4 and 4)', tostring(counts[OUT_SCRIBED]), tostring(counts[OUT_SKIPPED]))
          end
          local line = ledgerLine(r.lines, OUT_SKIPPED, 4)
          if not line or not line:find('Spell: E4 (row gone at lookup)', 1, true) then return false, 'E4 should be skipped as gone at lookup: ' .. tostring(line) end
          local ok, why = boughtExactly(r.sim, { 'E1', 'E2', 'E3', 'E5' })
          if not ok then return false, why end
          return neverTouched(r.sim, { 'X1', 'U1', 'X2' })
      end),

    T('T17', 'REQ', 'NEW', FFFP, 'D-017 F\'\' outcome 2 with a range applied: a scribe that never completes stops the run after the first eligible purchase; the other 4 eligible entries are not attempted; the 3 preclassified skips keep their reasons',
      function(c)
          local r = c.scribefail
          local n, counts = ledger(r.lines)
          if n ~= 8 then return false, 'expected 8 built-list entries, saw ' .. tostring(n) end
          if counts[OUT_NOSCRIBE] ~= 1 or counts[OUT_STOP] ~= 4 or counts[OUT_SKIPPED] ~= 3 then
              return false, string.format('counts: scribe not completed=%s not attempted=%s skipped=%s (expected 1/4/3)', tostring(counts[OUT_NOSCRIBE]), tostring(counts[OUT_STOP]), tostring(counts[OUT_SKIPPED]))
          end
          local line = ledgerLine(r.lines, OUT_SKIPPED, 3)
          if not line then return false, 'no skipped line' end
          -- also: no LEDGER DEFECT, skipped=0 and "Skipped (0): none" (the stop at the first eligible entry leaves every preclassified entry
          -- to markRemainingNotAttempted, so this is where relabelling would show). Added after the mutation runs showed T17 did not check them.
          return mixedCommon(r)
      end),

    T('T18', 'REQ', 'REGRESSION', ALLP, 'D-014 F\'\' (a): in every scenario that builds a list, every entry ends with exactly one outcome, the counts add up, and no LEDGER DEFECT or "NO OUTCOME RECORDED" appears',
      function(c)
          local seen = 0
          for name, r in pairs(c) do
              local n, counts = ledger(r.lines)
              if n then
                  seen = seen + 1
                  local sum = 0; for _, v in pairs(counts) do sum = sum + v end
                  if sum ~= n then return false, string.format('%s: ledger counts add up to %d, built %d', name, sum, n) end
                  if (counts['NO OUTCOME RECORDED'] or 0) ~= 0 then return false, name .. ': an entry has no recorded outcome' end
                  if #grep(r.lines, 'LEDGER DEFECT') ~= 0 then return false, name .. ': LEDGER DEFECT logged' end
              end
          end
          if seen < 8 then return false, 'only ' .. seen .. ' scenarios built a list' end
          return true
      end),

    T('T19', 'REQ', 'NEW', FFFP, 'D-025 E: when the list is built one [list] line states the visit\'s range and the counts (in range, outside, unreadable); the Bazaar says it has no range',
      function(c)
          local a = grep(c.r1.lines, '[list] Level range 1-25 (ticked tier 1-25): 2 in range, 8 outside, 0 unreadable.')
          if #a ~= 1 then return false, 'expected one range line for the 1-25 visit, saw ' .. #a end
          local u = grep(c.unread.lines, '[list] Level range 1-25 (ticked tier 1-25): 2 in range, 0 outside, 5 unreadable.')
          if #u ~= 1 then return false, 'expected one range line for the unreadable scenario, saw ' .. #u end
          local b = grep(c.bazaar.lines, '[list] No level range for this visit (Bazaar): every scroll the vendor sells is eligible.')
          if #b ~= 1 then return false, 'expected one no-range line for the Bazaar, saw ' .. #b end
          return true
      end),

    T('T20', 'REQ', 'NEW', FFFP, 'D-025 E: range skips are ledger outcomes only: in the 1-25 visit 8 entries are "deliberately skipped" while the run outcome line reports skipped=0 and the final summary is "Skipped (0): none"',
      function(c)
          local r = c.r1
          local n, counts = ledger(r.lines)
          if counts == nil or counts[OUT_SKIPPED] ~= 8 then return false, 'expected 8 deliberately skipped, saw ' .. tostring(counts and counts[OUT_SKIPPED]) end
          local o = grep(r.lines, 'Run outcome (Nav & Shop "Vicar Ceraen")')
          if #o ~= 1 or not o[1]:find('skipped=0', 1, true) then return false, 'the run outcome line should report skipped=0: ' .. tostring(o[1]) end
          if #grep(r.lines, 'Skipped (0): none') ~= 1 then return false, 'the final Skipped summary should be "Skipped (0): none"' end
          return true
      end),

    T('T21', 'REQ', 'NEW', FFFP, 'D-025 E: the final scan reports out-of-range leftovers as a count, without repeating their names',
      function(c)
          local fs = grep(c.r1.lines, 'Final scan (log only, bought nothing)')
          if #fs ~= 1 then return false, 'expected one final scan line, saw ' .. #fs end
          if not fs[1]:find('Rows still listed for entries skipped as outside the level range: 8.', 1, true) then return false, 'the count of out-of-range rows is missing: ' .. fs[1] end
          if fs[1]:find('B26', 1, true) or fs[1]:find('B71', 1, true) then return false, 'the final scan repeats out-of-range names: ' .. fs[1] end
          return true
      end),
}

local function evaluate(script)
    local c = runAll(script)
    local res = {}
    for _, t in ipairs(TESTS) do
        local ok, a, b = pcall(t.fn, c)
        if not ok then res[t.id] = { pass = false, msg = 'test errored: ' .. tostring(a) }
        else res[t.id] = { pass = a == true, msg = b } end
    end
    return res
end

-- ---------------------------------------------------------------- mutations (filled in after the build; expected sets are written before the first run)
-- Written BEFORE the first mutation run (D-025 F''): the tests each broken build must fail. All sets are from reading what each test
-- asserts, not from a run.
local ALL_BUYERS = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T14', 'T15', 'T16', 'T17', 'T19', 'T20', 'T21' } -- every test that counts what a visit buys
local function without(list, drop)
    local d, out = {}, {}
    for _, v in ipairs(drop) do d[v] = true end
    for _, v in ipairs(list) do if not d[v] then out[#out + 1] = v end end
    return out
end
local MUTATIONS = {
    { name = 'low boundary is exclusive (n > low)', fails = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T7', 'T19', 'T20', 'T21' },
      from = "if n >= low and n <= high then", to = "if n > low and n <= high then" },
    { name = 'high boundary is exclusive (n < high)', fails = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T19', 'T20', 'T21' },
      from = "if n >= low and n <= high then", to = "if n >= low and n < high then" },
    { name = 'the range\'s low and high are swapped in the classification call', fails = ALL_BUYERS,
      from = "classifyLevel(e.levelText, range.low, range.high)", to = "classifyLevel(e.levelText, range.high, range.low)" },
    { name = 'an unreadable level counts as in range', fails = { 'T6', 'T14', 'T15', 'T16', 'T17', 'T19' },
      from = "    return 'unreadable', string.format('level unreadable (\"%s\")', trimmed)", to = "    return 'in', ''" },
    { name = 'the Bazaar is given a range (1-25)', fails = { 'T13', 'T19' },
      from = "runSpellSpree({ unrestricted = true })", to = "runSpellSpree({ low = 1, high = 25, label = '1-25' })" },
    -- T14, T15, T17 also fail: the reason text names the range ("outside the selected level range 2-25"), which my first prediction missed
    { name = 'off by one in the label parse (low + 1)', fails = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T7', 'T14', 'T15', 'T17', 'T19', 'T20', 'T21' },
      from = "local range = { low = tonumber(a), high = tonumber(b) }", to = "local range = { low = tonumber(a) + 1, high = tonumber(b) }" },
    -- the bypassed-filtering mutations (D-025 F''): the purchase-counting scenarios must catch them, not only the unit tests
    { name = 'classifyLevel says "in" for everything', fails = ALL_BUYERS,
      from = "    if levelText == nil then return 'unreadable', 'level unreadable (no value)' end", to = "    do return 'in', '' end\n    if levelText == nil then return 'unreadable', 'level unreadable (no value)' end" },
    { name = 'the range is not passed from the visit to runSpellSpree', fails = without({ 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T14', 'T15', 'T16', 'T17', 'T18', 'T19', 'T20', 'T21' }, {}),
      from = "runNavAndShop(entry.name, entry.range)", to = "runNavAndShop(entry.name)" },
    { name = 'the 1-70 bound is dropped (both validation points share the function)', fails = { 'T8', 'T12' },
      from = "if low < RANGE_MIN or high > RANGE_MAX then return false, string.format(", to = "if false then return false, string.format(" },
    { name = 'the 1-70 bound is dropped at the label parse only', fails = { 'T8' },
      from = "\n    local ok, why = validateRange(range)\n    if not ok then return nil, why end\n", to = "\n    local ok, why = true, nil\n    if not ok then return nil, why end\n" },
    { name = 'runSpellSpree no longer validates the range it receives', fails = { 'T11', 'T12' },
      from = "            local ok, why = validateRange(range)\n            if not ok then\n                refusal = 'Invalid level range'", to = "            local ok, why = true, nil\n            if not ok then\n                refusal = 'Invalid level range'" },
    -- T17 is not in this set: its stop comes at the first eligible entry, before any preclassified entry is reached (my first prediction missed that)
    { name = 'entries classified before the loop are processed anyway', fails = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T14', 'T15', 'T16', 'T18' },
      from = "        if entry.outcome then\n            -- already classified", to = "        if false then\n            -- already classified" },
    -- T14 is not in this set: its only entry after the stop is eligible, so nothing preclassified is touched (my first prediction missed that)
    { name = 'markRemainingNotAttempted no longer skips entries that already have an outcome', fails = { 'T15', 'T17', 'T18' },
      from = "if not entries[i].outcome then setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason) end", to = "setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason)" },
    { name = 'range skips are also counted in S.skipped and S.skippedNames', fails = { 'T14', 'T15', 'T17', 'T20' },
      from = "                setOutcome(e, OUTCOME.SKIPPED, reason)\n            end\n        end\n        logLine(string.format('[list] Level range",
      to = "                setOutcome(e, OUTCOME.SKIPPED, reason)\n                S.skipped = S.skipped + 1; table.insert(S.skippedNames, e.name)\n            end\n        end\n        logLine(string.format('[list] Level range" },
}

local failures = 0
local function report(label, ok, detail)
    print(string.format('%-6s %s%s', ok and 'PASS' or 'FAIL', label, detail and (' -- ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

print('=== baseline: spellspree.lua against the simulated MQ ===')
local base = evaluate(SCRIPT)
for _, t in ipairs(TESTS) do report(string.format('%s [%s, %s] %s', t.id, t.kind, t.label, t.src), base[t.id].pass, base[t.id].msg) end

if arg[1] == 'stage' then
    local stage = tonumber(arg[2])
    local mismatches = 0
    for _, t in ipairs(TESTS) do
        local got = base[t.id].pass and 'pass' or 'fail'
        local want = t.st[stage]
        local same = got == want
        if not same then mismatches = mismatches + 1 end
        print(string.format('%-4s %s expected %s, got %s%s', same and 'OK' or 'DIFF', t.id, want, got, (got == 'fail' and base[t.id].msg) and (' -- ' .. base[t.id].msg:sub(1, 150)) or ''))
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
        local mutated = SOURCE:sub(1, at - 1) .. m.to .. SOURCE:sub(at + #m.from)
        local path = TMP .. '\\mutant_' .. i .. '.lua'
        local f = assert(io.open(path, 'wb')); f:write(mutated); f:close()
        local realSource = SOURCE
        SOURCE = mutated
        local ok, res = pcall(evaluate, path)
        SOURCE = realSource
        if not ok then
            report('mutation ' .. i .. ' ' .. m.name, false, 'harness error: ' .. tostring(res))
        else
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
end

print(string.format('\n%s: %d failure(s)', failures == 0 and 'ALL OK' or 'NOT OK', failures))
os.exit(failures == 0 and 0 or 1)
