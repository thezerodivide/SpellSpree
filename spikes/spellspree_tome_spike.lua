---@diagnostic disable: undefined-global, undefined-field
-- ============================================================================
-- SpellSpree discipline-tome spike -- READ-ONLY investigation (decision log D-030)
-- ----------------------------------------------------------------------------
-- NOT part of the SpellSpree build. It never buys, sells, scribes or learns anything, and it does not select or click
-- anything in the vendor window. It only reads windows and TLOs, and (in watch mode) listens to chat lines.
--
-- Three modes. Chat output is kept to a few lines; everything else goes to
--   <MacroQuest logs>\spellspree\spike_<server>_<character>.log
--
--   /lua run spellspree_tome_spike names
--        Stand in the Plane of Knowledge. For each of the ten tome vendors it asks the same exact-name question the SpellSpree
--        build asks (npc "=<name>") and also a loose search, and records the real name text byte by byte, so punctuation
--        (Zhao V'karin / V`karin / V'karin) is read from the game, not guessed.
--
--   /lua run spellspree_tome_spike dump
--        Open a tome vendor's window first (tick "usable items only" as you normally do). It reads every row (name, Qty, price,
--        Lvl), tallies the name prefixes, lists the disciplines this character already knows (Me.CombatAbility by index) and,
--        for each tome, whether the discipline named by the tome (the name without "Tome of ") is known. Run it once at each
--        vendor you want compared, e.g. both Berserker vendors.
--
--   /lua run spellspree_tome_spike watch "Tome of Bellow" [seconds]
--        YOU buy that one tome and right-click it to learn it, by hand, while this runs (default 120 s). It records, only when
--        something changes: how many copies are in your bags, your money, whether the discipline reads as known, the cursor
--        item, and any chat line that mentions learn / already / cannot / discipline / tome.
--        Run it a second time with a tome for a discipline you ALREADY know, to see what the game says.
-- ============================================================================
local mq = require('mq')

local SPIKE_VERSION = '0.1.0-spike.1'
local args = { ... }
local mode = tostring(args[1] or 'names'):lower()

local VENDORS = {
    { class = 'Bard',         name = 'Larquin Julinok' },
    { class = 'Beastlord',    name = 'Tana Clawguard' },
    { class = 'Berserker',    name = 'Kurlond Axebringer' },
    { class = 'Berserker',    name = 'Gaddi Buruca' },
    { class = 'Monk',         name = 'Beorobin Amondson' },
    { class = 'Paladin',      name = 'Ulin Velnik' },
    { class = 'Ranger',       name = 'Keshyk Wardorn' },
    { class = 'Rogue',        name = 'Blane Darkblade' },
    { class = 'Shadowknight', name = 'Zhao V\'karin' },     -- punctuation unverified: the names mode reads the real one
    { class = 'Warrior',      name = 'Heldin Swordbreaker' },
}

-- ---------------------------------------------------------------- logging ----
local t0 = mq.gettime()
local logPath, logOff = nil, false

local function tlo(fn)
    local ok, v = pcall(fn)
    if ok then return v end
    return nil
end

local function openLog()
    local logs = tlo(function() return mq.TLO.MacroQuest.Path('logs')() end)
    local server = tlo(function() return mq.TLO.EverQuest.Server() end) or 'unknown'
    local char = tlo(function() return mq.TLO.Me.CleanName() end) or 'unknown'
    if type(logs) ~= 'string' or logs == '' then logOff = true; return end
    local dir = logs:gsub('[/\\]+$', '') .. '/spellspree'
    local native = dir:gsub('/', '\\')
    os.execute('if not exist "' .. native .. '" mkdir "' .. native .. '"')
    logPath = dir .. '/spike_' .. tostring(server):gsub('[^%w_%-]', '_') .. '_' .. tostring(char):gsub('[^%w_%-]', '_') .. '.log'
end

-- to the log file only
local function log(msg)
    if logOff or not logPath then return end
    local f = io.open(logPath, 'a')
    if not f then logOff = true; return end
    f:write(string.format('%s | +%dms | tome-spike %s | %s', os.date('%Y-%m-%d %H:%M:%S'), mq.gettime() - t0, SPIKE_VERSION, (tostring(msg):gsub('[\r\n]+', ' / '))), '\n')
    f:close()
end

-- to the chat window AND the log (kept to a few lines per run)
local function say(msg)
    print('\ag[tome-spike]\ax ' .. tostring(msg))
    log(msg)
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- the text with every character outside letters, digits and space shown as <0xNN>, so punctuation is unambiguous
local function bytes(s)
    return (tostring(s):gsub('[^%w ]', function(c) return string.format('<0x%02X>', c:byte()) end))
