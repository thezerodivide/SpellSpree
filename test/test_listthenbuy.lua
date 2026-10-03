-- Tests for Step 1, list-then-buy (decision log D-017; design D-014 items A'-K, F'' and H').
-- Run from the repo root:  luajit test/test_listthenbuy.lua
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, a model of MacroQuest and of the
-- vendor window built from what the live logs showed (rows leaving the list late and unprompted, a partial
-- list right after open, ...). A pass proves the script does what D-017 says against that model; it proves
-- nothing about the live client.
--
-- Every test cites the source of its expected value in `src` (Development Protocol section 7): a D-017 item
-- or a decision-log entry. Expected values come from those texts and from the mock's own independent record
-- (sim.purchases, sim.buyClicks, sim.cmds), never from running the script and pasting its output.
--
-- After the baseline run each MUTATION breaks the script on purpose and the harness checks that exactly the
-- named test(s) fail (section 7: prove a test can fail for the right reason).
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = 'spellspree.lua'
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\listthenbuy'

local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')
local LOGNAME = 'spellspree_SimServer_Simtest.log'

local FIVE = {
    { name = 'Alpha', price = 100, level = 10 }, { name = 'Beta', price = 100, level = 20 },
    { name = 'Gamma', price = 100, level = 25 }, { name = 'Delta', price = 100, level = 40 },
    { name = 'Epsilon', price = 100, level = 50 },
}
local function copy(t) local o = {}; for i, v in ipairs(t) do o[i] = v end; return o end
local function base(dir, extra)
    local o = { logsRaw = dir, rootRaw = dir, nonSpells = { 'Pickled Cat Food', 'Blue Diamond' }, spells = copy(FIVE) }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end

local SCENARIOS = {
    base       = function(d) return base(d, { reorderAfterBuy = true }) end,
    vanish     = function(d) return base(d, { reorderAfterBuy = true, events = { { atMs = 4000, kind = 'vanish', name = 'Spell: Gamma' } } }) end,
    partial    = function(d) return base(d, { partialAtOpen = { rows = 2, untilMs = 1500 } }) end,
    neversettle = function(d) return base(d, { neverSettles = true }) end,
    emptyvendor = function(d) return { logsRaw = d, rootRaw = d, nonSpells = {}, spells = {} } end,
    misselect1 = function(d) return base(d, { misselect = { name = 'Spell: Beta', times = 1 } }) end,
    misselect3 = function(d) return base(d, { misselect = { name = 'Spell: Beta', times = 3 } }) end,
    drift      = function(d) return base(d, { driftOnce = { name = 'Spell: Beta', afterMs = 200 } }) end,
    prefix     = function(d) return { logsRaw = d, rootRaw = d, nonSpells = { 'Cat Food' },
                    spells = { { name = 'Fear of the Dead', price = 100, level = 30 }, { name = 'Fear', price = 100, level = 5 } } } end,
    moneyshort = function(d) return base(d, { money = 250 }) end,
    userstop   = function(d) return base(d, { stopAtMs = 6000 }) end,
    scribefail = function(d) return base(d, { scribeRejectFirst = 99 }) end,
    stack      = function(d) return base(d, { preScrolls = { 'Spell: Alpha' }, stackOnExisting = true }) end,
    stale      = function(d) return base(d, { staleMs = 10000, reorderAfterBuy = true }) end,
    newscroll  = function(d) return base(d, { events = { { atMs = 9000, kind = 'appear', name = 'Spell: Newbie', price = 100, level = 33 } } }) end,
    dup        = function(d) return { logsRaw = d, rootRaw = d, nonSpells = { 'Cat Food' },
                    spells = { { name = 'Alpha', price = 100, level = 10 }, { name = 'Beta', price = 100, level = 20 }, { name = 'Alpha', price = 100, level = 10 } } } end,
}

local function runAll(script)
    local out = {}
    for name, mk in pairs(SCENARIOS) do
        local dir = TMP .. '\\' .. name
        mkdir(dir)
        os.remove(dir .. '\\spellspree\\' .. LOGNAME)
        local sim = R.run(script, mk(dir))
        out[name] = { sim = sim, lines = R.readLines(dir .. '\\spellspree\\' .. LOGNAME) or {} }
    end
    return out
end

