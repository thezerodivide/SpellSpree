-- Runs spellspree.lua (or a mutated copy) against the mock MQ in test/mock_mq.lua.
-- SIMULATION ONLY -- see the header of mock_mq.lua.
local M = {}

local here = (arg and arg[0] or ''):gsub('[\\/][^\\/]*$', '')
package.path = here .. '/?.lua;' .. package.path
local mock = require('mock_mq')

-- scriptPath: file to run. opts: see mock_mq.new. Returns the sim table with
-- .ok/.runErr (did the script chunk finish), .prints, .cmds, .purchases.
function M.run(scriptPath, opts)
    local sim = mock.new(opts)
    package.loaded['mq'], package.loaded['ImGui'] = sim.mq, sim.ImGui
    package.preload['mq'] = function() return sim.mq end
    package.preload['ImGui'] = function() return sim.ImGui end
    _G.ImGuiCond = { FirstUseEver = 0 }

    local realPrint = print
    _G.print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        local line = table.concat(parts, ' ')
        sim.prints[#sim.prints + 1] = line
        -- printSpreeSummary's last line ("Skipped (...") exists in both the pre-logging
        -- baseline and the current script, so runs of either end at the same point.
        if line:find('Skipped (', 1, true) then sim.finished = true end
    end

    local chunk, err = loadfile(scriptPath)
    if not chunk then _G.print = realPrint; error('load failed: ' .. tostring(err)) end
    local ok, runErr = pcall(chunk)
    _G.print = realPrint
    sim.ok, sim.runErr = ok, runErr
    return sim
end

function M.readLines(path)
    local lines = {}
    local f = io.open(path, 'rb')
    if not f then return nil end
    -- the script appends in Windows text mode, so lines end in CRLF
    for l in f:lines() do lines[#lines + 1] = (l:gsub('\r$', '')) end
    f:close()
    return lines
end

return M
