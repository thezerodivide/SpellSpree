---@diagnostic disable: undefined-global, undefined-field
-- ============================================================================
-- SpellSpree vendor spike -- READ-ONLY investigation (decision log D-010)
-- ----------------------------------------------------------------------------
-- NOT part of the SpellSpree build. It never buys, sells or scribes anything.
-- The only things it does to the game are: select (highlight) vendor rows, which
-- prompts the vendor's usual price tell, and read windows/TLOs.
--
-- Open a spell vendor's window first, with the "usable items only" box ticked as
-- you normally have it, then:
--
--   /lua run spellspree_spike                 -- probe: answers D-010 questions 1-4, 6
--   /lua run spellspree_spike watch "Spell: Calm" [seconds]
--        -- watch: YOU buy and scribe that one spell by hand while this runs
--        -- (default 90 s). It records how the vendor list reacts: D-010 question 5.
--
-- Output goes to the chat window and to
--   <MacroQuest logs>\spellspree\spike_<server>_<character>.log
-- Everything printed is a raw observation; nothing here decides anything.
-- ============================================================================
local mq = require('mq')

local SPIKE_VERSION = '0.1.0-spike.1'
local args = { ... }
local mode = tostring(args[1] or 'probe'):lower()

-- ---------------------------------------------------------------- logging ----
local t0 = mq.gettime()
local logPath
local logOff = false

-- value of a TLO read, or nil if it can't be read
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

local function log(msg)
    local line = string.format('%s | +%dms | spike %s | %s', os.date('%Y-%m-%d %H:%M:%S'), mq.gettime() - t0, SPIKE_VERSION, tostring(msg))
    print('\ag[spike]\ax ' .. tostring(msg))
    if logOff or not logPath then return end
    local f = io.open(logPath, 'a')
    if not f then logOff = true; print('\ar[spike]\ax could not open ' .. logPath .. ' -- screen output only'); return end
    f:write(line:gsub('[\r\n]+', ' / '), '\n')
    f:close()
end

-- ------------------------------------------------------------ vendor reads ----
local function merchantOpen()
    return tlo(function() return mq.TLO.Window('MerchantWnd').Open() end) == true
end

local function itemList()
    return mq.TLO.Window('MerchantWnd').Child('ItemList')
end

local function rowCount()
    return tonumber(tlo(function() return itemList().Items() end))
end

local function merchantItemsCount()
    return tonumber(tlo(function() return mq.TLO.Merchant.Items() end))
end

-- text of row r, column c of the visible list; nil if unreadable/empty
local function cell(r, c)
    local v = tlo(function() return itemList().List(string.format('%d,%d', r, c))() end)
    if v == nil or v == false then return nil end
    return tostring(v)
end

local function selectedName()
    return tlo(function() return mq.TLO.Merchant.SelectedItem.Name() end)
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function selectRow(r)
    mq.cmdf('/notify MerchantWnd ItemList listselect %d', r)
    mq.delay(200)
    mq.doevents()
end

local MAX_COL = 8

