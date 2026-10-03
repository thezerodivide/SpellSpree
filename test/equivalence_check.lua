-- One-off evidence for decision D-004: the logging change alters no behavior.
-- Runs the pre-logging baseline script and the current script through the same
-- simulated scenarios and compares what each SENT to the game (command sequence),
-- what it bought, and the simulated time it took. SIMULATION ONLY.
-- Usage: luajit test/equivalence_check.lua <baseline.lua> <current.lua>
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')
local baseline, current = arg[1], arg[2]
assert(baseline and current, 'usage: equivalence_check.lua <baseline.lua> <current.lua>')

local TMP = (os.getenv('TEMP') or '.') .. '\\spellspree_sim\\equiv'
os.execute('if not exist "' .. TMP .. '" mkdir "' .. TMP .. '"')

local spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } }
local scenarios = {
    { name = 'reorder', o = { nonSpells = { 'Pickled Cat Food' }, spells = spells, reorderAfterBuy = true } },
    { name = 'liveRefresh', o = { nonSpells = { 'Pickled Cat Food' }, spells = spells, liveRefresh = true } },
    { name = 'rejects', o = { spells = { { name = 'Alpha', price = 100 } }, scribeRejectFirst = 2 } },
    { name = 'broke', o = { money = 50, spells = spells } },
}

local bad = 0
for _, sc in ipairs(scenarios) do
    local function go(path)
        local o = {}
        for k, v in pairs(sc.o) do o[k] = v end
        o.logsRaw, o.rootRaw = TMP, TMP
        local sim = R.run(path, o)
        return sim
    end
    local a, b = go(baseline), go(current)
    local problems = {}
    if #a.cmds ~= #b.cmds then problems[#problems + 1] = string.format('command count %d vs %d', #a.cmds, #b.cmds) end
    for i = 1, math.min(#a.cmds, #b.cmds) do
        if a.cmds[i] ~= b.cmds[i] then problems[#problems + 1] = string.format('command %d: "%s" vs "%s"', i, a.cmds[i], b.cmds[i]); break end
    end
    if table.concat(a.purchases, ',') ~= table.concat(b.purchases, ',') then problems[#problems + 1] = 'purchases differ' end
    if a.clockMs ~= b.clockMs then problems[#problems + 1] = string.format('simulated time %dms vs %dms', a.clockMs, b.clockMs) end
    if a.money ~= b.money then problems[#problems + 1] = 'final money differs' end
    print(string.format('%-12s %s  (cmds=%d, bought=%d, simulated %dms)', sc.name, #problems == 0 and 'IDENTICAL' or 'DIFFERENT',
        #b.cmds, #b.purchases, b.clockMs))
    for _, p in ipairs(problems) do print('    ' .. p) end
    if #problems > 0 then bad = bad + 1 end
end
os.exit(bad == 0 and 0 or 1)
