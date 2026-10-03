---@diagnostic disable: undefined-global, undefined-field
-- ============================================================================
-- SpellSpree -- automated vendor spell buyer & scriber
-- ----------------------------------------------------------------------------
-- Run with: /lua run spellspree
--
-- Two ways to run it:
--
--   Plane of Knowledge -- tick the class/tier boxes and hit Run Shopping
--   Spree. It paths to each vendor in turn, opens them, and works the list.
--
--   Bazaar (1-50 spells) -- there is no navmesh for the Bazaar, so nothing
--   is automated up to the merchant. Walk there, open the vendor's window
--   yourself, and hit Buy From Open Vendor. The class/tier boxes are ignored
--   on that path: you already chose the vendor by opening it, so it simply
--   buys every scroll that merchant will sell you.
--
-- Both paths run the same purchase loop, and both handle spell scrolls
-- ("Spell: <name>") and bard songs ("Song: <name>").
--
-- Once a merchant window is open, it will:
--   1. Try to turn on the merchant's "usable items only" filter (best-effort --
--      the exact checkbox name varies by UI skin, see USABLE_FILTER_CANDIDATES).
--   2. Before each purchase, find the first genuinely open inventory slot
--      (lowest bag, lowest slot) -- same order the client fills new items
--      into -- and use that as the expected landing spot. No moving things
--      around, no forcing anything into a pre-cleared slot. Warns and stops
--      cleanly if there's no free space anywhere.
--   3. Walk the merchant's item list top to bottom. For each item that's a
--      spell scroll: buy it, confirm the quantity window if one pops up,
--      right-click it where it landed to scribe it into your spellbook,
--      confirm a scribe dialog if one pops up, then move to the next item.
--   3b. The vendor window changes under a row-by-row scan (rows leave the list
--      late, in batches, and unprompted), so row positions are never trusted:
--      the script waits for the visible list to settle, reads it ONCE into a list
--      of scroll names, then finds each name's row by exact name just before
--      buying it. Each name is bought at most once; there is no reopen and no
--      repeat pass. Every name ends with one logged outcome (D-017).
--   4. Stop (and close the vendor) once the list runs out. Stops (vendor left
--      open) if it can't afford the next spell, if inventory fills up
--      mid-run, or if a purchase just plain fails -- in that case it skips
--      that one spell and keeps going rather than getting stuck.
--
-- NOTE: written without an in-game test pass. The four /notify commands for
-- buy/quantity/select/scribe are taken directly from a known-working macro,
-- so those should be solid. The "usable items only" checkbox name and the
-- scribe-confirmation dialog name are best-effort guesses (commented below)
-- since those vary by UI skin/client era -- if either doesn't fire, it's
-- non-fatal, but paste back the exact child-window name if you know it and
-- I'll wire it in directly.
-- ============================================================================

local mq    = require('mq')
local ImGui = require('ImGui')

local VERSION = '1.6.0-test.4'
local open    = true

-- ============================================================================
-- Theme
-- ============================================================================
local COLOR_INFO = { 0.75, 0.80, 0.92, 1.0 }
local COLOR_GOOD = { 0.40, 0.90, 0.55, 1.0 }
local COLOR_WARN = { 1.00, 0.76, 0.30, 1.0 }
local COLOR_ERR  = { 0.95, 0.35, 0.35, 1.0 }
local COLOR_GOLD = { 1.00, 0.84, 0.35, 1.0 }
local COLOR_MUTE = { 0.55, 0.58, 0.65, 1.0 }
local COLOR_WHITE = { 1.00, 1.00, 1.00, 1.0 }

-- ============================================================================
-- Diagnostics
-- ============================================================================
-- Flip to true to get the development diagnostics back in the log: the raw
-- text of every vendor tell, every parsed price quote, and the predicted
-- landing slot at the start of a vendor. They're off by default because they
-- fired two lines per item and buried the lines that actually say what
-- happened. They stay in the code rather than getting deleted -- each one
-- answered a real question during testing (does mq.event fire here at all;
-- is the price pattern matching; is the slot prediction pointing somewhere
-- real), and those are the same questions worth asking first if something
-- ever goes sideways again.
local DEBUG = false

-- ============================================================================
-- PoK spell vendors -- hand-verified in-game by the user, not scraped from
-- old wiki pages. Edit this table directly if a name ever changes.
-- ============================================================================
local TIERS = { '1-25', '26-50', '51-60', '61-70' }

local CLASS_ORDER = {
    'Cleric', 'Bard', 'Enchanter', 'Wizard', 'Shadowknight', 'Necromancer',
    'Shaman', 'Druid', 'Magician', 'Ranger', 'Paladin', 'Beastlord',
}

