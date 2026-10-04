-- Tests for Step 6, discipline-tome shopping in the Plane of Knowledge (decision log D-030; design items A-K'' of Revisions 1-4).
-- Run from the repo root:  luajit test/test_tomes.lua            (baseline, then mutation checks)
--                          luajit test/test_tomes.lua baseline   (baseline only)
--                          luajit test/test_tomes.lua stage N    (compare with the expected results of red-run stage N)
--
-- SIMULATION ONLY. These run spellspree.lua against test/mock_mq.lua, a model of MacroQuest and the vendor window (tome vendors, known disciplines, the cursor, chat
-- events; see docs/MOCK_MODEL.md rows 38-44). A pass proves the script does what D-030 says against that model. What the live client does for a learn of a NEW tome, for
-- /autoinventory and for Merchant.Name has never been observed and is checked in the live run. The pure rules (name tests, normalization, known verdicts, the learn
-- state table, the known scan, the cursor recovery) are also tested directly in test_units.lua, U36-U44.
--
-- Labels: REQ/CHAR and NEW/REGRESSION as in test_step3.lua. `st[n]` is the result expected at red-run stage n, written before the stage was run: 0 = unchanged script;
-- 1 = the new functions exposed as wrong stubs, nothing wired; 2 = the functions correct, nothing wired into the script's behavior; 3 = the full build. Expected values come
-- from the design text and from the mock's own record (sim.purchases, sim.buyClicks, sim.selectClicks, sim.tomeClicks, sim.autoinvCount, sim.cmds, sim.cursor), never from
-- running the script and pasting its output.
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local SCRIPT = os.getenv('SPELLSPREE_SCRIPT') or 'spellspree.lua'
local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\tomes'
local function readAll(path) local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close(); return s end
local function mkdir(p) os.execute('if not exist "' .. p .. '" mkdir "' .. p .. '"') end
local SOURCE = readAll(SCRIPT):gsub('\r\n', '\n')
local LOGNAME = 'spellspree_SimServer_Simtest.log'
mkdir(TMP)

-- ---------------------------------------------------------------- stock
local function tm(name, level, extra)
    local t = { name = name, level = level, price = 100 }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end
local NOISE = { 'Boar Meat', 'Diamond' }
local function vendor(tomes, spells, noise) return { nonSpells = noise or NOISE, spells = spells or {}, tomes = tomes } end

local K, G = 'Kurlond Axebringer', 'Gaddi Buruca'
local function berserkers(kurlond, gaddi) return { [K] = vendor(kurlond), [G] = vendor(gaddi) } end

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end

-- a Plane of Knowledge scenario; `extra` is merged over the defaults; classes the character has are listed in `classes`
local function pok(extra)
    return function(dir)
        local o = { logsRaw = dir, rootRaw = dir, zone = 'poknowledge', clickPrefix = 'Run Shopping Spree', classes = { 'MNK' },
            openTrees = { Monk = true, Berserker = true, Paladin = true, Shadowknight = true, Warrior = true, Rogue = true }, ticks = {}, vendors = {} }
        for k, v in pairs(deepcopy(extra)) do o[k] = v end
        -- _fresh builds options holding state (a counter) anew for every run of the scenario, so repeated evaluations (the mutation runs) start alike
        if extra._fresh then for k, v in pairs(extra._fresh()) do o[k] = v end end
        return o
    end
end
local MONK = 'Beorobin Amondson'

