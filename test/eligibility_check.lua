-- Evidence for D-017 choice G: replacing the scan mechanism changes WHAT is bought by nothing.
-- Runs a previous build and the current script through the same simulated vendors and compares the SET of
-- scrolls each one bought (order, commands and timing legitimately differ now). SIMULATION ONLY.
-- Usage: luajit test/eligibility_check.lua <previous build .lua> <current .lua>
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')
local previous, current = arg[1], arg[2]
assert(previous and current, 'usage: eligibility_check.lua <previous.lua> <current.lua>')

local TMP = (os.getenv('TEMP') or '.'):gsub('\\', '/') .. '/spellspree_sim/eligibility'
local function dirFor(tag)
    local d = TMP .. '/' .. tag
    os.execute('if not exist "' .. d:gsub('/', '\\') .. '" mkdir "' .. d:gsub('/', '\\') .. '"')
    return d
end

local spells = {
    { name = 'Alpha', price = 100, level = 10 }, { name = 'Beta', price = 200, level = 20 },
    { name = 'Gamma', price = 300, level = 30 }, { name = 'Delta', price = 400, level = 40 },
}
local function mk(extra)
    return function(dir)
        local o = { logsRaw = dir, rootRaw = dir, nonSpells = { 'Pickled Cat Food', 'Blue Diamond' }, spells = spells }
        for k, v in pairs(extra) do o[k] = v end
        return o
    end
end
local scenarios = {
    { name = 'reorder after every buy', o = mk({ reorderAfterBuy = true }) },
    { name = 'scribed rows leave the list at once', o = mk({ liveRefresh = true }) },
    { name = 'a scribe rejected twice before it takes', o = mk({ scribeRejectFirst = 2 }) },
    { name = 'no money at all', o = mk({ money = 50 }) },
    { name = 'Plane of Knowledge spree, two vendors', o = function(dir) return {
        logsRaw = dir, rootRaw = dir, zone = 'poknowledge', checkClass = 'Cleric', clickPrefix = 'Run Shopping Spree',
        vendors = { ['Vicar Ceraen'] = { nonSpells = { 'Pickled Cat Food' }, spells = spells }, ['Vicar Thiran'] = { nonSpells = { 'Pickled Cat Food' } } } } end,
      -- D-025: Step 3 buys only spells whose level is in a visited range. All four Cleric tiers are ticked, so vendor 1 is visited
      -- for 1-25 and 61-70 (Vicar Thiran stocks nothing): the expected purchases are the previous build's purchases whose level is in one of these.
      ranges = { { 1, 25 }, { 61, 70 } } },
}

local function setString(list) local t = {}; for i, v in ipairs(list) do t[i] = v end; table.sort(t); return table.concat(t, ', ') end

local bad = 0
for i, sc in ipairs(scenarios) do
    local a = R.run(previous, sc.o(dirFor('prev' .. i)))
    local b = R.run(current, sc.o(dirFor('cur' .. i)))
    local expected, money = a.purchases, a.money
    if sc.ranges then
        local info = {}
        for _, sp in ipairs(spells) do info['Spell: ' .. sp.name] = sp end
        expected, money = {}, a.money
        for _, name in ipairs(a.purchases) do
            local sp, keep = info[name], false
            for _, r in ipairs(sc.ranges) do if sp.level >= r[1] and sp.level <= r[2] then keep = true end end
            if keep then expected[#expected + 1] = name else money = money + sp.price end
        end
    end
    local sa, sb = setString(expected), setString(b.purchases)
    local same = sa == sb and money == b.money
    print(string.format('%-45s %s  (%s bought %d, current bought %d, money left %s vs %s)', sc.name,
        same and (sc.ranges and 'SAME SET IN RANGE' or 'SAME SET') or 'DIFFERENT', sc.ranges and 'previous in range' or 'previous', #expected, #b.purchases, tostring(money), tostring(b.money)))
    if not same then bad = bad + 1; print('   previous: ' .. sa); print('   current:  ' .. sb) end
end
os.exit(bad == 0 and 0 or 1)