end

-- ------------------------------------------------------------ vendor reads ----
local function merchantOpen() return tlo(function() return mq.TLO.Window('MerchantWnd').Open() end) == true end
local function itemList() return mq.TLO.Window('MerchantWnd').Child('ItemList') end
local function rowCount() return tonumber(tlo(function() return itemList().Items() end)) end
local function cell(r, c)
    local v = tlo(function() return itemList().List(string.format('%d,%d', r, c))() end)
    if v == nil or v == false then return nil end
    return tostring(v)
end

-- ------------------------------------------------------------------ names ----
local function runNames()
    openLog()
    log(string.format('mode names; zone=%s; character=%s', tostring(tlo(function() return mq.TLO.Zone.ShortName() end)), tostring(tlo(function() return mq.TLO.Me.CleanName() end))))
    local exact, loose = 0, 0
    for _, v in ipairs(VENDORS) do
        local sp = tlo(function() return mq.TLO.Spawn(string.format('npc "=%s"', v.name)) end)
        local id = sp and tlo(function() return sp.ID() end)
        local found = id and id > 0
        if found then exact = exact + 1 end
        log(string.format('%s | %s | exact lookup npc "=%s": %s (ID=%s, CleanName=%q, Name=%q, Distance=%s)', v.class, v.name, v.name,
            found and 'FOUND' or 'not found', tostring(id), tostring(tlo(function() return sp.CleanName() end)),
            tostring(tlo(function() return sp.Name() end)), tostring(tlo(function() return sp.Distance() end))))
        -- loose search on the first word, to read the real spelling when the exact lookup fails
        local first = v.name:match('^(%S+)')
        for n = 1, 3 do
            local s2 = tlo(function() return mq.TLO.NearestSpawn(n, string.format('npc %s', first)) end)
            local id2 = s2 and tlo(function() return s2.ID() end)
            if id2 and id2 > 0 then
                local cn = tlo(function() return s2.CleanName() end)
                log(string.format('    loose match %d for "%s": ID=%s CleanName=%q bytes=%s', n, first, tostring(id2), tostring(cn), bytes(cn or '')))
                if cn and trim(cn):lower() == v.name:lower() then loose = loose + 1 end
            end
        end
    end
    say(string.format('names: %d of %d vendors found by the exact lookup the build uses; details in %s', exact, #VENDORS, tostring(logPath)))
end

-- ------------------------------------------------------------------- dump ----
-- wait for the visible list to stop changing (same idea as the build: 8 unchanged polls, 15 s at most)
local function settle()
    local last, same, waited = nil, 0, 0
    while waited < 15000 do
        local n = rowCount()
        if n and n >= 1 and n == last then same = same + 1 else same = 0 end
        last = n
        if same >= 8 then return n end
        mq.delay(250)
        waited = waited + 250
    end
    return last, true
end

local function knownDisciplines()
    local list, misses = {}, 0
    for i = 1, 600 do
        local nm = tlo(function() return mq.TLO.Me.CombatAbility(i).Name() end)
        if nm and trim(nm) ~= '' and tostring(nm) ~= 'NULL' then
            list[#list + 1] = tostring(nm); misses = 0
        else
            misses = misses + 1
            if misses >= 5 then break end
        end
    end
    return list
end

local function runDump()
    openLog()
    if not merchantOpen() then say('dump: no merchant window is open. Open a tome vendor first.'); return end
    local vendor = tlo(function() return mq.TLO.Target.CleanName() end)
    local rows, timedOut = settle()
    log(string.format('mode dump; vendor(target)=%q; zone=%s; character=%s; visible rows=%s%s', tostring(vendor),
        tostring(tlo(function() return mq.TLO.Zone.ShortName() end)), tostring(tlo(function() return mq.TLO.Me.CleanName() end)), tostring(rows), timedOut and ' (the list did not settle in 15 s)' or ''))
    if not rows or rows < 1 then say('dump: the list has no rows.'); return end

    local known = knownDisciplines()
    local knownSet = {}
    for _, k in ipairs(known) do knownSet[trim(k):lower()] = true end
    log(string.format('known disciplines by Me.CombatAbility(index): %d: %s', #known, table.concat(known, '; ')))

    local tomes, others, prefixes = 0, 0, {}
    local matched, unmatched = 0, 0
    for r = 1, rows do
        local name = cell(r, 2)
        local qty, pp, gp, sp, cp, lvl = cell(r, 3), cell(r, 4), cell(r, 5), cell(r, 6), cell(r, 7), cell(r, 8)
        local isTome = name and name:match('^Tome of ') ~= nil
        local first = name and (name:match('^(%S+%s+%S+)') or name) or '(unreadable)'
        prefixes[first] = (prefixes[first] or 0) + 1
        local extra = ''
        if isTome then
            tomes = tomes + 1
            local derived = trim((name:gsub('^Tome of ', '')))
            local inList = knownSet[derived:lower()] == true
            local byName = tlo(function() return mq.TLO.Me.CombatAbility(derived)() end)
            local byNameName = tlo(function() return mq.TLO.Me.CombatAbility(derived).Name() end)
            if inList then matched = matched + 1 else unmatched = unmatched + 1 end
            extra = string.format(' | derived=%q | in known list=%s | Me.CombatAbility(derived)=%s Name=%s', derived, inList and 'YES' or 'no', tostring(byName), tostring(byNameName))
        else
            others = others + 1
        end
        log(string.format('row %d | %q | qty=%s | price=%spp %sgp %ssp %scp | lvl=%s%s', r, tostring(name), tostring(qty), tostring(pp), tostring(gp), tostring(sp), tostring(cp), tostring(lvl), extra))
    end
    local parts = {}
    for p, c in pairs(prefixes) do parts[#parts + 1] = string.format('%s x%d', p, c) end
    table.sort(parts)
    log(string.format('summary: %d rows; %d start with "Tome of "; %d other rows; the discipline named by the tome is in the known list for %d, not for %d; name prefixes: %s',
        rows, tomes, others, matched, unmatched, table.concat(parts, '; ')))
    say(string.format('dump: %d rows, %d tomes, %d other; known disciplines %d (matched to tomes: %d); details in %s', rows, tomes, others, #known, matched, tostring(logPath)))
end

-- ------------------------------------------------------------------ watch ----
local function copperOnHand()
    local function n(f) return tonumber(tlo(f)) or 0 end
    return n(function() return mq.TLO.Me.Platinum() end) * 1000 + n(function() return mq.TLO.Me.Gold() end) * 100
        + n(function() return mq.TLO.Me.Silver() end) * 10 + n(function() return mq.TLO.Me.Copper() end)
end

local function runWatch()
    openLog()
    local tome = args[2]
    local seconds = tonumber(args[3]) or 120
    if not tome or tome == '' then say('watch: give the tome name, e.g.  /lua run spellspree_tome_spike watch "Tome of Bellow" 120'); return end
    local derived = trim((tostring(tome):gsub('^Tome of ', '')))
    local lines = {}
    for _, word in ipairs({ 'learn', 'already', 'cannot', 'discipline', 'tome' }) do
        mq.event('tome_spike_' .. word, '#*#' .. word .. '#*#', function(line) lines[#lines + 1] = tostring(line) end)
    end
    log(string.format('mode watch; tome=%q; derived discipline=%q; seconds=%d; character=%s', tostring(tome), derived, seconds, tostring(tlo(function() return mq.TLO.Me.CleanName() end))))
    say(string.format('watch: recording for %d s. Buy "%s" and right-click it to learn it, by hand.', seconds, tostring(tome)))
    local lastKey = nil
    local waited = 0
    while waited < seconds * 1000 do
        mq.doevents()
        local copies = tonumber(tlo(function() return mq.TLO.FindItemCount('=' .. tome)() end)) or 0
        local byName = tlo(function() return mq.TLO.Me.CombatAbility(derived).Name() end)
        local known = (byName ~= nil and trim(byName) ~= '' and tostring(byName) ~= 'NULL')
        local knownCount = #knownDisciplines()
        local cursor = tlo(function() return mq.TLO.Cursor.Name() end)
        local key = table.concat({ copies, copperOnHand(), tostring(known), knownCount, tostring(cursor), tostring(merchantOpen()) }, '|')
        if key ~= lastKey then
            lastKey = key
            log(string.format('state: copies of "%s" in bags=%d; money=%dcp; discipline "%s" reads as known=%s (%s); known disciplines=%d; cursor=%s; merchant open=%s',
                tostring(tome), copies, copperOnHand(), derived, tostring(known), tostring(byName), knownCount, tostring(cursor), tostring(merchantOpen())))
        end
        while #lines > 0 do log('chat line: ' .. table.remove(lines, 1)) end
        mq.delay(500)
        waited = waited + 500
    end
    while #lines > 0 do log('chat line: ' .. table.remove(lines, 1)) end
    say(string.format('watch: finished; details in %s', tostring(logPath)))
end

-- ------------------------------------------------------------------- main ----
if mode == 'names' then runNames()
elseif mode == 'dump' then runDump()
elseif mode == 'watch' then runWatch()
else print('\ar[tome-spike]\ax unknown mode "' .. mode .. '". Use: names | dump | watch "<tome name>" [seconds]') end