local SCENARIOS = {
    -- the tome-only class box (the parent box of Monk) ticks tomes; five tomes, none known
    monk_plain = pok({ ticks = { '##class_Monk' }, vendors = { [MONK] = vendor({ tm('Fearless Discipline', 40), tm('Inner Flame Discipline', 56, { teaches = 'Innerflame Discipline' }),
        tm('Stone Stance Discipline', 51, { teaches = 'Stonestance Discipline' }), tm('Phantom Shadow', 65), tm('Elbow Strike', 5) }) } }),
    -- the same stock, three disciplines already known: one exact, two that match only when spaces are ignored
    monk_known = pok({ ticks = { '##class_Monk' }, knownDisciplines = { 'Fearless Discipline', 'Innerflame Discipline', 'Stonestance Discipline' },
        vendors = { [MONK] = vendor({ tm('Fearless Discipline', 40), tm('Inner Flame Discipline', 56, { teaches = 'Innerflame Discipline' }),
            tm('Stone Stance Discipline', 51, { teaches = 'Stonestance Discipline' }), tm('Phantom Shadow', 65), tm('Elbow Strike', 5) }) } }),
    -- no level bounding: levels 0, 71, no level and text
    levels = pok({ ticks = { '##class_Monk' }, vendors = { [MONK] = vendor({ tm('Level Zero', 0), tm('Level Seventy One', 71), tm('No Level', nil), tm('Word Level', nil, { levelText = 'abc' }) }) } }),
    -- the name rule: near-misses, scrolls and songs among one real tome
    rules = pok({ ticks = { '##class_Monk' }, vendors = { [MONK] = vendor({ tm('Real Discipline', 10) }, { { name = 'Foliage Shield', level = 44, price = 100 } },
        { 'tome of fire', 'Tomes of Lore', 'Tome of', 'Tome Of Water', 'Song: Chant of Battle', 'Boar Meat' }) } }),
    -- Berserker: both vendors, the smaller one's stock entirely inside the larger one's (observed live); Diversive Strike teaches Divertive Strike (inferred)
    overlap = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, vendors = berserkers(
        { tm('Battle Cry', 30), tm('Head Strike', 12), tm('Leg Strike', 18), tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) },
        { tm('Head Strike', 12), tm('Leg Strike', 18), tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) }) }),
    -- a tome whose Buy click is sent but whose payment does not happen (too dear for the money on hand), at both vendors
    pay_unseen = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, money = 1000, vendors = berserkers(
        { tm('Cheap A', 5), tm('Dear X', 6, { price = 10000 }), tm('Cheap B', 7) }, { tm('Dear X', 6, { price = 10000 }) }) }),
    -- a tome that never reaches the Buy click at the first vendor (selection never verified) and may be tried at the second
    misselect = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, misselect = { name = 'Tome of Head Strike', times = 3 }, vendors = berserkers(
        { tm('Battle Cry', 30), tm('Head Strike', 12) }, { tm('Head Strike', 12) }) }),
    -- a known discipline whose tome name cannot be derived (the check misses it): message, cursor, recovery; the run continues
    slip = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, vendors = berserkers(
        { tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }), tm('Head Strike', 12) }, { tm('Head Strike', 12) }) }),
    -- the tome passes through the cursor for 400 ms and is then learned
    transient = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeTransientCursorMs = 400, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- the unreadable initial count, four ways
    count_nil = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, countOverride = function() return nil end, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    count_raise = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, countOverride = function() error('simulated count read error') end, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    count_text = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, countOverride = function() return 'x' end, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    count_zero = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, countOverride = function() return 0 end, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- the tome is on the cursor, the discipline is known, but there is no message and no by-name evidence: unresolved
    cursor_unresolved = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, knownMessageNever = true, vendors = berserkers(
        { tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) }, { tm('Head Strike', 12) }) }),
    -- the same, corroborated only by a by-name lookup that turns positive after the classification (no message)
    cursor_byname = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, knownMessageNever = true,
        _fresh = function() local n = 0; return { byNameResult = function() n = n + 1; if n == 1 then return nil end return 7 end } end,
        vendors = { [K] = vendor({ tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) }), [G] = vendor({ tm('Head Strike', 12) }) } }),
    -- learning completes between two attempts (after the first window, before the second reclassification)
    between = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeLearnDelayMs = 1100, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- the target slot is emptied, replaced and moved, with the count unchanged (the tome is hidden, not gone)
    replaced = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeReplaceAfterClick = 'Tome of Other', vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    vanish = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeVanishAfterClick = true, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    relocate = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeRelocateAfterClick = true, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    late = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, tomeVanishAfterClick = true, hiddenReleaseMs = 1500, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- the known scan cannot read slot 1 (Fearless is known), but the by-name lookup can
    scanerr = pok({ ticks = { '##class_Monk' }, knownDisciplines = { 'Fearless Discipline', 'Bellow' }, knownScanErrors = { [1] = true },
        vendors = { [MONK] = vendor({ tm('Fearless Discipline', 40), tm('Elbow Strike', 5) }) } }),
    -- the by-name lookup cannot confirm a known discipline the list cannot see either: nonpositive results
    byname_zero = pok({ ticks = { '##class_Monk' }, knownDisciplines = { 'Fearless Discipline' }, knownScanErrors = { [1] = true }, byNameResult = function() return 0 end,
        vendors = { [MONK] = vendor({ tm('Fearless Discipline', 40) }) } }),
    byname_raise = pok({ ticks = { '##class_Monk' }, knownDisciplines = { 'Fearless Discipline' }, knownScanErrors = { [1] = true }, byNameResult = function() return 'RAISE' end,
        vendors = { [MONK] = vendor({ tm('Fearless Discipline', 40) }) } }),
    -- two known names that normalize alike and a tome that matches both
    ambig = pok({ ticks = { '##class_Monk' }, knownDisciplines = { 'Foo Bar', 'FooBar' }, vendors = { [MONK] = vendor({ tm('Foo-Bar', 10, { teaches = 'Foo-Bar' }) }) } }),
    -- two runs: the first aborts (the count cannot be read), the second is not affected by the abort
    abort_twice = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, presses = 2, runs = 2, pressNotBeforeMs = { [2] = 90000 },
        _fresh = function() local n = 0; return { countOverride = function(_, real) n = n + 1; if n <= 1 then return nil end return real end } end,
        vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- Shadowknight: the vendor's name has a backtick
    zhao = pok({ classes = { 'SHD' }, ticks = { 'Discipline Tomes##Shadowknight' }, vendors = { ['Zhao V`karin'] = vendor({ tm('Unholy Aura Discipline', 55), tm('Leechcurse Discipline', 50) }) } }),
    -- money for two of five tomes
    money = pok({ ticks = { '##class_Monk' }, money = 250, vendors = { [MONK] = vendor({ tm('Tome A', 1), tm('Tome B', 2), tm('Tome C', 3), tm('Tome D', 4), tm('Tome E', 5) }) } }),
    -- Paladin: the four ranges and the tomes in one run; the class box ticks the ranges only; the tomes box alone
    paladin_both = pok({ classes = { 'PAL' }, ticks = { '1-25##Paladin', 'Discipline Tomes##Paladin' }, vendors = {
        ['Cavalier Waut'] = vendor({}, { { name = 'Spell A', level = 10, price = 100 }, { name = 'Spell B', level = 30, price = 100 } }, { 'Boar Meat' }),
        ['Ulin Velnik'] = vendor({ tm('Deflection Discipline', 30), tm('Holyforge Discipline', 55) }) } }),
    paladin_parent = pok({ classes = { 'PAL' }, ticks = { '##class_Paladin' }, vendors = {
        ['Cavalier Waut'] = vendor({}, { { name = 'Spell A', level = 10, price = 100 } }, { 'Boar Meat' }), ['Cavalier Aodus'] = vendor({}, {}, { 'Boar Meat' }),
        ['Cavalier Preradus'] = vendor({}, {}, { 'Boar Meat' }), ['Ulin Velnik'] = vendor({ tm('Deflection Discipline', 30) }) } }),
    paladin_tomes = pok({ classes = { 'PAL' }, ticks = { 'Discipline Tomes##Paladin' }, vendors = {
        ['Cavalier Waut'] = vendor({}, { { name = 'Spell A', level = 10, price = 100 } }, { 'Boar Meat' }), ['Ulin Velnik'] = vendor({ tm('Deflection Discipline', 30) }) } }),
    -- a scroll visit at a vendor that also lists tomes: the tomes are ignored
    scroll_visit = pok({ classes = { 'PAL' }, ticks = { '1-25##Paladin' }, vendors = {
        ['Cavalier Waut'] = vendor({ tm('Stray Tome', 5) }, { { name = 'Spell A', level = 10, price = 100 } }, { 'Boar Meat' }) } }),
    -- a different item lands where the tome should be
    landwrong = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, landAs = function() return 'Tome of Other' end, vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- recovery fails, or has no room
    recfail = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, autoinventoryFails = true, vendors = berserkers(
        { tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) }, { tm('Head Strike', 12) }) }),
    noroom = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, fillBagOnCursor = true, vendors = berserkers(
        { tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }) }, { tm('Head Strike', 12) }) }),
    -- something else is on the cursor when a tome visit starts
    startcursor = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, startCursor = 'Mystery Bone', vendors = berserkers({ tm('Battle Cry', 30) }, { tm('Leg Strike', 18) }) }),
    -- Stop pressed while /autoinventory is working (the cursor empties 1.5 s after the command)
    stoprecov = pok({ classes = { 'BER' }, ticks = { '##class_Berserker' }, knownDisciplines = { 'Divertive Strike' }, autoinvDelayMs = 1500, stopAtMs = 7500, vendors = berserkers(
        { tm('Diversive Strike', 24, { teaches = 'Divertive Strike' }), tm('Head Strike', 12) }, { tm('Head Strike', 12) }) }),
    -- all four tome-only classes and the Berserker pair, ticked at once
    allclasses = pok({ classes = { 'WAR', 'MNK', 'ROG', 'BER' }, ticks = { '##class_Warrior', '##class_Monk', '##class_Rogue', '##class_Berserker' }, vendors = {
        ['Heldin Swordbreaker'] = vendor({ tm('Warrior Disc', 10) }), [MONK] = vendor({ tm('Monk Disc', 10) }), ['Blane Darkblade'] = vendor({ tm('Rogue Disc', 10) }),
        [K] = vendor({ tm('Berserker Disc', 10) }), [G] = vendor({ tm('Berserker Disc', 10) }) } }),
}

