-- Tests for Step 5, the log file follows the character that is playing (decision log D-028; design items A'-I'', Revisions 1-4).
-- Run from the repo root:  luajit test/test_logswitch.lua            (baseline, then mutation checks)
--                          luajit test/test_logswitch.lua baseline   (baseline only)
--                          luajit test/test_logswitch.lua stage N    (compare with the expected results of red-run stage N)
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, a model of MacroQuest and the vendor window, with a character name
-- that changes at set simulated times. A pass proves the script does what D-028 says against that model; the live check (the developer
-- switches characters in one client and confirms two files) is separate. The unit tests of the sync itself (guards, counter, failures,
-- throttle, snapshot) are in test_units.lua, U24-U34.
--
-- Labels: REQ/CHAR and NEW/REGRESSION as in test_step3.lua. `st[n]` is the result expected at red-run stage n, written before the stage was
-- run: 0 = unchanged script; 1 = new functions exposed as wrong stubs, nothing wired; 2 = the sync and helpers correct but nothing calls
-- them (logWriteFile and the run paths unchanged); 3 = the full build. Expected values come from the decision text and from the files the
-- script wrote and the mock's own record of purchases, never from running the script and pasting its output.
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = os.getenv('SPELLSPREE_SCRIPT') or 'spellspree.lua'   -- the red runs of stage 0 use the script as it was before Step 5
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\logswitch'
local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')
mkdir(TMP)

local function sp(name, level) return { name = name, price = 100, level = level } end
local function vendors()
    local function v(list) return { nonSpells = { 'Pickled Cat Food' }, spells = list } end
    return {
        ['Vicar Ceraen'] = v({ sp('A1', 5), sp('A2', 10) }), ['Vicar Thiran'] = v({}), ['Vicar Delin'] = v({}), ['Vicar Diarin'] = v({}),
    }
end
local function pok(extra)
    return function(dir)
        local o = { logsRaw = dir, rootRaw = dir, zone = 'poknowledge', clickPrefix = 'Run Shopping Spree', classes = { 'CLR' },
            openTrees = { Cleric = true }, ticks = { '1-25##Cleric' }, vendors = vendors() }
        for k, v in pairs(extra) do o[k] = v end
        return o
    end
end
local function ids(...) -- ids({atMs, character}, ...) on the default server
    local t = {}
    for _, e in ipairs({ ... }) do t[#t + 1] = { atMs = e[1], server = e[3] or 'SimServer', character = e[2] } end
    return t
end

-- name -> mock options. Run 1 starts at once; the second press is held back until the stated time, after the previous run has ended.
local SCENARIOS = {
    same     = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 } }),
    sw       = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'Other' }) }),
    between  = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 60000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'Other' }), redetectAtMs = 33000 }),
    midrun   = pok({ presses = 1, runs = 1, identities = ids({ 0, 'Simtest' }, { 3000, 'Other' }) }),
    back     = pok({ presses = 3, runs = 3, pressNotBeforeMs = { [2] = 31000, [3] = 61000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'Other' }, { 60000, 'Simtest' }) }),
    destfail = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'Other' }), logsUnreadableAfterMs = 30000 }),
    -- scenarios that run on a copy of the script in which every spree raises an error when it ends
    errsw    = pok({ presses = 1, runs = 1, identities = ids({ 0, 'Simtest' }, { 3000, 'Other' }) }),
    errno    = pok({ presses = 1, runs = 1 }),
    errtwice = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'Other' }) }),
    -- added after the mutation runs showed the plan left these untested (see the decision log, D-028 build results)
    quick    = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 33800 }, redetectAtMs = 33000, identities = ids({ 0, 'Simtest' }, { 33500, 'Other' }) }),
    unread   = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 }, identities = ids({ 0, 'Simtest' }, { 30000, 'NULL' }) }),
    samekey  = pok({ presses = 2, runs = 2, pressNotBeforeMs = { [2] = 40000 }, identities = ids({ 0, 'A_b' }, { 30000, 'A b' }) }),
}

