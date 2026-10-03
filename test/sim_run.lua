-- Runs spellspree.lua (or a mutated copy) against the mock MQ in test/mock_mq.lua.
-- SIMULATION ONLY -- see the header of mock_mq.lua.
local M = {}

local here = (arg and arg[0] or ''):gsub('[\\/][^\\/]*$', '')
package.path = here .. '/?.lua;' .. package.path
local mock = require('mock_mq')

-- scriptPath: file to run. opts: see mock_mq.new. Returns the sim table with
-- .ok/.runErr (did the script chunk finish), .prints, .cmds, .purchases.
-- D-026 E': when the script logs "No vendors selected" it returns without printing the summary, so nothing else would end a run
-- (it used to drag on to the 400,000-delay guard). The run now ends after this many further delays; the grace is long enough
-- that a later forbidden action (a /nav, a Buy) would still be seen, and the tests prove that. Tests may change it to show
-- they would notice (see the harness mutations in test_step2.lua).
M.GRACE = 20

function M.run(scriptPath, opts, ...)
    assert(rawget(_G, 'SPELLSPREE_UNIT') == nil, 'SPELLSPREE_UNIT is set: the script would stop at the unit-test hook instead of running')
    local sim = mock.new(opts)
    sim.summaries, sim.errorRuns = 0, 0
    local realDelay = sim.mq.delay
    sim.mq.delay = function(ms)
        -- decided before the delay so the frame drawn inside it already sees the run as finished
        if sim.noVendorsAt and not sim.finished and sim.delays + 1 >= sim.noVendorsAt + M.GRACE then
            sim.finished, sim.endedBy = true, 'no-vendors'
        end
        return realDelay(ms)
    end
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
        if line:find('Skipped (', 1, true) then
            sim.summaries = (sim.summaries or 0) + 1
            -- a scenario that presses Run several times (opts.runs) ends after that many summaries
            if sim.summaries + (sim.errorRuns or 0) >= (opts and opts.runs or 1) then sim.finished = true; sim.endedBy = sim.endedBy or 'summary' end
        end
        -- a run that raises an error never prints the summary: its error line counts as the run's end (D-028 tests)
        if line:find('Unexpected error', 1, true) then
            sim.errorRuns = (sim.errorRuns or 0) + 1
            if (sim.summaries or 0) + sim.errorRuns >= (opts and opts.runs or 1) and not sim.finished then sim.finished = true; sim.endedBy = sim.endedBy or 'error-line' end
        end
        if line:find('No vendors selected', 1, true) and not sim.noVendorsAt then sim.noVendorsAt = sim.delays end
    end

    local chunk, err = loadfile(scriptPath)
    if not chunk then _G.print = realPrint; error('load failed: ' .. tostring(err)) end
    local ok, runErr = pcall(chunk, ...)
    _G.print = realPrint
    sim.ok, sim.runErr = ok, runErr
    if not sim.endedBy then
        sim.endedBy = (not ok and tostring(runErr):find('simulation runaway', 1, true)) and 'guard' or (ok and 'other' or 'error')
    end
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