local function runScenario(script, tag, mk)
    local dir = TMP .. '\\' .. tag
    os.execute('if exist "' .. dir .. '" rmdir /s /q "' .. dir .. '"')
    mkdir(dir)
    local sim = R.run(script, mk(dir))
    return { sim = sim, lines = R.readLines(dir .. '\\spellspree\\' .. LOGNAME) or {}, dir = dir }
end
local function runAll(script)
    local out = {}
    for name, mk in pairs(SCENARIOS) do out[name] = runScenario(script, name, mk) end
    return out
end
local function replaceOnce(src, from, to)
    local at = src:find(from, 1, true)
    assert(at and not src:find(from, at + 1, true), 'transform target not found exactly once: ' .. from)
    return src:sub(1, at - 1) .. to .. src:sub(at + #from)
end

-- ---------------------------------------------------------------- helpers
local function grep(lines, plain)
    local hits = {}
    for _, l in ipairs(lines or {}) do if l:find(plain, 1, true) then hits[#hits + 1] = l end end
    return hits
end
-- every right-click command sent landed on a tome that was in its slot: none was sent at an empty slot or while the tome was on the cursor
local function noStrayClicks(sim)
    local n = 0
    for _, cmd in ipairs(sim.cmds) do if cmd:find('rightmouseup', 1, true) then n = n + 1 end end
    return n == sim.tomeClicks, string.format('%d right-click command(s) sent, but only %d reached a tome in its slot', n, sim.tomeClicks)
end
local function count(list, pred) local n = 0; for _, v in ipairs(list) do if pred(v) then n = n + 1 end end; return n end
local function cmdCount(sim, prefix) return count(sim.cmds, function(c) return c:sub(1, #prefix) == prefix end) end
local function visited(sim)
    local seq = {}
    for _, c in ipairs(sim.cmds) do local n = c:match('^/target npc "=(.+)"$'); if n then seq[#seq + 1] = n end end
    return seq
end
local function show(t) return '[' .. table.concat(t, ', ') .. ']' end
local function sameList(a, b) if #a ~= #b then return false end; for i = 1, #a do if a[i] ~= b[i] then return false end end; return true end
local function setOf(list) local s = {}; for _, v in ipairs(list) do s[v] = (s[v] or 0) + 1 end; return s end
local function tomes(list) local t = {}; for _, n in ipairs(list) do t[#t + 1] = 'Tome of ' .. n end; return t end
local function boughtExactly(sim, want)
    local got, w = setOf(sim.purchases), setOf(tomes(want))
    for n in pairs(w) do if got[n] ~= 1 then return false, string.format('"%s" was bought %d time(s), expected 1', n, got[n] or 0) end end
    for n, c in pairs(got) do if not w[n] then return false, string.format('"%s" was bought (%d time(s)) but is not in %s', n, c, show(want)) end end
    return true
end
local function neverTouched(sim, names)
    for _, n in ipairs(names) do
        if sim.selectClicks[n] or sim.buyClicks[n] then return false, string.format('"%s" was selected or Buy-clicked', n) end
    end
    return true
end
local function firstFail(...)
    for _, r in ipairs({ ... }) do if not r[1] then return false, r[2] end end
    return true
end
-- every "Outcome ledger" line of the run, in order: { n=, counts={label=count} }
local function ledgers(lines)
    local out = {}
    for _, l in ipairs(lines) do
        local n, rest = l:match('Outcome ledger %((%d+) built%-list entries%): (.-)%.$')
        if n then
            local counts = {}
            for label, c in rest:gmatch('([^;=]+)=(%d+)') do counts[(label:gsub('^%s+', ''))] = tonumber(c) end
            out[#out + 1] = { n = tonumber(n), counts = counts }
        end
    end
    return out
end
-- the names-and-reasons line of an outcome in a visit's ledger (visit index v, 1-based), or nil
local function ledgerNames(lines, label, v)
    local visit = 0
    local seen
    for _, l in ipairs(lines) do
        if l:find('Outcome ledger (', 1, true) then visit = visit + 1 end
        if visit == v and l:find('  ' .. label .. ' (', 1, true) and l:find('): ', 1, true) then seen = l end
    end
    return seen
end
-- elapsed ms (the +Nms column) of a log line
local function elapsed(l) return tonumber(l:match('| %+(%d+)ms |')) end

local LEARNED, NOT_LEARNED, SKIPPED, STOPPED, NOT_BOUGHT = 'bought and learned', 'bought, learn not completed', 'deliberately skipped', 'not attempted because the run stopped', 'attempted, not bought'
local TOME_LABELS = { [LEARNED] = true, [NOT_LEARNED] = true }

-- ---------------------------------------------------------------- tests
local function T(id, kind, label, st, src, fn) return { id = id, kind = kind, label = label, st = st, src = src, fn = fn } end
local F, P = 'fail', 'pass'
local FFFP = { [0] = F, [1] = F, [2] = F, [3] = P }
local ALLP = { [0] = P, [1] = P, [2] = P, [3] = P }

local TESTS = {
    T('D1', 'REQ', 'NEW', FFFP, 'D-030 A / requirement 1-3: the tome-only class Monk appears and its parent box selects Discipline Tomes: one visit to its vendor, no range needed; all five unknown tomes are bought and learned, once each',
      function(c)
          local r = c.monk_plain
          return firstFail({ sameList(visited(r.sim), { MONK }), 'visited ' .. show(visited(r.sim)) .. ', expected only ' .. MONK },
              { boughtExactly(r.sim, { 'Fearless Discipline', 'Inner Flame Discipline', 'Stone Stance Discipline', 'Phantom Shadow', 'Elbow Strike' }) },
              { r.sim.tomeClicks == 5, 'expected 5 right-clicks (one per tome), saw ' .. r.sim.tomeClicks },
              { r.sim.autoinvCount == 0, '/autoinventory was sent' })
      end),

    T('D2', 'REQ', 'NEW', FFFP, 'D-030 B / requirement 3: a tome visit has no level bounding: tomes at level 0, 71, with no level and with text for a level are all bought',
      function(c) return boughtExactly(c.levels.sim, { 'Level Zero', 'Level Seventy One', 'No Level', 'Word Level' }) end),

    T('D3', 'REQ', 'NEW', FFFP, 'D-030 C: only a row named "Tome of <something>" is a tome: near-misses ("tome of fire", "Tomes of Lore", "Tome of", "Tome Of Water"), a Song: scroll, a Spell: scroll and plain items are never selected or clicked',
      function(c)
          local r = c.rules
          return firstFail({ boughtExactly(r.sim, { 'Real Discipline' }) },
              { neverTouched(r.sim, { 'tome of fire', 'Tomes of Lore', 'Tome of', 'Tome Of Water', 'Song: Chant of Battle', 'Spell: Foliage Shield', 'Boar Meat' }) })
      end),

    T('D4', 'REQ', 'NEW', FFFP, 'D-030 D: tomes of disciplines the character already knows are skipped before any click: exactly spelled, and spelled with a space the discipline name lacks (Inner Flame / Innerflame, Stone Stance / Stonestance); the others are bought; the skips are ledger outcomes and not in the Skipped counter',
      function(c)
          local r = c.monk_known
          local led = ledgers(r.lines)[1]
          local line = ledgerNames(r.lines, SKIPPED, 1)
          local o = grep(r.lines, 'Run outcome (Nav & Shop "' .. MONK .. '")')
          return firstFail({ boughtExactly(r.sim, { 'Phantom Shadow', 'Elbow Strike' }) },
              { neverTouched(r.sim, { 'Tome of Fearless Discipline', 'Tome of Inner Flame Discipline', 'Tome of Stone Stance Discipline' }) },
              { led and led.counts[SKIPPED] == 3, 'expected 3 deliberately skipped' },
              { line and line:find('discipline already known', 1, true), 'the skip reason should say the discipline is already known: ' .. tostring(line) },
              { #o == 1 and o[1]:find('skipped=0', 1, true), 'the run outcome line should report skipped=0: ' .. tostring(o[1]) })
      end),

    T('D5', 'REQ', 'NEW', FFFP, 'D-030 D: each tome visit logs how the known-discipline scan went (names found, read errors and empty slots counted apart, last filled slot, how it ended) and each tome\'s verdict',
      function(c)
          local r = c.monk_known
          return firstFail({ #grep(r.lines, 'known-discipline scan: 3 name(s); readErrors=0; emptySlots=') == 1, 'the scan line is missing or wrong' },
              { #grep(r.lines, 'ended by empty-run') >= 1, 'the way the scan ended is not logged' },
              { #grep(r.lines, 'known check for "Tome of Fearless Discipline"') == 1, 'no verdict line for Fearless' })
      end),

    T('D6', 'REQ', 'NEW', FFFP, 'D-030 E (the Berserker overlap): visiting both vendors in order (Kurlond Axebringer, then Gaddi Buruca): every tome is bought once in total; the second vendor\'s tomes are all skipped as "already handled earlier in this run (<vendor>)"',
      function(c)
          local r = c.overlap
          local second = ledgerNames(r.lines, SKIPPED, 2)
          return firstFail({ sameList(visited(r.sim), { K, G }), 'visited ' .. show(visited(r.sim)) },
              { boughtExactly(r.sim, { 'Battle Cry', 'Head Strike', 'Leg Strike', 'Diversive Strike' }) },
              { second and second:find('already handled earlier in this run (' .. K .. ')', 1, true), 'the second vendor\'s skips should name the first vendor: ' .. tostring(second) })
      end),

    T('D7', 'REQ', 'NEW', FFFP, 'D-030 E: a tome whose Buy click was sent but whose payment was not seen is recorded as attempted and is NOT clicked again at the second vendor (at most one Buy click per tome item per run)',
      function(c)
          local r = c.pay_unseen
          return firstFail({ r.sim.buyClicks['Tome of Dear X'] == 1, 'Dear X got ' .. tostring(r.sim.buyClicks['Tome of Dear X']) .. ' Buy clicks, expected 1' },
              { boughtExactly(r.sim, { 'Cheap A', 'Cheap B' }) },
              { sameList(visited(r.sim), { K, G }), 'both vendors should have been visited' })
      end),

    T('D8', 'REQ', 'NEW', FFFP, 'D-030 E: a tome that never reached the Buy click at the first vendor (selection never verified) is tried again, and bought, at the second',
      function(c)
          local r = c.misselect
          return firstFail({ r.sim.buyClicks['Tome of Head Strike'] == 1, 'Head Strike should have exactly one Buy click (at the second vendor), saw ' .. tostring(r.sim.buyClicks['Tome of Head Strike']) },
              { boughtExactly(r.sim, { 'Battle Cry', 'Head Strike' }) })
      end),

    T('D9', 'REQ', 'NEW', FFFP, 'D-030 F\'\' / G: a normal tome: bought, right-clicked once, consumed, the discipline learned; the ledger labels it "bought and learned" (never "bought and scribed") and counts it; no /autoinventory',
      function(c)
          local r = c.monk_plain
          local led = ledgers(r.lines)[1]
          return firstFail({ led and led.counts[LEARNED] == 5, 'expected 5 "bought and learned" in the ledger' },
              { led and led.counts['bought and scribed'] == nil, 'a tome visit must not print "bought and scribed"' },
              { r.sim.knownDiscSet['Elbow Strike'] ~= nil, 'the discipline was not learned' },
              { #grep(r.lines, 'Confirmed learned: "Tome of Elbow Strike"') == 1, 'no "Confirmed learned" line' })
      end),

    T('D10', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3 section 3.1): a known discipline the check cannot see (the tome\'s name cannot be derived): the game answers "You already know this discipline." and puts the tome on the cursor; with the message as corroboration it is put away with one /autoinventory, recorded "bought, learn not completed" with the reason, and the run goes on',
      function(c)
          local r = c.slip
          local line = ledgerNames(r.lines, NOT_LEARNED, 1)
          return firstFail({ r.sim.autoinvCount == 1, '/autoinventory was sent ' .. r.sim.autoinvCount .. ' time(s), expected 1' },
              { r.sim.cursor == nil, 'the cursor is not empty at the end' },
              { noStrayClicks(r.sim) },
              { line and line:find('discipline already known', 1, true), 'the outcome reason should say the discipline was already known: ' .. tostring(line) },
              { r.sim.buyClicks['Tome of Head Strike'] == 1 and r.sim.knownDiscSet['Head Strike'] ~= nil, 'the run should have gone on and learned Head Strike' })
      end),

    T('D11', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3): a tome that merely passes through the cursor for 400 ms and is then consumed is Learned, never "already known": no /autoinventory, outcome "bought and learned"',
      function(c)
          local r = c.transient
          local led = ledgers(r.lines)[1]
          return firstFail({ r.sim.autoinvCount == 0, '/autoinventory was sent for a transient pass' },
              { led and led.counts[LEARNED] == 1, 'the tome should be "bought and learned"' },
              { r.sim.knownDiscSet['Battle Cry'] ~= nil, 'the discipline should have been learned' })
      end),

    T('D12', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 4): an unreadable initial count (nil, a raising read, text, zero) sends no learning click, records "bought, learn not completed" with the count failure, stops the whole spree (the second vendor is never visited) and says so',
      function(c)
          for _, k in ipairs({ 'count_nil', 'count_raise', 'count_text', 'count_zero' }) do
              local r = c[k]
              local line = ledgerNames(r.lines, NOT_LEARNED, 1)
              local ok2, why = firstFail({ r.sim.tomeClicks == 0, k .. ': a learning click was sent' },
                  { line and line:find('item count could not be read', 1, true), k .. ': the outcome should name the count failure: ' .. tostring(line) },
                  { sameList(visited(r.sim), { K }), k .. ': visited ' .. show(visited(r.sim)) .. ', the second vendor must not be visited' },
                  { #grep(r.lines, 'Tome safety stop: item count unreadable') >= 1, k .. ': no safety-stop line' })
              if not ok2 then return false, why end
          end
          return true
      end),

    T('D13', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3): the tome is on the cursor with no message and no by-name evidence: the outcome is unresolved, no /autoinventory is sent, the tome stays on the cursor and the whole spree stops',
      function(c)
          local r = c.cursor_unresolved
          local line = ledgerNames(r.lines, NOT_LEARNED, 1)
          return firstFail({ r.sim.autoinvCount == 0, '/autoinventory was sent without corroboration' },
              { r.sim.cursor ~= nil, 'the tome should have been left on the cursor' },
              { noStrayClicks(r.sim) },
              { line and line:find('no sign it was already known', 1, true), 'the reason should say the game gave no sign: ' .. tostring(line) },
              { sameList(visited(r.sim), { K }), 'the second vendor must not be visited' })
      end),

    T('D14', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3): corroboration by the by-name lookup taken just before the click alone (no message) is enough: put away with /autoinventory, the run continues',
      function(c)
          local r = c.cursor_byname
          return firstFail({ r.sim.autoinvCount == 1, '/autoinventory was sent ' .. r.sim.autoinvCount .. ' time(s), expected 1' },
              { r.sim.cursor == nil, 'the cursor is not empty at the end' },
              { noStrayClicks(r.sim) },
              { sameList(visited(r.sim), { K, G }), 'the run should have gone on to the second vendor' })
      end),

    T('D15', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 4): learning that completes between two attempts is recognized from the slot, the cursor and the count against the original baseline, with no second right-click; the baseline is read once per tome and logged',
      function(c)
          local r = c.between
          local line = grep(r.lines, 'recognized between attempts')
          return firstFail({ r.sim.tomeClicks == 2, 'two tomes, so two right-clicks in all (one each), saw ' .. r.sim.tomeClicks },
              { #line >= 1, 'no "recognized between attempts" line' },
              { #grep(r.lines, 'learn baseline for "Tome of Battle Cry": n0=1') == 1, 'the baseline should be logged exactly once for the tome' })
      end),

    T('D16', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 4): an emptied, vanished or replaced target slot is never right-clicked: after the first click that took the tome away (count unchanged) no further right-click is sent; the operation ends unresolved within 3 s and stops the whole spree',
      function(c)
          for _, k in ipairs({ 'replaced', 'vanish' }) do
              local r = c[k]
              local click, stop
              for _, l in ipairs(r.lines) do
                  if not click and l:find('CMD', 1, true) and l:find('learn "Tome of Battle Cry"', 1, true) then click = elapsed(l) end
                  if not stop and l:find('Tome safety stop: learning unresolved', 1, true) then stop = elapsed(l) end
              end
              if r.sim.tomeClicks ~= 1 then return false, k .. ': expected exactly 1 right-click, saw ' .. r.sim.tomeClicks end
              if not click or not stop then return false, k .. ': missing the click line or the unresolved stop line' end
              if stop - click > 3500 then return false, string.format('%s: the observation took %d ms (limit about 3000)', k, stop - click) end
              if not sameList(visited(r.sim), { K }) then return false, k .. ': the second vendor must not be visited' end
          end
          return true
      end),

    T('D17', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 4): a tome that moved to another slot is clicked only at the slot a fresh read confirms (never the old empty one): two right-clicks, at two different slots, and it is learned',
      function(c)
          local r = c.relocate
          local slots = r.sim.tomeClickSlots
          return firstFail({ #slots >= 2, 'expected a second click at the new slot, saw ' .. #slots .. ' click(s)' },
              { slots[1] ~= slots[2], 'the second click went to the old slot ' .. tostring(slots[1]) },
              { r.sim.knownDiscSet['Battle Cry'] ~= nil, 'the discipline should have been learned' })
      end),

    T('D18', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 4): learning that shows up late, during the bounded observation (the count drops 1.5 s after the click), is recognized as Learned with no further click and no abort: the second vendor is visited',
      function(c)
          local r = c.late
          return firstFail({ r.sim.tomeClicks == 2, 'two tomes, one click each; saw ' .. r.sim.tomeClicks },
              { r.sim.knownDiscSet['Battle Cry'] ~= nil, 'the discipline should have been learned' },
              { sameList(visited(r.sim), { K, G }), 'no abort: both vendors should be visited' })
      end),

    T('D19', 'REQ', 'NEW', FFFP, 'D-030 D\' (Revision 3): a known-scan whose reads raise at some slots is logged with the read errors counted apart from empty slots and warned as possibly incomplete, and the by-name lookup still recognizes the discipline the scan missed',
      function(c)
          local r = c.scanerr
          return firstFail({ #grep(r.lines, 'readErrors=1') >= 1, 'the scan line should show readErrors=1' },
              { #grep(r.lines, 'possibly incomplete') >= 1, 'no "possibly incomplete" warning' },
              { neverTouched(r.sim, { 'Tome of Fearless Discipline' }) },
              { boughtExactly(r.sim, { 'Elbow Strike' }) })
      end),

    T('D20', 'REQ', 'NEW', FFFP, 'D-030 D\' (Revision 3): nonpositive or raising by-name results never make a tome known: the tome the list cannot see is bought and, being known, answered "already known" and put away',
      function(c)
          for _, k in ipairs({ 'byname_zero', 'byname_raise' }) do
              local r = c[k]
              if (r.sim.buyClicks['Tome of Fearless Discipline'] or 0) ~= 1 then return false, k .. ': the tome should have been bought (it is not known by either test)' end
              if r.sim.autoinvCount ~= 1 then return false, k .. ': the already-known path should have run once' end
              local okc, whyc = noStrayClicks(r.sim)
              if not okc then return false, k .. ': ' .. whyc end
          end
          return true
      end),

    T('D21', 'REQ', 'NEW', FFFP, 'D-030 D\' (Revision 3): an ambiguous normalized match (two known names that normalize alike) is never "known" from the list: the tome is bought and the ambiguity is logged',
      function(c)
          local r = c.ambig
          return firstFail({ #grep(r.lines, 'ambiguous known match') >= 1, 'the ambiguity was not logged' },
              { r.sim.buyClicks['Tome of Foo-Bar'] == 1, 'the tome should have been bought' })
      end),

    T('D22', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3 section 3.2): the abort flag is cleared for every run: a first run aborted by an unreadable count visits one vendor, the second run (the count readable) visits both',
      function(c)
          local r = c.abort_twice
          return firstFail({ sameList(visited(r.sim), { K, K, G }), 'visited ' .. show(visited(r.sim)) .. ', expected [K, K, G]' },
              { r.sim.knownDiscSet['Battle Cry'] ~= nil and r.sim.knownDiscSet['Leg Strike'] ~= nil, 'the second run should have learned both' })
      end),

    T('D23', 'REQ', 'NEW', FFFP, 'D-030 A / observed live: Shadowknight\'s tome vendor, Zhao V`karin (a backtick in the name), is found and visited and his tomes are bought',
      function(c)
          local r = c.zhao
          return firstFail({ sameList(visited(r.sim), { 'Zhao V`karin' }), 'visited ' .. show(visited(r.sim)) },
              { boughtExactly(r.sim, { 'Unholy Aura Discipline', 'Leechcurse Discipline' }) })
      end),

    T('D24', 'REQ', 'NEW', FFFP, 'D-030 G / D-017: out of money partway through a tome visit: every tome on the list ends with one outcome and the ledger adds up (2 learned, 2 attempted not bought, 1 not attempted), the labels are the tome labels',
      function(c)
          local r = c.money
          local led = ledgers(r.lines)[1]
          if not led then return false, 'no ledger' end
          local sum = 0; for _, v in pairs(led.counts) do sum = sum + v end
          return firstFail({ led.counts[LEARNED] == 2 and led.counts[NOT_BOUGHT] == 2 and led.counts[STOPPED] == 1, 'counts: learned=' .. tostring(led.counts[LEARNED]) .. ' not bought=' .. tostring(led.counts[NOT_BOUGHT]) .. ' not attempted=' .. tostring(led.counts[STOPPED]) },
              { sum == led.n and led.n == 5, 'the counts add up to ' .. sum .. ', entries ' .. led.n },
              { #grep(r.lines, 'LEDGER DEFECT') == 0, 'a LEDGER DEFECT was logged' })
      end),

    T('D25', 'REQ', 'NEW', FFFP, 'D-030 A: a class with ranges and tomes (Paladin) ticking 1-25 and Discipline Tomes visits the spell vendor first and then the tome vendor; the spells are bought within the range and the tomes are learned; the scroll ledger keeps its labels and the tome ledger uses the tome labels',
      function(c)
          local r = c.paladin_both
          local l1, l2 = ledgers(r.lines)[1], ledgers(r.lines)[2]
          return firstFail({ sameList(visited(r.sim), { 'Cavalier Waut', 'Ulin Velnik' }), 'visited ' .. show(visited(r.sim)) },
              { r.sim.buyClicks['Spell: Spell A'] == 1 and r.sim.buyClicks['Spell: Spell B'] == nil, 'only the in-range spell should be bought' },
              { r.sim.knownDiscSet['Deflection Discipline'] ~= nil and r.sim.knownDiscSet['Holyforge Discipline'] ~= nil, 'both tomes should be learned' },
              { l1 and l1.counts['bought and scribed'] == 1 and l1.counts[LEARNED] == nil, 'the spell ledger must keep its labels' },
              { l2 and l2.counts[LEARNED] == 2 and l2.counts['bought and scribed'] == nil, 'the tome ledger must use the tome labels' })
      end),

    T('D26', 'REQ', 'NEW', FFFP, 'D-030 Revision 2 answer 1: the parent class box of a class with ranges ticks the four ranges only (no tome vendor is visited), and the Discipline Tomes box alone visits only the tome vendor',
      function(c)
          local a, b = c.paladin_parent, c.paladin_tomes
          -- the four ranges: 1-25, 26-50, 51-60, and 61-70 (which uses the 1-25 vendor again, D-022); no tome vendor
          return firstFail({ sameList(visited(a.sim), { 'Cavalier Waut', 'Cavalier Aodus', 'Cavalier Preradus', 'Cavalier Waut' }), 'the class box visited ' .. show(visited(a.sim)) },
              { sameList(visited(b.sim), { 'Ulin Velnik' }), 'the tomes box alone visited ' .. show(visited(b.sim)) })
      end),

    T('D27', 'REQ', 'NEW', FFFP, 'D-030 A (Revision 2 answer 1): the four tome-only classes appear (Warrior, Monk, Rogue, Berserker): ticked together they visit Heldin Swordbreaker, Beorobin Amondson, Blane Darkblade, Kurlond Axebringer and Gaddi Buruca in class order, and the button counts five visits',
      function(c)
          local r = c.allclasses
          return firstFail({ sameList(visited(r.sim), { 'Heldin Swordbreaker', MONK, 'Blane Darkblade', K, G }), 'visited ' .. show(visited(r.sim)) },
              { r.sim.lastRunLabel and r.sim.lastRunLabel:find('(5 selected)', 1, true), 'the button label was: ' .. tostring(r.sim.lastRunLabel) })
      end),

    T('D28', 'REQ', 'NEW', FFFP, 'D-030 H: a tome visit logs the vendor name read from Merchant.Name and a tome list line with its counts',
      function(c)
          local r = c.monk_known
          return firstFail({ #grep(r.lines, 'merchant window name: ' .. MONK) >= 1, 'no merchant name line' },
              { #grep(r.lines, '[list] Built the tome list: 5 tome(s) from') == 1, 'no tome list line' },
              { #grep(r.lines, '[list] Tome check: 3 known, 0 handled earlier in this run, 2 to buy.') == 1, 'no tome check line' })
      end),

    T('D29', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 2 answer 5): a different item landing where the tome should be is never right-clicked: no learning click, "bought, learn not completed: purchased tome not located", and the whole spree stops',
      function(c)
          local r = c.landwrong
          local line = ledgerNames(r.lines, NOT_LEARNED, 1)
          return firstFail({ r.sim.tomeClicks == 0, 'a right-click was sent to the wrong item' },
              { line and line:find('purchased tome not located', 1, true), 'the outcome reason: ' .. tostring(line) },
              { sameList(visited(r.sim), { K }), 'the second vendor must not be visited' })
      end),

    T('D30', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 2 answer 7): recovery that does not clear the cursor stops the whole spree and leaves the tome on the cursor; no room to put the tome away stops the spree without sending /autoinventory',
      function(c)
          local a, b = c.recfail, c.noroom
          return firstFail({ a.sim.autoinvCount == 1 and a.sim.cursor ~= nil, 'recfail: one command and the tome still on the cursor expected' },
              { sameList(visited(a.sim), { K }), 'recfail: the second vendor must not be visited' },
              { #grep(a.lines, 'Tome safety stop: tome left on the cursor') >= 1, 'recfail: no safety-stop line' },
              { b.sim.autoinvCount == 0, 'noroom: /autoinventory was sent with no free slot' },
              { sameList(visited(b.sim), { K }), 'noroom: the second vendor must not be visited' },
              { #grep(b.lines, 'Tome safety stop: no room to put the tome away') >= 1, 'noroom: no safety-stop line' })
      end),

    T('D31', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 3 section 3.2, failure 6): an item on the cursor when a tome visit starts stops the whole spree before anything is bought',
      function(c)
          local r = c.startcursor
          return firstFail({ #r.sim.purchases == 0, 'something was bought' },
              { sameList(visited(r.sim), { K }), 'the second vendor must not be visited' },
              { #grep(r.lines, 'Tome safety stop') >= 1, 'no safety-stop line' })
      end),

    T('D32', 'REQ', 'NEW', FFFP, 'D-030 F\'\' (Revision 2 answer 7): Stop pressed while /autoinventory is working: the recovery completes first (the tome is back in the bags, the cursor empty), then the run ends "Stopped by user" with the rest not attempted',
      function(c)
          local r = c.stoprecov
          local o = grep(r.lines, 'Run outcome (Nav & Shop "' .. K .. '")')
          return firstFail({ r.sim.autoinvCount == 1, '/autoinventory should have been sent once' },
              { r.sim.cursor == nil, 'the tome must not be left on the cursor by a Stop' },
              { #o >= 1 and o[1]:find('Stopped by user', 1, true), 'the run should end "Stopped by user": ' .. tostring(o[1]) },
              { r.sim.buyClicks['Tome of Head Strike'] == nil, 'nothing after the Stop should be bought' })
      end),

    T('D33', 'REQ', 'NEW', FFFP, 'D-030 Revision 4 (the abort reasons): every tome safety stop says "Tome safety stop:" and ends the spree with the existing message',
      function(c)
          for _, k in ipairs({ 'count_nil', 'cursor_unresolved', 'vanish', 'landwrong' }) do
              if #grep(c[k].lines, 'ending the shopping spree early') < 1 then return false, k .. ': the spree was not ended with the "ending the shopping spree early" message' end
          end
          return true
      end),

    T('D34', 'REQ', 'NEW', { [0] = F, [1] = F, [2] = F, [3] = P }, 'D-030 B (Revision 2): runSpellSpree called without the item kind is refused before anything is read: ERROR "No item kind", nothing selected or bought (fail closed)',
      function()
          local path = TMP .. '\\nokind.lua'
          local src = SOURCE
          local a = src:find('local function runNavAndShop', 1, true)
          local b = a and src:find('\nlocal function ', a + 10, true)
          assert(a and b, 'runNavAndShop not found')
          local body, n = src:sub(a, b):gsub('runSpellSpree%b()', function() return 'runSpellSpree({ low = 1, high = 25, label = "1-25" })' end)
          assert(n == 1, 'expected one runSpellSpree call in runNavAndShop')
          src = src:sub(1, a - 1) .. body .. src:sub(b + 1)
          local f = assert(io.open(path, 'wb')); f:write(src); f:close()
          local r = runScenario(path, 'nokind', SCENARIOS.paladin_both)
          local errs = grep(r.lines, '| ERROR ')
          local named = false
          for _, l in ipairs(errs) do if l:find('No item kind', 1, true) then named = true end end
          return firstFail({ named, 'no ERROR line with "No item kind"' }, { next(r.sim.buyClicks) == nil, 'a Buy click was sent' }, { next(r.sim.selectClicks) == nil, 'a select click was sent' })
      end),

    T('D35', 'REQ', 'REGRESSION', ALLP, 'D-030 C / I: a scroll visit at a vendor that also lists tomes buys the spells in range and never selects or clicks the tomes',
      function(c)
          local r = c.scroll_visit
          return firstFail({ r.sim.buyClicks['Spell: Spell A'] == 1, 'the in-range spell should be bought' }, { neverTouched(r.sim, { 'Tome of Stray Tome' }) })
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

-- filled in after the build; the expected sets are written before the first run
-- Mutation checks (D-030). The predictions in `fails` were written BEFORE the first mutation run; see docs/evidence/2026-10-03_step6_mutations.txt
-- for the first-run result and any prediction that was wrong. An empty `fails` is a prediction that nothing in THIS suite catches the mutant
-- (the unit suite or a structural reason covers it, said in the name).
local MUTATIONS = {
    { name = 'the "Tome of " rule ignores case', fails = { 'D3' },
      from = "if name:sub(1, #TOME_PREFIX) ~= TOME_PREFIX then return false end", to = "if name:sub(1, #TOME_PREFIX):lower() ~= TOME_PREFIX:lower() then return false end" },
    { name = 'normalization keeps spaces', fails = { 'D4', 'D21', 'D28' },
      from = ":lower():gsub('[^a-z0-9]', ''))", to = ":lower():gsub('[^a-z0-9 ]', ''))" },
    { name = 'the Buy click does not record the tome as attempted', fails = { 'D7' },
      from = "if kind == 'tome' then S.tomesDone[name] = { state = 'attempted', vendor = S.visitVendor } end", to = "" },
    { name = 'the run-wide tome record is carried across runs', fails = { 'D22' },
      from = "S.tomesDone, S.abortSpree = {}, false", to = "S.abortSpree = false" },
    { name = 'the known check is removed', fails = { 'D4', 'D19', 'D28' },
      from = "            if verdict == 'known' then\n                knownCount", to = "            if false then\n                knownCount" },
    { name = 'the already-known recovery sends nothing (the tome stays on the cursor)', fails = { 'D10', 'D14', 'D20', 'D30', 'D32' },
      from = "(it was not consumed)', name), '/autoinventory')", to = "(it was not consumed)', name), '/nop')" },
    { name = "Berserker's second vendor is missing", fails = { 'D6', 'D7', 'D8', 'D14', 'D15', 'D18', 'D22', 'D27' },
      from = "{ 'Kurlond Axebringer', 'Gaddi Buruca' }", to = "{ 'Kurlond Axebringer' }" },
    { name = 'a tome visit applies a level bound', fails = { 'D2' },
      from = "elseif isTomeName(name) then\n            if byName[name] then", to = "elseif isTomeName(name) and (tonumber(listCell(r, LIST_COL.LVL)) or 0) >= 1 and (tonumber(listCell(r, LIST_COL.LVL)) or 0) <= 70 then\n            if byName[name] then" },
    { name = 'a scroll visit also buys tomes', fails = { 'D35' },
      from = "elseif isScrollName(name) then\n            if byName[name] then", to = "elseif isScrollName(name) or isTomeName(name) then\n            if byName[name] then" },
    { name = 'a tome on the cursor is treated as known without corroboration', fails = { 'D13', 'D33' },
      from = "return (message or knownBefore) and 'known' or 'unresolved', nil", to = "return 'known', nil" },
    { name = 'a count of zero does not block the first click', fails = { 'D12' },
      from = "if not n0 or n0 < 1 then", to = "if not n0 then" },
    { name = 'the baseline count is read again before each attempt', fails = { 'D15' },
      from = "        local o = observe(); local st = learnState(o, n0, name)\n        describe(o, st, string.format('attempt %d/%d'", to = "        n0 = readItemCount(name) or n0\n        local o = observe(); local st = learnState(o, n0, name)\n        describe(o, st, string.format('attempt %d/%d'" },
    { name = 'the click is sent without the fresh slot read (the mock cannot change state between two instant reads: not caught here by design)', fails = {},
      from = "if item and itemDisplayName(item) == name and not cursorItemName() then", to = "if true then" },
    { name = 'the observation window is 100 times longer', fails = { 'D16' },
      from = "local TOME_OBSERVE_PASSES, TOME_OBSERVE_MS = 15, 200", to = "local TOME_OBSERVE_PASSES, TOME_OBSERVE_MS = 1500, 200" },
    { name = 'a "learned" reading between attempts is handed to the click path instead of finishing', fails = { 'D15' },
      from = "local final, fo = resolve(o, st)", to = "local final, fo = resolve(o, st == 'learned' and 'clickable' or st)" },
    { name = 'the pending observation right-clicks the tome', fails = { 'D10', 'D13', 'D14', 'D20' },
      from = "            mq.delay(TOME_OBSERVE_MS); mq.doevents()\n            local o = observe(); local st = learnState(o, n0, name)\n            describe(o, st, string.format('cursor wait", to = "            mq.delay(TOME_OBSERVE_MS); mq.doevents()\n            sendCmd('x', targetSlotNotifyCmd(targetBag, targetSlot))\n            local o = observe(); local st = learnState(o, n0, name)\n            describe(o, st, string.format('cursor wait" },
    { name = 'recovery does not look at the cursor first (covered by the unit suite U44, not here)', fails = {},
      from = "    if before ~= name then return 'changed', before end\n", to = "" },
    { name = 'a tome safety stop does not set the abort flag', fails = { 'D12', 'D13', 'D16', 'D22', 'D29', 'D30', 'D33' },
      from = "    S.abortSpree = true\n    setOutcome(entry, outcome, detail)", to = "    setOutcome(entry, outcome, detail)" },
    { name = 'the abort flag is not checked after a visit', fails = { 'D12', 'D13', 'D16', 'D22', 'D29', 'D30', 'D33' },
      from = "if S.abortSpree or isSpreeAbortingReason(S.lastStopReason) then", to = "if isSpreeAbortingReason(S.lastStopReason) then" },
    { name = 'an ambiguous list match is treated as known', fails = { 'D21' },
      from = "if listState == 'ambiguous' then return 'ambiguous', nil end", to = "if listState == 'ambiguous' then return 'known', 'list' end" },
    { name = 'a by-name result of zero is accepted as a slot', fails = { 'D20' },
      from = "or n ~= math.floor(n) or n < 1 then return nil end", to = "or n ~= math.floor(n) or n < 0 then return nil end" },
    { name = 'a read that raises is counted as an empty slot', fails = { 'D19' },
      from = "            readErrors = readErrors + 1\n            emptyRun = emptyRun + 1", to = "            emptySlots = emptySlots + 1\n            emptyRun = emptyRun + 1" },
}

local failures = 0
local function report(label, ok, detail)
    print(string.format('%-6s %s%s', ok and 'PASS' or 'FAIL', label, detail and (' -- ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

print('=== baseline: spellspree.lua against the simulated MQ ===')
local base = evaluate(SCRIPT)
for _, t in ipairs(TESTS) do report(string.format('%s [%s, %s] %s', t.id, t.kind, t.label, t.src), base[t.id].pass, base[t.id].msg) end

if arg[1] == 'dump' then -- P-1: print the log of one scenario (luajit test/test_tomes.lua dump <scenario>)
    local c = runAll(SCRIPT)
    for _, l in ipairs(c[arg[2]].lines) do print(l) end
    os.exit(0)
end

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