local function fileFor(dir, character) return dir .. '\\spellspree\\spellspree_SimServer_' .. character .. '.log' end
local function lines(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local t = {}
    for l in f:lines() do t[#t + 1] = (l:gsub('\r$', '')) end
    f:close()
    return t
end
local function count(ls, plain) local n = 0; for _, l in ipairs(ls or {}) do if l:find(plain, 1, true) then n = n + 1 end end; return n end
local function lastIndex(ls, plain) local at; for i, l in ipairs(ls or {}) do if l:find(plain, 1, true) then at = i end end; return at end
local function firstIndex(ls, plain) for i, l in ipairs(ls or {}) do if l:find(plain, 1, true) then return i end end end
local function countPrints(sim, plain) local n = 0; for _, l in ipairs(sim.prints) do if l:find(plain, 1, true) then n = n + 1 end end; return n end

local function runScenario(script, tag, scenario)
    local dir = TMP .. '\\' .. tag
    os.execute('if exist "' .. dir .. '" rmdir /s /q "' .. dir .. '"')
    mkdir(dir)
    local sim = R.run(script, SCENARIOS[scenario](dir))
    local files = {}
    for _, c in ipairs({ 'Simtest', 'Other', 'A_b', 'NULL' }) do files[c] = lines(fileFor(dir, c)) end
    return { sim = sim, dir = dir, files = files, old = files.Simtest, new = files.Other }
end
local function replaceOnce(src, from, to)
    local at = src:find(from, 1, true)
    assert(at and not src:find(from, at + 1, true), 'transform target not found exactly once: ' .. from)
    return src:sub(1, at - 1) .. to .. src:sub(at + #from)
end
-- a copy of the script in which every shopping spree raises an error when it ends; `throttle` (optional) replaces the sync interval
local function errorScript(tag, throttle)
    local src = replaceOnce(SOURCE, "logLine(string.format('Shopping spree: all %d vendor(s) done.', #list), COLOR_GOLD)", "error('forced test error')")
    if throttle then
        local at = src:find('LOG_SYNC_EVERY_MS = 2000', 1, true)       -- absent before the build: the change is then a no-op
        if at then src = src:sub(1, at - 1) .. 'LOG_SYNC_EVERY_MS = ' .. throttle .. src:sub(at + #'LOG_SYNC_EVERY_MS = 2000') end
    end
    local path = TMP .. '\\' .. tag .. '.lua'
    local f = assert(io.open(path, 'wb')); f:write(src); f:close()
    return path
end

local function T(id, kind, label, st, src, fn) return { id = id, kind = kind, label = label, st = st, src = src, fn = fn } end
-- a test added after the build (post = true): its stage-0 result was taken against the script as it was before Step 5 (SPELLSPREE_SCRIPT),
-- and it passes at stage 3; stages 1 and 2 were not run for it
local F, P = 'fail', 'pass'
local FFFP = { [0] = F, [1] = F, [2] = F, [3] = P }
local ALLP = { [0] = P, [1] = P, [2] = P, [3] = P }
local POST = { [0] = F, [3] = P, post = true } -- added after the build; no stage 1 or 2 result exists

local TRANSITION = 'identity changed: SimServer/Simtest -> SimServer/Other'

local TESTS = {
    T('W1', 'REQ', 'NEW', FFFP, 'D-028 A\'-B\': a character switch between two runs puts the second run (its Run press, range line, ledger, outcome line) in the new character\'s file and none of it in the old; the old file ends with the transition line; the new file starts with the continued-session header and has the new-file notice',
      function(c)
          local r = c.sw
          if not r.new then return false, 'no file was written for Other' end
          if count(r.old, 'Outcome ledger') ~= 1 or count(r.new, 'Outcome ledger') ~= 1 then return false, string.format('ledgers: old %d, new %d (expected 1 and 1)', count(r.old, 'Outcome ledger'), count(r.new, 'Outcome ledger')) end
          if count(r.old, 'User pressed Run Shopping Spree.') ~= 1 or count(r.new, 'User pressed Run Shopping Spree.') ~= 1 then return false, 'each file should hold exactly its own Run press' end
          if count(r.new, 'Level range 1-25') ~= 1 then return false, 'the second run\'s range line should be in the new file only' end
          local last = r.old[#r.old]
          if not last:find(TRANSITION, 1, true) then return false, 'the old file does not end with the transition line: ' .. tostring(last) end
          if not r.new[1]:find('continued session', 1, true) then return false, 'the new file does not start with the continued session header: ' .. tostring(r.new[1]) end
          if count(r.new, 'Logging to a new file for Other: ') ~= 1 then return false, 'the new-file notice is missing' end
          return true
      end),

    T('W2', 'REQ', 'REGRESSION', ALLP, 'D-028 / F: with no character change there is one file, no transition line and no continued-session header across two runs',
      function(c)
          local r = c.same
          if r.new then return false, 'a second file exists' end
          if count(r.old, 'identity changed') ~= 0 or count(r.old, 'continued session') ~= 0 then return false, 'a transition line or header was written' end
          if count(r.old, 'Outcome ledger') ~= 2 then return false, 'expected both runs in the one file' end
          return true
      end),

    T('W3', 'REQ', 'NEW', FFFP, 'D-028 A\' (Revision 2 section 4): records written between runs follow the character: after a switch in the idle time, a Re-detect press and its class detection are in the new file, not the old',
      function(c)
          local r = c.between
          if not r.new then return false, 'no file was written for Other' end
          if count(r.new, 'User pressed Re-detect.') ~= 1 then return false, 'the Re-detect press should be in the new file' end
          if count(r.old, 'User pressed Re-detect.') ~= 0 then return false, 'the Re-detect press was written to the old file' end
          local detects = 0
          for _, l in ipairs(r.new) do if l:find('Detected class(es)', 1, true) or l:find('Could not detect any classes', 1, true) then detects = detects + 1 end end
          if detects < 1 then return false, 'the class detection after Re-detect is not in the new file' end
          if count(r.old, 'identity changed') ~= 1 then return false, 'expected one transition line in the old file' end
          return true
      end),

    T('W4', 'REQ', 'NEW', FFFP, 'D-028 D: every run-start observation carries the character and the server: run 1 as Simtest, run 2 as Other',
      function(c)
          local r = c.sw
          local a = {}
          for _, ls in ipairs({ r.old or {}, r.new or {} }) do
              for _, l in ipairs(ls) do if l:find('| run start: ', 1, true) then a[#a + 1] = l end end
          end
          if #a ~= 2 then return false, 'expected two run-start lines, saw ' .. #a end
          if not (a[1]:find('character=Simtest', 1, true) and a[1]:find('server=SimServer', 1, true)) then return false, 'run 1 start line: ' .. a[1] end
          if not (a[2]:find('character=Other', 1, true) and a[2]:find('server=SimServer', 1, true)) then return false, 'run 2 start line: ' .. a[2] end
          return true
      end),

    T('W5', 'REQ', 'NEW', FFFP, 'D-028 E\'\': a character change during a run leaves every record of the run in the original file with one note (observed, original, "records stay"); right after the run the transition record and the new file\'s header appear and the new file holds nothing of the run',
      function(c)
          local r = c.midrun
          if count(r.old, 'identity differs during a run') ~= 1 then return false, 'expected one note in the original file, saw ' .. count(r.old, 'identity differs during a run') end
          if count(r.old, 'Outcome ledger') ~= 1 or count(r.old, 'Skipped (') ~= 1 then return false, 'the whole run should be in the original file' end
          local t, e = lastIndex(r.old, TRANSITION), lastIndex(r.old, 'Skipped (')
          if not t or not e or t < e then return false, 'the transition record should come after the run\'s last record' end
          if not r.new then return false, 'no file for Other' end
          if not r.new[1]:find('continued session', 1, true) then return false, 'the new file should start with the header: ' .. tostring(r.new[1]) end
          if count(r.new, 'Outcome ledger') ~= 0 or count(r.new, 'User pressed') ~= 0 then return false, 'the new file holds part of the run' end
          return true
      end),

    T('W6', 'REQ', 'NEW', FFFP, 'D-028 E\'\' ordering: a run that ends in an error after a mid-run character change: the error line is in the original file, before the transition record; the new file starts with the header and has no error line; the same whether the throttle interval is open or shut',
      function()
          for _, throttle in ipairs({ '0', '1000000000' }) do
              local path = errorScript('errsw_' .. throttle, throttle)
              local r = runScenario(path, 'errsw_' .. throttle, 'errsw')
              local label = 'throttle ' .. throttle .. ': '
              if not r.old then return false, label .. 'no original file' end
              local e, t = lastIndex(r.old, 'Unexpected error'), lastIndex(r.old, TRANSITION)
              if not e then return false, label .. 'the error line is not in the original file' end
              if not t then return false, label .. 'no transition record in the original file' end
              if t < e then return false, label .. 'the transition record comes before the error line' end
              if not r.new then return false, label .. 'no file for Other' end
              if count(r.new, 'Unexpected error') ~= 0 then return false, label .. 'the error line is in the new file' end
              if not r.new[1]:find('continued session', 1, true) then return false, label .. 'the new file does not start with the header: ' .. tostring(r.new[1]) end
          end
          return true
      end),

    T('W7', 'CHAR', 'REGRESSION', ALLP, 'D-028 E\'\' (no change): a run that ends in an error with no character change: the error line is in the one file, with no transition record after it',
      function()
          local r = runScenario(errorScript('errno'), 'errno', 'errno')
          if r.new then return false, 'a second file exists' end
          if count(r.old, 'Unexpected error') ~= 1 then return false, 'expected one error line, saw ' .. count(r.old, 'Unexpected error') end
          if count(r.old, 'identity changed') ~= 0 or count(r.old, 'continued session') ~= 0 then return false, 'an identity record was written' end
          return true
      end),

    T('W8', 'REQ', 'NEW', FFFP, 'D-028 / Revision 2 section 6: switching away and back appends: Simtest\'s file holds run 1 then (appended) a continued session header and run 3, B\'s file holds run 2 between its header and the transition back; earlier lines stay intact and in order',
      function(c)
          local r = c.back
          if not r.new or not r.old then return false, 'expected both files' end
          if count(r.old, 'Outcome ledger') ~= 2 then return false, 'Simtest\'s file should hold runs 1 and 3, saw ' .. count(r.old, 'Outcome ledger') end
          if count(r.new, 'Outcome ledger') ~= 1 then return false, 'Other\'s file should hold run 2, saw ' .. count(r.new, 'Outcome ledger') end
          local firstLedger, header = firstIndex(r.old, 'Outcome ledger'), lastIndex(r.old, 'continued session')
          if not header or header < firstLedger then return false, 'the continued session header should be appended after run 1 in Simtest\'s file' end
          if count(r.old, 'continued session') ~= 1 then return false, 'expected exactly one appended header in Simtest\'s file' end
          if count(r.old, 'session start: build=') ~= 1 then return false, 'the original startup block should appear once' end
          if not r.new[#r.new]:find('identity changed: SimServer/Other -> SimServer/Simtest', 1, true) then return false, 'Other\'s file should end with the transition back: ' .. tostring(r.new[#r.new]) end
          if count(r.old, TRANSITION) ~= 1 then return false, 'Simtest\'s file should hold the first transition line once' end
          return true
      end),

    T('W9', 'REQ', 'NEW', FFFP, 'D-028 E / I\'\': a logging failure on the new destination (the logs path unreadable after the switch) changes no purchase, writes one failure notice and no success notice, and nothing more is written to either file',
      function(c)
          local r, control = c.destfail, c.same
          if table.concat(r.sim.purchases, ',') ~= table.concat(control.sim.purchases, ',') then return false, 'the purchases differ from the run without a switch' end
          if countPrints(r.sim, 'File logging is OFF') ~= 1 then return false, 'expected one failure notice, saw ' .. countPrints(r.sim, 'File logging is OFF') end
          if countPrints(r.sim, 'Logging to a new file') ~= 0 then return false, 'a success notice was printed' end
          if not r.old or not r.old[#r.old]:find(TRANSITION, 1, true) then return false, 'the old file should end at the transition record: ' .. tostring(r.old and r.old[#r.old]) end
          if r.new then return false, 'a file was created for Other' end
          return true
      end),

    T('W10', 'REQ', 'NEW', FFFP, 'D-028 E\'\' / I\'\' (guards): after a run that failed with an error, the next run still follows a character change (the hold was released): run 1 errors, the character changes, run 2\'s records, including its error line, are in the new file',
      function()
          local r = runScenario(errorScript('errtwice'), 'errtwice', 'errtwice')
          if not r.new then return false, 'no file for Other' end
          if count(r.old, 'Unexpected error') ~= 1 or count(r.new, 'Unexpected error') ~= 1 then return false, string.format('error lines: old %d, new %d (expected 1 and 1)', count(r.old, 'Unexpected error'), count(r.new, 'Unexpected error')) end
          if count(r.new, 'User pressed Run Shopping Spree.') ~= 1 then return false, 'the second Run press should be in the new file' end
          if count(r.old, TRANSITION) ~= 1 then return false, 'one transition record expected in the old file' end
          return true
      end),

    T('W11', 'REQ', 'NEW', POST, 'D-028 A\' (forced sync at the press): a character change within 2,000 ms after the last sync, then a Run press: the press line is in the new file (the throttle alone would have left it in the old one)',
      function(c)
          local r = c.quick
          if not r.new then return false, 'no file for Other' end
          if count(r.new, 'User pressed Run Shopping Spree.') ~= 1 then return false, 'the second Run press should be in the new file, saw ' .. count(r.new, 'User pressed Run Shopping Spree.') end
          if count(r.old, 'User pressed Run Shopping Spree.') ~= 1 then return false, 'the old file should hold only the first Run press' end
          if count(r.old, TRANSITION) ~= 1 then return false, 'one transition line expected in the old file' end
          return true
      end),

    T('W12', 'REQ', 'NEW', POST, 'D-028 C: a character name that reads NULL keeps the current file (no file for NULL), writes one OBS line, and both runs stay in the one file with no transition or header',
      function(c)
          local r = c.unread
          if r.files.NULL then return false, 'a file was created for the unreadable name' end
          if r.new then return false, 'a file for Other exists' end
          if count(r.old, 'identity unreadable') ~= 1 then return false, 'expected one OBS line, saw ' .. count(r.old, 'identity unreadable') end
          if count(r.old, 'Outcome ledger') ~= 2 then return false, 'both runs should be in the one file' end
          if count(r.old, 'identity changed') ~= 0 or count(r.old, 'continued session') ~= 0 then return false, 'a transition or header was written' end
          return true
      end),

    T('W13', 'REQ', 'NEW', POST, 'D-028 A\' (Revision 3 section 2): two raw names that sanitize to one file ("A_b" then "A b"): one file, one identity-change record and one continued session header in it, no new-file notice',
      function(c)
          local r = c.samekey
          local a = r.files.A_b
          if not a then return false, 'no file for A_b' end
          if r.old or r.new then return false, 'another file exists' end
          if count(a, 'identity changed: SimServer/A_b -> SimServer/A b') ~= 1 then return false, 'expected one identity-change record, saw ' .. count(a, 'identity changed: SimServer/A_b -> SimServer/A b') end
          if count(a, 'continued session') ~= 1 then return false, 'expected one continued session header' end
          if count(a, 'Logging to a new file') ~= 0 then return false, 'a new-file notice was written for the same file' end
          if count(a, 'Outcome ledger') ~= 2 then return false, 'both runs should be in the one file' end
          return true
      end),

    T('W14', 'REQ', 'NEW', POST, "D-028 E'' (the error write is protected): a failure while writing a failed run's error line neither stops the script nor leaves the hold set: the next run after a character change is written to the new file",
      function()
          local src = replaceOnce(SOURCE, "logLine(string.format('Shopping spree: all %d vendor(s) done.', #list), COLOR_GOLD)", "error('forced test error')")
          local tail = "    if color == COLOR_ERR then level = 'ERROR' elseif color == COLOR_WARN then level = 'WARN' end\n    logWriteFile(level, text)\nend"
          src = replaceOnce(src, tail, "    if color == COLOR_ERR then level = 'ERROR' elseif color == COLOR_WARN then level = 'WARN' end\n    logWriteFile(level, text)\n    if tostring(text):find('^Unexpected error') then error('forced logLine failure') end\nend")
          local path = TMP .. '\\logfail.lua'
          local f = assert(io.open(path, 'wb')); f:write(src); f:close()
          local r = runScenario(path, 'logfail', 'errtwice')
          if not r.sim.ok then return false, 'the script stopped: ' .. tostring(r.sim.runErr) end
          if not r.new then return false, 'no file for Other: the hold was not released' end
          if count(r.new, 'User pressed Run Shopping Spree.') ~= 1 then return false, 'the second Run press should be in the new file' end
          if count(r.old, 'Unexpected error') ~= 1 then return false, "the first run's error line should be in the original file" end
          return true
      end),
}

local function evaluate(script)
    local c = {}
    for name in pairs({ same = 1, sw = 1, between = 1, midrun = 1, back = 1, destfail = 1, quick = 1, unread = 1, samekey = 1 }) do c[name] = runScenario(script, name, name) end
    local res = {}
    for _, t in ipairs(TESTS) do
        local ok, a, b = pcall(t.fn, c)
        if not ok then res[t.id] = { pass = false, msg = 'test errored: ' .. tostring(a) }
        else res[t.id] = { pass = a == true, msg = b } end
    end
    return res
end

-- filled in after the build; the expected sets are written before the first run
-- Step 5 mutations (D-028). The expected sets below were written before the first run, from reading what each test asserts.
local MUTATIONS = {
    { name = "logSyncIdentity never syncs", fails = { 'W1', 'W3', 'W5', 'W6', 'W8', 'W9', 'W10', 'W11', 'W12', 'W13', 'W14' },
      from = "    if LOG.syncing or LOG.disabled or not LOG.path then return end\n    local now = logClockMs()",
      to = "    do return end\n    local now = logClockMs()" },
    { name = "the forced sync at the Run press is removed (the press line relies on the throttle)", fails = { 'W11' },
      from = "            logSyncIdentity(true)\n            logLine('User pressed Run Shopping Spree.', COLOR_MUTE)",
      to = "            logLine('User pressed Run Shopping Spree.', COLOR_MUTE)" },
    { name = "LOG.path is not cleared on a switch", fails = { 'W1', 'W3', 'W5', 'W6', 'W8', 'W9', 'W10', 'W11', 'W14' },
      from = "            LOG.path, LOG.identityKey, LOG.writes = nil, nil, 0",
      to = "            LOG.identityKey, LOG.writes = nil, 0" },
    { name = "the identity-changed line is not written", fails = { 'W1', 'W3', 'W5', 'W6', 'W8', 'W9', 'W10', 'W11', 'W13' },
      from = "        logObs(string.format('identity changed: %s/%s -> %s/%s; %s',",
      to = "        local _ = (string.format('identity changed: %s/%s -> %s/%s; %s'," },
    { name = "an unreadable identity is not recognised (the script switches on it)", fails = { 'W12' },
      from = "        if logUnavailable(server) or logUnavailable(char) then",
      to = "        if false then" },
    { name = "the new file header is not marked as a continued session", fails = { 'W1', 'W5', 'W6', 'W8', 'W13' },
      from = "'session start (continued session): build=v%s source=%s load offset=+%dms'",
      to = "'session start: build=v%s source=%s load offset=+%dms'" },
    { name = "there is no recursion guard", fails = { 'W6' },
      from = "    if LOG.syncing or LOG.disabled or not LOG.path then return end",
      to = "    if LOG.disabled or not LOG.path then return end" },
    { name = "the destination is decided on the raw identity only (the same file is treated as a switch)", fails = { 'W13' },
      from = "        local sameFile = (key == LOG.identityKey)",
      to = "        local sameFile = false" },
    { name = "the success notice is written even after a failure", fails = { 'W9' },
      from = "        if not LOG.disabled and not sameFile then\n            logLine(string.format('Logging to a new file",
      to = "        if not sameFile then\n            logLine(string.format('Logging to a new file" },
    { name = "detection is suppressed while a run holds the file", fails = { 'W5' },
      from = "        if LOG.hold then\n            local id = server",
      to = "        if LOG.hold then\n            do return end\n            local id = server" },
    { name = "no forced sync after the dispatch", fails = { 'W5', 'W6' },
      from = "    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\nend",
      to = "    LOG.hold, LOG.heldNoted = false, nil\nend" },
    { name = "the forced sync is skipped when the run failed", fails = { 'W6' },
      from = "    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\nend",
      to = "    LOG.hold, LOG.heldNoted = false, nil\n    if ok then logSyncIdentity(true) end\nend" },
    { name = "LOG.hold is not cleared after a failed run", fails = { 'W6', 'W10', 'W14' },
      from = "    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\nend",
      to = "    if ok then LOG.hold, LOG.heldNoted = false, nil end\n    logSyncIdentity(true)\nend" },
    { name = "the forced sync comes before the error line", fails = { 'W6' },
      from = "    if not ok then\n        S.state = STATE.STOPPED\n        S.lastStopReason = 'Script error'\n        pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end)\n    end\n    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\nend",
      to = "    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\n    if not ok then\n        S.state = STATE.STOPPED\n        S.lastStopReason = 'Script error'\n        pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end)\n    end\nend" },
    { name = "the error line is written after the hold is cleared (the order of Revision 3)", fails = { 'W6' },
      from = "    if not ok then\n        S.state = STATE.STOPPED\n        S.lastStopReason = 'Script error'\n        pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end)\n    end\n    LOG.hold, LOG.heldNoted = false, nil\n    logSyncIdentity(true)\nend",
      to = "    if not ok then\n        S.state = STATE.STOPPED\n        S.lastStopReason = 'Script error'\n    end\n    LOG.hold, LOG.heldNoted = false, nil\n    if not ok then pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end) end\n    logSyncIdentity(true)\nend" },
    { name = "the error write is not protected", fails = { 'W14' },
      from = "        pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end)",
      to = "        logLine('Unexpected error: ' .. tostring(err), COLOR_ERR)" },
    -- W5 also fails: the note during a run is written by the sync that logWriteFile runs, so without it nothing is detected (my first prediction missed that)
    { name = "logWriteFile no longer runs the throttled sync", fails = { 'W3', 'W5' },
      from = "    -- D-028 A': the character may have changed since the last record; the sync is throttled and guarded against re-entry\n    logSyncIdentity(false)\n    if LOG.disabled then return end\n",
      to = "" },
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
        if want == nil then goto skip end
        local same = got == want
        if not same then mismatches = mismatches + 1 end
        print(string.format('%-4s %s expected %s, got %s%s', same and 'OK' or 'DIFF', t.id, want, got, (got == 'fail' and base[t.id].msg) and (' -- ' .. base[t.id].msg:sub(1, 150)) or ''))
        ::skip::
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
