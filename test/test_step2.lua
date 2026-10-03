-- Tests for Step 2, every 61-70 selection uses the 1-25 vendor (decision log D-022; design D-021 items A'-F').
-- Run from the repo root:  luajit test/test_step2.lua
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, a model of MacroQuest and the vendor window.
-- A pass proves the script routes and labels visits as D-022 says against that model; it proves nothing about the
-- live client.
--
-- Each test cites the source of its expected value in `src` (Development Protocol section 7): a D-022 / D-021 item or
-- the developer's recorded requirement (D-020 R34). Expected values come from those texts and from the mock's own
-- record of what the script did (the commands it sent, what it bought), never from running the script and pasting
-- its output.
--
-- After the baseline run, each MUTATION breaks the script on purpose; exactly the tests named for it must fail (the
-- expected sets were written before the first run).
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = 'spellspree.lua'
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\step2'
local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')
local LOGNAME = 'spellspree_SimServer_Simtest.log'

-- The vendors in the zone (each also sells a non-scroll item, as every live vendor did: a list with no rows at all never
-- "settles" under D-017 B', see the ledger). The OLD 61-70 vendors (Vicar Diarin, Channeler Alyrianne) are present with empty stock so
-- that visiting them would show up as a /target command; the script must never do so (D-022 A').
local VENDORS = {
    ['Vicar Ceraen']        = { nonSpells = { 'Pickled Cat Food' }, spells = { { name = 'Calm', price = 100, level = 10 }, { name = 'Mark of the Righteous', price = 100, level = 63 } } },
    ['Vicar Thiran']        = { nonSpells = { 'Pickled Cat Food' }, spells = { { name = 'Blessing of Faith', price = 100, level = 35 } } },
    ['Vicar Delin']         = { nonSpells = { 'Pickled Cat Food' }, spells = { { name = 'Armor of Faith', price = 100, level = 55 } } },
    ['Vicar Diarin']        = { nonSpells = { 'Pickled Cat Food' }, spells = {} },
    ['Channeler Olaemos']   = { nonSpells = { 'Pickled Cat Food' }, spells = { { name = 'Minor Shielding', price = 100, level = 12 }, { name = 'Evacuate', price = 100, level = 64 } } },
    ['Channeler Alyrianne'] = { nonSpells = { 'Pickled Cat Food' }, spells = {} },
}
local function scenario(extra)
    return function(dir)
        local o = { logsRaw = dir, rootRaw = dir, zone = 'poknowledge', clickPrefix = 'Run Shopping Spree', vendors = VENDORS }
        for k, v in pairs(extra) do o[k] = v end
        return o
    end
end

local SCENARIOS = {
    all4    = scenario({ classes = { 'CLR' }, ticks = { '##class_Cleric' } }),
    only61  = scenario({ classes = { 'CLR' }, openTrees = { Cleric = true }, ticks = { '61-70##Cleric' } }),
    both    = scenario({ classes = { 'CLR' }, openTrees = { Cleric = true }, ticks = { '1-25##Cleric', '61-70##Cleric' } }),
    multi   = scenario({ classes = { 'CLR', 'WIZ' }, openTrees = { Cleric = true, Wizard = true }, ticks = { '61-70##Cleric', '61-70##Wizard' } }),
}

local function runScenarios(script, only)
    local out = {}
    for name, mk in pairs(SCENARIOS) do
        if not only or only[name] then
            local dir = TMP .. '\\' .. name
            mkdir(dir)
            os.remove(dir .. '\\spellspree\\' .. LOGNAME)
            local sim = R.run(script, mk(dir))
            out[name] = { sim = sim, lines = R.readLines(dir .. '\\spellspree\\' .. LOGNAME) or {} }
        end
    end
    return out
end

local function grep(lines, plain)
    local hits = {}
    for _, l in ipairs(lines or {}) do if l:find(plain, 1, true) then hits[#hits + 1] = l end end
    return hits
end

-- the NPCs the script targeted, in order (one /target npc command per visit)
local function visited(sim)
    local seq = {}
    for _, c in ipairs(sim.cmds) do
        local n = c:match('^/target npc "=(.+)"$')
        if n then seq[#seq + 1] = n end
    end
    return seq
end
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
local function show(t) return '[' .. table.concat(t, ', ') .. ']' end

-- the source text between two markers
local function between(text, from, to)
    local a = text:find(from, 1, true)
    local b = a and text:find(to, a, true)
    return (a and b) and text:sub(a, b) or ''
end
local function stripBlockComments(t) return (t:gsub('%-%-%[%[.-%]%]', '')) end

-- Runs the S6 scenario (Cleric 61-70 ticked, mapping deleted) on a copy of the real script, after `transform` changed its text.
local function runWithTransform(transform)
    local mutated = SOURCE:gsub("    %['61%-70'%] = '1%-25',\n", '', 1)
    if mutated == SOURCE then error('could not simulate the missing mapping (active line not found)', 0) end
    mutated = transform(mutated)
    local path = TMP .. '\\no_mapping.lua'
    local f = assert(io.open(path, 'wb')); f:write(mutated); f:close()
    local dir = TMP .. '\\nomapping'
    mkdir(dir)
    os.remove(dir .. '\\spellspree\\' .. LOGNAME)
    local sim = R.run(path, SCENARIOS.only61(dir))
    return sim, R.readLines(dir .. '\\spellspree\\' .. LOGNAME) or {}
end

-- All the checks for "no vendor is configured": returns true, or false plus every problem found (so a test can see which kinds).
local function noVendorCheck(sim, lines)
    local problems = {}
    local w = grep(lines, 'No vendor is configured for Cleric 61-70')
    if #w ~= 1 then problems[#problems + 1] = 'expected one WARN naming Cleric 61-70, saw ' .. #w
    elseif not w[1]:find('| WARN ', 1, true) then problems[#problems + 1] = 'the line is not at WARN level' end
    local function cmdCount(prefix) local n = 0; for _, cmd in ipairs(sim.cmds) do if cmd:sub(1, #prefix) == prefix then n = n + 1 end end; return n end
    if #visited(sim) ~= 0 then problems[#problems + 1] = 'a visit was made with no vendor configured (/target npc)' end
    if cmdCount('/nav') ~= 0 then problems[#problems + 1] = 'a /nav command was sent (' .. cmdCount('/nav') .. ')' end
    if cmdCount('/notify MerchantWnd MW_Buy_Button') ~= 0 then problems[#problems + 1] = 'a Buy click was sent' end
    if #sim.purchases ~= 0 then problems[#problems + 1] = 'the mock saw ' .. #sim.purchases .. ' purchase(s)' end
    local printed = false
    for _, l in ipairs(sim.prints) do if l:find('No vendors selected', 1, true) then printed = true end end
    if not printed then problems[#problems + 1] = '"No vendors selected" was not printed' end
    if not sim.ok then problems[#problems + 1] = 'the script chunk did not finish: ' .. tostring(sim.runErr) end
    if sim.endedBy ~= 'no-vendors' then problems[#problems + 1] = 'the run did not end through the no-vendors grace (endedBy=' .. tostring(sim.endedBy) .. ')' end
    if sim.delays >= 1000 then problems[#problems + 1] = 'the run used ' .. sim.delays .. ' delays, expected far fewer than the 400,000 guard' end
    if #problems > 0 then return false, table.concat(problems, '; ') end
    return true
end

local OLD_NAMES = { 'Vicar Diarin', 'Minstrel Silnon', 'Illusionist Acored', 'Channeler Alyrianne', 'Reaver Muron', 'Heretic Ceikon',
    'Mystic Pikor', 'Wanderer Kedrisan', 'Elementalist Siewth', 'Pathfinder Naend', 'Cavalier Cerakor', 'Primalist Loerith' }

local TESTS = {
    { id = 'S1', src = 'D-022 A\', C / D-020 R34: with all four Cleric tiers ticked the visits are vendor 1, 2, 3, then vendor 1 again, and the old 61-70 vendor is never targeted',
      fn = function(c)
          local got = visited(c.all4.sim)
          local want = { 'Vicar Ceraen', 'Vicar Thiran', 'Vicar Delin', 'Vicar Ceraen' }
          if not same(got, want) then return false, 'visited ' .. show(got) .. ', expected ' .. show(want) end
          local outcomes = grep(c.all4.lines, 'Run outcome (Nav & Shop "Vicar Ceraen")')
          if #outcomes ~= 2 then return false, 'expected two separate visits (two outcome lines) to Vicar Ceraen, saw ' .. #outcomes end
          if not outcomes[1]:find('This vendor: bought=2,', 1, true) then return false, 'first visit should have bought 2: ' .. outcomes[1] end
          if not outcomes[2]:find('This vendor: bought=0,', 1, true) or not outcomes[2]:find('state=Done', 1, true) then
              return false, 'the second visit should end Done having bought 0: ' .. outcomes[2]
          end
          return true
      end },

    { id = 'S2', src = 'D-022 A\': ticking only 61-70 visits only the 1-25 vendor',
      fn = function(c)
          local got = visited(c.only61.sim)
          if not same(got, { 'Vicar Ceraen' }) then return false, 'visited ' .. show(got) .. ', expected [Vicar Ceraen]' end
          return true
      end },

    { id = 'S3', src = 'D-022 C / D-020 R34: ticking 1-25 and 61-70 is two visits to the 1-25 vendor, not one merged visit',
      fn = function(c)
          local got = visited(c.both.sim)
          if not same(got, { 'Vicar Ceraen', 'Vicar Ceraen' }) then return false, 'visited ' .. show(got) .. ', expected two visits to Vicar Ceraen' end
          return true
      end },

    { id = 'S4', src = 'D-022 A\' / F\': a multi-class selection routes each class\'s 61-70 to that class\'s own 1-25 vendor, in class order (Cleric, then Wizard)',
      fn = function(c)
          local got = visited(c.multi.sim)
          local want = { 'Vicar Ceraen', 'Channeler Olaemos' }
          if not same(got, want) then return false, 'visited ' .. show(got) .. ', expected ' .. show(want) end
          return true
      end },

    { id = 'S5', src = 'D-022 D\': the label of a 61-70 visit says "using the 1-25 vendor" (and does not claim a purchase); the other three visits carry no such note',
      fn = function(c)
          local lines = grep(c.all4.lines, '--- Vendor ')
          if #lines ~= 4 then return false, 'expected 4 visit labels, saw ' .. #lines end
          for i = 1, 3 do
              if lines[i]:find('using the', 1, true) then return false, 'visit ' .. i .. ' wrongly carries a "using the" note' end
          end
          if not lines[4]:find('Vicar Ceraen (Cleric 61-70, using the 1-25 vendor)', 1, true) then return false, 'visit 4 label is: ' .. lines[4] end
          if lines[4]:find('bought', 1, true) then return false, 'the label claims a purchase' end
          return true
      end },

    { id = 'S6', src = 'D-022 A\': a ticked tier with no vendor mapping logs a WARN naming the class and tier and is skipped (configuration error simulated by deleting the active 61-70 mapping); D-026 E\': nothing is navigated to, targeted or bought, and the run ends normally',
      fn = function(c)
          local sim, lines = runWithTransform(function(src) return src end)
          local ok, why = noVendorCheck(sim, lines)
          return ok, why
      end },

    { id = 'S7', src = 'D-022 B\': the old 61-70 vendor names are kept as comments (all 12), no 61-70 name is active, exactly one active 61-70 mapping entry (to 1-25), and the restoration note is present',
      fn = function(c)
          for _, name in ipairs(OLD_NAMES) do
              if not SOURCE:find("--[[ ['61-70'] = '" .. name .. "' ]]", 1, true) then return false, name .. ' is not kept as an inline comment' end
          end
          local data = between(SOURCE, 'local VENDOR_DATA = {', '\n}\n')
          if stripBlockComments(data):find("['61-70']", 1, true) then return false, 'an active 61-70 entry remains in VENDOR_DATA' end
          local map = between(SOURCE, 'local TIER_VENDOR = {', '\n}\n')
          local active = stripBlockComments(map)
          local _, n = active:gsub("%['61%-70'%]", '')
          if n ~= 1 then return false, 'expected exactly one active 61-70 mapping entry, found ' .. n end
          if not active:find("['61-70'] = '1-25'", 1, true) then return false, 'the active 61-70 mapping does not point at 1-25' end
          if not SOURCE:find('delete the active', 1, true) then return false, 'the restoration note is missing' end
          return true
      end },

    { id = 'S8', src = 'D-022 E: nothing else changes (Step 1 behavior kept): in the four-tier Cleric run every spell is bought exactly once',
      fn = function(c)
          local got = {}
          for _, n in ipairs(c.all4.sim.purchases) do got[n] = (got[n] or 0) + 1 end
          for _, n in ipairs({ 'Spell: Calm', 'Spell: Mark of the Righteous', 'Spell: Blessing of Faith', 'Spell: Armor of Faith' }) do
              if got[n] ~= 1 then return false, n .. ' was bought ' .. tostring(got[n] or 0) .. ' time(s)' end
          end
          if #c.all4.sim.purchases ~= 4 then return false, 'the mock saw ' .. #c.all4.sim.purchases .. ' purchases, expected 4' end
          return true
      end },

    { id = 'S9', src = 'D-026 E\': the S6 checks detect a forbidden action during the grace (a modified script sends /nav id on the main-loop pass after "No vendors selected"; the checks must fail and name the navigation)',
      fn = function(c)
          local sim, lines = runWithTransform(function(src)
              local a = "logLine('No vendors selected -- check at least one class/tier box first.', COLOR_WARN)\n        return\n"
              local b = '    mq.doevents()\n    if S.reDetectRequested then\n'
              local at = src:find(a, 1, true)
              assert(at and not src:find(a, at + 1, true), 'forbidden-action hook point A not found exactly once')
              local bt = src:find(b, 1, true)
              assert(bt and not src:find(b, bt + 1, true), 'forbidden-action hook point B not found exactly once')
              local newA = "logLine('No vendors selected -- check at least one class/tier box first.', COLOR_WARN)\n        S.forbiddenNext = true\n        return\n"
              local newB = "    mq.doevents()\n    if S.forbiddenNext then S.forbiddenNext = false; sendCmd('forbidden action for the grace test', '/nav id 4242') end\n    if S.reDetectRequested then\n"
              -- B comes after A in the file, so replace B first
              src = src:sub(1, bt - 1) .. newB .. src:sub(bt + #b)
              return src:sub(1, at - 1) .. newA .. src:sub(at + #a)
          end)
          local ok, why = noVendorCheck(sim, lines)
          if ok then return false, 'the checks passed although the script navigated during the grace' end
          if not why:find('/nav', 1, true) then return false, 'the checks failed but did not name the navigation: ' .. why end
          return true
      end },
}

local function evaluate(script)
    local c = runScenarios(script)
    local res = {}
    for _, t in ipairs(TESTS) do
        local ok, a, b = pcall(t.fn, c)
        if not ok then res[t.id] = { pass = false, msg = 'test errored: ' .. tostring(a) }
        else res[t.id] = { pass = a == true, msg = b } end
    end
    return res
end

-- exactly the named tests must fail for each deliberate defect (written before the first run)
local MUTATIONS = {
    -- S6 also fails here, legitimately: it simulates a missing mapping by deleting the active 61-70 mapping line, which this
    -- mutation has already changed (my first prediction missed that dependency). S9 uses the same technique, so it fails here too
    -- (predicted before the run, D-026).
    { name = 'a ticked 61-70 goes back to the 61-70 vendor', fails = { 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S9' },
      from = "    ['61-70'] = '1-25',\n", to = "    ['61-70'] = '61-70',\n" },
    { name = 'the visit label no longer says which vendor is used', fails = { 'S5' },
      from = "string.format(', using the %s vendor', entry.vendorTier)", to = "''" },
    { name = 'a missing vendor mapping is skipped silently again', fails = { 'S6' },
      from = "                    logLine(string.format('No vendor is configured for %s %s (vendor tier %s) -- skipping that visit.',\n                        className, tier, tostring(vendorTier)), COLOR_WARN)",
      to = "                    local _ = tostring(vendorTier)" },
    -- S8 also fails here, legitimately: Vicar Delin is never visited, so its spell is never bought (my first prediction missed it).
    { name = '51-60 is routed to the 1-25 vendor', fails = { 'S1', 'S5', 'S8' },
      from = "    ['51-60'] = '51-60',\n", to = "    ['51-60'] = '1-25',\n" },
    { name = 'one old 61-70 vendor name is left active, not commented out', fails = { 'S7' },
      from = "--[[ ['61-70'] = 'Vicar Diarin' ]]", to = "['61-70'] = 'Vicar Diarin'" },
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
        -- the tests that read the source (S6, S7) must look at the mutant, not at the real file
        local realSource = SOURCE
        SOURCE = mutated:gsub('\r\n', '\n')
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

-- Mutations of the harness itself (D-026 E'): the named tests must fail (expected sets written before the first run).
local HARNESS_MUTATIONS = {
    { name = 'no grace after "No vendors selected" (the run ends at the first delay)', fails = { 'S9' }, grace = 0 },
    { name = 'no early termination (the run drags on to the runaway guard)', fails = { 'S6' }, grace = math.huge },
}
for i, m in ipairs(HARNESS_MUTATIONS) do
    local realGrace = R.GRACE
    R.GRACE = m.grace
    local ok, res = pcall(evaluate, SCRIPT)
    R.GRACE = realGrace
    if not ok then
        report('harness mutation ' .. i .. ' ' .. m.name, false, 'harness error: ' .. tostring(res))
    else
        local expected = {}
        for _, id in ipairs(m.fails) do expected[id] = true end
        local problems = {}
        for _, t in ipairs(TESTS) do
            local failed = not res[t.id].pass
            if expected[t.id] and not failed then problems[#problems + 1] = t.id .. ' should have failed but passed' end
            if not expected[t.id] and failed then problems[#problems + 1] = t.id .. ' failed unexpectedly (' .. tostring(res[t.id].msg) .. ')' end
        end
        report('harness mutation ' .. i .. ' ' .. m.name, #problems == 0, #problems > 0 and table.concat(problems, '; ') or ('caught by ' .. table.concat(m.fails, ',')))
    end
end

print(string.format('\n%s: %d failure(s)', failures == 0 and 'ALL OK' or 'NOT OK', failures))
os.exit(failures == 0 and 0 or 1)
