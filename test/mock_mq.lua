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
--       manualBuy = { name=, buyAtMs=, scribeAtMs=, removeAtMs= } (the developer buys and
--       scribes one spell by hand while the spike watches; the row leaves the list late),
--       vendors = { [npcName] = { spells=, nonSpells= } } (Plane of Knowledge
--       shopping spree: each NPC has its own stock; click the Cleric class box,
--       then Run Shopping Spree; NPCs not listed are absent from the zone).
function M.new(opts)
    local sim = {
        opts = opts, clockMs = 0, cmds = {}, prints = {}, merchantOpen = true,
        usableChecked = true, known = {}, targetId = 4242, finished = false,
        scribeRejects = opts.scribeRejectFirst or 0, delays = 0, purchases = {},
    }
    sim.money = opts.money or 10000000

    -- merchant rows, in vendor order
    local function buildRows(spec)
        local rows, id = {}, 1000
        for _, n in ipairs(spec.nonSpells or {}) do
            id = id + 1; rows[#rows + 1] = { name = n, id = id, price = 5 }
        end
        for _, sp in ipairs(spec.spells or {}) do
            id = id + 1; rows[#rows + 1] = { name = 'Spell: ' .. sp.name, id = id, price = sp.price or 100 }
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
            if r then sim.selected = r end
            return
        end
        if cmd == '/notify MerchantWnd MW_Buy_Button leftmouseup' then
            local r = sim.selected
            if r and sim.merchantOpen and sim.money >= r.price then
                sim.money = sim.money - r.price
                sim.purchases[#sim.purchases + 1] = r.name
                if sim.vendorName then
                    local list = sim.purchasesByVendor[sim.vendorName] or {}
                    list[#list + 1] = r.name
                    sim.purchasesByVendor[sim.vendorName] = list
                end
                local existing
                if opts.stackOnExisting then
                    for s = 1, 10 do if sim.bag[s] and sim.bag[s].name == r.name then existing = sim.bag[s] end end
                end
                if existing then
                    existing.stack = existing.stack + 1
                else
                    local s = firstFreeBagSlot()
                    if s then sim.bag[s] = { name = r.name, stack = 1 } end
                end
                if opts.reorderAfterBuy then
                    table.insert(sim.visible, table.remove(sim.visible, 1))
                end
            end
            return
        end
        local slot = cmd:match('^/itemnotify in pack1 (%d+) rightmouseup$')
        if slot then
            local it = sim.bag[tonumber(slot)]
            if it and it.name:match('^Spell:') then
                if sim.scribeRejects > 0 then sim.scribeRejects = sim.scribeRejects - 1; return end
                sim.known[it.name] = true
                if it.stack > 1 then it.stack = it.stack - 1 else sim.bag[tonumber(slot)] = nil end
                if opts.liveRefresh then
                    for i, r in ipairs(sim.visible) do
                        if r.name == it.name then table.remove(sim.visible, i); break end
                    end
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
    if opts.manualBuy then
        local mb, done = opts.manualBuy, {}
        local function find(list) for i, r in ipairs(list) do if r.name == mb.name then return i, r end end end
        sim.tick = function()
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

    -- ---------------------------------------------------------------- mq
    local mq = { configDir = 'C:/sim/config' }
    function mq.cmd(c) handleCmd(c) end
    function mq.cmdf(f, ...) handleCmd(string.format(f, ...)) end
    function mq.gettime() return sim.clockMs end
    function mq.doevents() end
    function mq.event() end
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
                    if cn == 'ItemList' then
                        return node(true, {
                            Items = function() return #sim.visible end,
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
                                    local r = sim.visible[tonumber(body)]
                                    if not r then return ret(nil) end
                                    if col == 1 then return ret('') elseif col == 2 then return ret(r.name) elseif col == 3 then return ret(tostring(r.price) .. 'cp') end
                                    return ret(nil)
                                end
                                if col ~= 2 then return ret(nil) end
                                local exact = body:sub(1, 1) == '='
                                local want = (exact and body:sub(2) or body):lower()
                                for i, r in ipairs(sim.visible) do
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
            return node(true, { Open = function() return true end, Child = function() return node(nil) end })
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
    mq.TLO = {
        Window = window,
        Zone = { ShortName = function() return opts.zone or 'bazaar' end },
        EverQuest = { Server = function() return 'SimServer' end },
        MacroQuest = { Path = function(n)
            if opts.logsUnreadable then return node(nil) end
            return node(paths[n])
        end },
        Me = {
            Platinum = coin('pp'), Gold = coin('gp'), Silver = coin('sp'), Copper = coin('cp'),
            NumBagSlots = function() return 10 end,
            CleanName = function() return 'Simtest' end,
            Class = { ShortName = function() return 'CLR' end },
            Inventory = function(name)
                local n = tonumber(name:match('^pack(%d+)$'))
                return itemNode(n and packItem(n))
            end,
        },
        Cursor = node(nil, { Name = function() return nil end }),
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
        return v, false
    end
    function ImGui.TreeNode() return false end
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
