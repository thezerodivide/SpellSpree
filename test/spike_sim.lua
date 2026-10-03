-- Runs spikes/spellspree_spike.lua (probe, then watch) against the mock MQ and prints
-- the spike's own log, so it can be read before the spike is handed over.
-- SIMULATION ONLY: this shows that the spike runs cleanly and that its log reads
-- sensibly. It says nothing about what the real client returns.
-- Usage (repo root):  luajit test/spike_sim.lua
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local base = (os.getenv('TEMP') or '.'):gsub('\\', '/') .. '/spellspree_sim/spike'
local function fresh(tag)
    local dir = base .. '/' .. tag
    os.execute('if not exist "' .. dir:gsub('/', '\\') .. '" mkdir "' .. dir:gsub('/', '\\') .. '"')
    os.remove(dir .. '/spellspree/spike_SimServer_Simtest.log')
    return dir
end
local function show(dir)
    for _, l in ipairs(R.readLines(dir .. '/spellspree/spike_SimServer_Simtest.log') or { '(no log file)' }) do print(l) end
end

local stock = {
    nonSpells = { 'Pickled Cat Food', 'Skull Marked Shield', 'Skull Marked Shield (Enchanted)' },
    spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } },
}

local which = arg[1] or 'both'
if which == 'probe' or which == 'both' then
    local dir = fresh('probe')
    local o = { logsRaw = dir, rootRaw = dir, nonSpells = stock.nonSpells, spells = stock.spells }
    local sim = R.run('spikes/spellspree_spike.lua', o)
    print('##### PROBE: script ok=' .. tostring(sim.ok) .. ' err=' .. tostring(sim.runErr) .. ' cmds sent=' .. #sim.cmds .. ' purchases=' .. #sim.purchases)
    show(dir)
end
if which == 'watch' or which == 'both' then
    local dir = fresh('watch')
    local o = { logsRaw = dir, rootRaw = dir, nonSpells = stock.nonSpells, spells = stock.spells,
        manualBuy = { name = 'Spell: Beta', buyAtMs = 3000, scribeAtMs = 6000, removeAtMs = 12000 } }
    local sim = R.run('spikes/spellspree_spike.lua', o, 'watch', 'Spell: Beta', '25')
    print('\n##### WATCH: script ok=' .. tostring(sim.ok) .. ' err=' .. tostring(sim.runErr) .. ' cmds sent=' .. #sim.cmds)
    show(dir)
end

if which == 'watchmissing' then
    -- a name that is not on the list (e.g. already scribed): the spike must stop at once and say what is there
    local dir = fresh('watchmissing')
    local o = { logsRaw = dir, rootRaw = dir, nonSpells = stock.nonSpells, spells = stock.spells }
    local sim = R.run('spikes/spellspree_spike.lua', o, 'watch', 'Spell: Alph', '25')
    print('##### WATCH, NAME NOT ON LIST: script ok=' .. tostring(sim.ok) .. ' err=' .. tostring(sim.runErr) .. ' simulated ms=' .. sim.clockMs)
    show(dir)
end
