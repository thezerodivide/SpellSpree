-- Smoke run: one scenario, prints the resulting log. Usage: luajit test/smoke.lua [scenario]
package.path = 'test/?.lua;' .. package.path
local R = require('sim_run')

local outDir = os.getenv('TEMP') .. '\\spellspree_sim\\smoke'
os.execute('if not exist "' .. outDir .. '" mkdir "' .. outDir .. '"')
local logFile = outDir .. '\\spellspree\\spellspree_SimServer_Simtest.log'
os.remove(logFile)

local sim = R.run('spellspree.lua', {
    logsRaw = outDir, rootRaw = outDir,
    nonSpells = { 'Pickled Cat Food' },
    spells = { { name = 'Alpha', price = 100 }, { name = 'Beta', price = 200 }, { name = 'Gamma', price = 300 } },
    reorderAfterBuy = true,
})
print('script chunk ok:', sim.ok, sim.runErr)
print('purchases:', table.concat(sim.purchases, ', '))
print('commands sent:', #sim.cmds)
local lines = R.readLines(logFile) or {}
print('log lines:', #lines)
for _, l in ipairs(lines) do print(l) end
