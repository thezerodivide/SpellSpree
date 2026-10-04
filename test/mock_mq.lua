-- Simulation harness for spellspree.lua -- a mock MacroQuest + ImGui.
--
-- SIMULATION ONLY. Everything here is the AI's MODEL of how MacroQuest and the
-- EQ merchant window behave, written from reading spellspree.lua and the MQ
-- source. It has never been compared against a live client, and a passing run
-- proves nothing about live behavior (Development Protocol section 10).
local M = {}

-- A callable TLO-style node: node() returns its value (nil = "does not exist"),
-- node.Member is looked up in `members`.
local function node(value, members)
    return setmetatable({}, {
        __call = function() return value end,
        __index = function(_, k) return members and members[k] end,
    })
end

-- opts: money (copper), spells = { {name=,price=}, ... }, nonSpells = { names },
--       reorderAfterBuy (bool), liveRefresh (bool: scribed rows vanish at once,
--       else only after the vendor is closed and reopened), stackOnExisting
--       (bool: a bought scroll stacks onto an existing copy), preScrolls
--       (names already sitting unscribed in bag 1), scribeRejectFirst (n),
--       logsRaw / rootRaw / logsUnreadable (log path scenarios), zone,
--       Step 1 (list-then-buy, D-017) scenarios, all of them models of what the live logs showed:
--         spells[i].level (the Lvl column); staleMs (a scribed row stays in the list that long);
--         partialAtOpen = { rows=, untilMs= } (the visible count is small right after open);
--         neverSettles (the count keeps changing); events = { {atMs=, kind='vanish'|'appear', name=, price=} };
--         misselect = { name=, times= } (a click on that row selects a different row that many times);
--         driftOnce = { name=, afterMs= } (the selection moves away from that item shortly after it is made);
--       Step 3 (level bounding, D-025): spells[i].levelText = the raw text returned for column 8 (overrides level; false = the cell is
--         missing, so the TLO returns nil for it). sim.selectClicks[name] counts the select clicks that landed on each row (a record
--         for tests, no behavior).
--       Step 6 (discipline tomes, D-030): a vendor's spec may carry tomes = { { name=, price=, level=, teaches= }, ... } (rows named "Tome of <name>", the
--         discipline taught defaults to <name>); knownDisciplines = { 'Bellow', ... } (what the character already knows, readable through Me.CombatAbility(i) by
--         index and by exact name, no Me.CombatAbilityCount); knownScanErrors = { [slot] = true } (that slot's read raises); byNameResult = function(name) (what the
--         by-name lookup returns instead of the slot number); countOverride = function(name, real) (what FindItemCount returns; may return nil, a non-number or raise);
--         Right-clicking a tome for an UNKNOWN discipline consumes it and teaches it, for a KNOWN one the chat line "You already know this discipline." is queued and
--         the tome goes to the cursor, not consumed. Options: tomeTransientCursorMs (the tome sits on the cursor that long, then is consumed), tomeLearnDelayMs (consumed
--         only that long after the click), tomeRejectFirst (the first n right-clicks do nothing), knownMessageNever (no chat line), landAs = function(row) (the name that
--         lands in the bag), tomeVanishAfterClick (the tome leaves its slot without being consumed or on the cursor), tomeRelocateAfterClick (it moves to another slot),
--         tomeReplaceAfterClick = 'Tome of X' (a different item takes its slot); these three act on the FIRST right-click only, and the tome they take away stays counted by
--         FindItemCount (it is hidden, not gone) until hiddenReleaseMs, when it is consumed and the discipline learned. autoinventoryFails, autoinvDelayMs (the cursor empties that
--         long after /autoinventory), fillBagOnCursor (every free bag slot fills when a known tome lands on the cursor), startCursor = 'Name' (an item on the cursor at the start). sim.tomeClicks / sim.tomeClickSlots / sim.autoinvCount record
--         what the script did; sim.cursor is the cursor item. mq.event handlers are kept and run by mq.doevents on the chat lines queued in sim.chat.
--       Step 5 (log follows the character, D-028): identities = { {atMs=, server=, character=}, ... } (the server and character name the TLOs
--         return from each simulated time on; a nil or non-string value models an unreadable read); logsUnreadableAfterMs (Path('logs') reads
--         nil from then on); presses = n and pressNotBeforeMs = { [k] = ms } (the Run button is pressed again for the k-th time once the
--         previous run's summary has printed and that time has passed); redetectAtMs (the Re-detect button is pressed once at that time).
--       D-030: merchantLabel = the text of the merchant window's vendor-name label (MW_MerchantName); absent = the label reads nothing.
--         selectDelay = { name=, ms= } (a click on that row only takes effect that many ms later, every time; until then the
--           selection stays where it was, and a late landing replaces whatever is selected then; D-026, delayed selection);
--         stopAtMs (the Stop button is pressed once at that simulated time).
--       Step 2 (vendor routing, D-022): classes = {'CLR','WIZ'} (what the Inventory window reports, so the class
--         boxes for those classes are drawn); openTrees = { Cleric = true } (that class's tier boxes are drawn);
--         ticks = { '##class_Cleric', '61-70##Cleric' } (checkbox labels ticked once each, as a click would).
--       manualBuy = { name=, buyAtMs=, scribeAtMs=, removeAtMs= } (the developer buys and
--       scribes one spell by hand while the spike watches; the row leaves the list late),
--       vendors = { [npcName] = { spells=, nonSpells= } } (Plane of Knowledge
--       shopping spree: each NPC has its own stock; click the Cleric class box,
--       then Run Shopping Spree; NPCs not listed are absent from the zone).
function M.new(opts)
    local sim = {
        opts = opts, clockMs = 0, cmds = {}, prints = {}, merchantOpen = not opts.startClosed,
        usableChecked = true, known = {}, targetId = 4242, finished = false,
        scribeRejects = opts.scribeRejectFirst or 0, delays = 0, purchases = {}, buyClicks = {}, pending = {}, ticks = {}, selectClicks = {}, chat = {}, events = {}, tomeClicks = 0, tomeClickSlots = {}, autoinvCount = 0, tomeRejects = 0, later = {}, hidden = {}, cursor = opts.startCursor and { name = opts.startCursor } or nil,
    }
    sim.money = opts.money or 10000000

    -- merchant rows, in vendor order
    local function buildRows(spec)
        local rows, id = {}, 1000
        for _, n in ipairs(spec.nonSpells or {}) do
            id = id + 1; rows[#rows + 1] = { name = n, id = id, price = 5 }
        end
        for _, sp in ipairs(spec.spells or {}) do
            id = id + 1; rows[#rows + 1] = { name = 'Spell: ' .. sp.name, id = id, price = sp.price or 100, level = sp.level, levelText = sp.levelText }
        end
        for _, tm in ipairs(spec.tomes or {}) do
            id = id + 1; rows[#rows + 1] = { name = 'Tome of ' .. tm.name, id = id, price = tm.price or 100, level = tm.level, levelText = tm.levelText, isTome = true, teaches = tm.teaches or tm.name }
        end
        return rows
    end
    sim.rows = buildRows(opts)
    sim.vendorName = nil
    sim.vendorIds = {}              -- npc name -> spawn id (PoK scenarios)
    sim.purchasesByVendor = {}      -- npc name -> { scroll names bought there }
    do
        local n = 0
        for name in pairs(opts.vendors or {}) do n = n + 1; sim.vendorIds[name] = 7000 + n end
    end

    local function rebuildVisible()
        sim.visible = {}
        for _, r in ipairs(sim.rows) do
            if not sim.known[r.name] then sim.visible[#sim.visible + 1] = r end
        end
        sim.selected = nil
    end
    rebuildVisible()

    -- inventory: pack1 is an open 10-slot bag, packs 2..10 hold loose junk
    sim.bag = {}
    for _, n in ipairs(opts.preScrolls or {}) do
        sim.bag[#sim.bag + 1] = { name = n, stack = 1 }
    end
    sim.packOpen = { [1] = true }

    local function packItem(n)
        if n == 1 then
            return { name = 'Big Bag', container = 10, open = sim.packOpen[1], slots = sim.bag }
        elseif n >= 2 and n <= 10 then
            return { name = 'Junk ' .. n, container = 0 }
        end
        return nil
    end

    local function itemNode(it)
        if not it then return node(nil, { Name = function() return nil end }) end
        return node(it.name, {
            Name = function() return it.name end,
            Container = function() return it.container or 0 end,
            Stack = function() return it.stack or 1 end,
            Open = function() return it.open end,
            Item = function(slot) return itemNode(it.slots and it.slots[slot]) end,
        })
    end

    local function firstFreeBagSlot()
        for s = 1, 10 do if not sim.bag[s] then return s end end
    end

    local function handleCmd(cmd)
        sim.cmds[#sim.cmds + 1] = cmd
        local row = cmd:match('^/notify MerchantWnd ItemList listselect (%d+)$')
        if row then
            local r = sim.visible[tonumber(row)]
            if r then sim.selectClicks[r.name] = (sim.selectClicks[r.name] or 0) + 1 end
            if r and opts.misselect and r.name == opts.misselect.name and (sim.misselected or 0) < (opts.misselect.times or 1) then
                -- the list shifted under the click: a different row ends up selected
                sim.misselected = (sim.misselected or 0) + 1
                local other = sim.visible[tonumber(row) % #sim.visible + 1]
                if other then sim.selected = other; return end
            end
            if r and opts.selectDelay and r.name == opts.selectDelay.name then
                sim.lateSelects = sim.lateSelects or {}
                sim.lateSelects[#sim.lateSelects + 1] = { atMs = sim.clockMs + (opts.selectDelay.ms or 0), row = r }
                return
            end
            if r then
                sim.selected = r
                if opts.driftOnce and r.name == opts.driftOnce.name and not sim.drifted and not sim.driftAt then
                    sim.driftAt = sim.clockMs + (opts.driftOnce.afterMs or 200)
                end
            end
            return
        end
        if cmd == '/notify MerchantWnd MW_Buy_Button leftmouseup' then
            local r = sim.selected
            if r then sim.buyClicks[r.name] = (sim.buyClicks[r.name] or 0) + 1 end
            if r and sim.merchantOpen and sim.money >= r.price then
                sim.money = sim.money - r.price
                sim.purchases[#sim.purchases + 1] = r.name
                if sim.vendorName then
                    local list = sim.purchasesByVendor[sim.vendorName] or {}
                    list[#list + 1] = r.name
                    sim.purchasesByVendor[sim.vendorName] = list
                end
                local existing
                local landName = (opts.landAs and r.isTome) and opts.landAs(r) or r.name
                if opts.stackOnExisting then
                    for s = 1, 10 do if sim.bag[s] and sim.bag[s].name == landName then existing = sim.bag[s] end end
                end
                if existing then
                    existing.stack = existing.stack + 1
                else
                    local s = firstFreeBagSlot()
                    if s then sim.bag[s] = { name = landName, stack = 1, teaches = r.teaches } end
                end
                if opts.reorderAfterBuy then
                    table.insert(sim.visible, table.remove(sim.visible, 1))
                end
            end
            return
        end
        if cmd == '/autoinventory' then
            sim.autoinvCount = sim.autoinvCount + 1
            if sim.cursor and not opts.autoinventoryFails then
                local s = firstFreeBagSlot()
                if s then
                    local item = sim.cursor
                    local function put() sim.bag[s] = { name = item.name, stack = 1, teaches = item.teaches }; sim.cursor = nil end
                    if opts.autoinvDelayMs then sim.later[#sim.later + 1] = { atMs = sim.clockMs + opts.autoinvDelayMs, fn = put } else put() end
                end
            end
            return
        end
        local slot = cmd:match('^/itemnotify in pack1 (%d+) rightmouseup$')
        if slot then
            local it = sim.bag[tonumber(slot)]
            if it and it.name:match('^Tome of ') then
                local n = tonumber(slot)
                sim.tomeClicks = sim.tomeClicks + 1
                sim.tomeClickSlots[#sim.tomeClickSlots + 1] = n
                if opts.tomeRejectFirst and sim.tomeRejects < opts.tomeRejectFirst then sim.tomeRejects = sim.tomeRejects + 1; return end
                local function takeFromSlot()
                    if it.stack > 1 then it.stack = it.stack - 1 else sim.bag[n] = nil end
                end
                local function learn() sim.knownDisc[#sim.knownDisc + 1] = it.teaches; sim.knownDiscSet[it.teaches] = #sim.knownDisc end
                local function hide()
                    sim.hidden[it.name] = (sim.hidden[it.name] or 0) + 1
                    if opts.hiddenReleaseMs then
                        sim.later[#sim.later + 1] = { atMs = sim.clockMs + opts.hiddenReleaseMs, fn = function()
                            sim.hidden[it.name] = sim.hidden[it.name] - 1; learn()
                        end }
                    end
                end
                if opts.tomeVanishAfterClick and not sim.vanished then sim.vanished = true; takeFromSlot(); hide(); return end
                if opts.tomeRelocateAfterClick and not sim.relocated then
                    sim.relocated = true
                    local s2 = firstFreeBagSlot()
                    sim.bag[n] = nil
                    if s2 then sim.bag[s2] = it end
                    return
                end
                if opts.tomeReplaceAfterClick and not sim.replaced then
                    sim.replaced = true
                    sim.bag[n] = { name = opts.tomeReplaceAfterClick, stack = 1 }
                    hide()
                    return
                end
                if sim.knownDiscSet[it.teaches] then
                    if not opts.knownMessageNever then sim.chat[#sim.chat + 1] = 'You already know this discipline.' end
                    takeFromSlot()
                    sim.cursor = { name = it.name, teaches = it.teaches }
                    if opts.fillBagOnCursor then
                        for s4 = 1, 10 do if not sim.bag[s4] then sim.bag[s4] = { name = 'Junk Filler', stack = 1 } end end
                    end
                elseif opts.tomeTransientCursorMs then
                    takeFromSlot()
                    sim.cursor = { name = it.name, teaches = it.teaches }
                    sim.later[#sim.later + 1] = { atMs = sim.clockMs + opts.tomeTransientCursorMs, fn = function() sim.cursor = nil; learn() end }
                elseif opts.tomeLearnDelayMs then
                    sim.later[#sim.later + 1] = { atMs = sim.clockMs + opts.tomeLearnDelayMs, fn = function()
                        for s3 = 1, 10 do if sim.bag[s3] == it then if it.stack > 1 then it.stack = it.stack - 1 else sim.bag[s3] = nil end; break end end
                        learn()
                    end }
                else
                    takeFromSlot()
                    learn()
                end
                return
            end
            if it and it.name:match('^Spell:') then
                if sim.scribeRejects > 0 then sim.scribeRejects = sim.scribeRejects - 1; return end
                sim.known[it.name] = true
                if it.stack > 1 then it.stack = it.stack - 1 else sim.bag[tonumber(slot)] = nil end
                if opts.liveRefresh then
                    for i, r in ipairs(sim.visible) do
                        if r.name == it.name then table.remove(sim.visible, i); break end
                    end
                elseif opts.staleMs then
                    sim.pending[#sim.pending + 1] = { name = it.name, atMs = sim.clockMs + opts.staleMs }
                end
            end
            return
        end
        local pack = cmd:match('^/itemnotify pack(%d+) rightmouseup$')
        if pack then
            sim.packOpen[tonumber(pack)] = not sim.packOpen[tonumber(pack)]
            return
        end
        if cmd == '/notify MerchantWnd MW_Done_Button leftmouseup' then sim.merchantOpen = false; return end
        if cmd == '/notify MerchantWnd MW_UsableButton leftmouseup' then sim.usableChecked = not sim.usableChecked; return end
        local tid = cmd:match('^/target id (%d+)$')
        if tid then sim.targetId = tonumber(tid); return end
        local tnpc = cmd:match('^/target npc "=(.+)"$')
        if tnpc then
            if sim.vendorIds[tnpc] then sim.targetId = sim.vendorIds[tnpc] end
            return
        end
        if cmd == '/click right target' then
            if opts.vendors then
                for name, vid in pairs(sim.vendorIds) do
                    if vid == sim.targetId then
                        sim.vendorName = name
                        sim.rows = buildRows(opts.vendors[name])
                        sim.merchantOpen = true
                        sim.known = sim.known   -- scribed spells stay known across vendors
                        rebuildVisible()
                    end
                end
            elseif sim.targetId == 4242 then
                sim.merchantOpen = true; rebuildVisible()
            end
            return
        end
        -- /windowstate etc: accepted, no model
    end

    -- a spell bought, scribed and removed from the list by hand (spike watch mode)
    sim.book = {}
    sim.knownDisc, sim.knownDiscSet = {}, {}
    for i, n in ipairs(opts.knownDisciplines or {}) do sim.knownDisc[i] = n; sim.knownDiscSet[n] = i end
    if opts.manualBuy then
        local mb, done = opts.manualBuy, {}
        local function find(list) for i, r in ipairs(list) do if r.name == mb.name then return i, r end end end
        sim.ticks[#sim.ticks + 1] = function()
            if not done.buy and sim.clockMs >= mb.buyAtMs then
                done.buy = true
                local _, r = find(sim.rows)
                sim.money = sim.money - (r and r.price or 0)
                sim.bag[#sim.bag + 1] = { name = mb.name, stack = 1 }
            end
            if done.buy and not done.scribe and sim.clockMs >= mb.scribeAtMs then
                done.scribe = true
                for slot, it in pairs(sim.bag) do if it.name == mb.name then sim.bag[slot] = nil; break end end
                sim.known[mb.name] = true
                sim.book[(mb.name:gsub('^Spell:%s*', ''))] = 17
            end
            if done.scribe and not done.remove and sim.clockMs >= mb.removeAtMs then
                done.remove = true
                local i = find(sim.visible)
                if i then table.remove(sim.visible, i) end
            end
        end
    end

    -- timed changes to the vendor list (Step 1 scenarios)
    sim.ticks[#sim.ticks + 1] = function()
        for _, ev in ipairs(opts.events or {}) do
            if not ev.done and sim.clockMs >= ev.atMs then
                ev.done = true
                if ev.kind == 'vanish' then
                    for i, r in ipairs(sim.visible) do if r.name == ev.name then table.remove(sim.visible, i); break end end
                    for i, r in ipairs(sim.rows) do if r.name == ev.name then table.remove(sim.rows, i); break end end
                elseif ev.kind == 'appear' then
                    local r = { name = ev.name, id = 9000 + #sim.rows, price = ev.price or 100, level = ev.level }
                    sim.rows[#sim.rows + 1] = r
                    sim.visible[#sim.visible + 1] = r
                end
            end
        end
        for _, p in ipairs(sim.pending) do
            if not p.done and sim.clockMs >= p.atMs then
                p.done = true
                for i, r in ipairs(sim.visible) do if r.name == p.name then table.remove(sim.visible, i); break end end
            end
        end
        for _, l in ipairs(sim.lateSelects or {}) do
            if not l.done and sim.clockMs >= l.atMs then
                l.done = true
                for _, r in ipairs(sim.visible) do if r == l.row then sim.selected = r; break end end
            end
        end
        if sim.driftAt and sim.clockMs >= sim.driftAt and not sim.drifted then
            sim.drifted = true
            local cur = sim.selected
            for i, r in ipairs(sim.visible) do
                if r == cur then sim.selected = sim.visible[i % #sim.visible + 1]; break end
            end
        end
    end
    sim.ticks[#sim.ticks + 1] = function()
        for _, l in ipairs(sim.later) do
            if not l.done and sim.clockMs >= l.atMs then l.done = true; l.fn() end
        end
    end
    sim.tick = function() for _, f in ipairs(sim.ticks) do f() end end

    -- the row count the list reports (can be small right after open, or never stable)
    function sim.visibleCount()
        if opts.neverSettles then return #sim.visible + (sim.delays % 2) end
        if opts.partialAtOpen and sim.clockMs < opts.partialAtOpen.untilMs then
            return math.min(#sim.visible, opts.partialAtOpen.rows)
        end
        return #sim.visible
    end

    -- ---------------------------------------------------------------- mq
    local mq = { configDir = 'C:/sim/config' }
    function mq.cmd(c) handleCmd(c) end
    function mq.cmdf(f, ...) handleCmd(string.format(f, ...)) end
    function mq.gettime() return sim.clockMs end
    function mq.doevents()
        while #sim.chat > 0 do
            local line = table.remove(sim.chat, 1)
            for _, ev in ipairs(sim.events) do
                local pat = ev.pattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'):gsub('#%*#', '.*'):gsub('#%d+#', '(.-)')
                if line:match(pat) then ev.fn(line) end
            end
        end
    end
    function mq.event(name, pattern, fn) sim.events[#sim.events + 1] = { name = name, pattern = pattern, fn = fn } end
    mq.imgui = { init = function(_, fn) sim.draw = fn end }
    function mq.delay(ms)
        sim.delays = sim.delays + 1
        if sim.delays > 400000 then error('simulation runaway: too many delays') end
        sim.clockMs = sim.clockMs + (tonumber(ms) or 0)
        if sim.tick then sim.tick() end
        if sim.draw then sim.draw() end
    end

    local function window(name)
        if name == 'MerchantWnd' then
            return node(true, {
                Open = function() return sim.merchantOpen end,
                Child = function(cn)
                    if cn == 'MW_MerchantName' then
                        -- the label that shows the vendor's name (D-030): opts.merchantLabel, or the name of the vendor opened in a Plane of Knowledge run
                        local label = opts.merchantLabel or sim.vendorName
                        if label == nil then return node(nil) end
                        return node(label, { Text = function() return label end })
                    end
                    if cn == 'ItemList' then
                        return node(true, {
                            Items = function() return sim.visibleCount() end,
                            SelectedIndex = function()
                                for i, r in ipairs(sim.visible) do if r == sim.selected then return i end end
                            end,
                            -- List('row,col') -> cell text; List('=name,col') / List('name,col') -> 1-based row.
                            -- Columns in this model: 1 = icon (empty), 2 = item name, 3 = price text; others absent.
                            List = function(spec)
                                -- real MQ returns a TLO node here (callers do List(x)()), so wrap the value
                                local function ret(v) return node(v) end
                                local body, col = tostring(spec):match('^(.*),(%d+)$')
                                col = tonumber(col)
                                if not body then return ret(nil) end
                                if tonumber(body) then
                                    if tonumber(body) > sim.visibleCount() then return ret(nil) end
                                    local r = sim.visible[tonumber(body)]
                                    if not r then return ret(nil) end
                                    -- columns as in the live window: icon, name, Qty, platinum, gold, silver, copper, Lvl
                                    local P = r.price
                                    if col == 1 then return ret('')
                                    elseif col == 2 then return ret(r.name)
                                    elseif col == 3 then return ret('--')
                                    elseif col == 4 then return ret(tostring(math.floor(P / 1000)))
                                    elseif col == 5 then return ret(tostring(math.floor((P % 1000) / 100)))
                                    elseif col == 6 then return ret(tostring(math.floor((P % 100) / 10)))
                                    elseif col == 7 then return ret(tostring(P % 10))
                                    elseif col == 8 then
                                        if r.levelText == false then return ret(nil) end
                                        if r.levelText ~= nil then return ret(r.levelText) end
                                        return ret(r.level and string.format('%3d', r.level) or '--')
                                    end
                                    return ret(nil)
                                end
                                if col ~= 2 then return ret(nil) end
                                local exact = body:sub(1, 1) == '='
                                local want = (exact and body:sub(2) or body):lower()
                                for i, r in ipairs(sim.visible) do
                                    if i > sim.visibleCount() then break end
                                    local nm = r.name:lower()
                                    if (exact and nm == want) or (not exact and nm:sub(1, #want) == want) then return ret(i) end
                                end
                                return ret(nil)
                            end,
                        })
                    end
                    if cn == 'MW_UsableButton' then return node(true, { Checked = function() return sim.usableChecked end }) end
                    return node(nil)
                end,
            })
        end
        if name == 'InventoryWindow' then
            return node(true, { Open = function() return true end, Child = function(cn)
                if cn == 'IW_ClassAbbr' and opts.classes then
                    return node(true, { Text = function() return table.concat(opts.classes, '\n') end })
                end
                return node(nil)
            end })
        end
        return node(true, { Open = function() return false end, Child = function() return node(nil) end })
    end

    local function coin(denom)
        return function()
            local c = sim.money
            local pp = math.floor(c / 1000); c = c % 1000
            local gp = math.floor(c / 100); c = c % 100
            local sp = math.floor(c / 10); c = c % 10
            return ({ pp = pp, gp = gp, sp = sp, cp = c })[denom]
        end
    end

    local paths = { logs = opts.logsRaw, root = opts.rootRaw }
    local function identity(kind)
        local server, character = 'SimServer', 'Simtest'
        for _, e in ipairs(opts.identities or {}) do
            if sim.clockMs >= (e.atMs or 0) then server, character = e.server, e.character end
        end
        if kind == 'server' then return server end
        return character
    end
    mq.TLO = {
        Window = window,
        Zone = { ShortName = function() return opts.zone or 'bazaar' end },
        EverQuest = { Server = function() return identity('server') end },
        MacroQuest = { Path = function(n)
            if opts.logsUnreadable then return node(nil) end
            if opts.logsUnreadableAfterMs and sim.clockMs >= opts.logsUnreadableAfterMs then return node(nil) end
            return node(paths[n])
        end },
        Me = {
            Platinum = coin('pp'), Gold = coin('gp'), Silver = coin('sp'), Copper = coin('cp'),
            NumBagSlots = function() return 10 end,
            CleanName = function() return identity('character') end,
            Class = { ShortName = function() return 'CLR' end },
            -- the character's known disciplines (D-030): by slot number a node whose Name() is the discipline; by exact name a node whose value is the slot number
            CombatAbility = function(arg)
                if type(arg) == 'number' then
                    if opts.knownScanErrors and opts.knownScanErrors[arg] then error('simulated read error at slot ' .. arg) end
                    local nm = sim.knownDisc[arg]
                    if not nm then return node(nil) end
                    return node(nm, { Name = function() return nm end })
                end
                if opts.byNameResult then
                    local v = opts.byNameResult(tostring(arg))
                    if v == 'RAISE' then error('simulated by-name read error') end
                    return node(v)
                end
                return node(sim.knownDiscSet[tostring(arg)])
            end,
            Inventory = function(name)
                local n = tonumber(name:match('^pack(%d+)$'))
                return itemNode(n and packItem(n))
            end,
        },
        Cursor = setmetatable({}, { __call = function() return sim.cursor and sim.cursor.name or nil end,
            __index = function(_, k) if k == 'Name' then return function() return sim.cursor and sim.cursor.name or nil end end end }),
        Merchant = {},
        Target = {
            ID = function() return sim.targetId end,
            CleanName = function()
                for name, vid in pairs(sim.vendorIds) do if vid == sim.targetId then return name end end
                return 'Sim Vendor'
            end,
            Name = function() return 'Sim_Vendor00' end,
        },
        Navigation = { Active = function() return false end, MeshLoaded = function() return true end },
        Spawn = function(q)
            local nm = tostring(q):match('"=(.-)"')
            local vid = nm and sim.vendorIds[nm]
            if vid then return node(true, { ID = function() return vid end }) end
            return node(nil)
        end,
    }
    mq.TLO.FindItemCount = function(spec)
        local exact = tostring(spec):sub(1, 1) == '='
        local want = (exact and tostring(spec):sub(2) or tostring(spec)):lower()
        local n = 0
        for _, it in pairs(sim.bag) do if it.name:lower() == want then n = n + (it.stack or 1) end end
        if sim.cursor and sim.cursor.name:lower() == want then n = n + 1 end   -- observed live: the cursor item is counted
        for hn, hc in pairs(sim.hidden) do if hn:lower() == want then n = n + hc end end
        if opts.countOverride then return node(opts.countOverride(tostring(spec), n)) end
        return node(n)
    end
    mq.TLO.Me.Book = function(name) return node(sim.book[name]) end
    mq.TLO.Merchant.Items = function() return #sim.rows end   -- model: the vendor's full stock, unfiltered
    mq.TLO.Merchant.Item = function(key)
        local r
        if tonumber(key) then r = sim.rows[tonumber(key)]
        else
            local exact = tostring(key):sub(1, 1) == '='
            local want = (exact and tostring(key):sub(2) or tostring(key)):lower()
            for _, x in ipairs(sim.rows) do
                local nm = x.name:lower()
                if (exact and nm == want) or (not exact and nm:sub(1, #want) == want) then r = x; break end
            end
        end
        if not r then return node(nil) end
        return node(r.name, { Name = function() return r.name end, ID = function() return r.id end })
    end
    mq.TLO.Merchant.SelectItem = function(key)
        local exact = tostring(key):sub(1, 1) == '='
        local want = (exact and tostring(key):sub(2) or tostring(key)):lower()
        for _, r in ipairs(sim.visible) do
            local nm = r.name:lower()
            if (exact and nm == want) or (not exact and nm:sub(1, #want) == want) then sim.selected = r; break end
        end
        return node(true)
    end
    setmetatable(mq.TLO.Merchant, { __index = function(_, k)
        if k == 'Name' then return function() return sim.vendorName end end
        if k == 'SelectedItem' then
            local r = sim.selected
            if not r then return node(nil) end
            return node(r.name, { Name = function() return r.name end, ID = function() return r.id end })
        end
    end })

    -- ------------------------------------------------------------- ImGui
    local ImGui = {}
    sim.clickPrefix = opts.clickPrefix or 'Buy From Open Vendor'
    function ImGui.Begin(_, open) return (not sim.finished), true end
    function ImGui.Button(label)
        if label == 'Stop' and opts.stopAtMs and not sim.stopped and sim.clockMs >= opts.stopAtMs then
            sim.stopped = true
            return true
        end
        if label == 'Re-detect' and opts.redetectAtMs and not sim.redetected and sim.clockMs >= opts.redetectAtMs then
            sim.redetected = true
            return true
        end
        if label:sub(1, 19) == 'Run Shopping Spree ' then sim.lastRunLabel = label end
        if opts.presses and sim.clickPrefix and label:sub(1, #sim.clickPrefix) == sim.clickPrefix then
            sim.pressCount = sim.pressCount or 0
            local notBefore = opts.pressNotBeforeMs and opts.pressNotBeforeMs[sim.pressCount + 1] or 0
            if sim.pressCount < opts.presses and (sim.summaries or 0) + (sim.errorRuns or 0) >= sim.pressCount and sim.clockMs >= notBefore then
                sim.pressCount = sim.pressCount + 1
                return true
            end
            return false
        end
        if label:sub(1, 19) == 'Run Shopping Spree ' then sim.lastRunLabel = label end   -- the visit count shown on the button (D-030)
        if sim.clickPrefix and label:sub(1, #sim.clickPrefix) == sim.clickPrefix then
            sim.clickPrefix = nil
            return true
        end
        return false
    end
    -- opts.checkClass = 'Cleric': tick that class's whole row once (PoK spree scenario)
    function ImGui.Checkbox(label, v)
        if opts.checkClass and not sim.classChecked and label == '##class_' .. opts.checkClass then
            sim.classChecked = true
            return true, true
        end
        sim.ticked = sim.ticked or {}
        for _, lb in ipairs(opts.ticks or {}) do
            if label == lb and not sim.ticked[lb] then
                sim.ticked[lb] = true
                return true, true
            end
        end
        return v, false
    end
    function ImGui.TreeNode(label) return (opts.openTrees and opts.openTrees[label]) == true end
    function ImGui.IsWindowHovered() return false end
    function ImGui.GetWindowPos() return 0, 0 end
    function ImGui.GetWindowSize() return 600, 780 end
    function ImGui.GetMousePos() return -100, -100 end
    function ImGui.GetWindowWidth() return 600 end
    function ImGui.GetScrollY() return 0 end
    function ImGui.GetScrollMaxY() return 0 end
    setmetatable(ImGui, { __index = function() return function() end end })

    sim.mq, sim.ImGui = mq, ImGui
    return sim
end

return M