-- The 61-70 vendor names below are COMMENTED OUT, not deleted (decision log D-021 B', D-020 addendum 2): no spells
-- are sold there now (its list is empty with the usable-only box on), and the level 61-65 spells are on the 1-25
-- vendor, so a ticked 61-70 is routed to the 1-25 vendor by TIER_VENDOR below. If the server ever changes where those
-- spells are, restore them (see the note on TIER_VENDOR).
local VENDOR_DATA = {
    Cleric        = { ['1-25'] = 'Vicar Ceraen',        ['26-50'] = 'Vicar Thiran',         ['51-60'] = 'Vicar Delin', --[[ ['61-70'] = 'Vicar Diarin' ]] },
    Bard          = { ['1-25'] = 'Minstrel Eoweril',    ['26-50'] = 'Minstrel Joet',         ['51-60'] = 'Minstrel Gwiar', --[[ ['61-70'] = 'Minstrel Silnon' ]] },
    Enchanter     = { ['1-25'] = 'Illusionist Jerup',   ['26-50'] = 'Illusionist Sevat',     ['51-60'] = 'Illusionist Lobaen', --[[ ['61-70'] = 'Illusionist Acored' ]] },
    Wizard        = { ['1-25'] = 'Channeler Olaemos',   ['26-50'] = 'Channeler Lariland',    ['51-60'] = 'Channeler Cerakoth', --[[ ['61-70'] = 'Channeler Alyrianne' ]] },
    Shadowknight  = { ['1-25'] = 'Reaver Nydlil',       ['26-50'] = 'Reaver Uledrith',       ['51-60'] = 'Reaver Thirlan', --[[ ['61-70'] = 'Reaver Muron' ]] },
    Necromancer   = { ['1-25'] = 'Heretic Drahur',      ['26-50'] = 'Heretic Elirev',        ['51-60'] = 'Heretic Edalith', --[[ ['61-70'] = 'Heretic Ceikon' ]] },
    Shaman        = { ['1-25'] = 'Mystic Abomin',       ['26-50'] = 'Mystic Goharkor',       ['51-60'] = 'Mystic Ryrin', --[[ ['61-70'] = 'Mystic Pikor' ]] },
    Druid         = { ['1-25'] = 'Wanderer Astobin',    ['26-50'] = 'Wanderer Qenda',        ['51-60'] = 'Wanderer Frardok', --[[ ['61-70'] = 'Wanderer Kedrisan' ]] },
    Magician      = { ['1-25'] = 'Elementalist Somat',  ['26-50'] = 'Elementalist Kaeob',    ['51-60'] = 'Elementalist Padan', --[[ ['61-70'] = 'Elementalist Siewth' ]] },
    Ranger        = { ['1-25'] = 'Pathfinder Viliken',  ['26-50'] = 'Pathfinder Vaered',     ['51-60'] = 'Pathfinder Thoajin', --[[ ['61-70'] = 'Pathfinder Naend' ]] },
    Paladin       = { ['1-25'] = 'Cavalier Waut',       ['26-50'] = 'Cavalier Aodus',        ['51-60'] = 'Cavalier Preradus', --[[ ['61-70'] = 'Cavalier Cerakor' ]] },
    Beastlord     = { ['1-25'] = 'Primalist Saosith',   ['26-50'] = 'Primalist Worenon',     ['51-60'] = 'Primalist Nydalith', --[[ ['61-70'] = 'Primalist Loerith' ]] },
}

-- Which vendor tier each ticked tier is bought from (decision log D-021 A', D-022). A ticked 61-70 uses the 1-25 vendor.
-- Each ticked tier is its own visit (D-020 R34): ticking 1-25 and 61-70 visits the 1-25 vendor twice, once per range.
--
-- TO RESTORE THE OLD 61-70 VENDORS (if the server moves the spells): in THIS table delete the active
--   ['61-70'] = '1-25'
-- line and un-comment the old one beside it, and in VENDOR_DATA remove the --[[ ]] markers around each ['61-70'] name.
-- Exactly ONE ['61-70'] entry may be active here: in a Lua table constructor a repeated key silently keeps the last one.
local TIER_VENDOR = {
    ['1-25']  = '1-25',
    ['26-50'] = '26-50',
    ['51-60'] = '51-60',
    ['61-70'] = '1-25',
    --[[ OLD, kept for restoring: ['61-70'] = '61-70', ]]
}

-- ============================================================================
-- Class detection -- ported from triune.lua's own detectClasses(), since
-- that's proven working code for this "trio" multi-class character setup,
-- not a guess. Reads the InventoryWindow's class display (a character can
-- be up to 3 classes at once on this server), falls back to Me.Class for a
-- normal single-class character. Maps onto our full class names so it can
-- filter the Shopping List.
-- ============================================================================
local MQSHORT = {
    WARRIOR = 'War', WAR = 'War', WARRIORS = 'War',
    CLERIC = 'Clr', CLR = 'Clr', CLERICS = 'Clr',
    PALADIN = 'Pal', PAL = 'Pal', PALADINS = 'Pal',
    RANGER = 'Rng', RNG = 'Rng', RANGERS = 'Rng',
    SHADOWKNIGHT = 'SK', SHD = 'SK', SK = 'SK', SHADOWKNIGHTS = 'SK',
    DRUID = 'Dru', DRU = 'Dru', DRUIDS = 'Dru',
    MONK = 'Mnk', MNK = 'Mnk', MONKS = 'Mnk',
    BARD = 'Brd', BRD = 'Brd', BARDS = 'Brd',
    ROGUE = 'Rog', ROG = 'Rog', ROGUES = 'Rog',
    SHAMAN = 'Shm', SHM = 'Shm', SHAMANS = 'Shm',
    NECROMANCER = 'Nec', NEC = 'Nec', NECROMANCERS = 'Nec',
    WIZARD = 'Wiz', WIZ = 'Wiz', WIZARDS = 'Wiz',
    MAGICIAN = 'Mag', MAG = 'Mag', MAGICIANS = 'Mag',
    ENCHANTER = 'Enc', ENC = 'Enc', ENCHANTERS = 'Enc',
    BEASTLORD = 'Bst', BST = 'Bst', BEASTLORDS = 'Bst',
    BERSERKER = 'Ber', BER = 'Ber', BERSERKERS = 'Ber',
}

-- Abbreviation -> our full class name (only the 12 that have PoK spell
-- vendors; War/Mnk/Rog/Ber just won't match anything, which is correct).
local ABBR_TO_FULLNAME = {
    Clr = 'Cleric', Brd = 'Bard', Enc = 'Enchanter', Wiz = 'Wizard',
    SK = 'Shadowknight', Nec = 'Necromancer', Shm = 'Shaman', Dru = 'Druid',
    Mag = 'Magician', Rng = 'Ranger', Pal = 'Paladin', Bst = 'Beastlord',
}

local function parseClassLine(text)
    if not text or type(text) ~= 'string' or text == '' or text == 'NULL' then return nil end
    local cleaned = text:gsub('^%s*%d+[%s%.:]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if cleaned == '' then return nil end
    local up = cleaned:upper()
    if up:find('^LEVEL') or up:find('^LVL') then return nil end
    local noSpaces = up:gsub('[%s_%-]+', '')
    if MQSHORT[noSpaces] then return MQSHORT[noSpaces] end
    for word in cleaned:gmatch('%a+') do
        local wup = word:upper()
        if MQSHORT[wup] then return MQSHORT[wup] end
    end
    return nil
end

local function addFound(found, norm)
    if not norm then return end
    for _, existing in ipairs(found) do
        if existing == norm then return end
    end
    found[#found + 1] = norm
end

local function scanOneNode(node, found)
    if not node or not node() then return end
    pcall(function()
        local items = node.Items()
        if items and items > 0 then
            for i = 1, items do
                local ok, text = pcall(function() return node.List(i)() end)
                if ok and text and text ~= '' and text ~= 'NULL' then
                    addFound(found, parseClassLine(text))
                end
            end
        end
    end)
    pcall(function()
        local text = node.Text()
        if text and text ~= '' and text ~= 'NULL' then
            for line in text:gmatch('[^\r\n]+') do
                addFound(found, parseClassLine(line))
            end
        end
    end)
end

local function walkChildTree(parentNode, found, depth)
    if not parentNode or not parentNode() then return end
    depth = depth or 0
    if depth > 15 then return end
    local okChild, child = pcall(function() return parentNode.FirstChild end)
    if not okChild or not child or not child() then return end
    local visited = 0
    while child and child() and visited < 200 do
        visited = visited + 1
        scanOneNode(child, found)
        walkChildTree(child, found, depth + 1)
        local okNext, nxt = pcall(function() return child.Next end)
        if not okNext or not nxt or not nxt() then break end
        child = nxt
    end
end

-- Forward declaration: the command logger (sendCmd) is defined with the file
-- logger further down, after the S state table it depends on.
local sendCmd

-- Contains mq.delay() (forces the Inventory window open briefly) -- must be
-- called from the main loop (a yieldable thread), never from inside the
-- ImGui draw() callback. Same crash triune's own comment warns about:
-- "Cannot delay from non-yieldable thread."
local function classesFromInventoryWindow()
    local wasOpen = false
    pcall(function() wasOpen = mq.TLO.Window('InventoryWindow').Open() end)
    if not wasOpen then
        sendCmd('open the Inventory window so its class display can be read for class detection (it was not open)', '/windowstate InventoryWindow open')
        mq.delay(250)
    end

    local found = {}

    pcall(function()
        local invWin = mq.TLO.Window('InventoryWindow')
        if not invWin or not invWin() then return end
        local abbrChild = invWin.Child('IW_ClassAbbr')
        if abbrChild and abbrChild() then
            local text = abbrChild.Text()
            if text and text ~= '' and text ~= 'NULL' then
                for line in text:gmatch('[^\r\n]+') do
                    addFound(found, parseClassLine(line))
                end
            end
        end
    end)

    if #found == 0 then
        pcall(function()
            local invWin = mq.TLO.Window('InventoryWindow')
            if not invWin or not invWin() then return end
            local clsChild = invWin.Child('IW_Class')
            if clsChild and clsChild() then
                local text = clsChild.Text()
                if text and text ~= '' and text ~= 'NULL' then
                    for line in text:gmatch('[^\r\n]+') do
                        addFound(found, parseClassLine(line))
                    end
                end
            end
        end)
    end

    if #found == 0 then
        pcall(function()
            local invWin = mq.TLO.Window('InventoryWindow')
            if invWin and invWin() then
                walkChildTree(invWin, found, 0)
            end
        end)
    end

    if not wasOpen then
        sendCmd('close the Inventory window again; it was not open before class detection', '/windowstate InventoryWindow close')
    end

    return #found > 0 and found or nil
end

-- Safe to call from the main loop only (see classesFromInventoryWindow).
-- Returns a list of our full class names, or nil if nothing was detected.
local function detectClasses()
    local abbrs = classesFromInventoryWindow()
    if not abbrs then
        local ok, mainClass = pcall(function() return mq.TLO.Me.Class.ShortName() end)
        if ok and mainClass and mainClass ~= '' and mainClass ~= 'NULL' then
            local norm = MQSHORT[mainClass:upper()]
            if norm then abbrs = { norm } end
        end
    end
    if not abbrs then return nil end

    local names = {}
    for _, abbr in ipairs(abbrs) do
        local fullName = ABBR_TO_FULLNAME[abbr]
        if fullName then table.insert(names, fullName) end
    end
    return #names > 0 and names or nil
end

-- ============================================================================
-- State
-- ============================================================================
local STATE = { IDLE = 'Idle', RUNNING = 'Running', STOPPED = 'Stopped', DONE = 'Done' }

-- S.selected[className][tier] = true/false, all unchecked by default -- an
-- explicit opt-in list of who to visit this run, not an opt-out.
local function freshSelection()
    local sel = {}
    for _, className in ipairs(CLASS_ORDER) do
        sel[className] = {}
        for _, tier in ipairs(TIERS) do
            sel[className][tier] = false
        end
    end
    return sel
end

local S = {
    state             = STATE.IDLE,
    stopRequested     = false,
    shoppingSpreeRequested = false,
    bazaarRequested   = false, -- "work the merchant that's already open" (Bazaar)
    reDetectRequested = true, -- start true so it auto-detects once on load
    detectedClasses   = nil, -- nil until first detection runs; then a set { [className] = true }
    selected          = freshSelection(),
    log               = {},
    bought            = 0,
    skipped           = 0,
    purchasedNames    = {},
    skippedNames      = {},
    spentCopper       = 0,
    currentName       = nil,
    currentIndex      = 0,
    lastStopReason    = nil,
    mouseOverOverlay  = false, -- true while the mouse is hovering this window (see draw())
    openedBags        = {}, -- [bagIdx] = true once we've clicked it open this run
    consecutiveNoMoneyMovement = 0, -- see the "not paid" branch in runSpellSpree
    stopOnOutOfMoney = true, -- false = skip unaffordable spells and keep going
}

local MAX_LOG_LINES = 400

-- ============================================================================
-- File logging (decision log D-004; Development Protocol section 8).
-- ----------------------------------------------------------------------------
-- Everything below writes to <MacroQuest logs dir>/spellspree/
-- spellspree_<server>_<character>.log, one line per record:
--   date time | +ms since load | build | LEVEL | message
-- Levels: INFO/WARN/ERROR (what logLine already narrated), CMD (a command sent
-- to the game, with the reason it was sent), OBS (something read from the game
-- or computed that a decision was based on), DEBUG (dbgLine; file always,
-- window only when DEBUG is true).
--
-- A logging failure must never change what the script does: every write is
-- inside pcall, and the first failure turns file logging off and says so once
-- in the window.
-- ============================================================================
local LOG_MAX_BYTES = 4 * 1024 * 1024
local LOG_ROTATE_CHECK_EVERY = 100
local LOG_SYNC_EVERY_MS = 2000
-- identity / identityKey: who the current file was resolved for (D-028). syncing: a sync is running (its own writes must not start another).
-- hold: a run is dispatched, so routing stays pinned to the run's file. heldNoted: identities already noted during this hold.
-- pendingIdentity: the snapshot a sync wants the next path resolution to use. lastSyncMs: when the last sync ran (throttle).
local LOG = { path = nil, dir = nil, disabled = false, writes = 0, resolution = nil, t0 = nil,
    identity = nil, identityKey = nil, syncing = false, hold = false, heldNoted = nil, pendingIdentity = nil, lastSyncMs = nil, unreadableNoted = false }
local logSyncIdentity -- defined after logLine/logObs (D-028); logWriteFile calls it

local function logClockMs()
    local ok, t = pcall(function() return mq.gettime() end)
    if ok and type(t) == 'number' then return t end
    return math.floor(os.clock() * 1000)
end
LOG.t0 = logClockMs()

-- A TLO read for a log line: tostring of the value, or 'n/a' if it can't be read.
local function tloText(fn)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return tostring(v) end
    return 'n/a'
end

local function logSafePart(s)
    return (tostring(s or 'unknown'):gsub('[^%w_%-]', '_'))
end

-- D-028 C: an identity read is unavailable when it is nil, "n/a" (what tloText returns for a failed read), "NULL" or empty after trimming.
local function logUnavailable(v)
    if v == nil then return true end
    local t = tostring(v):match('^%s*(.-)%s*$')
    return t == '' or t == 'n/a' or t == 'NULL'
end

-- The part of the file name that identifies the character: the sanitized server and character, as the name uses them (D-028 A').
local function logIdentityKeyFor(server, char)
    return logSafePart(server) .. '_' .. logSafePart(char)
end

local function logIsAbsolute(p)
    return p:match('^%a:[/\\]') ~= nil or p:match('^[/\\]') ~= nil
end

local function logEnsureDir(path)
    if path:find('["\r\n]') then return false end
    local native = path:gsub('/', '\\')
    local ok = os.execute('if not exist "' .. native .. '" mkdir "' .. native .. '"')
    return ok == true or ok == 0
end

-- Returns the log file path, or nil plus the reason it can't be had.
-- MacroQuest.Path('logs') is the client's own logs directory (read from MQ
-- source, MQ2MacroQuestType.cpp). Its compiled-in default is the relative
-- string "Logs", so a non-absolute value is joined onto Path('root'). What the
-- live client actually returns is recorded in LOG.resolution and logged at
-- startup, so the first live log answers it.
local function logResolvePath()
    local logsRaw, rootRaw
    pcall(function() logsRaw = mq.TLO.MacroQuest.Path('logs')() end)
    pcall(function() rootRaw = mq.TLO.MacroQuest.Path('root')() end)
    -- D-028 B': a sync passes the one reading it made; a first resolution (load) reads once itself
    local snap = LOG.pendingIdentity
    local server = snap and snap.server or tloText(function() return mq.TLO.EverQuest.Server() end)
    local char = snap and snap.char or tloText(function() return mq.TLO.Me.CleanName() end)
    LOG.resolution = string.format("MacroQuest.Path('logs')=%s, MacroQuest.Path('root')=%s, server=%s, character=%s",
        tostring(logsRaw), tostring(rootRaw), server, char)

    local base = (type(logsRaw) == 'string' and logsRaw ~= '') and logsRaw or nil
    if not base then return nil, "MacroQuest.Path('logs') unreadable" end
    if not logIsAbsolute(base) then
        if type(rootRaw) ~= 'string' or rootRaw == '' then
            return nil, 'logs path is relative (' .. base .. ") and MacroQuest.Path('root') is unreadable"
        end
        base = rootRaw:gsub('[/\\]+$', '') .. '/' .. base
    end
    local dir = base:gsub('[/\\]+$', '') .. '/spellspree'
    if not logEnsureDir(dir) then return nil, 'could not create ' .. dir end
    LOG.dir = dir
    LOG.identity = { server = server, char = char }
    LOG.identityKey = logIdentityKeyFor(server, char)
    LOG.pendingIdentity = nil
    return dir .. '/spellspree_' .. LOG.identityKey .. '.log'
end

local function logFail(reason)
    if LOG.disabled then return end -- D-028 B': one failure notice, however many failures follow
    LOG.disabled = true
    table.insert(S.log, { text = 'File logging is OFF: ' .. reason .. ' (window log only).', color = COLOR_ERR, t = os.date('%H:%M:%S') })
    print('\ay[SpellSpree]\ax File logging is OFF: ' .. reason)
end

local function logWriteFile(level, text)
    if LOG.disabled then return end
    -- D-028 A': the character may have changed since the last record; the sync is throttled and guarded against re-entry
    logSyncIdentity(false)
    if LOG.disabled then return end
    local ok, err = pcall(function()
        if not LOG.path then
            local path, why = logResolvePath()
            if not path then logFail(why); return end
            LOG.path = path
        end
        LOG.writes = LOG.writes + 1
        if LOG.writes % LOG_ROTATE_CHECK_EVERY == 1 then
            local prev = io.open(LOG.path, 'rb')
            if prev then
                local size = prev:seek('end')
                prev:close()
                if size and size > LOG_MAX_BYTES then
                    os.remove(LOG.path .. '.old')
                    os.rename(LOG.path, LOG.path .. '.old')
                end
            end
        end
        local f = io.open(LOG.path, 'a')
        if not f then logFail('could not open ' .. LOG.path); return end
        f:write(string.format('%s | +%dms | v%s | %-5s | %s\n', os.date('%Y-%m-%d %H:%M:%S'),
            logClockMs() - LOG.t0, VERSION, level, (tostring(text):gsub('[\r\n]+', ' / '))))
        f:close()
    end)
    if not ok then logFail(tostring(err)) end
end

local function logLine(text, color)
    table.insert(S.log, { text = text, color = color or COLOR_INFO, t = os.date('%H:%M:%S') })
    if #S.log > MAX_LOG_LINES then table.remove(S.log, 1) end
    print(string.format('\ay[SpellSpree]\ax %s', text))
    local level = 'INFO'
    if color == COLOR_ERR then level = 'ERROR' elseif color == COLOR_WARN then level = 'WARN' end
    logWriteFile(level, text)
end

-- Diagnostic log line. Always goes to the log file; shows in the window only
-- when DEBUG is on. See the DEBUG flag.
local function dbgLine(text)
    if DEBUG then logLine(text, COLOR_MUTE) else logWriteFile('DEBUG', text) end
end

-- An observation a decision was based on. File only.
local function logObs(text)
    logWriteFile('OBS', text)
end

-- Every command sent to the game goes through here so the log records what was
-- sent and why, BEFORE it is sent (so a hang or crash still leaves the record).
-- mq.cmdf is string.format followed by the same execute path as mq.cmd (MQ
-- source, lua_MQBindings.cpp command_format), so formatting here and calling
-- mq.cmd is equivalent. MQ gives no return value for these commands; success is
-- only ever inferred from state read afterward.
sendCmd = function(reason, fmt, ...)
    local cmd = fmt
    if select('#', ...) > 0 then cmd = string.format(fmt, ...) end
    logWriteFile('CMD', string.format('%s   [reason: %s]', cmd, reason))
    mq.cmd(cmd)
end

local function errHandler(e)
    if debug and debug.traceback then return debug.traceback(tostring(e), 2) end
    return tostring(e)
end

-- NOTE: earlier versions of this script tried to verify purchases/scribes by
-- watching for specific chat lines via mq.event ("You give X to Y.", "You
-- have finished scribing X."). In testing, NEITHER ever fired even once,
-- while both actions genuinely succeeded in-game -- meaning the event
-- pattern-matching itself isn't working reliably in this setup, not that
-- timing was off. Switched to verifying against TLO reads instead (money on
-- hand, bag contents) -- the same kind of check already used everywhere else
-- in this script and never once unreliable across all this testing.

-- ============================================================================
-- Small helpers
-- ============================================================================
local function merchantOpen()
    local ok, isOpen = pcall(function() return mq.TLO.Window('MerchantWnd').Open() end)
    return ok and isOpen and true or false
end

local function zoneShort()
    local ok, shortName = pcall(function() return mq.TLO.Zone.ShortName() end)
    if not ok or shortName == nil then return '' end
    return tostring(shortName):lower()
end

-- The observations a reviewer needs at the top of a log file (P-1): written at load, and again at the top of a file that a character
-- switch starts or continues (D-028 B). The text of the load version is what the earlier builds wrote.
local function logSessionHeader(continued, server, char)
    local source = tloText(function() return debug.getinfo(1, 'S').source end)
    if continued then
        logObs(string.format('session start (continued session): build=v%s source=%s load offset=+%dms', VERSION, source, logClockMs() - LOG.t0))
    else
        logObs(string.format('session start: build=v%s source=%s', VERSION, source))
    end
    logObs('log path resolution: ' .. tostring(LOG.resolution))
    logObs('log file: ' .. tostring(LOG.path))
    logObs(string.format('environment at %s: zone=%s character=%s server=%s class=%s merchantOpen=%s', continued and 'switch' or 'load',
        zoneShort(), char or tloText(function() return mq.TLO.Me.CleanName() end), server or tloText(function() return mq.TLO.EverQuest.Server() end),
        tloText(function() return mq.TLO.Me.Class.ShortName() end), tostring(merchantOpen())))
    logObs('known limits: MacroQuest returns nothing from /notify, /itemnotify, /target, /click or /nav. Each CMD line records what was sent and why; whether it worked is only inferred from the OBS lines that read game state afterward. A CMD followed by unchanged state means no effect was observed, not that the command was proven ignored.')
end

-- D-028: the log file follows the character that is playing. Reads the server and character ONCE and uses that one snapshot for everything
-- below. Unforced calls act at most once per LOG_SYNC_EVERY_MS; while a run holds the file (LOG.hold) it only notes a difference.
-- Raw identity unchanged: nothing. Raw differs but the same file: a record and a header in that file. Different file: a record in the old
-- file, then the new file starts with a header and a notice. Everything is written through logWriteFile (its own pcall; a failure turns
-- file logging off); the whole sync is inside a pcall and LOG.syncing is cleared after it, so it can never raise into a run.
logSyncIdentity = function(force)
    if LOG.syncing or LOG.disabled or not LOG.path then return end
    local now = logClockMs()
    if not force and LOG.lastSyncMs and (now - LOG.lastSyncMs) < LOG_SYNC_EVERY_MS then return end
    LOG.lastSyncMs = now
    LOG.syncing = true
    local ok, err = pcall(function()
        local server = tloText(function() return mq.TLO.EverQuest.Server() end)
        local char = tloText(function() return mq.TLO.Me.CleanName() end)
        if logUnavailable(server) or logUnavailable(char) then
            if not LOG.unreadableNoted then
                LOG.unreadableNoted = true
                logObs(string.format('identity unreadable (server=%s character=%s): keeping the current log file.', server, char))
            end
            return
        end
        LOG.unreadableNoted = false
        local old = LOG.identity
        if old and old.server == server and old.char == char then return end
        if LOG.hold then
            local id = server .. '/' .. char
            LOG.heldNoted = LOG.heldNoted or {}
            if not LOG.heldNoted[id] then
                LOG.heldNoted[id] = true
                logObs(string.format('identity differs during a run: observed %s, the run started as %s/%s; records stay in %s until the run ends.',
                    id, tostring(old and old.server), tostring(old and old.char), tostring(LOG.path)))
            end
            return
        end
        local key = logIdentityKeyFor(server, char)
        local sameFile = (key == LOG.identityKey)
        logObs(string.format('identity changed: %s/%s -> %s/%s; %s', tostring(old and old.server), tostring(old and old.char), server, char,
            sameFile and ('continuing in ' .. tostring(LOG.path)) or ('continuing in a new file for ' .. key)))
        if LOG.disabled then return end
        LOG.identity = { server = server, char = char }
        if not sameFile then
            LOG.pendingIdentity = { server = server, char = char }
            LOG.path, LOG.identityKey, LOG.writes = nil, nil, 0
        end
        logSessionHeader(true, server, char)
        if not LOG.disabled and not sameFile then
            logLine(string.format('Logging to a new file for %s: %s', char, tostring(LOG.path)), COLOR_INFO)
        end
    end)
    LOG.syncing = false
    if not ok then logFail('identity sync failed: ' .. tostring(err)) end
end

-- Plane of Knowledge's zone short name is "poknowledge" -- standard,
-- long-established EQ zone naming, not something specific to this server.
local function inPoK()
    return zoneShort() == 'poknowledge'
end

-- The Bazaar carries 1-50 spells and is the alternative when PoK is out of
-- reach. It gets a completely different treatment: there is no navmesh for
-- it, so nothing here paths anywhere or picks a vendor by name. You walk to
-- the merchant yourself, open the window yourself, and this just works the
-- list that is already in front of it.
local function inBazaar()
    return zoneShort() == 'bazaar'
end

local function myTotalCopper()
    local pp, gp, sp, cp = 0, 0, 0, 0
    pcall(function() pp = mq.TLO.Me.Platinum() or 0 end)
    pcall(function() gp = mq.TLO.Me.Gold() or 0 end)
    pcall(function() sp = mq.TLO.Me.Silver() or 0 end)
    pcall(function() cp = mq.TLO.Me.Copper() or 0 end)
    return pp * 1000 + gp * 100 + sp * 10 + cp
end

-- ============================================================================
-- Vendor price quotes -- UNVERIFIED, best-effort, not the primary defense.
-- ----------------------------------------------------------------------------
-- Item.Price() is confirmed unreliable (always reads 0, see isSpellItem's own
-- comment). This script's own earlier comment also mentions the vendor's tell
-- price quotes as something already seen in this environment ("That'll be
-- ... per Spell: Chaos Flux.") -- but the exact wording was never pinned
-- down, and this codebase has already hit chat events that silently never
-- fired even once during testing (see the note above logLine). So this is
-- built to fail SAFELY: if the quote never arrives, or the wording doesn't
-- match, nothing breaks -- the purchase just proceeds exactly as it did
-- before, falling back to the existing attempt-and-check-money-movement
-- logic, still backed by the "two in a row" stop. This can only ever make
-- things MORE informed, never less safe.
--
-- Confirmed against real chat log output: EVERY item selected in the
-- merchant window gets an automatic price tell, not just spells -- and,
-- importantly, the vendor uses BOTH wordings ("That'll be X per Y." AND
-- "That'll be X for Y.") depending on the item, not consistently one or the
-- other. Keyed by item name rather than one single slot for the most
-- recently seen quote -- with every item triggering a tell as it's merely
-- selected while scanning the list, a single slot got overwritten by
-- whatever was selected most recently by the time a purchase was actually
-- attempted several items later, which is why a quote that WAS captured
-- correctly still weren't being used for the right item at decision time.
-- ============================================================================
local priceQuotes = {} -- [itemName] = { copper = N, at = os.clock() }

-- Sums every "<number> <denomination>" pair found in a chunk of text,
-- whatever combination is actually present ("5 platinum", "3 gold and 2
-- silver", "1pp 4gp", etc.) -- tolerant of the exact phrasing on purpose,
-- since that's the one thing here with no confirmed source at all.
local function parseCopperFromText(text)
    if not text then return nil end
    local total, foundAny = 0, false
    local DENOMS = {
        { pat = '(%d+)%s*[Pp][Ll][Aa][Tt]', mult = 1000 }, { pat = '(%d+)%s*pp', mult = 1000 },
        { pat = '(%d+)%s*[Gg][Oo][Ll][Dd]', mult = 100 },  { pat = '(%d+)%s*gp', mult = 100 },
        { pat = '(%d+)%s*[Ss][Ii][Ll][Vv]', mult = 10 },   { pat = '(%d+)%s*sp', mult = 10 },
        { pat = '(%d+)%s*[Cc][Oo][Pp][Pp]', mult = 1 },    { pat = '(%d+)%s*cp', mult = 1 },
    }
    for _, d in ipairs(DENOMS) do
        local n = text:match(d.pat)
        if n then total = total + tonumber(n) * d.mult; foundAny = true end
    end
    return foundAny and total or nil
end

-- 1000000 -> "1,000,000". Only really matters for platinum, which is the
-- only denomination that gets big enough to need it.
local function withCommas(n)
    n = math.floor(tonumber(n) or 0)
    local sign = ''
    if n < 0 then sign = '-'; n = -n end
    local digits = tostring(n)
    local formatted = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    formatted = formatted:gsub('^,', '')
    return sign .. formatted
end

local function formatCoin(copper)
    copper = math.floor((tonumber(copper) or 0) + 0.5)
    local pp = math.floor(copper / 1000); copper = copper % 1000
    local gp = math.floor(copper / 100); copper = copper % 100
    local sp = math.floor(copper / 10); copper = copper % 10
    local cp = copper
    local parts = {}
    if pp > 0 then table.insert(parts, withCommas(pp) .. 'pp') end
    if gp > 0 then table.insert(parts, gp .. 'gp') end
    if sp > 0 then table.insert(parts, sp .. 'sp') end
    if cp > 0 or #parts == 0 then table.insert(parts, cp .. 'cp') end
    return table.concat(parts, ' ')
end

-- Plat-only, rounded UP so any leftover gold/silver/copper still shows as at
-- least 1pp instead of disappearing/rounding to 0.
local function formatCoinPPOnly(copper)
    copper = tonumber(copper) or 0
    return withCommas(math.ceil(copper / 1000)) .. 'pp'
end

local function bagItemCount(n)
    local ok, cnt = pcall(function() return mq.TLO.Me.Inventory('pack' .. n)() and mq.TLO.Me.Inventory('pack' .. n).Container() or 0 end)
    if ok and cnt then return cnt end
    return 0
end

local function bagSlotItem(bagIdx, slotIdx)
    local ok, it = pcall(function() return mq.TLO.Me.Inventory('pack' .. bagIdx).Item(slotIdx) end)
    if not ok or not it or not it() then return nil end
    return it
end

-- Reads a general inventory slot's own item, when nothing is nested inside a
-- bag there -- i.e. whatever a purchase landed as a loose item directly in
-- that slot, not inside a container. Distinct from bagSlotItem above, which
-- only ever looks INSIDE a bag.
local function topLevelSlotItem(bagIdx)
    local ok, it = pcall(function() return mq.TLO.Me.Inventory('pack' .. bagIdx) end)
    if not ok or not it or not it() then return nil end
    return it
end

-- Reads whatever landed at a firstFreeInventorySlot() result, whichever kind
-- of slot it turned out to be -- see the slotIdx == 0 sentinel note there.
local function readTargetSlot(bagIdx, slotIdx)
    if slotIdx == 0 then return topLevelSlotItem(bagIdx) end
    return bagSlotItem(bagIdx, slotIdx)
end

-- Builds the right /itemnotify for interacting with a firstFreeInventorySlot()
-- result -- a sub-slot inside a bag needs "in packN M", a loose top-level
-- item needs a plain click on the slot itself, same as ensureBagOpen's own
-- click on the bag icon.
local function targetSlotNotifyCmd(bagIdx, slotIdx)
    if slotIdx == 0 then
        return string.format('/itemnotify pack%d rightmouseup', bagIdx)
    end
    return string.format('/itemnotify in pack%d %d rightmouseup', bagIdx, slotIdx)
end

-- Human-readable form of a firstFreeInventorySlot() result, for log lines.
-- slotIdx 0 means the general inventory slot itself, with nothing equipped
-- there -- not a bag, so it isn't called one.
local function slotLabel(bagIdx, slotIdx)
    if slotIdx == 0 then
        return string.format('main inventory slot %d', bagIdx)
    end
    return string.format('bag %d/slot %d', bagIdx, slotIdx)
end

-- Name of whatever's on the cursor right now, or nil if the cursor is empty.
-- Nothing this script does should ever leave an item on the cursor -- every
-- action here is a click on something already sitting in a bag slot or the
-- merchant window, never a pick-up. If something IS there, that means some
-- action didn't complete the way it was supposed to, and continuing on
-- autopilot risks dropping, destroying, or misplacing it.
local function cursorItemName()
    local ok, has = pcall(function() return mq.TLO.Cursor() ~= nil end)
    if not ok or not has then return nil end
    local name = 'something'
    pcall(function() name = mq.TLO.Cursor.Name() or name end)
    return name
end

-- Interacting with an item INSIDE a bag (via "/itemnotify in packN M ...")
-- apparently requires that bag's own container window to actually be open on
-- screen -- confirmed in testing, it silently doesn't work otherwise.
-- Right-clicking the bag icon itself ("/itemnotify packN rightmouseup") is
-- what actually opens it -- confirmed via live testing (left-click didn't do
-- it). That click TOGGLES, so it is only ever safe to send when the bag is
-- known to be closed -- sending it at a bag that's already open closes it,
-- which is the one thing everything downstream can't survive.
--
-- Whether a bag's window is open right now, as opposed to "did this script
-- click it open at some point." S.openedBags only ever tracked the latter,
-- and the gap between the two is what caused the stall: a bag the user (or
-- the client) had open already got toggled SHUT by the first ensureBagOpen
-- that reached it, and the blind re-open in the recovery paths could just as
-- easily close a bag as open one. Returns true, false, or nil when the
-- client won't say either way -- nil keeps the old once-per-session
-- bookkeeping as the fallback, since a guess is all that's left at that
-- point.
local function bagOpenState(bagIdx)
    local state = nil
    pcall(function()
        local it = mq.TLO.Me.Inventory('pack' .. bagIdx)
        if it and it() then
            local v = it.Open()
            if type(v) == 'boolean' then
                state = v
            elseif type(v) == 'number' then
                state = (v ~= 0)
            end
        end
    end)
    return state
end

-- Sends the toggle only when the bag is actually closed. Returns true if a
-- click was sent. Safe to call as often as needed -- unlike the old
-- once-per-session guard, this can re-open a bag that got closed later in
-- the run without ever risking closing one that's already open.
local function openBagIfClosed(bagIdx)
    local st = bagOpenState(bagIdx)
    if st == true then return false end
    sendCmd(string.format('open bag %d: bagOpenState=%s (not open); the click toggles, so it is only sent when not open', bagIdx, tostring(st)),
        '/itemnotify pack%d rightmouseup', bagIdx)
    -- Widened from 200ms -- on a slower connection, the window opening and
    -- its contents actually becoming readable through the TLO can take
    -- longer than 200ms to round-trip; better to spend an extra moment than
    -- read a bag before it's actually settled.
    mq.delay(400)
    return true
end

local function ensureBagOpen(bagIdx)
    local open = bagOpenState(bagIdx)
    if open == true then
        -- Already open, by whatever means. Record it so the nil-state
        -- fallback below doesn't go clicking at it later.
        S.openedBags[bagIdx] = true
        return
    end
    -- State unreadable: nothing to do but fall back to the old "click each
    -- bag at most once per session" rule.
    if open == nil and S.openedBags[bagIdx] then return end
    sendCmd(string.format('open bag %d: bagOpenState=%s (%s)', bagIdx, tostring(open),
        open == nil and 'unreadable, so using the once-per-session rule' or 'not open'),
        '/itemnotify pack%d rightmouseup', bagIdx)
    mq.delay(400)
    S.openedBags[bagIdx] = true
end

-- How many general inventory slots this character actually HAS. Not always
-- 12 -- it depends on the client/expansion, and 8 and 10 are both common.
-- That distinction mattered far more than it looks: the TLO returns nil for
-- a slot that is merely EMPTY and also nil for a slot that DOESN'T EXIST, so
-- the hardcoded 1..12 scan below used to treat the non-existent packs past
-- the real end of inventory as "a free top-level slot" and hand one back as
-- the landing target for the next purchase. Every purchase then went through
-- for real, landed somewhere real, and failed to read back from a slot that
-- can never hold anything -- which is exactly what produced "didn't buy for
-- some reason" on items the vendor's own tells confirm were bought and paid
-- for. Me.NumBagSlots is the authoritative count; the fallback only applies
-- if it can't be read at all, and the landing-check sweep further down is
-- what covers a wrong guess either way.
local function generalSlotCount()
    local n = nil
    pcall(function() n = tonumber(mq.TLO.Me.NumBagSlots()) end)
    if not n or n < 1 then n = 10 end
    if n > 12 then n = 12 end
    return n
end

-- Finds the first genuinely open slot anywhere in general inventory -- lowest
-- bag, lowest slot within that bag, checked in the same pack1-slot1,
-- pack1-slot2, ..., pack2-slot1, ... order the client fills new items into.
-- No moving things around, no forcing anything into a specific pre-cleared
-- slot -- just find wherever the next purchase will actually land, and use
-- that. Returns bagIdx, slotIdx, or nil, nil if there's nowhere free at all.
--
-- Opens each bag before trusting a read from it, same as the comment above
-- ensureBagOpen already established for interacting with an item inside one
-- -- that finding was never actually applied here, which is the real bug
-- behind two separate symptoms that looked unrelated: a bag that has never
-- been opened can read as having free space when it does not (letting a
-- purchase go through with nowhere for it to actually land, however that
-- then manifests), and the post-purchase landing check re-reads that exact
-- same unreliable data, which is how a purchase that genuinely succeeded
-- still got reported as "didn't buy."
--
-- Priority confirmed directly by in-game testing: an empty TOP-LEVEL general
-- inventory slot is filled before the client ever puts a new item inside a
-- bag, full stop -- not "whichever comes first while scanning slot by
-- slot." An earlier version of this got that order wrong: it checked each
-- general inventory slot in turn and, the moment one held a bag with room,
-- used a slot inside THAT bag right away -- so an empty top-level slot
-- sitting a couple of positions further along never even got considered if
-- an earlier slot happened to hold a bag with space. That is backwards from
-- how the client actually behaves: any bare open slot wins over any amount
-- of room inside any bag, regardless of which one comes first in slot order.
-- Two full passes fixes that -- every top-level slot is checked for being
-- completely empty before bag contents are looked at at all, and bags are
-- only ever considered once every single top-level slot is confirmed
-- occupied by something. slotIdx 0 is the sentinel for "the top-level slot
-- itself, not a sub-slot inside a bag there" -- real in-bag indices always
-- start at 1, so 0 can never collide with one.
local function firstFreeInventorySlot()
    -- Pass 1: any completely empty top-level slot at all, lowest index wins.
    -- This alone decides the answer whenever one exists -- pass 2 below is
    -- never reached in that case.
    for bagIdx = 1, generalSlotCount() do
        local slotItem = nil
        pcall(function() slotItem = mq.TLO.Me.Inventory('pack' .. bagIdx) end)
        if not (slotItem and slotItem() ~= nil) then
            return bagIdx, 0
        end
    end

    -- Pass 2: only reached once every top-level slot is confirmed occupied
    -- by something (a bag or a loose item) -- now, and only now, look inside
    -- bags for room, in the same pack1-slot1, pack1-slot2, ..., order.
    for bagIdx = 1, generalSlotCount() do
        local slotItem = nil
        pcall(function() slotItem = mq.TLO.Me.Inventory('pack' .. bagIdx) end)
        if slotItem and slotItem() ~= nil then
            local containerSize = 0
            pcall(function() containerSize = tonumber(slotItem.Container()) or 0 end)
            if containerSize > 0 then
                ensureBagOpen(bagIdx)
                local size = bagItemCount(bagIdx)
                if size <= 0 then size = containerSize end
                for slot = 1, size do
                    if not bagSlotItem(bagIdx, slot) then
                        return bagIdx, slot
                    end
                end
            end
            -- else: a loose, non-container item occupies this slot outright
            -- -- nothing to look inside.
        end
    end
    return nil, nil
end

-- ============================================================================
-- "Usable items only" filter. Confirmed straight from this UI's own
-- EQUI_MerchantWnd.xml: it's a <Button item="MW_UsableButton"> with
-- Style_Checkbox=true (paired with a <Label item="MW_UsableLabel"> reading
-- "Show only items I can use") -- NOT a separate Checkbox-type element,
-- which is why the earlier name guesses never matched anything at all.
-- MW_UsableButton is tried first; the rest stay as fallbacks in case a
-- different UI skin names it something else.
-- ============================================================================
local USABLE_FILTER_CANDIDATES = {
    'MW_UsableButton',
    'MW_UsableOnlyCheckbox', 'MW_UseableOnlyCheckbox', 'MW_ItemFilterCheckbox',
    'MW_CanUseCheckbox', 'MW_CanUseCheckBox', 'MW_UsableCheckBox',
    'MW_FilterCheckbox', 'MW_Filter_Checkbox',
}

local function verifyUsableFilterOn()
    for _, name in ipairs(USABLE_FILTER_CANDIDATES) do
        local ok, exists = pcall(function() return mq.TLO.Window('MerchantWnd').Child(name)() ~= nil end)
        if ok and exists then
            local function isChecked()
                local checked = false
                pcall(function() checked = mq.TLO.Window('MerchantWnd').Child(name).Checked() end)
                return checked
            end

            if isChecked() then
                logLine('"Usable items only" filter is on.', COLOR_MUTE)
                return true
            end

            -- Still worth trying to click it automatically, then verify
            -- instead of assuming -- but this is now a hard requirement, not
            -- a warning: if it's not confirmed on, the run does not start.
            for attempt = 1, 2 do
                sendCmd(string.format('turn on the usable-items-only checkbox %s (attempt %d/2; Checked() read false)', name, attempt),
                    '/notify MerchantWnd %s leftmouseup', name)
                mq.delay(300)
                if isChecked() then
                    logLine(string.format('Enabled "usable items only" filter (%s).', name), COLOR_GOOD)
                    return true
                end
            end

            logLine(string.format('"Usable items only" (%s) is NOT checked, and clicking it isn\'t taking. Check that box yourself, then hit Start again -- this run will not start without it.', name), COLOR_ERR)
            return false
        end
    end
    logLine('Could not find a "usable items only" checkbox on this UI at all -- can\'t confirm it\'s on, so this run will not start. If this vendor has that option, check it yourself and hit Start again.', COLOR_ERR)
    return false
end

-- ============================================================================
-- Merchant list helpers
-- ============================================================================
-- Visible merchant rows are authoritative for enumeration. Merchant.Item(N) is
-- intentionally NOT used here: with the merchant's usable-only filter enabled,
-- its indexing can diverge from MerchantWnd -> ItemList, which is the list the
-- user is actually looking at and the one /notify listselect operates on.
local function merchantVisibleRowCount()
    local count = nil
    pcall(function()
        local itemList = mq.TLO.Window('MerchantWnd').Child('ItemList')
        if itemList and itemList() then
            count = tonumber(itemList.Items())
        end
    end)
    return count
end

-- Whatever the merchant window is ACTUALLY showing as selected right now
-- (after a listselect). This is ground truth -- Merchant.Item(N) and the
-- UI's Nth visible row can disagree (seen in testing: selecting index N
-- bought a totally unrelated item, most likely because the "usable items
-- only" filter changes what's visually listed). Every buy decision below is
-- driven off THIS, never off a pre-fetched Item(N) guess.
local function merchantSelectedItem()
    local ok, it = pcall(function() return mq.TLO.Merchant.SelectedItem end)
    if not ok or not it then return nil end
    local existsOk, exists = pcall(function() return it() ~= nil end)
    if not existsOk or not exists then return nil end
    return it
end

local function itemDisplayName(it)
    local name = 'Unknown'
    pcall(function() name = it.Name() or name end)
    return name
end


-- Searches every general inventory slot and bag for an existing item with
-- this exact name, returning its location and current stack count. Used only
-- to recognize a purchase that stacked onto an existing copy instead of
-- landing in a new slot -- confirmed happening in testing (spell scrolls
-- stack on this server). Doesn't open any bags itself; a stale read from a
-- bag that's never been opened just means this search misses a copy sitting
-- in there, which only costs this best-effort detection, not anything that
-- gates a purchase.
local function findExistingCopy(name)
    for bagIdx = 1, generalSlotCount() do
        local slotItem = nil
        pcall(function() slotItem = mq.TLO.Me.Inventory('pack' .. bagIdx) end)
        if slotItem and slotItem() then
            local containerSize = 0
            pcall(function() containerSize = tonumber(slotItem.Container()) or 0 end)
            if containerSize > 0 then
                local size = bagItemCount(bagIdx)
                if size <= 0 then size = containerSize end
                for slot = 1, size do
                    local it = bagSlotItem(bagIdx, slot)
                    if it and itemDisplayName(it) == name then
                        local stack = 1
                        pcall(function() stack = tonumber(it.Stack()) or 1 end)
                        return bagIdx, slot, stack
                    end
                end
            elseif itemDisplayName(slotItem) == name then
                local stack = 1
                pcall(function() stack = tonumber(slotItem.Stack()) or 1 end)
                return bagIdx, 0, stack
            end
        end
    end
    return nil, nil, nil
end

-- Finds a copy of this item ANYWHERE in general inventory, skipping one known
-- location (typically the copy that was already sitting there before a
-- purchase, so a pre-existing scroll isn't mistaken for the new one). Opens
-- bags as it goes, since an unopened bag reads as empty.
--
-- This is the safety net for the landing check. Money leaving your pocket
-- already proves the purchase posted, so once that's confirmed the right
-- question is "where did it actually land," not "did it buy." Predicting the
-- destination slot can go wrong for reasons invisible from here, and
-- declaring a confirmed, paid-for purchase a failure is much the worse of
-- the two errors -- it loses the scribe step too, leaving a scroll sitting
-- unscribed in a bag with the log claiming it was never bought.
local function findCopyAnywhere(name, skipBag, skipSlot)
    for bagIdx = 1, generalSlotCount() do
        local slotItem = nil
        pcall(function() slotItem = mq.TLO.Me.Inventory('pack' .. bagIdx) end)
        if slotItem and slotItem() then
            local containerSize = 0
            pcall(function() containerSize = tonumber(slotItem.Container()) or 0 end)
            if containerSize > 0 then
                ensureBagOpen(bagIdx)
                local size = bagItemCount(bagIdx)
                if size <= 0 then size = containerSize end
                for slot = 1, size do
                    if not (skipBag == bagIdx and skipSlot == slot) then
                        local it = bagSlotItem(bagIdx, slot)
                        if it and itemDisplayName(it) == name then
                            return bagIdx, slot
                        end
                    end
                end
            elseif not (skipBag == bagIdx and skipSlot == 0) then
                if itemDisplayName(slotItem) == name then
                    return bagIdx, 0
                end
            end
        end
    end
    return nil, nil
end

-- Vendor-sold scrolls are named by a fixed prefix -- "Spell: <Name>" for
-- every casting class, and "Song: <Name>" for bard songs. Both are visible
-- right in the merchant window and in the vendor's own /tell price quotes
-- ("That'll be ... per Spell: Chaos Flux."). Bard vendors were always in the
-- list, but every one of their items fell through the Spell:-only gate and
-- got tallied as a non-spell, so a bard spree bought nothing.
--
-- This prefix is the ONLY signal used. There used to be a fallback checking
-- Item.Spell.Name(), but that turned out to be flawed by design, not just
-- unreliable: Item.Spell reflects ANY spell effect associated with the item
-- (a worn effect, a proc, a clicky) -- NOT specifically "this is a scroll."
-- That's exactly why an enchanted earring (its enchantment IS a spell
-- effect) and a food item both false-positived through it and got bought
-- (and in the food's case, then got eaten instead of scribed, since the
-- script blindly right-clicked whatever it thought was a scroll).
local SCROLL_PREFIXES = { '^Spell:%s', '^Song:%s' }

-- One place that answers "is this name a scribable scroll", used both by the
-- merchant-list gate and by the post-purchase check on what actually landed
-- in the bag. Kept as one function so those two can never drift apart -- the
-- landed check is the last thing standing between a mis-read item and a
-- blind right-click on it.
local function isScrollName(name)
    if name == nil then return false end
    for _, pat in ipairs(SCROLL_PREFIXES) do
        if name:match(pat) then return true end
    end
    return false
end

local function isSpellItem(it, knownName)
    return isScrollName(knownName or itemDisplayName(it))
end

-- Confirm the quantity window if one pops up after Buy.
--
-- A short retry loop, not one fixed wait then a single check -- the original
-- single-shot version assumed the window would be fully open within exactly
-- 150ms. On a connection with any real latency, the buy click's round trip
-- and the window actually opening can easily take longer than that on their
-- own, meaning the single check could run in the gap before the window ever
-- appears, silently missing a quantity prompt that was still on its way.
local function handleQuantityWindowIfOpen()
    for poll = 1, 5 do -- up to ~750ms
        local ok, isOpen = pcall(function() return mq.TLO.Window('QuantityWnd').Open() end)
        if ok and isOpen then
            logObs(string.format('QuantityWnd open at poll %d/5 -- accepting it.', poll))
            sendCmd('accept the quantity window that opened after Buy', '/notify QuantityWnd QTYW_Accept_Button leftmouseup')
            mq.delay(150)
            return
        end
        mq.delay(150)
    end
    logObs('QuantityWnd did not open within 5 polls (~750ms) after Buy. Not necessarily a problem: whether a single-scroll purchase shows one is not established.')
end

-- Confirm a scribe-confirmation dialog if one pops up (varies by client/UI --
-- best-effort, harmless if it doesn't match anything). Same retry reasoning
-- as handleQuantityWindowIfOpen above, for the same latency-tolerance reason.
local SCRIBE_CONFIRM_CANDIDATES = { 'ConfirmationDialogBox', 'ScribeConfirmWnd' }
local function handleScribeConfirmIfOpen()
    for poll = 1, 5 do -- up to ~750ms
        for _, wname in ipairs(SCRIBE_CONFIRM_CANDIDATES) do
            local ok, isOpen = pcall(function() return mq.TLO.Window(wname).Open() end)
            if ok and isOpen then
                logObs(string.format('%s open at poll %d/5 -- confirming it.', wname, poll))
                pcall(function() sendCmd(string.format('confirm the scribe dialog %s', wname), '/notify %s CD_Yes_Button leftmouseup', wname) end)
                mq.delay(150)
                return
            end
        end
        mq.delay(150)
    end
    logObs('No scribe-confirmation window (ConfirmationDialogBox/ScribeConfirmWnd) seen within 5 polls (~750ms). Not necessarily a problem: whether this client shows one is not established.')
end

-- The very first scribe click can silently fail to register if the mouse is
-- still hovering this window when it fires -- the MQ2 overlay appears to
-- swallow it before it reaches the game. Rather than let that happen quietly,
-- pause here and tell the user to move their mouse into the game world, then
-- wait until it's actually clear before proceeding. Loops (not a fixed
-- delay) since this depends entirely on the user, not on timing. Always
-- prints immediately on entry (no shared/module-level throttle that could
-- carry over from an earlier call and suppress this one), then reminds every
-- few seconds if it's still waiting.
-- Capped rather than truly unbounded. The previous version only ever exited
-- on the flag clearing or Stop being pressed -- fine if the user is actually
-- watching, but if this fires during an unattended multi-vendor run and the
-- mouse just happens to be sitting over the window (parked there, AFK,
-- whatever), there was nothing to ever break out of this on its own. That
-- silent, indefinite wait is the most likely explanation for "locks up the
-- lua, have to kill it with /lua stop" -- the script wasn't actually stuck,
-- it was correctly waiting for an input that was never going to come.
local MOUSE_OVERLAY_WAIT_TIMEOUT = 60
local function waitForMouseOffOverlay()
    if not S.mouseOverOverlay then return end
    logLine('Mouse is over the SpellSpree window -- move it into the game world so the click actually registers.', COLOR_WARN)
    local startedAt = os.clock()
    local lastReminderAt = startedAt
    while S.mouseOverOverlay do
        if S.stopRequested then return end
        if (os.clock() - startedAt) > MOUSE_OVERLAY_WAIT_TIMEOUT then
            logLine(string.format('Waited %ds for the mouse to move -- giving up on that and trying the click anyway.',
                MOUSE_OVERLAY_WAIT_TIMEOUT), COLOR_WARN)
            return
        end
        if (os.clock() - lastReminderAt) > 5.0 then
            lastReminderAt = os.clock()
            logLine('Still waiting -- move your mouse off the SpellSpree window.', COLOR_WARN)
        end
        mq.delay(100)
    end
    logObs(string.format('mouse left the SpellSpree window after %.1fs of waiting.', os.clock() - startedAt))
end


-- ============================================================================
-- Main run loop -- called from the plain main loop below (NOT from the ImGui
-- callback), so mq.delay() here is safe. Stop button just flips
-- S.stopRequested, checked between every step.
-- ============================================================================
local function closeVendor(reason)
    if merchantOpen() then
        pcall(function() sendCmd(reason or 'close the merchant window', '/notify MerchantWnd MW_Done_Button leftmouseup') end)
    else
        logObs('closeVendor: merchant window already closed; nothing sent.')
    end
end

-- Final outcome of one vendor run, in one line, so a log can be read from its end.
-- S.bought/S.skipped/S.spentCopper accumulate across a whole shopping spree (by
-- design), so the line reports THIS vendor's result (counters now minus the
-- snapshot taken just before the run) and the spree total separately, each
-- labelled. Printing only the accumulated figures read as a per-vendor result
-- (D-009).
local function runCounters()
    return { bought = S.bought, skipped = S.skipped, spent = S.spentCopper }
end

local function logRunOutcome(label, before)
    logLine(string.format('Run outcome (%s): state=%s, reason="%s". This vendor: bought=%d, skipped=%d, spent=%s. Spree total so far: bought=%d, skipped=%d, spent=%s.',
        label, tostring(S.state), tostring(S.lastStopReason),
        S.bought - before.bought, S.skipped - before.skipped, formatCoin(S.spentCopper - before.spent),
        S.bought, S.skipped, formatCoin(S.spentCopper)), COLOR_GOLD)
end

-- ============================================================================
-- List-then-buy (decision log D-017, replacing the repeat-pass scan of D-001).
-- ----------------------------------------------------------------------------
-- The vendor window changes under a row-by-row scan: scribed rows leave the list
-- late and in batches, and rows leave it with nobody acting on them (live logs,
-- D-010 addenda 3-4). So row POSITIONS are never trusted here. When a vendor is
-- open the script:
--   1. waits for the visible usable list to settle (B');
--   2. reads it ONCE into a list of the scroll rows, by name (A');
--   3. for each name, finds that row by EXACT NAME right before clicking it,
--      selects it, and verifies the selected name immediately before Buy (C, H');
--   4. buys and scribes with the existing logic, each name at most once (E);
--   5. records exactly one outcome for every name (F'') and, if the window is
--      still open, does a log-only final scan.
-- No close/reopen, no second pass. Level-range filtering is a later, separate
-- change (D-013, Step 2).
-- ============================================================================
local LIST_COL = { NAME = 2, QTY = 3, PP = 4, GP = 5, SP = 6, CP = 7, LVL = 8 } -- confirmed from the window header (D-012 addendum)
local LIST_POLL_MS       = 250   -- B': untuned starting values (Protocol section 15)
local LIST_STABLE_POLLS  = 8
local LIST_MAX_WAIT_MS   = 15000
local SELECT_ATTEMPTS    = 3     -- H': untuned

-- Text of one cell of the visible merchant list, or nil if unreadable/absent.
local function listCell(r, c)
    local v = nil
    pcall(function() v = mq.TLO.Window('MerchantWnd').Child('ItemList').List(string.format('%d,%d', r, c))() end)
    if v == nil or v == false then return nil end
    return tostring(v)
end

-- Row number (1-based) of the visible row whose name is EXACTLY `name`, or nil. The leading "=" makes the
-- match exact; without it MacroQuest matches substrings (live probe, D-010 addendum 3).
local function rowForName(name)
    local v = nil
    pcall(function()
        v = mq.TLO.Window('MerchantWnd').Child('ItemList').List(string.format('=%s,%d', name, LIST_COL.NAME))()
    end)
    return tonumber(v)
end

local function selectedNameNow()
    local sel = merchantSelectedItem()
    if not sel then return nil end
    return itemDisplayName(sel)
end

-- B'. Returns the settled row count, or nil plus the reason. A stable count is a heuristic, not proof that
-- the list is complete; every poll is logged so the values can be tuned from live runs.
local function waitForListToSettle()
    local startedAt = logClockMs()
    local last, same, polls = nil, 0, 0
    while true do
        mq.doevents()
        if S.stopRequested then return nil, 'Stopped by user' end
        if not merchantOpen() then return nil, 'Merchant closed' end
        local n = merchantVisibleRowCount()
        polls = polls + 1
        if n and n >= 1 and n == last then
            same = same + 1
        elseif n and n >= 1 then
            same = 1
        else
            same = 0
        end
        last = n
        logObs(string.format('list settle poll %d: count=%s, same-count polls in a row=%d/%d, waited %d ms',
            polls, tostring(n), same, LIST_STABLE_POLLS, logClockMs() - startedAt))
        if same >= LIST_STABLE_POLLS then return n end
        if logClockMs() - startedAt >= LIST_MAX_WAIT_MS then
            return nil, 'Vendor list did not settle'
        end
        mq.delay(LIST_POLL_MS)
    end
end

-- A'. Reads the visible list once and keeps the scroll rows, one entry per name (first occurrence).
-- D-025 A', B. The level bounding of a visit. A range is { low, high, label }; it is valid only if both are whole numbers with
-- 1 <= low <= high <= 70, and the same function checks a range wherever one is received, so the two places cannot drift apart.
local RANGE_MIN, RANGE_MAX = 1, 70

local function validateRange(range)
    if type(range) ~= 'table' then return false, 'the range is not a table' end
    local low, high = range.low, range.high
    local function whole(n) return type(n) == 'number' and n == math.floor(n) and n > -math.huge and n < math.huge end
    if not whole(low) or not whole(high) then return false, 'low and high must be whole numbers' end
    if low < RANGE_MIN or high > RANGE_MAX then return false, string.format('the range must lie within %d-%d', RANGE_MIN, RANGE_MAX) end
    if low > high then return false, 'low is above high' end
    return true
end

-- "1-25" -> 1, 25 (the label the checkbox uses); nil and a reason for anything else, including a pair outside 1-70.
local function parseTierRange(label)
    if type(label) ~= 'string' then return nil, 'the tier label is not text' end
    local a, b = label:match('^(%d+)%-(%d+)$')
    if not a then return nil, string.format('"%s" is not two whole numbers joined by "-"', label) end
    local range = { low = tonumber(a), high = tonumber(b) }
    local ok, why = validateRange(range)
    if not ok then return nil, why end
    return range.low, range.high
end

-- The Lvl cell text (raw, as read) against a validated range: 'in', 'outside' or 'unreadable', plus the reason. Only whole numbers are
-- levels (surrounding whitespace is ignored); anything else, or no value, is unreadable. Zero and negatives are outside every range.
local function classifyLevel(levelText, low, high)
    if levelText == nil then return 'unreadable', 'level unreadable (no value)' end
    local trimmed = tostring(levelText):match('^%s*(.-)%s*$')
    if trimmed:match('^%-?%d+$') then
        local n = tonumber(trimmed)
        if n >= low and n <= high then return 'in', '' end
        return 'outside', string.format('outside the selected level range %d-%d (Lvl %s)', low, high, trimmed)
    end
    return 'unreadable', string.format('level unreadable ("%s")', trimmed)
end

local function buildSpellList(rows)
    local entries, byName = {}, {}
    local unreadable, duplicates, nonScroll = 0, {}, 0
    for r = 1, rows do
        local name = listCell(r, LIST_COL.NAME)
        if name == nil then
            unreadable = unreadable + 1
        elseif isScrollName(name) then
            if byName[name] then
                duplicates[#duplicates + 1] = name
                logLine(string.format('[list] "%s" appears more than once (row %d); keeping the first, buying it once.', name, r), COLOR_WARN)
            else
                local function clean(c) return (tostring(listCell(r, c) or '?'):gsub('%s+', '')) end
                local price = string.format('%spp %sgp %ssp %scp', clean(LIST_COL.PP), clean(LIST_COL.GP), clean(LIST_COL.SP), clean(LIST_COL.CP))
                local e = {
                    name = name, index = #entries + 1, row = r, outcome = nil, detail = nil, selectAttempts = 0,
                    levelText = listCell(r, LIST_COL.LVL), qtyText = listCell(r, LIST_COL.QTY), priceText = price,
                }
                entries[#entries + 1] = e
                byName[name] = e
            end
        else
            nonScroll = nonScroll + 1
        end
    end
    return entries, byName, { unreadable = unreadable, duplicates = duplicates, nonScroll = nonScroll }
end

-- F''(a). The six outcomes. Every built-list entry ends with exactly one.
local OUTCOME = {
    SCRIBED       = 'bought and scribed',
    BOUGHT_NO_SCRIBE = 'bought, scribe not completed',
    NOT_BOUGHT    = 'attempted, not bought',
    SKIPPED       = 'deliberately skipped',
    NOT_ATTEMPTED = 'not attempted because the run stopped',
    NONE          = 'NO OUTCOME RECORDED',
}
local OUTCOME_ORDER = { OUTCOME.SCRIBED, OUTCOME.BOUGHT_NO_SCRIBE, OUTCOME.NOT_BOUGHT, OUTCOME.SKIPPED, OUTCOME.NOT_ATTEMPTED, OUTCOME.NONE }

local function setOutcome(entry, outcome, detail)
    if entry.outcome then
        logLine(string.format('LEDGER DEFECT: an outcome was recorded twice for "%s" (kept "%s", ignored "%s").', entry.name, entry.outcome, outcome), COLOR_ERR)
        return
    end
    entry.outcome, entry.detail = outcome, detail
    logObs(string.format('outcome for "%s": %s%s', entry.name, outcome, detail and (' -- ' .. detail) or ''))
end

-- Entries from `fromIndex` on that have no outcome yet were never reached because the run stopped.
local function markRemainingNotAttempted(entries, fromIndex, reason)
    for i = fromIndex, #entries do
        if not entries[i].outcome then setOutcome(entries[i], OUTCOME.NOT_ATTEMPTED, reason) end
    end
end

-- Logs the ledger: counts for every outcome, names for all but the first. An entry with no outcome is a defect.
local function logLedger(entries)
    local groups = {}
    for _, o in ipairs(OUTCOME_ORDER) do groups[o] = {} end
    for _, e in ipairs(entries) do
        if not e.outcome then
            logLine(string.format('LEDGER DEFECT: "%s" ended with no recorded outcome.', e.name), COLOR_ERR)
            e.outcome, e.detail = OUTCOME.NONE, 'no outcome was recorded'
        end
        table.insert(groups[e.outcome], e)
    end
    local parts = {}
    for _, o in ipairs(OUTCOME_ORDER) do parts[#parts + 1] = string.format('%s=%d', o, #groups[o]) end
    logLine(string.format('Outcome ledger (%d built-list entries): %s.', #entries, table.concat(parts, '; ')), COLOR_GOLD)
    for idx, o in ipairs(OUTCOME_ORDER) do
        if idx > 1 and #groups[o] > 0 then
            local names = {}
            for _, e in ipairs(groups[o]) do names[#names + 1] = e.detail and string.format('%s (%s)', e.name, e.detail) or e.name end
            logLine(string.format('  %s (%d): %s', o, #groups[o], table.concat(names, '; ')), o == OUTCOME.NONE and COLOR_ERR or COLOR_WARN)
        end
    end
end

-- F''(b). Log-only. Never buys. Needs the window open.
local function finalScan(entries, byName)
    if not merchantOpen() then
        logObs('final scan skipped: the merchant window is not open.')
        return
    end
    local n = merchantVisibleRowCount()
    if not n then
        logObs('final scan skipped: the visible row count is unreadable.')
        return
    end
    local newScrolls, lingering, other, outOfRange = {}, {}, {}, 0
    for r = 1, n do
        local name = listCell(r, LIST_COL.NAME)
        if name and isScrollName(name) then
            local e = byName[name]
            if not e then
                newScrolls[#newScrolls + 1] = name
            elseif e.outcome == OUTCOME.SCRIBED then
                lingering[#lingering + 1] = name
            elseif e.rangeSkip then
                outOfRange = outOfRange + 1
            else
                other[#other + 1] = string.format('%s (%s)', name, tostring(e.outcome))
            end
        end
    end
    logLine(string.format('Final scan (log only, bought nothing): %d rows read. New scrolls not on the built list: %d%s. Rows still listed for bought-and-scribed entries (expected for about 10 s after a scribe): %d. Rows still listed for entries skipped as outside the level range: %d. Rows still listed for other outcomes: %d%s.',
        n, #newScrolls, #newScrolls > 0 and (' [' .. table.concat(newScrolls, '; ') .. ']') or '', #lingering, outOfRange, #other,
        #other > 0 and (' [' .. table.concat(other, '; ') .. ']') or ''), #newScrolls > 0 and COLOR_WARN or COLOR_INFO)
end

-- C + H'. Looks the row up by exact name NOW, selects it, and checks the selected name. Attempts are counted
-- per entry across the whole visit (3 in total, including the check right before Buy).
-- Returns 'ok', 'gone' (the row is not in the list at lookup: D) or 'unverified' (3 attempts used).
local function selectEntry(entry)
    while entry.selectAttempts < SELECT_ATTEMPTS do
        local row = rowForName(entry.name)
        if not row then
            logObs(string.format('exact-name lookup for "%s" found no row.', entry.name))
            return 'gone'
        end
        entry.selectAttempts = entry.selectAttempts + 1
        sendCmd(string.format('select "%s": exact-name lookup gave row %d (selection attempt %d/%d)', entry.name, row, entry.selectAttempts, SELECT_ATTEMPTS),
            '/notify MerchantWnd ItemList listselect %d', row)
        local selName = nil
        for _ = 1, 12 do -- up to 360 ms, as the old scan did
            mq.delay(30)
            selName = selectedNameNow()
            if selName == entry.name then break end
        end
        logObs(string.format('selection check for "%s": row %d, Merchant.SelectedItem.Name=%s (attempt %d/%d)',
            entry.name, row, tostring(selName), entry.selectAttempts, SELECT_ATTEMPTS))
        if selName == entry.name then return 'ok' end
    end
    return 'unverified'
end

-- Buys and scribes ONE built-list entry with the existing logic. Records its outcome. Returns 'continue', or
-- 'stop' after setting S.state / S.lastStopReason (the caller marks the rest as not attempted).
local function processEntry(entry)
    local name = entry.name
    S.currentName, S.currentIndex = name, entry.index
    logObs(string.format('entry %d "%s": list row at build time %d, Lvl=%s, Qty=%s, price in list=%s (read from the list; gates nothing)',
        entry.index, name, entry.row, tostring(entry.levelText), tostring(entry.qtyText), tostring(entry.priceText)))

    local sel = selectEntry(entry)
    if sel == 'gone' then
        logLine(string.format('"%s" is no longer in the vendor list -- skipping it.', name), COLOR_WARN)
        setOutcome(entry, OUTCOME.SKIPPED, 'row gone at lookup')
        return 'continue'
    elseif sel == 'unverified' then
        logLine(string.format('Could not get "%s" selected after %d attempts -- skipping it.', name, SELECT_ATTEMPTS), COLOR_WARN)
        setOutcome(entry, OUTCOME.NOT_BOUGHT, string.format('selection not verified in %d attempts', SELECT_ATTEMPTS))
        return 'continue'
    end

    -- Proactive: selecting an item triggers the vendor's own price tell (confirmed in live logs). A short
    -- settle wait and an explicit doevents so the tell is processed before it is checked.
    mq.delay(250)
    mq.doevents()
    local q = priceQuotes[name]
    logObs(string.format('price quote for "%s": %s; money on hand %s', name,
        q and formatCoin(q.copper) or 'none received (not proof either way)', formatCoin(myTotalCopper())))
    if q and q.copper > myTotalCopper() then
        if S.stopOnOutOfMoney then
            logLine(string.format('Vendor quoted "%s" at %s -- you have %s. Not enough. Stopping.',
                name, formatCoin(q.copper), formatCoin(myTotalCopper())), COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = string.format('Not enough money for "%s" (quoted %s)', name, formatCoin(q.copper))
            setOutcome(entry, OUTCOME.NOT_ATTEMPTED, S.lastStopReason)
            return 'stop'
        end
        logLine(string.format('Vendor quoted "%s" at %s -- you have %s. Not enough, skipping just this one.',
            name, formatCoin(q.copper), formatCoin(myTotalCopper())), COLOR_WARN)
        S.skipped = S.skipped + 1
        table.insert(S.skippedNames, name)
        setOutcome(entry, OUTCOME.SKIPPED, 'unaffordable by the vendor quote (setting: skip)')
        return 'continue'
    end

    -- Item.Price() is unreliable here (always 0), so the only pre-check is whether there is any money at all.
    if myTotalCopper() <= 0 then
        if S.stopOnOutOfMoney then
            logLine(string.format('Out of money -- can\'t afford "%s". Stopping.', name), COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Out of money'
            setOutcome(entry, OUTCOME.NOT_ATTEMPTED, 'Out of money')
            return 'stop'
        end
        logLine(string.format('Out of money -- can\'t afford "%s". Skipping it and checking the rest.', name), COLOR_WARN)
        S.skipped = S.skipped + 1
        table.insert(S.skippedNames, name)
        setOutcome(entry, OUTCOME.SKIPPED, 'out of money (setting: skip)')
        return 'continue'
    end

    local targetBag, targetSlot = firstFreeInventorySlot()
    if not targetBag then
        logLine('No free inventory space left -- stopping.', COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Inventory full'
        setOutcome(entry, OUTCOME.NOT_ATTEMPTED, 'Inventory full')
        return 'stop'
    end
    logObs(string.format('expected landing slot for "%s": %s', name, slotLabel(targetBag, targetSlot)))
    waitForMouseOffOverlay()
    -- Nothing to open when the target is an empty top-level slot itself (slotIdx == 0).
    if targetSlot ~= 0 then ensureBagOpen(targetBag) end

    -- Baseline for stack-detection below -- see findExistingCopy.
    local existingBag, existingSlot, existingStackBefore = findExistingCopy(name)
    logObs(string.format('pre-buy existing copy of "%s": %s', name,
        existingBag and string.format('%s, stack %s', slotLabel(existingBag, existingSlot), tostring(existingStackBefore)) or 'none found'))

    -- H': verify the selection IMMEDIATELY before Buy. The waits and bag handling above take hundreds of
    -- milliseconds to over a second, and the list can shift in that time. A mismatch re-selects (counting
    -- toward the 3 attempts); the Buy click itself is never retried.
    if selectedNameNow() ~= name then
        logLine(string.format('The selection is no longer "%s" just before Buy (it reads "%s") -- selecting it again.', name, tostring(selectedNameNow())), COLOR_WARN)
        local again = selectEntry(entry)
        if again == 'gone' then
            logLine(string.format('"%s" left the vendor list before Buy -- skipping it.', name), COLOR_WARN)
            setOutcome(entry, OUTCOME.SKIPPED, 'row gone before Buy')
            return 'continue'
        elseif again ~= 'ok' then
            logLine(string.format('Could not get "%s" selected before Buy within %d attempts -- skipping it.', name, SELECT_ATTEMPTS), COLOR_WARN)
            setOutcome(entry, OUTCOME.NOT_BOUGHT, string.format('selection not verified in %d attempts (before Buy)', SELECT_ATTEMPTS))
            return 'continue'
        end
    end

    logLine(string.format('Buying "%s"...', name), COLOR_INFO)
    local copperBeforeBuy = myTotalCopper()
    sendCmd(string.format('buy the selected item "%s" (selection verified as this item just before; money before %s)', name, formatCoin(copperBeforeBuy)),
        '/notify MerchantWnd MW_Buy_Button leftmouseup')
    handleQuantityWindowIfOpen()

    -- Wait for money on hand to actually drop -- the TLO-based confirmation that the transaction posted.
    local paid = false
    local paidPolls = 0
    for _ = 1, 15 do -- up to ~3s
        paidPolls = paidPolls + 1
        if myTotalCopper() < copperBeforeBuy then
            paid = true
            break
        end
        mq.delay(200)
        mq.doevents()
    end
    logObs(string.format('money check after buying "%s": before=%s now=%s paid=%s (polls=%d/15)',
        name, formatCoin(copperBeforeBuy), formatCoin(myTotalCopper()), tostring(paid), paidPolls))
    if not paid then
        -- The quote may have arrived late; if so it gives a definitive answer.
        local q2 = priceQuotes[name]
        if q2 and q2.copper > myTotalCopper() then
            logLine(string.format('Vendor quoted "%s" at %s -- you have %s. Not enough, skipping just this one.',
                name, formatCoin(q2.copper), formatCoin(myTotalCopper())), COLOR_WARN)
            S.skipped = S.skipped + 1
            table.insert(S.skippedNames, name)
            setOutcome(entry, OUTCOME.NOT_BOUGHT, 'no payment observed; the vendor quote exceeds the money on hand')
            return 'continue'
        end

        -- Two misses in a row is a strong signal of being out of money for this vendor's price range.
        S.consecutiveNoMoneyMovement = S.consecutiveNoMoneyMovement + 1
        if S.consecutiveNoMoneyMovement >= 2 then
            if S.stopOnOutOfMoney then
                logLine(string.format('Money on hand hasn\'t moved for two purchases in a row (now "%s") -- most likely out of money for this vendor. Stopping here rather than guessing at every remaining item.', name), COLOR_ERR)
                S.state = STATE.STOPPED
                S.lastStopReason = string.format('Probably not enough money (stopped at "%s")', name)
                setOutcome(entry, OUTCOME.NOT_BOUGHT, 'no payment observed (second in a row)')
                return 'stop'
            end
            logLine(string.format('Money on hand hasn\'t moved for two purchases in a row (now "%s") -- most likely out of money for this vendor. "Stop when out of money" is off, so skipping and checking the rest anyway.', name), COLOR_WARN)
            S.skipped = S.skipped + 1
            table.insert(S.skippedNames, name)
            setOutcome(entry, OUTCOME.NOT_BOUGHT, 'no payment observed (second in a row)')
            return 'continue'
        end

        logLine(string.format('Money on hand didn\'t move for "%s" -- most likely not enough coin for it (no vendor quote to confirm it outright, so not stopping the whole vendor over one miss). Skipping it.', name), COLOR_WARN)
        S.skipped = S.skipped + 1
        table.insert(S.skippedNames, name)
        setOutcome(entry, OUTCOME.NOT_BOUGHT, 'no payment observed')
        return 'continue'
    else
        S.consecutiveNoMoneyMovement = 0
    end

    -- Verify it landed where expected (retried up to ~3s: the slot can lag the purchase).
    local landed, landedOk = nil, false
    local landPolls = 0
    for _ = 1, 15 do -- up to ~3s
        landPolls = landPolls + 1
        landed = readTargetSlot(targetBag, targetSlot)
        if landed then landedOk = true; break end
        mq.delay(200)
    end
    logObs(string.format('landing read of %s for "%s": %s (polls=%d/15)', slotLabel(targetBag, targetSlot), name,
        landed and ('found "' .. itemDisplayName(landed) .. '"') or 'nothing readable there', landPolls))
    if landed then
        local landedName = itemDisplayName(landed)
        if landedName ~= name then
            logLine(string.format('Something landed in %s ("%s") but the name doesn\'t match "%s" -- proceeding anyway.', slotLabel(targetBag, targetSlot), landedName, name), COLOR_WARN)
        end
    end

    if not landedOk and targetSlot ~= 0 then
        -- One recovery attempt: a closed bag reads as empty, which looks like a failed purchase.
        if openBagIfClosed(targetBag) then
            logLine(string.format('"%s" isn\'t reading back from bag %d/slot %d and that bag reads as closed -- re-opening it before giving up.', name, targetBag, targetSlot), COLOR_WARN)
        else
            logLine(string.format('"%s" isn\'t reading back from bag %d/slot %d, but that bag is already open -- giving it one more read rather than toggling it shut.', name, targetBag, targetSlot), COLOR_WARN)
            mq.delay(400)
        end
        landed = readTargetSlot(targetBag, targetSlot)
        if landed then
            landedOk = true
            logLine(string.format('"%s" showed up after re-opening the bag -- it did buy, just wasn\'t readable at the time.', name), COLOR_GOOD)
        end
    end

    -- The money already left, so the purchase posted: sweep the inventory for the scroll and retarget.
    if not landedOk then
        local foundBag, foundSlot = findCopyAnywhere(name, existingBag, existingSlot)
        if foundBag then
            landed = readTargetSlot(foundBag, foundSlot)
            if landed then
                targetBag, targetSlot = foundBag, foundSlot
                landedOk = true
                logLine(string.format('"%s" didn\'t land in the slot it was expected in -- found it in %s instead. It did buy.', name, slotLabel(targetBag, targetSlot)), COLOR_GOOD)
            end
        end
    end

    -- A purchase that stacks onto an EXISTING copy looks like "didn't land" too (confirmed to happen here).
    local stackedInstead = false
    if not landedOk and existingBag then
        local nowBag, nowSlot, nowStack = findExistingCopy(name)
        if nowBag and nowStack and existingStackBefore and nowStack > existingStackBefore then
            landedOk = true
            stackedInstead = true
            S.bought = S.bought + 1
            table.insert(S.purchasedNames, name)
            local actualSpent = math.max(0, copperBeforeBuy - myTotalCopper())
            S.spentCopper = S.spentCopper + actualSpent
            logLine(string.format('"%s" stacked onto an existing copy (now %d) instead of landing in a new slot -- it did buy. Not auto-scribing this one, since it isn\'t clear whether the existing copy was already scribed -- check it yourself if it wasn\'t.', name, nowStack), COLOR_GOOD)
        end
    end

    if not landedOk then
        logLine(string.format('"%s" didn\'t buy for some reason -- skipping it.', name), COLOR_WARN)
        S.skipped = S.skipped + 1
        table.insert(S.skippedNames, name)
        setOutcome(entry, OUTCOME.BOUGHT_NO_SCRIBE, 'money moved but the scroll could not be located')
        return 'continue'
    elseif stackedInstead then
        setOutcome(entry, OUTCOME.BOUGHT_NO_SCRIBE, 'stacked onto an existing copy; not auto-scribed')
        return 'continue'
    end

    -- Hard safety gate: never right-click anything that isn't name-confirmed as a scroll.
    local landedName = itemDisplayName(landed)
    if not isScrollName(landedName) then
        logLine(string.format('"%s" landed in %s but isn\'t named like a spell or song scroll -- NOT right-clicking it. Stopping so you can check what happened.', landedName, slotLabel(targetBag, targetSlot)), COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = string.format('Refused to scribe non-spell item: "%s"', landedName)
        setOutcome(entry, OUTCOME.BOUGHT_NO_SCRIBE, string.format('a non-scroll item landed ("%s")', landedName))
        return 'stop'
    end

    S.bought = S.bought + 1
    table.insert(S.purchasedNames, name)
    -- The ACTUAL measured drop in money on hand is the only trustworthy cost figure.
    local actualSpent = math.max(0, copperBeforeBuy - myTotalCopper())
    S.spentCopper = S.spentCopper + actualSpent
    logLine(string.format('Scribing "%s"...', name), COLOR_INFO)

    -- The client can reject the right-click for a while after a purchase, so click, watch for the scroll to
    -- leave the slot, and click again -- up to 20 tries. Stop is respected between attempts.
    local scribed = false
    local maxAttempts = 20
    local recoveryAttempted = false
    for attempt = 1, maxAttempts do
        mq.delay(attempt == 1 and 150 or 1000)
        if S.stopRequested then break end

        waitForMouseOffOverlay()
        if S.stopRequested then break end

        -- A few attempts in with no progress, the bag is probably closed: toggle it open exactly once.
        if targetSlot ~= 0 and attempt == 4 and not scribed and not recoveryAttempted then
            recoveryAttempted = true
            waitForMouseOffOverlay()
            if openBagIfClosed(targetBag) then
                logLine(string.format('Still no progress on "%s" -- bag %d reads as closed, re-opening it.', name, targetBag), COLOR_WARN)
            end
        end

        sendCmd(string.format('scribe "%s": right-click the scroll at %s (attempt %d/%d)', name, slotLabel(targetBag, targetSlot), attempt, maxAttempts),
            targetSlotNotifyCmd(targetBag, targetSlot))
        handleScribeConfirmIfOpen()

        for _ = 1, 5 do
            local stillThere = readTargetSlot(targetBag, targetSlot)
            if not stillThere or itemDisplayName(stillThere) ~= name then
                scribed = true
                break
            end
            mq.delay(200)
        end
        logObs(string.format('scribe attempt %d/%d for "%s": %s', attempt, maxAttempts, name,
            scribed and 'scroll no longer reads in the slot (scribe inferred; MQ gives no direct confirmation)' or 'scroll still reads in the slot'))
        if scribed then break end
        if S.stopRequested then break end

        if attempt % 5 == 0 then
            logLine(string.format('Still trying to scribe "%s" (attempt %d/%d)...', name, attempt, maxAttempts), COLOR_WARN)
        end
    end

    if scribed then
        -- The scroll can transit through the cursor briefly during the scribe animation.
        for _ = 1, 15 do -- up to ~3s
            if not cursorItemName() then break end
            mq.delay(200)
        end
        local stuck = cursorItemName()
        logObs('cursor after scribing "' .. name .. '": ' .. tostring(stuck or 'empty'))
        setOutcome(entry, OUTCOME.SCRIBED, nil)
        if stuck then
            logLine(string.format('"%s" scribed, but something is still on the cursor afterward ("%s") -- stopping to be safe.', name, stuck), COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = string.format('Cursor not clear after scribing "%s"', name)
            return 'stop'
        end
        logLine(string.format('Confirmed scribed: "%s" (cost %s, scroll left %s).', name, formatCoin(actualSpent), slotLabel(targetBag, targetSlot)), COLOR_GOOD)
        return 'continue'
    end

    if S.stopRequested then
        logLine('Stopped by user.', COLOR_WARN)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Stopped by user'
        setOutcome(entry, OUTCOME.BOUGHT_NO_SCRIBE, 'the user pressed Stop during the scribe')
        return 'stop'
    end
    logLine(string.format('"%s" was bought, but the scroll never left %s after %d tries -- a common cause is a full spellbook. Stopping so you can check.', name, slotLabel(targetBag, targetSlot), maxAttempts), COLOR_ERR)
    S.state = STATE.STOPPED
    S.lastStopReason = string.format('Scribe failed on "%s"', name)
    setOutcome(entry, OUTCOME.BOUGHT_NO_SCRIBE, string.format('scribe failed after %d attempts', maxAttempts))
    return 'stop'
end

local function runSpellSpree(range)
    S.state = STATE.RUNNING
    -- NOT resetting bought/skipped/spentCopper here -- they accumulate across the whole shopping spree (all
    -- vendors); they are reset once at the start of runShoppingSpree.
    S.currentName, S.currentIndex = nil, 0
    S.lastStopReason = nil
    -- Reset per vendor: a streak within THIS vendor's list must not carry over from another vendor.
    S.consecutiveNoMoneyMovement = 0
    -- Also per vendor: a quote from another vendor's identically named item must not misinform a decision.
    priceQuotes = {}
    -- D-025 D: the visit's level range is a required argument, checked before anything is read or bought. A PoK visit passes
    -- { low, high, label }; the Bazaar passes { unrestricted = true }. Nothing else buys: a caller that forgets the range fails closed.
    local unrestricted = type(range) == 'table' and range.unrestricted == true
    if not unrestricted then
        local refusal
        if range == nil then
            refusal = 'No level range'
            logLine('No level range was given for this visit -- buying nothing.', COLOR_ERR)
        else
            local ok, why = validateRange(range)
            if not ok then
                refusal = 'Invalid level range'
                logLine(string.format('Invalid level range for this visit (%s) -- buying nothing.', tostring(why)), COLOR_ERR)
            end
        end
        if refusal then
            S.state = STATE.STOPPED
            S.lastStopReason = refusal
            return
        end
    end
    -- NOT resetting S.openedBags: a bag's open/closed state in the game does not reset between vendors, and
    -- the click that opens it TOGGLES it.
    logLine('Starting up...', COLOR_GOLD)
    logObs(string.format('run start: character=%s server=%s zone=%s target=%s merchantOpen=%s stopOnOutOfMoney=%s money=%s bought/skipped so far=%d/%d',
        tloText(function() return mq.TLO.Me.CleanName() end), tloText(function() return mq.TLO.EverQuest.Server() end),
        zoneShort(), tloText(function() return mq.TLO.Target.CleanName() end), tostring(merchantOpen()),
        tostring(S.stopOnOutOfMoney), formatCoin(myTotalCopper()), S.bought, S.skipped))
    logLine('This will open bags as needed to buy and scribe into -- please leave them open once they pop up (closing one mid-run can briefly misread a purchase as failed).', COLOR_WARN)

    if not merchantOpen() then
        logLine('No merchant window open -- open a vendor first.', COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'No merchant open'
        return
    end

    do
        local stray = cursorItemName()
        if stray then
            logLine(string.format('There\'s already something on your cursor ("%s") -- clear that before starting.', stray), COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Item already on cursor'
            return
        end
    end

    if not verifyUsableFilterOn() then
        S.state = STATE.STOPPED
        S.lastStopReason = '"Usable items only" not confirmed on'
        return
    end

    do
        local checkBag, checkSlot = firstFreeInventorySlot()
        if not checkBag then
            logLine('No free inventory space anywhere -- make room before running this.', COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Inventory full'
            return
        end
        logObs(string.format('first free slot at run start: %s.', slotLabel(checkBag, checkSlot)))
    end

    -- A': wait for the visible usable list to settle, then read it once.
    local rows, why = waitForListToSettle()
    if not rows then
        if why == 'Stopped by user' then
            logLine('Stopped by user.', COLOR_WARN)
        elseif why == 'Merchant closed' then
            logLine('Merchant window closed unexpectedly -- stopping.', COLOR_ERR)
        else
            logLine(string.format('The vendor list did not settle within %d ms -- skipping this vendor rather than buying from a possibly partial list.', LIST_MAX_WAIT_MS), COLOR_ERR)
        end
        S.state = STATE.STOPPED
        S.lastStopReason = why
        return
    end
    logLine(string.format('[list] The visible list settled at %d row(s).', rows), COLOR_GOLD)

    local entries, byName, stats = buildSpellList(rows)
    logLine(string.format('[list] Built the spell list: %d scroll(s) to buy from %d row(s); %d non-scroll row(s) ignored; %d unreadable row(s); %d duplicate name(s).',
        #entries, rows, stats.nonScroll, stats.unreadable, #stats.duplicates), COLOR_GOLD)
    do
        local chunk = {}
        for _, e in ipairs(entries) do
            chunk[#chunk + 1] = string.format('%d=%s [Lvl %s, %s]', e.index, e.name, tostring(e.levelText), e.priceText)
            if #chunk == 4 then logObs('built list: ' .. table.concat(chunk, ' | ')); chunk = {} end
        end
        if #chunk > 0 then logObs('built list: ' .. table.concat(chunk, ' | ')) end
    end

    -- D-025 C, E: one pass before any purchase. An entry whose level is outside the visit's range, or unreadable, is recorded as
    -- deliberately skipped now, so it is never selected or clicked and an early stop cannot relabel it. Range skips are ledger
    -- outcomes only (S.skipped and S.skippedNames are not touched).
    if unrestricted then
        logLine('[list] No level range for this visit (Bazaar): every scroll the vendor sells is eligible.', COLOR_GOLD)
    else
        local inCount, outCount, unreadableCount = 0, 0, 0
        for _, e in ipairs(entries) do
            local verdict, reason = classifyLevel(e.levelText, range.low, range.high)
            if verdict == 'in' then
                inCount = inCount + 1
            else
                if verdict == 'outside' then outCount = outCount + 1; e.rangeSkip = true else unreadableCount = unreadableCount + 1 end
                setOutcome(e, OUTCOME.SKIPPED, reason)
            end
        end
        logLine(string.format('[list] Level range %d-%d (ticked tier %s): %d in range, %d outside, %d unreadable.',
            range.low, range.high, tostring(range.label or (range.low .. '-' .. range.high)), inCount, outCount, unreadableCount), COLOR_GOLD)
    end

    local function finish()
        logLedger(entries)
        finalScan(entries, byName)
    end

    for i, entry in ipairs(entries) do
        if entry.outcome then
            -- already classified (D-025 C): no select, no click, no pause
        else
            -- Explicit and frequent: the outer main loop's doevents only runs once before this function.
            mq.doevents()

            if S.stopRequested then
                logLine('Stopped by user.', COLOR_WARN)
                S.state = STATE.STOPPED
                S.lastStopReason = 'Stopped by user'
                markRemainingNotAttempted(entries, i, S.lastStopReason)
                finish()
                return
            end
            if not merchantOpen() then
                logLine('Merchant window closed unexpectedly -- stopping.', COLOR_ERR)
                S.state = STATE.STOPPED
                S.lastStopReason = 'Merchant closed'
                markRemainingNotAttempted(entries, i, S.lastStopReason)
                finish()
                return
            end
            do
                local stray = cursorItemName()
                if stray then
                    logLine(string.format('Something ended up on your cursor ("%s") -- that means an action didn\'t complete cleanly. Stopping before anything gets lost or misplaced.', stray), COLOR_ERR)
                    S.state = STATE.STOPPED
                    S.lastStopReason = string.format('Unexpected item on cursor: "%s"', stray)
                    markRemainingNotAttempted(entries, i, S.lastStopReason)
                    finish()
                    return
                end
            end

            local result = processEntry(entry)
            if result == 'stop' then
                markRemainingNotAttempted(entries, i + 1, S.lastStopReason)
                finish()
                return
            end
            mq.delay(100)
        end
    end

    if #entries == 0 then
        logLine('No spell or song scrolls are listed on this vendor.', COLOR_GOLD)
    else
        logLine(string.format('Reached the end of the built list (%d entr%s).', #entries, #entries == 1 and 'y' or 'ies'), COLOR_GOLD)
    end
    S.state = STATE.DONE
    S.lastStopReason = 'End of the built list'
    finish()
    closeVendor('the built list is finished')
end

-- ============================================================================
-- Nav & Shop: path to a named NPC, open their merchant window, run the exact
-- same buy-everything logic as a normal Start, then close the merchant when
-- done -- a full "walk up, buy it all, walk away" cycle. Built to test with
-- one NPC first; the plan is to expand to a list of stops later.
--
-- UNVERIFIED, same as everything else in this script has been at first:
-- /nav id <ID> for pathing, and /click right target for opening the merchant
-- window, are both standard MQ2 commands I'm reasonably confident about, but
-- neither has been tested live yet in this script.
-- ============================================================================
-- The "=" prefix forces an EXACT name match instead of a substring match --
-- without it, "Illusionist Sevat" also matches "Illusionist Sevata", which
-- is exactly the wrong-NPC problem this fixes. Used for both the spawn
-- lookup (so /nav id targets the right one) and the actual /target command.
local function findNpcSpawn(npcName)
    local ok, spawn = pcall(function() return mq.TLO.Spawn(string.format('npc "=%s"', npcName)) end)
    if not ok or not spawn or not spawn() then return nil end
    return spawn
end

local function runNavAndShop(npcName, range)
    S.state = STATE.RUNNING
    S.lastStopReason = nil
    logLine(string.format('Nav & Shop: looking for "%s"...', npcName), COLOR_GOLD)

    -- Don't kick off anything -- not even the nav -- until the mouse is
    -- confirmed off the overlay.
    waitForMouseOffOverlay()
    if S.stopRequested then
        logLine('Stopped by user.', COLOR_WARN)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Stopped by user'
        return
    end

    local meshLoaded = false
    pcall(function() meshLoaded = mq.TLO.Navigation.MeshLoaded() end)
    if not meshLoaded then
        logLine('No navmesh loaded for this zone -- can\'t auto-path. Load MQ2Nav\'s mesh for this zone first.', COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'No navmesh loaded'
        return
    end

    local spawn = findNpcSpawn(npcName)
    if not spawn then
        logLine(string.format('Could not find an exact match for "%s" in this zone.', npcName), COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = string.format('NPC not found: "%s"', npcName)
        return
    end
    local npcId = spawn.ID()

    logLine(string.format('Found "%s" (#%d) -- navigating...', npcName, npcId), COLOR_INFO)
    sendCmd(string.format('navigate to "%s" (#%d)', npcName, npcId), '/nav id %d', npcId)
    mq.delay(300)

    local navStartAt = os.clock()
    local lastNavMsgAt = 0
    while true do
        if S.stopRequested then
            logLine('Stopped by user.', COLOR_WARN)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Stopped by user'
            sendCmd('stop navigation: user pressed Stop', '/nav stop')
            return
        end
        local navActive = false
        pcall(function() navActive = mq.TLO.Navigation.Active() end)
        if not navActive then break end
        if (os.clock() - navStartAt) > 60 then
            logLine(string.format('Navigation to "%s" timed out after 60s -- stopping.', npcName), COLOR_ERR)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Navigation timed out'
            sendCmd('stop navigation: 60s limit reached', '/nav stop')
            return
        end
        if (os.clock() - lastNavMsgAt) > 5.0 then
            lastNavMsgAt = os.clock()
            logLine(string.format('Still navigating to "%s"...', npcName), COLOR_MUTE)
        end
        mq.delay(200)
    end

    logLine(string.format('Arrived near "%s".', npcName), COLOR_GOOD)

    -- Retry for a few seconds rather than one shot -- right after nav
    -- finishes, the client doesn't always have the NPC targetable
    -- immediately (still settling into position, LoS, etc.), and one
    -- 300ms attempt was giving up before it had a real chance to land.
    local targetOk = false
    for attempt = 1, 10 do -- up to ~3s
        if S.stopRequested then break end
        sendCmd(string.format('target "%s" after arriving (attempt %d/10)', npcName, attempt), '/target npc "=%s"', npcName)
        mq.delay(300)
        pcall(function() targetOk = mq.TLO.Target.ID() == npcId end)
        logObs(string.format('target check: Target.ID=%s expected=%s ok=%s', tloText(function() return mq.TLO.Target.ID() end), tostring(npcId), tostring(targetOk)))
        if targetOk then break end
    end
    if not targetOk then
        logLine(string.format('Could not target "%s" after arriving.', npcName), COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Could not target NPC'
        return
    end

    waitForMouseOffOverlay()
    sendCmd(string.format('open the merchant window of "%s" by right-clicking the target', npcName), '/click right target')

    local merchOpen = false
    for _ = 1, 25 do -- up to ~5s
        if merchantOpen() then
            merchOpen = true
            break
        end
        mq.delay(200)
    end
    if not merchOpen then
        logLine(string.format('Right-clicked "%s" but the merchant window never opened.', npcName), COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Merchant window never opened'
        return
    end

    logLine('Merchant window open -- starting the buy run.', COLOR_GOOD)
    local countersBefore = runCounters()
    runSpellSpree(range)
    logRunOutcome('Nav & Shop "' .. npcName .. '"', countersBefore)

    -- Always close, no matter how the buy run ended -- this is meant to be a
    -- full, self-contained cycle, not something that leaves a vendor window
    -- hanging open for you to deal with afterward.
    closeVendor('Nav & Shop finished; always close the merchant however the buy run ended')
    logLine('Nav & Shop: done, merchant closed.', COLOR_GOLD)
end

-- ============================================================================
-- Shopping Spree: run Nav & Shop back-to-back for every checked class/tier
-- vendor. A failure on one vendor (not found, merchant never opened, etc.)
-- just moves on to the next one -- but running out of money stops the whole
-- spree early, since every vendor after that would fail the same way.
-- ============================================================================
local function collectSelectedVendors()
    local list = {}
    for _, className in ipairs(CLASS_ORDER) do
        for _, tier in ipairs(TIERS) do
            if S.selected[className][tier] then
                -- OLD (kept, D-021 B'): local npcName = VENDOR_DATA[className] and VENDOR_DATA[className][tier]
                local vendorTier = TIER_VENDOR[tier]
                local npcName = vendorTier and VENDOR_DATA[className] and VENDOR_DATA[className][vendorTier]
                -- D-025 A': the ticked tier's label is the level range of the visit; a label that is not a valid range refuses the visit
                local low, high = parseTierRange(tier)
                if not low then
                    logLine(string.format('Invalid level range for %s %s: %s -- skipping that visit (nothing will be bought).',
                        className, tier, tostring(high)), COLOR_ERR)
                elseif npcName then
                    table.insert(list, { class = className, tier = tier, vendorTier = vendorTier, name = npcName,
                        range = { low = low, high = high, label = tier } })
                else
                    logLine(string.format('No vendor is configured for %s %s (vendor tier %s) -- skipping that visit.',
                        className, tier, tostring(vendorTier)), COLOR_WARN)
                end
            end
        end
    end
    return list
end

-- Some stop reasons mean the whole spree needs to stop, not just this one
-- vendor -- something stuck on the cursor needs your attention right now
-- (don't go wandering off to another vendor with it), and a full inventory
-- or spellbook will just fail the exact same way at every vendor after
-- this one too, so there's no point continuing.
local function isSpreeAbortingReason(reason)
    if not reason then return false end
    local r = reason:lower()
    return r:find('cursor') ~= nil
        or r:find('out of money') ~= nil
        or r:find('inventory full') ~= nil
        or r:find('scribe failed') ~= nil
end

local function printSpreeSummary()
    if #S.purchasedNames > 0 then
        logLine(string.format('Purchased (%d): %s', #S.purchasedNames, table.concat(S.purchasedNames, ', ')), COLOR_GOOD)
    else
        logLine('Purchased (0): none', COLOR_GOOD)
    end
    if #S.skippedNames > 0 then
        logLine(string.format('Skipped (%d): %s', #S.skippedNames, table.concat(S.skippedNames, ', ')), COLOR_WARN)
    else
        logLine('Skipped (0): none', COLOR_MUTE)
    end
end

local function runShoppingSpree()
    local list = collectSelectedVendors()
    if #list == 0 then
        logLine('No vendors selected -- check at least one class/tier box first.', COLOR_WARN)
        return
    end

    S.bought, S.skipped, S.spentCopper = 0, 0, 0
    S.purchasedNames, S.skippedNames = {}, {}
    logLine(string.format('Shopping spree: %d vendor(s) selected.', #list), COLOR_GOLD)
    for i, entry in ipairs(list) do
        if S.stopRequested then
            logLine('Stopped by user.', COLOR_WARN)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Stopped by user'
            printSpreeSummary()
            return
        end

        -- D': say where the visit goes when it differs from the ticked tier (logged before any purchase)
        local via = (entry.vendorTier ~= entry.tier) and string.format(', using the %s vendor', entry.vendorTier) or ''
        logLine(string.format('--- Vendor %d/%d: %s (%s %s%s) ---', i, #list, entry.name, entry.class, entry.tier, via), COLOR_GOLD)
        runNavAndShop(entry.name, entry.range)

        if S.stopRequested then
            logLine('Stopped by user.', COLOR_WARN)
            S.state = STATE.STOPPED
            S.lastStopReason = 'Stopped by user'
            printSpreeSummary()
            return
        end
        if isSpreeAbortingReason(S.lastStopReason) then
            logLine(string.format('"%s" -- ending the shopping spree early, no point visiting the rest.', S.lastStopReason), COLOR_ERR)
            S.state = STATE.STOPPED
            printSpreeSummary()
            return
        end
    end

    logLine(string.format('Shopping spree: all %d vendor(s) done.', #list), COLOR_GOLD)
    S.state = STATE.DONE
    S.lastStopReason = 'Shopping spree complete'
    printSpreeSummary()
end

-- Bazaar run. Deliberately does almost nothing of its own: no vendor list, no
-- spawn lookup, no /nav, no /click -- the Bazaar has no navmesh, so there is
-- nothing to path along and no way to open a merchant from here reliably.
-- You stand at the merchant and open the window; this picks it up from there
-- and runs the exact same purchase loop the PoK vendors use.
--
-- The class/tier checkboxes are ignored on purpose. They exist to pick WHICH
-- PoK NPC to walk to, and that question has no meaning when you have already
-- chosen the NPC by opening its window -- the run simply buys every scroll
-- the open merchant will sell you.
local function runBazaarShop()
    if not inBazaar() then
        logLine('Not in the Bazaar -- this button is for working a merchant you opened there yourself.', COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'Not in the Bazaar'
        return
    end
    if not merchantOpen() then
        logLine('No merchant window open -- walk up to the spell vendor and open it first.', COLOR_ERR)
        S.state = STATE.STOPPED
        S.lastStopReason = 'No merchant open'
        return
    end

    S.bought, S.skipped, S.spentCopper = 0, 0, 0
    S.purchasedNames, S.skippedNames = {}, {}
    logLine('Bazaar: working the merchant window you have open.', COLOR_GOLD)

    local countersBefore = runCounters()
    runSpellSpree({ unrestricted = true })
    logRunOutcome('Bazaar', countersBefore)
    printSpreeSummary()
end

-- ============================================================================
-- ImGui
-- ============================================================================
local function stateColor()
    if S.state == STATE.RUNNING then return COLOR_GOOD end
    if S.state == STATE.DONE then return COLOR_GOLD end
    if S.state == STATE.STOPPED then return COLOR_WARN end
    return COLOR_MUTE
end

local function draw()
    ImGui.SetNextWindowSize(600, 780, ImGuiCond.FirstUseEver)
    local shown
    open, shown = ImGui.Begin('SpellSpree v' .. VERSION .. '###spellSpree', open)
    if not shown then
        ImGui.End()
        return
    end

    -- Two independent ways to detect "is the mouse over this window" --
    -- kept both since IsWindowHovered() alone wasn't reliably catching it.
    local hoverOk1, hover1 = pcall(function() return ImGui.IsWindowHovered() end)
    local wx, wy, ww, wh, mx, my = 0, 0, 0, 0, 0, 0
    local rectOk = pcall(function()
        wx, wy = ImGui.GetWindowPos()
        ww, wh = ImGui.GetWindowSize()
        mx, my = ImGui.GetMousePos()
    end)
    local hover2 = rectOk and mx >= wx and mx <= wx + ww and my >= wy and my <= wy + wh
    S.mouseOverOverlay = (hoverOk1 and hover1 == true) or (hover2 == true)

    ImGui.TextColored(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], COLOR_GOLD[4], 'SpellSpree')
    ImGui.SameLine()
    ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4], 'buy & scribe every spell, vendor after vendor')
    ImGui.Separator()
    ImGui.Dummy(0, 2)

    local mOpen = merchantOpen()
    ImGui.Text('Merchant:')
    ImGui.SameLine()
    if mOpen then
        ImGui.TextColored(COLOR_GOOD[1], COLOR_GOOD[2], COLOR_GOOD[3], COLOR_GOOD[4], 'Open')
    else
        ImGui.TextColored(COLOR_ERR[1], COLOR_ERR[2], COLOR_ERR[3], COLOR_ERR[4], 'Not open')
    end
    ImGui.SameLine()
    ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4], '    Status:')
    ImGui.SameLine()
    local sc = stateColor()
    ImGui.TextColored(sc[1], sc[2], sc[3], sc[4], S.state)
    local isInPoK     = inPoK()
    local isInBazaar  = inBazaar()
    ImGui.SameLine()
    ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4], '    Zone:')
    ImGui.SameLine()
    if isInPoK then
        ImGui.TextColored(COLOR_GOOD[1], COLOR_GOOD[2], COLOR_GOOD[3], COLOR_GOOD[4], 'Plane of Knowledge')
    elseif isInBazaar then
        ImGui.TextColored(COLOR_GOOD[1], COLOR_GOOD[2], COLOR_GOOD[3], COLOR_GOOD[4], 'Bazaar')
    else
        ImGui.TextColored(COLOR_ERR[1], COLOR_ERR[2], COLOR_ERR[3], COLOR_ERR[4], 'no spell vendors here')
    end
    if S.state == STATE.RUNNING and S.currentName then
        ImGui.SameLine()
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            string.format('(#%d: %s)', S.currentIndex, S.currentName))
    end
    if S.lastStopReason and S.state ~= STATE.RUNNING then
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            'Last stop reason: ' .. S.lastStopReason)
    end
    if S.mouseOverOverlay then
        ImGui.TextColored(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3], COLOR_WARN[4],
            '!! Mouse is over this window -- move it into the game world')
    end
    if S.state == STATE.RUNNING then
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            'Leave any bag windows this opens alone until it\'s done.')
    end

    ImGui.Dummy(0, 6)
    ImGui.Separator()
    ImGui.Dummy(0, 2)
    ImGui.Text(string.format('Bought: %d', S.bought))
    ImGui.SameLine()
    ImGui.Text(string.format('    Skipped: %d', S.skipped))
    ImGui.SameLine()
    ImGui.TextColored(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], COLOR_WHITE[4],
        '    Spent: ' .. formatCoinPPOnly(S.spentCopper))
    ImGui.Text('On hand: ' .. formatCoin(myTotalCopper()))

    ImGui.Dummy(0, 6)
    ImGui.Separator()
    ImGui.Dummy(0, 2)

    -- Only one of the two paths can possibly apply where you are standing, so
    -- only one is ever drawn. Showing the PoK vendor tree while you are in the
    -- Bazaar is worse than clutter -- it reads like something you are meant to
    -- tick before the Bazaar button will work, when in fact it is ignored
    -- there entirely.
    local pokRange = tostring(TIERS[1]):match('^(%d+)') .. '-' ..
                     tostring(TIERS[#TIERS]):match('(%d+)$')

    if isInPoK then
        ImGui.TextColored(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], COLOR_GOLD[4],
            string.format('Plane of Knowledge (%s)', pokRange))
        ImGui.SameLine()
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            '-- pick vendors, then run')

        if S.detectedClasses then
            local names = {}
            for _, className in ipairs(CLASS_ORDER) do
                if S.detectedClasses[className] then table.insert(names, className) end
            end
            ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
                'Detected: ' .. (#names > 0 and table.concat(names, ', ') or 'none of your classes have PoK vendors'))
        else
            ImGui.TextColored(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3], COLOR_WARN[4],
                'No classes detected -- showing the full list.')
        end
        ImGui.SameLine()
        ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 90)
        if ImGui.Button('Re-detect', 80, 0) then
            S.reDetectRequested = true
            logLine('User pressed Re-detect.', COLOR_MUTE)
        end

        ImGui.Dummy(0, 2)
        for _, className in ipairs(CLASS_ORDER) do
            if (not S.detectedClasses) or S.detectedClasses[className] then
                local allChecked = true
                for _, tier in ipairs(TIERS) do
                    if not S.selected[className][tier] then
                        allChecked = false
                        break
                    end
                end
                local newClassChecked, classChanged = ImGui.Checkbox('##class_' .. className, allChecked)
                if classChanged then
                    for _, tier in ipairs(TIERS) do
                        S.selected[className][tier] = newClassChecked
                    end
                end
                ImGui.SameLine()
                if ImGui.TreeNode(className) then
                    ImGui.Indent()
                    for _, tier in ipairs(TIERS) do
                        local checked, changed = ImGui.Checkbox(tier .. '##' .. className, S.selected[className][tier])
                        if changed then
                            S.selected[className][tier] = checked
                        end
                    end
                    ImGui.Unindent()
                    ImGui.TreePop()
                end
            end
        end

        local selectedCount = 0
        for _, className in ipairs(CLASS_ORDER) do
            for _, tier in ipairs(TIERS) do
                if S.selected[className][tier] then
                    selectedCount = selectedCount + 1
                end
            end
        end

        ImGui.Dummy(0, 4)
        local newStop, stopChanged = ImGui.Checkbox('Stop when out of money (uncheck to skip and keep shopping)', S.stopOnOutOfMoney)
        if stopChanged then
            S.stopOnOutOfMoney = newStop
            logLine('User set "stop when out of money" to ' .. tostring(newStop) .. '.', COLOR_MUTE)
        end

        ImGui.Dummy(0, 4)
        local canSpree = (S.state ~= STATE.RUNNING) and selectedCount > 0
        if not canSpree then ImGui.BeginDisabled() end
        if ImGui.Button(string.format('Run Shopping Spree (%d selected)', selectedCount), 260, 0) then
            S.stopRequested = false
            S.shoppingSpreeRequested = true
            logSyncIdentity(true)
            logLine('User pressed Run Shopping Spree.', COLOR_MUTE)
        end
        if not canSpree then ImGui.EndDisabled() end

        ImGui.SameLine()
        local canStop = (S.state == STATE.RUNNING)
        if not canStop then ImGui.BeginDisabled() end
        if ImGui.Button('Stop', 100, 0) then
            S.stopRequested = true
            logLine('User pressed Stop.', COLOR_WARN)
        end
        if not canStop then ImGui.EndDisabled() end

        if selectedCount == 0 and S.state ~= STATE.RUNNING then
            ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
                'Tick at least one class/tier above.')
        end

    elseif isInBazaar then
        ImGui.TextColored(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], COLOR_GOLD[4], 'Bazaar (1-50)')
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            'There is no navmesh for the Bazaar, so nothing can walk you to the')
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            'vendor. Find the spell merchant, open its window, then hit the button.')
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            string.format('Bazaar stocks 1-50 only -- Plane of Knowledge covers %s.', pokRange))

        ImGui.Dummy(0, 4)
        local newStop, stopChanged = ImGui.Checkbox('Stop when out of money (uncheck to skip and keep shopping)', S.stopOnOutOfMoney)
        if stopChanged then
            S.stopOnOutOfMoney = newStop
            logLine('User set "stop when out of money" to ' .. tostring(newStop) .. '.', COLOR_MUTE)
        end

        ImGui.Dummy(0, 4)
        local canBazaar = (S.state ~= STATE.RUNNING) and mOpen
        if not canBazaar then ImGui.BeginDisabled() end
        if ImGui.Button('Buy From Open Vendor', 260, 0) then
            S.stopRequested = false
            S.bazaarRequested = true
            logSyncIdentity(true)
            logLine('User pressed Buy From Open Vendor.', COLOR_MUTE)
        end
        if not canBazaar then ImGui.EndDisabled() end

        ImGui.SameLine()
        local canStop = (S.state == STATE.RUNNING)
        if not canStop then ImGui.BeginDisabled() end
        if ImGui.Button('Stop', 100, 0) then
            S.stopRequested = true
            logLine('User pressed Stop.', COLOR_WARN)
        end
        if not canStop then ImGui.EndDisabled() end

        if S.state ~= STATE.RUNNING then
            if mOpen then
                ImGui.TextColored(COLOR_GOOD[1], COLOR_GOOD[2], COLOR_GOOD[3], COLOR_GOOD[4],
                    'Ready -- buys every spell and song this merchant sells.')
            else
                ImGui.TextColored(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3], COLOR_WARN[4],
                    'No merchant window open yet.')
            end
        end

    else
        ImGui.TextColored(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], COLOR_GOLD[4], 'Nothing to buy here')
        ImGui.Dummy(0, 2)
        ImGui.TextColored(COLOR_INFO[1], COLOR_INFO[2], COLOR_INFO[3], COLOR_INFO[4],
            string.format('Plane of Knowledge  --  spells %s', pokRange))
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            '    Pick class and tier here, and it walks vendor to vendor for you.')
        ImGui.Dummy(0, 2)
        ImGui.TextColored(COLOR_INFO[1], COLOR_INFO[2], COLOR_INFO[3], COLOR_INFO[4],
            'Bazaar  --  spells 1-50')
        ImGui.TextColored(COLOR_MUTE[1], COLOR_MUTE[2], COLOR_MUTE[3], COLOR_MUTE[4],
            '    No navmesh there, so you walk to the merchant and open it yourself.')

        if S.state == STATE.RUNNING then
            ImGui.Dummy(0, 4)
            if ImGui.Button('Stop', 100, 0) then
            S.stopRequested = true
            logLine('User pressed Stop.', COLOR_WARN)
        end
        end
    end

    ImGui.Dummy(0, 6)
    ImGui.Separator()
    ImGui.Dummy(0, 2)
    ImGui.Text('Log')
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 90)
    if ImGui.Button('Clear Log', 80, 0) then
        S.log = {}
    end
    ImGui.BeginChild('SpellSpreeLog', 0, 140, true)
    local wasNearBottom = true
    pcall(function()
        wasNearBottom = (ImGui.GetScrollY() >= ImGui.GetScrollMaxY() - 15)
    end)
    ImGui.PushTextWrapPos(0.0)
    for _, entry in ipairs(S.log) do
        ImGui.TextColored(entry.color[1], entry.color[2], entry.color[3], entry.color[4],
            entry.t .. '  ' .. entry.text)
    end
    ImGui.PopTextWrapPos()
    if wasNearBottom then ImGui.SetScrollHereY(1.0) end
    ImGui.EndChild()

    ImGui.End()
end

-- Unit-test hook (decision log D-026). Only a test sets _G.SPELLSPREE_UNIT, to an empty table: the script then fills that table
-- with these pieces and stops here, so nothing below runs (no window, no events, no main loop). Nothing above this point touches
-- the game or the log file. Normal runs never set it.
if type(rawget(_G, 'SPELLSPREE_UNIT')) == 'table' then
    local unit = _G.SPELLSPREE_UNIT
    unit.parseClassLine, unit.parseCopperFromText, unit.withCommas = parseClassLine, parseCopperFromText, withCommas
    unit.formatCoin, unit.formatCoinPPOnly, unit.isScrollName = formatCoin, formatCoinPPOnly, isScrollName
    unit.setOutcome, unit.markRemainingNotAttempted, unit.logLedger = setOutcome, markRemainingNotAttempted, logLedger
    unit.OUTCOME, unit.S, unit.LOG = OUTCOME, S, LOG
    unit.parseTierRange, unit.validateRange, unit.classifyLevel = parseTierRange, validateRange, classifyLevel
    unit.logWriteFile, unit.logLine, unit.logObs, unit.logFail = logWriteFile, logLine, logObs, logFail
    unit.logSyncIdentity, unit.logUnavailable, unit.logIdentityKeyFor = logSyncIdentity, logUnavailable, logIdentityKeyFor
    return
end

mq.imgui.init('SpellSpreeWindow', draw)

-- Best-effort price-quote listener -- see the block comment above
-- parseCopperFromText for why this is not trusted as the primary defense.
--
-- Now matched against the EXACT confirmed wording, copied straight from
-- chat: "Cavalier Waut tells you, 'That'll be 159 platinum 2 gold 1 silver
-- 9 copper per Spell: Crusaders Touch.'" -- so the earlier guesses (a "for"
-- variant that was never right, and a trailing #*# on the "per" one that may
-- well have been the actual problem) are gone. Simplified to the minimum
-- needed: one clean anchor, no trailing wildcard after the capture that
-- closes the pattern.
--
-- A silent pattern mismatch and mq.event genuinely not firing in this
-- environment look identical from here -- no error, just nothing happening
-- -- and this codebase has already hit that exact thing before (see the note
-- above logLine: two other chat events never fired even once in testing).
-- The debug listener right below answers that directly instead of leaving it
-- another guess: it matches on nothing but "tells you," and logs the raw
-- text straight to the SpellSpree log for ANY tell during a run. If that
-- never shows anything either, the answer is definitive -- mq.event isn't
-- catching vendor tells in this environment at all, and no amount of further
-- pattern tweaking will fix it. If it DOES show the tell but the price still
-- isn't being used, the raw text it logs is exactly what's needed to fix the
-- structured pattern for real.
local function onPriceQuote(_, amountText, itemText)
    local copper = parseCopperFromText(amountText)
    if copper then
        local itemName = tostring(itemText or ''):gsub('%s+$', '')
        priceQuotes[itemName] = { copper = copper, at = os.clock() }
        dbgLine(string.format('[price quote] "%s" = %s', itemName, formatCoin(copper)))
    end
end
-- Both wordings, confirmed both actually occur on the same vendor for
-- different items -- "for" was dropped in an earlier version on the
-- (wrong) assumption only "per" was real.
mq.event('spellspree_price_per', "#*#tells you, 'That'll be #1# per #2#.'", onPriceQuote)
mq.event('spellspree_price_for', "#*#tells you, 'That'll be #1# for #2#.'", onPriceQuote)

-- Raw-tell firehose. Only registered under DEBUG -- it matches every tell
-- during a run, so with the structured patterns above now confirmed working
-- it's pure duplication of the [price quote] line next to it.
if DEBUG then
    mq.event('spellspree_price_debug', "#*#tells you, #1#", function(_, rest)
        logLine(string.format('[tell debug] %s', tostring(rest)), COLOR_MUTE)
    end)
end

-- ============================================================================
-- Main loop -- all blocking work (mq.delay calls inside runSpellSpree and its
-- helpers) happens here, never inside the ImGui draw callback.
-- ============================================================================
logLine(string.format('SpellSpree v%s loaded. Check some vendors below and hit Run Shopping Spree.', VERSION), COLOR_GOLD)
logSessionHeader(false)

-- D-028 E'': one run is dispatched like this. The log file is reconciled with the character first; then the file is held (routing stays
-- pinned to the run's file while detection continues); the run executes; if it failed, its error line is written while the file is still
-- held, so it lands with the run's other records whatever the throttle says; the hold is released; and a forced sync follows, so the first
-- record after the run goes to the file for the character in force. Everything after the xpcall runs whether the run succeeded or failed.
local function dispatchRun(run)
    logSyncIdentity(true)
    LOG.hold, LOG.heldNoted = true, nil
    local ok, err = xpcall(run, errHandler)
    if not ok then
        S.state = STATE.STOPPED
        S.lastStopReason = 'Script error'
        pcall(function() logLine('Unexpected error: ' .. tostring(err), COLOR_ERR) end)
    end
    LOG.hold, LOG.heldNoted = false, nil
    logSyncIdentity(true)
end

while open do
    mq.doevents()
    if S.reDetectRequested then
        S.reDetectRequested = false
        local ok, detected = pcall(detectClasses)
        if ok and detected then
            local set = {}
            for _, className in ipairs(detected) do
                set[className] = true
            end
            S.detectedClasses = set
            logLine('Detected class(es): ' .. table.concat(detected, ', '), COLOR_GOLD)
        else
            logLine('Could not detect any classes -- showing the full list instead.', COLOR_WARN)
            S.detectedClasses = nil
        end
    end
    if S.shoppingSpreeRequested and S.state ~= STATE.RUNNING then
        S.shoppingSpreeRequested = false
        dispatchRun(runShoppingSpree)
    end
    if S.bazaarRequested and S.state ~= STATE.RUNNING then
        S.bazaarRequested = false
        dispatchRun(runBazaarShop)
    end
    mq.delay(50)
end
