-- Unit-test wrapper for spellspree.lua (decision log D-026, items A, B and C'').
--
-- withUnit(scriptPath, body) loads a FRESH copy of the real script with minimal stubs for `mq` and `ImGui`, with
-- _G.SPELLSPREE_UNIT set to an empty table. At its hook point the script fills that table with its testable pieces and returns
-- (the chunk's return value is not used). The body receives that table.
--
-- Everything from stub installation through the body runs inside ONE pcall; the saved globals and module entries are always
-- restored afterwards, and the original failure is then re-raised. A test that fails, a script that does not load and a script
-- that errors while it initialises all leave the process as they found it.
--
-- SIMULATION ONLY: the stubs are not MacroQuest. The script's behavior against a model of the vendor window is covered by the
-- scenario suites (mock_mq.lua); a live run is the only evidence about the real client.
local U = {}

-- every name the hook must provide, and the type each must have
U.EXPECTED = {
    parseClassLine = 'function', parseCopperFromText = 'function', withCommas = 'function', formatCoin = 'function',
    formatCoinPPOnly = 'function', isScrollName = 'function', setOutcome = 'function',
    markRemainingNotAttempted = 'function', logLedger = 'function',
    OUTCOME = 'table', S = 'table', LOG = 'table',
}
local EXPECTED_ORDER = { 'parseClassLine', 'parseCopperFromText', 'withCommas', 'formatCoin', 'formatCoinPPOnly', 'isScrollName',
    'setOutcome', 'markRemainingNotAttempted', 'logLedger', 'OUTCOME', 'S', 'LOG' }

local MODULES = { 'mq', 'ImGui' }

local function strict(name, allowed)
    return setmetatable({}, {
        __index = function(t, k)
            if allowed[k] ~= nil then return allowed[k] end
            error(string.format('unit-test stub: unexpected use of %s.%s', name, tostring(k)), 2)
        end,
        __newindex = function(_, k) error(string.format('unit-test stub: unexpected assignment to %s.%s', name, tostring(k)), 2) end,
    })
end

local function save()
    local s = { hook = rawget(_G, 'SPELLSPREE_UNIT'), print = _G.print, loaded = {}, preload = {} }
    for _, m in ipairs(MODULES) do s.loaded[m] = package.loaded[m]; s.preload[m] = package.preload[m] end
    return s
end

local function restore(s)
    _G.SPELLSPREE_UNIT = s.hook
    _G.print = s.print
    for _, m in ipairs(MODULES) do package.loaded[m] = s.loaded[m]; package.preload[m] = s.preload[m] end
end

-- `stubs` (optional, D-028): { mq = { field = value, ... } } adds fields to the strict mq stub for a test that needs a richer MacroQuest
-- (the logging identity tests give it a TLO tree and a clock); everything else stays refused.
local function install(unit, stubs)
    local allowed = { gettime = function() return 0 end }
    for k, v in pairs((stubs and stubs.mq) or {}) do allowed[k] = v end
    local mq = strict('mq', allowed)
    local imgui = strict('ImGui', {})
    for _, m in ipairs(MODULES) do package.loaded[m] = nil end
    package.loaded['mq'], package.loaded['ImGui'] = mq, imgui
    package.preload['mq'] = function() return mq end
    package.preload['ImGui'] = function() return imgui end
    _G.print = function() end
    _G.SPELLSPREE_UNIT = unit
end

-- `extra` (optional) is a list of { name, type } a particular test needs on top of the standing exports (D-025: Step 3 adds
-- parseTierRange, validateRange and classifyLevel; a test that needs them says so, so older tests do not depend on them)
local function verifyExports(unit, extra)
    for _, name in ipairs(EXPECTED_ORDER) do
        if type(unit[name]) ~= U.EXPECTED[name] then
            error(string.format('the script did not expose %s as a %s (got %s)', name, U.EXPECTED[name], type(unit[name])), 0)
        end
    end
    for _, want in ipairs(extra or {}) do
        if type(unit[want[1]]) ~= want[2] then
            error(string.format('the script did not expose %s as a %s (got %s)', want[1], want[2], type(unit[want[1]])), 0)
        end
    end
end

-- variant 'load-outside' is a deliberately weakened wrapper used only to show that the cleanup tests can fail (D-026 C'' mutation)
function U.new(variant)
    return function(scriptPath, body, extra, stubs)
        assert(rawget(_G, 'SPELLSPREE_UNIT') == nil, 'SPELLSPREE_UNIT is already set: an earlier test leaked it')
        local saved = save()
        local unit = {}
        local function load()
            install(unit, stubs)
            local chunk, lerr = loadfile(scriptPath)
            if not chunk then error('load failed: ' .. tostring(lerr), 0) end
            chunk()
            verifyExports(unit, extra)
        end
        local ok, err
        if variant == 'load-outside' then
            install(unit, stubs)
            local chunk, lerr = loadfile(scriptPath)       -- unprotected: an error here skips the restore below
            if not chunk then error('load failed: ' .. tostring(lerr), 0) end
            chunk()
            verifyExports(unit, extra)
            ok, err = pcall(body, unit)
        else
            ok, err = pcall(function() load(); body(unit) end)
        end
        restore(saved)
        local leaked = rawget(_G, 'SPELLSPREE_UNIT') ~= nil
        if not ok then
            if leaked then err = tostring(err) .. ' (and SPELLSPREE_UNIT was still set after cleanup)' end
            error(err, 0)
        end
        assert(not leaked, 'SPELLSPREE_UNIT was still set after cleanup')
    end
end

U.withUnit = U.new()
U.save, U.restore = save, restore
return U