-- price tells, so we can say whether a selection method prompts one
local tells = {}
local function onTell(_, a, b) tells[#tells + 1] = tostring(a) .. ' | ' .. tostring(b) end
mq.event('spike_tell_per', "#*#tells you, 'That'll be #1# per #2#.'", onTell)
mq.event('spike_tell_for', "#*#tells you, 'That'll be #1# for #2#.'", onTell)

-- --------------------------------------------------- find the name column ----
-- Select a few rows and see which column's text equals the selected item's name.
local function findNameColumn(rows)
    local votes, tested = {}, 0
    local picks = { 1, math.max(1, math.floor(rows / 2)), rows }
    local done = {}
    for _, r in ipairs(picks) do
        if not done[r] and r >= 1 and r <= rows then
            done[r] = true
            selectRow(r)
            local sel = selectedName()
            tested = tested + 1
            local cols = {}
            for c = 1, MAX_COL do
                local txt = cell(r, c)
                if txt ~= nil then
                    local same = (sel ~= nil and trim(txt):lower() == trim(sel):lower())
                    local loose = (sel ~= nil and trim(txt) ~= '' and trim(sel):lower():find(trim(txt):lower(), 1, true) ~= nil)
                    cols[#cols + 1] = string.format('c%d=%q%s', c, txt, same and ' (EQUALS selected name)' or (loose and ' (contained in selected name)' or ''))
                    if same then votes[c] = (votes[c] or 0) + 1 end
                end
            end
            log(string.format('row %d: Merchant.SelectedItem.Name=%q; cells: %s', r, tostring(sel), table.concat(cols, '; ')))
        end
    end
    local best, bestVotes = nil, 0
    for c, v in pairs(votes) do
        if v > bestVotes then best, bestVotes = c, v end
    end
    return best, bestVotes, tested
end

-- ---------------------------------------------------------------- sweeps ----
local function sweepNames(rows, col)
    local names, unreadable = {}, 0
    for r = 1, rows do
        local n = cell(r, col)
        if n == nil then unreadable = unreadable + 1 end
        names[r] = n
    end
    return names, unreadable
end

local function isScroll(name)
    return name ~= nil and (name:match('^Spell:%s') ~= nil or name:match('^Song:%s') ~= nil)
end

local function summarizeList(names, rows)
    local firstIdx, dup, spells = {}, {}, 0
    for r = 1, rows do
        local n = names[r]
        if n then
            if firstIdx[n] then dup[n] = (dup[n] or 1) + 1 else firstIdx[n] = r end
            if isScroll(n) then spells = spells + 1 end
        end
    end
    local dupList = {}
    for n, k in pairs(dup) do dupList[#dupList + 1] = string.format('%q x%d', n, k) end
    table.sort(dupList)
    return firstIdx, spells, dupList
end

-- ====================================================================== run ===
openLog()
log('=== spike start: mode=' .. mode .. ' ===')
log(string.format('character=%s server=%s zone=%s target=%s', tostring(tlo(function() return mq.TLO.Me.CleanName() end)),
    tostring(tlo(function() return mq.TLO.EverQuest.Server() end)), tostring(tlo(function() return mq.TLO.Zone.ShortName() end)),
    tostring(tlo(function() return mq.TLO.Target.CleanName() end))))
log('log file: ' .. tostring(logPath))

if not merchantOpen() then
    log('NO MERCHANT WINDOW OPEN. Open a spell vendor first, then run this again. Nothing was done.')
    return
end

local rows = rowCount()
local usable = tlo(function() return mq.TLO.Window('MerchantWnd').Child('MW_UsableButton').Checked() end)
log(string.format('ItemList.Items()=%s  Merchant.Items=%s  usable-only box checked=%s', tostring(rows), tostring(merchantItemsCount()), tostring(usable)))
if not rows or rows < 1 then
    log('ItemList.Items() is unreadable or zero; cannot continue.')
    return
end

-- Q1: which column is the name
log('--- Q1: which List column holds the item name (select 3 rows, compare cells with Merchant.SelectedItem.Name) ---')
local nameCol, votes, tested = findNameColumn(rows)
log(string.format('RESULT Q1: name column = %s (matched in %d of %d tested rows)', tostring(nameCol), votes, tested))
if not nameCol then
    log('Could not identify a name column; the spike cannot go further. The cell dump above shows what each column holds.')
    return
end

if mode == 'probe' then
    -- Q6 + list read: whole list, timed
    log('--- Q6: read the whole visible list, no selecting ---')
    local s0 = mq.gettime()
    local names, unreadable = sweepNames(rows, nameCol)
    local elapsed = mq.gettime() - s0
    local firstIdx, spells, dupList = summarizeList(names, rows)
    log(string.format('RESULT Q6: read %d rows (%d unreadable) in %d ms (%.2f ms/row); %d are Spell:/Song: scrolls; duplicate names: %d',
        rows, unreadable, elapsed, rows > 0 and elapsed / rows or 0, spells, #dupList))
    for _, d in ipairs(dupList) do log('  duplicate name: ' .. d) end
    local show = {}
    for r = 1, math.min(5, rows) do show[#show + 1] = string.format('%d:%q', r, tostring(names[r])) end
    log('first rows: ' .. table.concat(show, ', '))
    show = {}
    for r = math.max(1, rows - 4), rows do show[#show + 1] = string.format('%d:%q', r, tostring(names[r])) end
    log('last rows: ' .. table.concat(show, ', '))
    local spellNames, chunk = {}, {}
    for r = 1, rows do
        if isScroll(names[r]) then
            chunk[#chunk + 1] = string.format('%d=%s', r, names[r])
            if #chunk == 8 then spellNames[#spellNames + 1] = table.concat(chunk, ' | '); chunk = {} end
        end
    end
    if #chunk > 0 then spellNames[#spellNames + 1] = table.concat(chunk, ' | ') end
    for _, l in ipairs(spellNames) do log('scroll rows: ' .. l) end

    -- Q2: does the merchant's own list match the visible list
    log('--- Q2: Merchant.Item(n) against the visible list ---')
    local mCount = merchantItemsCount()
    log(string.format('Merchant.Items=%s vs ItemList.Items()=%d', tostring(mCount), rows))
    if mCount and mCount > 0 then
        local m0 = mq.gettime()
        local mNames, mSet, mUnreadable = {}, {}, 0
        for n = 1, mCount do
            local nm = tlo(function() return mq.TLO.Merchant.Item(n).Name() end)
            if nm == nil then mUnreadable = mUnreadable + 1 end
            mNames[n] = nm
            if nm then mSet[nm] = true end
        end
        local mElapsed = mq.gettime() - m0
        local vSet, onlyV, onlyM, samePos = {}, {}, {}, 0
        for r = 1, rows do if names[r] then vSet[names[r]] = true end end
        for r = 1, rows do if names[r] and not mSet[names[r]] then onlyV[#onlyV + 1] = names[r] end end
        for n = 1, mCount do if mNames[n] and not vSet[mNames[n]] then onlyM[#onlyM + 1] = mNames[n] end end
        for n = 1, math.min(rows, mCount) do if mNames[n] == names[n] then samePos = samePos + 1 end end
        log(string.format('RESULT Q2: Merchant.Item read %d entries (%d unreadable) in %d ms; only in visible list: %d; only in Merchant.Item: %d; same name at same position: %d of %d',
            mCount, mUnreadable, mElapsed, #onlyV, #onlyM, samePos, math.min(rows, mCount)))
        for k = 1, math.min(8, #onlyV) do log('  only in visible list: ' .. tostring(onlyV[k])) end
        for k = 1, math.min(8, #onlyM) do log('  only in Merchant.Item: ' .. tostring(onlyM[k])) end
    else
        log('RESULT Q2: Merchant.Items unreadable or zero.')
    end

    -- Q3: by-name lookup, exact vs not, against the sweep
    log('--- Q3: by-name row lookup, exact (=name) and not exact ---')
    local tests = {}
    local function addTest(label, name) if name then tests[#tests + 1] = { label = label, name = name } end end
    for r = 1, rows do if isScroll(names[r]) then addTest('first scroll', names[r]); break end end
    for r = 1, rows do if names[r] and not isScroll(names[r]) then addTest('first non-scroll', names[r]); break end end
    -- a name that is a proper prefix of another name in the list (exposes prefix matching)
    for r = 1, rows do
        local a = names[r]
        if a then
            for q = 1, rows do
                local b = names[q]
                if b and q ~= r and #b > #a and b:sub(1, #a):lower() == a:lower() then
                    addTest('name that prefixes another (' .. b .. ')', a)
                    goto prefixFound
                end
            end
        end
    end
    ::prefixFound::
    for _, t in ipairs(tests) do
        local exactRow = tonumber(tlo(function() return itemList().List('=' .. t.name .. ',' .. nameCol)() end))
        local looseRow = tonumber(tlo(function() return itemList().List(t.name .. ',' .. nameCol)() end))
        log(string.format('%s %q: sweep first row=%s; List("=name")=%s; List("name")=%s', t.label, t.name, tostring(firstIdx[t.name]), tostring(exactRow), tostring(looseRow)))
    end
    -- How does a lookup WITHOUT '=' match? Query a truncated name and an inner fragment of a real name.
    for r = 1, rows do
        local n = names[r]
        if isScroll(n) and #n > 8 then
            local cut = n:sub(1, #n - 3)
            local inner = n:sub(4)
            local rowCut = tonumber(tlo(function() return itemList().List(cut .. ',' .. nameCol)() end))
            local rowInner = tonumber(tlo(function() return itemList().List(inner .. ',' .. nameCol)() end))
            local rowCutExact = tonumber(tlo(function() return itemList().List('=' .. cut .. ',' .. nameCol)() end))
            log(string.format('match style on %q: List(%q)=%s [prefix-style match if a row]; List(%q)=%s [substring-style match if a row]; List("=%s")=%s [exact should be nil]',
                n, cut, tostring(rowCut), inner, tostring(rowInner), cut, tostring(rowCutExact)))
            break
        end
    end
    local missRow = tlo(function() return itemList().List('=No Such Item Exists,' .. nameCol)() end)
    log(string.format('List of a name that is not there returns: %s (type %s)', tostring(missRow), type(missRow)))

    -- Q4: Merchant.SelectItem from Lua
    log('--- Q4: Merchant.SelectItem(name) called from Lua ---')
    local target, other
    for r = 1, rows do if names[r] and not isScroll(names[r]) then target = target or names[r]; if target and names[r] ~= target then other = other or r end end end
    if target and other then
        selectRow(other)
        local before = selectedName()
        local tellsBefore = #tells
        log(string.format('selected row %d via listselect; SelectedItem.Name=%q; price tells so far=%d', other, tostring(before), #tells))
        local ret = tlo(function() return mq.TLO.Merchant.SelectItem('=' .. target) end)
        local seen = {}
        for _, wait in ipairs({ 0, 100, 200, 400, 800 }) do
            if wait > 0 then mq.delay(wait == 100 and 100 or wait / 2) end
            mq.doevents()
            seen[#seen + 1] = string.format('%dms:%q', wait, tostring(selectedName()))
        end
        log(string.format('called Merchant.SelectItem("=%s") without (): returned %s; SelectedItem.Name over time: %s; new price tells=%d',
            target, tostring(ret), table.concat(seen, ', '), #tells - tellsBefore))
        if selectedName() ~= target then
            local ret2 = tlo(function() return mq.TLO.Merchant.SelectItem('=' .. target)() end)
            mq.delay(300); mq.doevents()
            log(string.format('called again WITH (): returned %s; SelectedItem.Name=%q; new price tells=%d', tostring(ret2), tostring(selectedName()), #tells - tellsBefore))
        end
        local idx = tlo(function() return itemList().SelectedIndex() end)
        log(string.format('RESULT Q4: after SelectItem the list reports SelectedIndex=%s (row of "%s" in sweep: %s); SelectedItem.Name=%q', tostring(idx), target, tostring(firstIdx[target]), tostring(selectedName())))
        -- control: does a plain listselect prompt a tell in this same setup?
        local ctlBefore = #tells
        selectRow(other)
        mq.delay(300); mq.doevents()
        log(string.format('control: listselect of row %d prompted %d new price tell(s)', other, #tells - ctlBefore))
    else
        log('RESULT Q4: could not find two different non-scroll rows to test with; skipped.')
    end
    log('=== probe finished. Nothing was bought, sold or scribed. ===')

elseif mode == 'watch' then
    local want = args[2]
    local seconds = tonumber(args[3]) or 90
    local names = sweepNames(rows, nameCol)
    if not want or want == '' then
        for r = 1, rows do if isScroll(names[r]) then want = names[r]; break end end
        log('no spell name given; using the first scroll in the list: ' .. tostring(want))
    end
    local bookName = trim(tostring(want):gsub('^Spell:%s*', ''):gsub('^Song:%s*', ''))
    log(string.format('--- Q5: watching %q for %d s. BUY AND SCRIBE THAT ONE SPELL BY HAND NOW; do nothing else in the vendor window. ---', tostring(want), seconds))
    mq.cmd('/echo [spike] watching ' .. tostring(want) .. ' -- buy and scribe it by hand now')

    local prevKey, prevNames, lastBeat = nil, names, mq.gettime()
    local deadline = mq.gettime() + seconds * 1000
    local function state()
        local r = rowCount()
        local lookup = tonumber(tlo(function() return itemList().List('=' .. tostring(want) .. ',' .. nameCol)() end))
        local mi = tlo(function() return mq.TLO.Merchant.Item('=' .. tostring(want)).Name() end)
        local book = tlo(function() return mq.TLO.Me.Book(bookName)() end)
        local inInv = tlo(function() return mq.TLO.FindItemCount('=' .. tostring(want))() end)
        local cursor = tlo(function() return mq.TLO.Cursor.Name() end)
        return string.format('rows=%s merchantItems=%s listLookupRow=%s Merchant.Item=%s spellbookSlot=%s inInventory=%s cursor=%s merchantOpen=%s',
            tostring(r), tostring(merchantItemsCount()), tostring(lookup), tostring(mi), tostring(book), tostring(inInv), tostring(cursor), tostring(merchantOpen())), r
    end
    while mq.gettime() < deadline do
        mq.doevents()
        local key, r = state()
        if key ~= prevKey then
            log('STATE CHANGE: ' .. key)
            -- when the row count moves, say exactly which rows came or went
            if r and prevNames and r ~= #prevNames then
                local cur = sweepNames(r, nameCol)
                local was, now, gone, came = {}, {}, {}, {}
                for _, n in pairs(prevNames) do was[n] = true end
                for _, n in pairs(cur) do now[n] = true end
                for n in pairs(was) do if not now[n] then gone[#gone + 1] = n end end
                for n in pairs(now) do if not was[n] then came[#came + 1] = n end end
                table.sort(gone); table.sort(came)
                log(string.format('  row count %d -> %d. Names gone: %s. Names new: %s', #prevNames, r,
                    #gone > 0 and table.concat(gone, '; ') or 'none', #came > 0 and table.concat(came, '; ') or 'none'))
                prevNames = cur
            end
            prevKey, lastBeat = key, mq.gettime()
        elseif mq.gettime() - lastBeat > 5000 then
            log('heartbeat (no change): ' .. key)
            lastBeat = mq.gettime()
        end
        if not merchantOpen() then
            log('merchant window closed; stopping the watch.')
            break
        end
        mq.delay(250)
    end
    log('=== watch finished. ===')
else
    log('unknown mode "' .. mode .. '". Use: /lua run spellspree_spike   or   /lua run spellspree_spike watch "Spell: Calm" [seconds]')
end
