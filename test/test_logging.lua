-- Tests for the file logging added under decision D-004 (docs/DECISION_LOG.md).
-- Run from the repo root:  luajit test/test_logging.lua
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, which is a
-- model of MacroQuest, not MacroQuest. A pass here proves the logging does what
-- D-004 says against that model; it does not prove anything about a live client.
--
-- Every test names the source of its expected value in `src` (Development
-- Protocol section 7). Expected values come from D-004 / R10 or from the mock's
-- own independent record of what happened (sim.cmds, sim.purchases) -- never
-- from running the script and pasting its output.
--
-- After the baseline run, each MUTATION below breaks the script on purpose and
-- the harness checks that exactly the test(s) named for it fail (section 7:
-- prove a test can fail for the right reason).
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = 'spellspree.lua'
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\logging'

local function readAll(path)
    local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s
end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT)
local VERSION = assert(SOURCE:match("local VERSION = '([^']+)'"), 'cannot read VERSION from source')

local LOGNAME = 'spellspree_SimServer_Simtest.log'

-- name -> function(dir) returning mock options
local SCENARIOS = {
    reorder = function(dir) return {
        logsRaw = dir, rootRaw = dir, nonSpells = { 'Pickled Cat Food' },
        spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } },
        reorderAfterBuy = true } end,
    rejects = function(dir) return {
        logsRaw = dir, rootRaw = dir, spells = { { name = 'Alpha', price = 100 } },
        scribeRejectFirst = 2 } end,
    broke = function(dir) return {
        logsRaw = dir, rootRaw = dir, money = 50,
        spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 100 }, { name = 'Gamma', price = 100 } } } end,
    nolog = function(dir) return {
        logsRaw = dir, rootRaw = dir, logsUnreadable = true, nonSpells = { 'Pickled Cat Food' },
        spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } },
        reorderAfterBuy = true } end,
    -- Plane of Knowledge spree over two vendors; the second buys nothing (the case that
    -- slipped through in the first live log: vendor 2's outcome line showed vendor 1's totals).
    spree = function(dir) return {
        logsRaw = dir, rootRaw = dir, zone = 'poknowledge', checkClass = 'Cleric',
        clickPrefix = 'Run Shopping Spree',
        vendors = {
            ['Vicar Ceraen'] = { nonSpells = { 'Pickled Cat Food' },
                spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } } },
            ['Vicar Thiran'] = { nonSpells = { 'Pickled Cat Food' } },
        } } end,
    relative = function(dir) return {
        logsRaw = 'Logs', rootRaw = dir, spells = { { name = 'Alpha', price = 100 } } } end,
}

-- Runs every scenario against `script`; returns { name = {sim=, lines=, dir=} }.
local function runAll(script)
    local out = {}
    for name, mk in pairs(SCENARIOS) do
        local dir = TMP .. '\\' .. name
        mkdir(dir)
        local logDir = (name == 'relative') and (dir .. '\\Logs\\spellspree') or (dir .. '\\spellspree')
        os.remove(logDir .. '\\' .. LOGNAME)
        local sim = R.run(script, mk(dir))
        out[name] = { sim = sim, lines = R.readLines(logDir .. '\\' .. LOGNAME), logDir = logDir }
    end
    return out
end