local function grep(lines, plain)
    local hits = {}
    for _, l in ipairs(lines or {}) do if l:find(plain, 1, true) then hits[#hits + 1] = l end end
    return hits
end
local function count(list, pred) local n = 0; for _, v in ipairs(list) do if pred(v) then n = n + 1 end end; return n end
local function cmdCount(sim, plain) return count(sim.cmds, function(c) return c:find(plain, 1, true) ~= nil end) end

-- parse "Outcome ledger (N built-list entries): a=1; b=2; ..." -> N, { label = count }
local function ledger(lines)
    for _, l in ipairs(lines) do
        local n, rest = l:match('Outcome ledger %((%d+) built%-list entries%): (.-)%.$')
        if n then
            local counts = {}
            for label, c in rest:gmatch('([^;=]+)=(%d+)') do counts[(label:gsub('^%s+', ''))] = tonumber(c) end
            return tonumber(n), counts
        end
    end
end

local function setOf(list) local s = {}; for _, v in ipairs(list) do s[v] = (s[v] or 0) + 1 end; return s end
local function allNames(spells) local t = {}; for _, sp in ipairs(spells) do t[#t + 1] = 'Spell: ' .. sp.name end; return t end
local ALL5 = allNames(FIVE)

local OUT_SCRIBED, OUT_NOSCRIBE, OUT_NOTBOUGHT, OUT_SKIPPED, OUT_STOP, OUT_NONE =
    'bought and scribed', 'bought, scribe not completed', 'attempted, not bought', 'deliberately skipped',
    'not attempted because the run stopped', 'NO OUTCOME RECORDED'

local function boughtExactlyOnce(sim, names)
    local got = setOf(sim.purchases)
    for _, n in ipairs(names) do if got[n] ~= 1 then return false, string.format('"%s" was bought %d time(s), expected 1', n, got[n] or 0) end end
    local total = 0; for _, c in pairs(got) do total = total + c end
    if total ~= #names then return false, string.format('the mock saw %d purchases, expected %d', total, #names) end
    return true
end

local TESTS = {
    { id = 'L1', src = 'D-017 E / spec S-6: each name is bought at most once; with 5 spells and a vendor that reorders after every buy, all 5 are bought exactly once',
      fn = function(c)
          local r = c.base
          local ok, why = boughtExactlyOnce(r.sim, ALL5); if not ok then return false, why end
          for name, n in pairs(r.sim.buyClicks) do if n > 1 then return false, name .. ' got ' .. n .. ' Buy clicks' end end
          return true
      end },

    { id = 'L2', src = 'D-017 E: no close/reopen and no repeat pass (the only merchant close is the final one)',
      fn = function(c)
          local r = c.base
          if cmdCount(r.sim, '/click right target') ~= 0 then return false, 'the script re-opened the vendor' end
          if cmdCount(r.sim, 'MW_Done_Button') ~= 1 then return false, 'expected exactly one merchant close, saw ' .. cmdCount(r.sim, 'MW_Done_Button') end
          if #grep(r.lines, 'Starting pass') ~= 0 then return false, 'a pass was started' end
          return true
      end },

    { id = 'L3', src = 'D-017 D + F\'\' outcome 4: a row that is gone at lookup is skipped and logged; the others are still bought',
      fn = function(c)
          local r = c.vanish
          local others = {}; for _, n in ipairs(ALL5) do if n ~= 'Spell: Gamma' then others[#others + 1] = n end end
          local ok, why = boughtExactlyOnce(r.sim, others); if not ok then return false, why end
          if r.sim.buyClicks['Spell: Gamma'] then return false, 'the vanished spell was clicked for purchase' end
          if #grep(r.lines, 'is no longer in the vendor list') ~= 1 then return false, 'no single "no longer in the vendor list" line' end
          local n, counts = ledger(r.lines)
          if counts[OUT_SKIPPED] ~= 1 or counts[OUT_SCRIBED] ~= 4 then return false, 'ledger counts wrong' end
          return true
      end },

    { id = 'L4', src = 'D-017 B\': a list that is only partly loaded right after open (2 rows, then the full list) is not built from; all 5 are bought',
      fn = function(c)
          local ok, why = boughtExactlyOnce(c.partial.sim, ALL5)
          if not ok then return false, why end
          return true
      end },

    { id = 'L5', src = 'D-017 B\': a list that never settles stops the vendor after the 15 s maximum, with the reason, buying nothing',
      fn = function(c)
          local r = c.neversettle
          if #r.sim.purchases ~= 0 or cmdCount(r.sim, 'MW_Buy_Button') ~= 0 then return false, 'something was bought from an unsettled list' end
          local o = grep(r.lines, 'Run outcome (Bazaar)')
          if #o ~= 1 or not o[1]:find('Vendor list did not settle', 1, true) or not o[1]:find('state=Stopped', 1, true) then return false, 'outcome line lacks the stop reason' end
          if r.sim.clockMs < 14500 or r.sim.clockMs > 17500 then return false, string.format('stopped after %d simulated ms, expected about 15000', r.sim.clockMs) end
          return true
      end },

    { id = 'L6', src = 'D-017 H\': a click that selects the wrong row is retried (selection only); the right item is then bought once',
      fn = function(c)
          local r = c.misselect1
          local ok, why = boughtExactlyOnce(r.sim, ALL5); if not ok then return false, why end
          if r.sim.buyClicks['Spell: Beta'] ~= 1 then return false, 'Beta got ' .. tostring(r.sim.buyClicks['Spell: Beta']) .. ' Buy clicks, expected 1' end
          if #grep(r.lines, 'selection attempt 2/3') < 1 then return false, 'no second selection attempt was logged' end
          return true
      end },

    { id = 'L7', src = 'D-017 H\': after 3 failed selection attempts the item is skipped and logged, and nothing wrong is bought',
      fn = function(c)
          local r = c.misselect3
          local others = {}; for _, n in ipairs(ALL5) do if n ~= 'Spell: Beta' then others[#others + 1] = n end end
          local ok, why = boughtExactlyOnce(r.sim, others); if not ok then return false, why end
          local sel = count(r.lines, function(l) return l:find('CMD', 1, true) and l:find('select "Spell: Beta"', 1, true) end)
          if sel ~= 3 then return false, 'expected exactly 3 selection attempts for Beta, saw ' .. sel end
          local n, counts = ledger(r.lines)
          if counts[OUT_NOTBOUGHT] ~= 1 then return false, 'Beta is not in the "attempted, not bought" outcome' end
          return true
      end },

    { id = 'L8', src = 'D-017 H\': the selection is verified immediately before Buy; if it drifted, the item is selected again and the right one is bought, and Buy is never re-clicked',
      fn = function(c)
          local r = c.drift
          local ok, why = boughtExactlyOnce(r.sim, ALL5); if not ok then return false, why end
          for name, n in pairs(r.sim.buyClicks) do if n > 1 then return false, name .. ' got ' .. n .. ' Buy clicks' end end
          if #grep(r.lines, 'just before Buy') < 1 then return false, 'the pre-Buy mismatch was not logged' end
          return true
      end },

    { id = 'L9', src = 'D-017 C / A\': rows are found by EXACT name: "Fear" and "Fear of the Dead" (the longer name listed first) are each bought once',
      fn = function(c) return boughtExactlyOnce(c.prefix.sim, { 'Spell: Fear of the Dead', 'Spell: Fear' }) end },

    { id = 'L10', src = 'D-017 F\'\' (a): every built-list entry ends with exactly one outcome; none is left without one; the counts add up',
      fn = function(c)
          for name, r in pairs(c) do
              if name ~= 'neversettle' and name ~= 'emptyvendor' then -- these two never build a list, so there is no ledger
                  local n, counts = ledger(r.lines)
                  if not n then return false, name .. ': no ledger line' end
                  local sum = 0; for _, v in pairs(counts) do sum = sum + v end
                  if sum ~= n then return false, string.format('%s: ledger counts add up to %d, built %d', name, sum, n) end
                  if (counts[OUT_NONE] or 0) ~= 0 then return false, name .. ': an entry has no recorded outcome' end
                  if #grep(r.lines, 'LEDGER DEFECT') ~= 0 then return false, name .. ': LEDGER DEFECT logged' end
              end
          end
          return true
      end },

    { id = 'L11', src = 'D-017 F\'\' outcomes 3 and 5: out of money -> 2 bought and scribed, 2 attempted not bought, the rest not attempted (with the stop reason)',
      fn = function(c)
          local r = c.moneyshort
          local n, counts = ledger(r.lines)
          if n ~= 5 or counts[OUT_SCRIBED] ~= 2 or counts[OUT_NOTBOUGHT] ~= 2 or counts[OUT_STOP] ~= 1 then
              return false, 'ledger counts are not 2 scribed / 2 not bought / 1 not attempted'
          end
          local o = grep(r.lines, 'Run outcome (Bazaar)')
          if #o ~= 1 or not o[1]:find('state=Stopped', 1, true) then return false, 'the run did not end Stopped' end
          return true
      end },

    { id = 'L12', src = 'D-017 F\'\' outcome 5: the Stop button mid-run ends the run Stopped by user; entries not reached are "not attempted", none lacks an outcome',
      fn = function(c)
          local r = c.userstop
          local o = grep(r.lines, 'Run outcome (Bazaar)')
          if #o ~= 1 or not o[1]:find('Stopped by user', 1, true) then return false, 'the run did not end "Stopped by user"' end
          local n, counts = ledger(r.lines)
          if not n or (counts[OUT_STOP] or 0) < 1 then return false, 'no entry was recorded as not attempted' end
          return true
      end },

    { id = 'L13', src = 'D-017 F\'\' outcome 2: a scribe that never completes after payment is "bought, scribe not completed", and the run stops with the rest not attempted',
      fn = function(c)
          local r = c.scribefail
          local n, counts = ledger(r.lines)
          if counts[OUT_NOSCRIBE] ~= 1 or counts[OUT_STOP] ~= 4 then return false, 'ledger counts are not 1 / 4' end
          if #grep(r.lines, 'scribe failed after 20 attempts') < 1 then return false, 'the scribe-failure detail is not logged' end
          return true
      end },

    { id = 'L14', src = 'D-017 F\'\' outcome 2: a purchase that stacks onto an existing copy is "bought, scribe not completed" and is bought once',
      fn = function(c)
          local r = c.stack
          local n, counts = ledger(r.lines)
          if counts[OUT_NOSCRIBE] ~= 1 or counts[OUT_SCRIBED] ~= 4 then return false, 'ledger counts are not 1 stacked / 4 scribed' end
          if r.sim.buyClicks['Spell: Alpha'] ~= 1 then return false, 'Alpha was clicked to buy ' .. tostring(r.sim.buyClicks['Spell: Alpha']) .. ' times' end
          return true
      end },

    { id = 'L15', src = 'D-017 F\'\' (b): rows that linger about 10 s after a scribe are reported as expected lingering rows, with no new scrolls, and nothing is bought twice',
      fn = function(c)
          local r = c.stale
          local scr = {}; for i = 1, 3 do scr[i] = 'Spell: ' .. FIVE[i].name end
          local ok, why = boughtExactlyOnce(r.sim, ALL5); if not ok then return false, why end
          local f = grep(r.lines, 'Final scan')
          if #f ~= 1 then return false, 'no single final-scan line' end
          local lingering = tonumber(f[1]:match('about 10 s after a scribe%): (%d+)'))
          if not lingering or lingering < 1 then return false, 'no lingering rows reported' end
          if not f[1]:find('New scrolls not on the built list: 0', 1, true) then return false, 'a new scroll was reported' end
          return true
      end },

    { id = 'L16', src = 'D-017 F\'\' (b): a scroll that appears after the list was built is reported as new by the final scan and is not bought',
      fn = function(c)
          local r = c.newscroll
          local f = grep(r.lines, 'Final scan')
          if #f ~= 1 or not f[1]:find('New scrolls not on the built list: 1 [Spell: Newbie]', 1, true) then return false, 'the new scroll was not reported' end
          if r.sim.buyClicks['Spell: Newbie'] then return false, 'the new scroll was bought' end
          return true
      end },

    { id = 'L17', src = 'D-017 A\': a name listed twice is kept once (the first), the duplicate is logged, and it is bought once',
      fn = function(c)
          local r = c.dup
          if r.sim.buyClicks['Spell: Alpha'] ~= 1 then return false, 'Alpha got ' .. tostring(r.sim.buyClicks['Spell: Alpha']) .. ' Buy clicks' end
          if #grep(r.lines, 'appears more than once') ~= 1 then return false, 'the duplicate was not logged once' end
          local n = ledger(r.lines)
          if n ~= 2 then return false, 'the built list has ' .. tostring(n) .. ' entries, expected 2' end
          return true
      end },

    { id = 'L19', src = 'D-017 B-prime as approved ("at least 1 row") and ledger item 16: a vendor whose usable list is completely empty never settles, so the visit stops after the 15 s maximum with reason "Vendor list did not settle", buying nothing (this documents the approved behavior; it does not endorse it)',
      fn = function(c)
          local r = c.emptyvendor
          if #r.sim.purchases ~= 0 or cmdCount(r.sim, 'MW_Buy_Button') ~= 0 then return false, 'something was bought from an empty vendor' end
          local o = grep(r.lines, 'Run outcome (Bazaar)')
          if #o ~= 1 or not o[1]:find('Vendor list did not settle', 1, true) or not o[1]:find('state=Stopped', 1, true) then
              return false, 'outcome line lacks state=Stopped and the reason: ' .. tostring(o[1])
          end
          if r.sim.clockMs < 14500 or r.sim.clockMs > 17500 then return false, string.format('stopped after %d simulated ms, expected about 15000', r.sim.clockMs) end
          if #grep(r.lines, 'list settle poll') < 2 or #grep(r.lines, 'count=0') < 2 then return false, 'the polls do not show an empty list (count=0)' end
          return true
      end },

    { id = 'L18', src = 'D-017 A\': the list read logs each spell\'s Lvl (column 8); the mock gives Gamma level 25',
      fn = function(c)
          local hits = 0
          for _, l in ipairs(grep(c.base.lines, 'built list:')) do if l:find('Spell: Gamma [Lvl  25,', 1, true) then hits = hits + 1 end end
          if hits ~= 1 then return false, 'the built-list line does not show "Spell: Gamma [Lvl  25"' end
          return true
      end },
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

-- exactly the named tests must fail for each deliberate defect
local MUTATIONS = {
    { name = 'row lookup is not exact (the "=" is dropped)', fails = { 'L9' },
      from = "string.format('=%s,%d', name, LIST_COL.NAME)", to = "string.format('%s,%d', name, LIST_COL.NAME)" },
    { name = 'the check right before Buy is removed', fails = { 'L8' },
      from = "    if selectedNameNow() ~= name then\n        logLine(string.format('The selection is no longer", to = "    if false then\n        logLine(string.format('The selection is no longer" },
    { name = 'the list is built after one poll instead of waiting for it to settle', fails = { 'L4', 'L5' },
      from = "local LIST_STABLE_POLLS  = 8", to = "local LIST_STABLE_POLLS  = 1" },
    { name = 'only one selection attempt instead of 3', fails = { 'L6', 'L7', 'L8' },
      from = "local SELECT_ATTEMPTS    = 3", to = "local SELECT_ATTEMPTS    = 1" },
    { name = 'entries not reached after a stop get no outcome', fails = { 'L10', 'L11', 'L12', 'L13' },
      from = "        if not entries[i].outcome then setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason) end", to = "        if false then setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason) end" },
    { name = 'duplicate names are not collapsed', fails = { 'L17' },
      from = "            if byName[name] then", to = "            if false then" },
    { name = 'the final scan no longer reports new scrolls', fails = { 'L16' },
      from = "                newScrolls[#newScrolls + 1] = name", to = "                local _ = name" },
    -- L19 also measures the 15 s maximum, so it fails here too (my first prediction predates L19)
    { name = 'the settle wait never gives up within 15 s', fails = { 'L5', 'L19' },
      from = "local LIST_MAX_WAIT_MS   = 15000", to = "local LIST_MAX_WAIT_MS   = 60000" },
    -- predicted before running: only L19 depends on an empty list being refused as "settled"
    { name = 'an empty list (0 rows) is accepted as settled', fails = { 'L19' },
      from = "        if n and n >= 1 and n == last then", to = "        if n and n >= 0 and n == last then" },
    { name = 'a row that is gone at lookup gets no outcome', fails = { 'L3', 'L10' },
      from = "        setOutcome(entry, OUTCOME.SKIPPED, 'row gone at lookup')", to = "        local _ = 'row gone at lookup'" },
}

local failures = 0
local function report(label, ok, detail)
    print(string.format('%-6s %s%s', ok and 'PASS' or 'FAIL', label, detail and (' -- ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

print('=== baseline: spellspree.lua against the simulated MQ ===')
local base = evaluate(SCRIPT)
for _, t in ipairs(TESTS) do report(t.id .. ' ' .. t.src, base[t.id].pass, base[t.id].msg) end

if arg[1] == 'baseline' then
    -- the real build's logs stay in %TEMP%\spellspree_sim\listthenbuy\<scenario> for reading (mutation runs overwrite them)
    print(string.format('\n%s: %d failure(s) (baseline only, mutations skipped)', failures == 0 and 'ALL OK' or 'NOT OK', failures))
    os.exit(failures == 0 and 0 or 1)
end

print('\n=== mutation checks: each broken build must fail exactly its named test(s) ===')
mkdir(TMP)
for i, m in ipairs(MUTATIONS) do
    local at = SOURCE:find(m.from, 1, true)
    if not at or SOURCE:find(m.from, at + 1, true) then
        report('mutation ' .. i .. ' ' .. m.name, false, 'mutation target not found exactly once in source')
    else
        local mutated = SOURCE:sub(1, at - 1) .. m.to .. SOURCE:sub(at + #m.from)
        local path = TMP .. '\\mutant_' .. i .. '.lua'
        local f = assert(io.open(path, 'wb')); f:write(mutated); f:close()
        local ok, res = pcall(evaluate, path)
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