local function grep(lines, plain)
    local hits = {}
    for _, l in ipairs(lines or {}) do if l:find(plain, 1, true) then hits[#hits + 1] = l end end
    return hits
end

local LINE_PATTERN = '^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d | %+%d+ms | v[^|]+ | (%u+)%s+ | .+$'

local TESTS = {
    { id = 'T1', src = 'D-004 design choice: every mq.cmd/cmdf goes through one wrapper that logs the command and its reason',
      fn = function(c)
          local r = c.reorder
          if not r.lines then return false, 'no log file produced' end
          local cmdLines = {}
          for _, l in ipairs(r.lines) do
              local cmd, reason = l:match('| CMD   | (.-)   %[reason: (.+)%]$')
              if cmd then cmdLines[#cmdLines + 1] = { cmd = cmd, reason = reason } end
          end
          if #cmdLines ~= #r.sim.cmds then
              return false, string.format('mock saw %d commands, log has %d CMD lines', #r.sim.cmds, #cmdLines)
          end
          for i, sent in ipairs(r.sim.cmds) do
              if cmdLines[i].cmd ~= sent then
                  return false, string.format('command %d: mock saw "%s", log says "%s"', i, sent, cmdLines[i].cmd)
              end
              if cmdLines[i].reason == '' then return false, 'empty reason on command ' .. i end
          end
          return true
      end },

    { id = 'T2', src = 'D-004 design choice: startup logs build identity, and every line carries it',
      fn = function(c)
          local r = c.reorder
          if not r.lines or #grep(r.lines, 'session start: build=v' .. VERSION) ~= 1 then
              return false, 'no single "session start: build=v' .. VERSION .. '" line'
          end
          for i, l in ipairs(r.lines) do
              if not l:find('| v' .. VERSION .. ' |', 1, true) then return false, 'line ' .. i .. ' lacks build identity' end
          end
          return true
      end },

    { id = 'T3', src = 'D-004 design choice: line format "date time | +ms | build | LEVEL | message"',
      fn = function(c)
          local r = c.reorder
          if not r.lines or #r.lines == 0 then return false, 'no log lines' end
          local allowed = { INFO = true, WARN = true, ERROR = true, CMD = true, OBS = true, DEBUG = true }
          for i, l in ipairs(r.lines) do
              local level = l:match(LINE_PATTERN)
              if not level then return false, 'line ' .. i .. ' does not match the format: ' .. l:sub(1, 80) end
              if not allowed[level] then return false, 'line ' .. i .. ' has unknown level ' .. level end
          end
          return true
      end },

    { id = 'T4', src = 'R10 (D-004): final outcome is logged; expected purchase count is the mock\'s own record',
      fn = function(c)
          local r = c.reorder
          local outcomes = grep(r.lines, 'Run outcome (Bazaar)')
          if #outcomes ~= 1 then return false, 'expected exactly one Run outcome line, got ' .. #outcomes end
          local want = string.format('This vendor: bought=%d,', #r.sim.purchases)
          if not outcomes[1]:find(want, 1, true) then return false, 'outcome line lacks "' .. want .. '": ' .. outcomes[1] end
          if not outcomes[1]:find('state=Done', 1, true) then return false, 'outcome line lacks state=Done' end
          return true
      end },

    { id = 'T11', src = 'D-009 R18 and ledger Open item 12 (in the live log vendor 2, which bought nothing, reported the totals of vendor 1), with D-022 / D-020 R34 (vendor 1 is visited twice in a four-tier spree); expected counts are the per-vendor purchase record kept by the mock',
      fn = function(c)
          local r = c.spree
          local v1 = #(r.sim.purchasesByVendor['Vicar Ceraen'] or {})
          local v2 = #(r.sim.purchasesByVendor['Vicar Thiran'] or {})
          if v1 ~= 3 or v2 ~= 0 then return false, string.format('scenario sanity: mock bought %d at vendor 1 and %d at vendor 2 (expected 3 and 0)', v1, v2) end
          -- D-022 / D-020 R34: a four-tier Cleric spree visits Vicar Ceraen twice (1-25, then 61-70 via the 1-25 vendor);
          -- Vicar Delin is absent from this zone. The second visit finds nothing left and must report 0, not the total.
          local o1 = grep(r.lines, 'Run outcome (Nav & Shop "Vicar Ceraen")')
          local o2 = grep(r.lines, 'Run outcome (Nav & Shop "Vicar Thiran")')
          if #o1 ~= 2 or #o2 ~= 1 then return false, string.format('expected two outcome lines for vendor 1 (two visits) and one for vendor 2, got %d and %d', #o1, #o2) end
          for _, w in ipairs({ 'This vendor: bought=3,', 'Spree total so far: bought=3,' }) do
              if not o1[1]:find(w, 1, true) then return false, 'first vendor-1 visit lacks "' .. w .. '": ' .. o1[1] end
          end
          for _, w in ipairs({ 'This vendor: bought=0,', 'Spree total so far: bought=3,' }) do
              if not o1[2]:find(w, 1, true) then return false, 'second vendor-1 visit lacks "' .. w .. '": ' .. o1[2] end
              if not o2[1]:find(w, 1, true) then return false, 'vendor 2 line lacks "' .. w .. '": ' .. o2[1] end
          end
          return true
      end },

    { id = 'T5', src = 'R10 (D-004): observations used in decisions -- money before/after each purchase',
      fn = function(c)
          local r = c.reorder
          for _, name in ipairs(r.sim.purchases) do
              local hits = grep(r.lines, 'money check after buying "' .. name .. '"')
              if #hits ~= 1 then return false, 'no single money check for ' .. name end
              if not hits[1]:find('paid=true', 1, true) then return false, 'money check for ' .. name .. ' lacks paid=true' end
          end
          return true
      end },

    { id = 'T6', src = 'R10 (D-004): retry counts and reasons -- each scribe attempt is logged',
      fn = function(c)
          local r = c.rejects
          local sent = 0
          for _, cmd in ipairs(r.sim.cmds) do if cmd:match('^/itemnotify in pack1 %d+ rightmouseup$') then sent = sent + 1 end end
          if sent ~= 3 then return false, 'mock expected 3 scribe clicks (2 rejected + 1), saw ' .. sent end
          local clicks = grep(r.lines, 'right-click the scroll at')
          if #clicks ~= sent then return false, string.format('%d scribe clicks sent, %d logged', sent, #clicks) end
          for n = 1, 3 do
              if #grep(r.lines, 'scribe attempt ' .. n .. '/20') ~= 1 then return false, 'missing observation for attempt ' .. n end
          end
          return true
      end },

    { id = 'T7', src = 'D-004 implementation choice: a logging failure never alters what the script does',
      fn = function(c)
          local r = c.nolog
          if not r.sim.ok then return false, 'script chunk raised: ' .. tostring(r.sim.runErr) end
          if #r.sim.purchases ~= #c.reorder.sim.purchases then
              return false, string.format('with logging unavailable the run bought %d, with it %d', #r.sim.purchases, #c.reorder.sim.purchases)
          end
          if #grep(r.sim.prints, 'File logging is OFF') < 1 then return false, 'no visible "File logging is OFF" warning' end
          return true
      end },

    { id = 'T8', src = 'D-004 implementation choice: a relative logs path is joined onto MacroQuest.Path(root)',
      fn = function(c)
          local r = c.relative
          if not r.lines or #r.lines == 0 then return false, 'no log at <root>/Logs/spellspree/' end
          return true
      end },

    { id = 'T9', src = 'R10 (D-004): the log states where MQ cannot prove an action succeeded',
      fn = function(c)
          if #grep(c.reorder.lines, 'known limits:') ~= 1 then return false, 'no single "known limits:" line' end
          return true
      end },

    { id = 'T10', src = 'R10 (D-004): failures are logged with why; ERROR level carries the stop reason',
      fn = function(c)
          local r = c.broke
          local errs = grep(r.lines, '| ERROR |')
          local found = false
          for _, l in ipairs(errs) do if l:find('two purchases in a row', 1, true) then found = true end end
          if not found then return false, 'no ERROR line explaining the stop' end
          local outcomes = grep(r.lines, 'Run outcome (Bazaar)')
          if #outcomes ~= 1 or not outcomes[1]:find('state=Stopped', 1, true) then return false, 'no Run outcome with state=Stopped' end
          if #r.sim.purchases ~= 0 then return false, 'mock says something was bought with no money' end
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

-- Each mutation: break one thing, expect exactly `fails` to fail.
local MUTATIONS = {
    -- T6 also fails here, legitimately: it checks that each scribe click was logged as a CMD line.
    { name = 'sendCmd stops logging commands', fails = { 'T1', 'T6' },
      from = "logWriteFile('CMD', string.format('%s   [reason: %s]', cmd, reason))", to = '' },
    { name = 'elapsed-time column loses its "+" in the line format', fails = { 'T3' },
      from = "'%s | +%dms | v%s | %-5s | %s\\n'", to = "'%s | %dms | v%s | %-5s | %s\\n'" },
    { name = 'money observation removed', fails = { 'T5' },
      from = "logObs(string.format('money check after buying", to = "local _ = (string.format('money check after buying" },
    { name = 'scribe attempt observation removed', fails = { 'T6' },
      from = "logObs(string.format('scribe attempt %d/%d for", to = "local _ = (string.format('scribe attempt %d/%d for" },
    { name = 'logging failure escapes instead of being contained', fails = { 'T7' },
      from = "LOG.disabled = true\n", to = "LOG.disabled = true\n    error('mutant: logging failure escapes')\n" },
    { name = 'ERROR color no longer mapped to the ERROR level', fails = { 'T10' },
      from = "if color == COLOR_ERR then level = 'ERROR' elseif", to = "if false then level = 'ERROR' elseif" },
    { name = 'startup stops logging build identity', fails = { 'T2' },
      from = "logObs(string.format('session start: build=v%s", to = "local _ = (string.format('session start: build=v%s" },
    { name = 'outcome line prints the accumulated totals as the result of this vendor', fails = { 'T11' },
      from = "S.bought - before.bought, S.skipped - before.skipped, formatCoin(S.spentCopper - before.spent),",
      to = "S.bought, S.skipped, formatCoin(S.spentCopper)," },
    { name = 'known-limits statement removed', fails = { 'T9' },
      from = "logObs('known limits:", to = "local _ = ('known limits:" },
}

local failures = 0
local function report(label, ok, detail)
    print(string.format('%-6s %s%s', ok and 'PASS' or 'FAIL', label, detail and (' -- ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

print('=== baseline: spellspree.lua (v' .. VERSION .. ') against the simulated MQ ===')
local base = evaluate(SCRIPT)
for _, t in ipairs(TESTS) do
    report(t.id .. ' ' .. t.src, base[t.id].pass, base[t.id].msg)
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
            -- a mutant that cannot even run still counts as "caught" only if it was meant to break the run
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
