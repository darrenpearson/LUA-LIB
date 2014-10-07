-------------------------------------------------------------------------------
--- LCD Services.
-- Functions to configure the LCD
-- @module rinLibrary.K400LCD
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local tonumber = tonumber
local math = math
local string = string
local bit32 = require "bit"
local timers = require 'rinSystem.rinTimers.Pack'
local naming = require 'rinLibrary.namings'
local canonical = naming.canonicalisation
local dbg = require "rinLibrary.rinDebug"
local system = require "rinSystem.Pack"
local utils = require 'rinSystem.utilities'
local deepcopy = require 'rinLibrary.deepcopy'

local lpeg = require 'rinLibrary.lpeg'
local C, Cg, Cs, Ct = lpeg.C, lpeg.Cg, lpeg.Cs, lpeg.Ct
local P, Pi, R, S, V, spc = lpeg.P, lpeg.Pi, lpeg.R, lpeg.S, lpeg.V, lpeg.space
local sdot = P'.'
local scdot = (1 - sdot) * sdot^-1
local equals, formatPosition = spc^0 * P'=' * spc^0

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Define a pattern to match the display options and produce an option table.
local function boolArg(s) return Cg(Pi(s), s) end
local function nameArg(s) return Pi(s) / s end
local writeArgPat = P{
            spc^0 * Ct((V'opt' * ((spc + P',')^1 * V'opt')^0)^-1) * spc^0 * P(-1),
    opt =   V'time' + boolArg'clear' + boolArg'wait' + boolArg'once' + V'align',
    time =  (Pi'time' * equals)^-1 * Cg(lpeg.float / tonumber, 'time'),
    align = Pi'align' * equals * Cg(nameArg'left' + nameArg'right', 'align')
}

-------------------------------------------------------------------------------
-- Return the number of LCD characters a string will consume.
-- @function strLenR400
-- @param s The string to assess
-- @return The number of display characters
-- @see padDots
-- @see strSubR400
-- @local
local strLenPat = Cs((scdot / ' ' + sdot)^0)
local function strLenR400(s)
    return #strLenPat:match(s)
end

-------------------------------------------------------------------------------
-- Takes a string and pads ... with . . . for R420 to handle.
-- @function padDots
-- @param s String
-- @return Padded string
-- @see strSubR400
-- @see strLenR400
-- @local
local padDotsPat = Cs((scdot + sdot / ' .')^0)
local function padDots(s)
    return padDotsPat:match(s)
end

-------------------------------------------------------------------------------
-- Extract a substring based on the LCD width.
-- @param s String to substring
-- @param stPos Starting position
-- @param endPos Ending position, nil for end of string
-- @return The substring between display positions stPos and endPos
-- @see padDots
-- @see strLenR400
-- @local
local function strSubR400(s, stPos, endPos)
    if endPos == nil then
        endPos = #s
    end

    local n = 0
    local function process(s)
        n = n + 1
        return n >= stPos and n <= endPos and s or ''
    end
    return Cs(((scdot + sdot) / process)^0):match(s)
end

-------------------------------------------------------------------------------
-- Right justify a string in a given field
-- @param s string to justify
-- @param w width to justify to
-- @return justified string
-- @usage
-- if device.rightJustify('hello', 6) == ' hello' then
--     print('yes')
-- end
-- @local
local function rightJustify(s, w)
    s = tostring(s)
    local l = strLenR400(s)
    if l >= w then
        return s
    end
    if s:sub(1, 1) == '.' then l = l - 1 end
    return string.rep(" ", w-l) .. s
end

-------------------------------------------------------------------------------
-- Helper function to apply a callback to every element of the specified array
-- @param t Array to modify
-- @param f Callback function to execute
-- @return Modified table
-- @local
local function xform(t, f)
    if utils.callable(f) then
        for i = 1, #t do
            t[i] = f(t[i])
        end
    end
    return t
end

-------------------------------------------------------------------------------
-- Split a long string into shorter strings of multiple words
-- that fit into length len.
-- @param f field description table
-- @param s String
-- @param align Alignment of result
-- @return list of fragments of the string formatted to fit the field width
-- @local
local function splitWords(f, s, align)
    local t, p = {}, ''
    local len, strlen, strsub = f.length, f.strlen, f.strsub
    s = tostring(s)

    if strlen(s) <= len then
        table.insert(t, s)
    else
        for w in string.gmatch(s, "%S+") do
            if strlen(p) + strlen(w) < len then
                if p == '' then
                    p = w
                else
                    p = p .. ' '..w
                end
            elseif strlen(p) > len then
                table.insert(t, strsub(p, 1, len))
                p = strsub(p, len+1)
                if strlen(p) + strlen(w) < len then
                    p = p .. ' ' .. w
                else
                    table.insert(t, p)
                    p = w
                end
            else
                if #p > 0 then
                    table.insert(t, p)
                end
                p = w
            end
        end

        while strlen(p) > len do
            table.insert(t, strsub(p, 1, len))
            p = strsub(p, len+1)
        end
        if #p > 0 or #t == 0 then
            table.insert(t, p)
        end
    end

    xform(t, f[(align or 'left') .. 'Justify'])
    return xform(t, f.finalFormat)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--LCD display registers
local REG_LCDMODE              = 0x000D
local REG_DISP_BOTTOM_LEFT     = 0x000E    -- Takes string
local REG_DISP_BOTTOM_RIGHT    = 0x000F    -- Takes string
local REG_DISP_TOP_LEFT        = 0x00B0    -- Takes string
local REG_DISP_TOP_RIGHT       = 0x00B1    -- Takes string
local REG_DISP_TOP_ANNUN       = 0x00B2
local REG_DISP_TOP_UNITS       = 0x00B3    -- Takes string
local REG_DISP_BOTTOM_ANNUN    = 0x00B4
local REG_DISP_BOTTOM_UNITS    = 0x00B5

local REG_DISP_AUTO_TOP_ANNUN  = 0x00B6    -- Register
local REG_DISP_AUTO_TOP_LEFT   = 0x00B7    -- Register
local REG_DISP_AUTO_BOTTOM_LEFT= 0x00B8    -- Register

--local REG_DEFAULTMODE          = 0x0166

local botAnnunState = 0
local topAnnunState = 0
local waitPos = 1

local display = {
    topleft = {
        top = true, left = true,
        length = 6,
        rightJustify = function(s) return rightJustify(s, 6) end,
        reg = REG_DISP_TOP_LEFT,
        regUnits = REG_DISP_TOP_UNITS,
        regAuto = REG_DISP_AUTO_TOP_LEFT,
        strlen = strLenR400,
        finalFormat = padDots,
        strsub = strSubR400,
        units = nil,    saveUnits = 0,
        auto = nil,     saveAuto = 0
    },
    
    topright = {
        top = true, right = true,
        length = 4,
        rightJustify = function(s) return rightJustify(s, 4) end,
        reg = REG_DISP_TOP_RIGHT,
        strlen = strLenR400,        -- need to fix these to match the weird display '8.8-8.8'
        finalFormat = padDots,
        strsub = strSubR400
    },

    bottomleft = {
        bottom = true,  left = true,
        length = 9,
        rightJustify = function(s) return rightJustify(s, 9) end,
        reg = REG_DISP_BOTTOM_LEFT,
        regUnits = REG_DISP_BOTTOM_UNITS,
        regAuto = REG_DISP_AUTO_BOTTOM_LEFT,
        strlen = strLenR400,
        finalFormat = padDots,
        strsub = strSubR400,
        units = nil,    saveUnits = 0,
        auto = nil,     saveAuto = 0
    },

    bottomright = {
        bottom = true,  right = true,
        length = 8,
        rightJustify = function(s) return rightJustify(s, 8) end,
        reg = REG_DISP_BOTTOM_RIGHT,
        strlen = strLenR400,
        finalFormat = padDots,
        strsub = strSubR400
    },
--[[
    pcmode = {
        remote = true,
        length = 7,
        rightJustify = function(s)
            if #s > 6 and s:sub(1,1) == '-' then
                return s
            end
            return string.sub('       ' .. s, -7)
        end,
        reg = 0xA205,
        strlen = function(s)
            if #s > 0 and s:sub(1,1) == '-' then
                return #s - 1
            end
            return #s
        end,
        finalFormat = function(s)
            if #s > 1 and s:sub(1,1) ~= '-' then
                s = ' ' .. s
            end
            return '\002' .. string.sub(s .. '        ', 1, 8) .. ' 00\003'
        end,
        strsub = function(s, stPos, endPos)
            if #s > 1 and s:sub(1,1) == '-' then
                endPos = endPos + 1
            end
            return s:sub(stPos, endPos)
        end
    }
--]]
}

--- Display Control Modes.
--
-- The control parameter for the write to display functions is reasonably
-- complex.
--
-- If this parameter is left nil, defaults are used for all settings (see below).
--
-- If this parameter is a number, it is treated as the time between segments
-- of the message to display.  The other settings default as below.
--
-- The this parameter is a string, it is considered to be a space or comma separated list
-- of values.  For example, the string <i>"time=2, once, clear"</i>
-- specified a two second display between elements, clear the field after wards and only display
-- the message once.  For the <i>time</i> parameter, the <i>time=</i> can be omitted.  Thus,
-- "once 2 clear" has the same meaning as the previous example.
--
-- If this parameter is a table, it contains a number of fields which fine tune
-- the display behaviour.  These fields are described below.
--
-- @table displayControl
-- @field time The time parameter is the number of second between the display being updated (default 0.8).
-- @field once Once is a boolean that forces the message to be shown once rather
-- than repeating (default: repeat/display forever).
-- @field wait Wait is a boolean for causes the display call to not return until after
-- the message has been fully displayed (default: don't wait).  The wait implies the once option.
-- @field clear Clear is a boolean, that clears the message from the display once it has been
-- shown (default: don't clear).  The clear implies the once option.

--- Display Fields.
--
-- These are use as the first arugment the the @see write and associated functions.
--
-- @table displayField
-- @field bottomLeft The bottom left field
-- @field bottomRight The bottom right field
-- @field topLeft The top left field
-- @field topRight The top right field

--- LCD Control Modes.
--@table lcdControlModes
-- @field default Set to a default setting (currently dual)
-- @field dual Change to dual display mode
-- @field lua Communication mode, necessary for LUA control
-- @field master Change to master display mode
-- @field product Change to product display mode
local lcdModes = {
    default = private.k410(0) or private.k422(0) or 1,
    dual    = private.k410(0) or 1,                             -- dynamic
    lua     = private.k410(1) or 2,
    master  = private.k410(2) or 3,
    product = private.valueByDevice{ k402=0, k422=0, k491=0 }   -- normal
}

-------------------------------------------------------------------------------
-- Called to setup LCD control.
-- The rinApp framework generally takes care of calling this function for you.
-- However, sometimes you'll want to return control to the display device
-- for a time and grab control again later.
-- @param mode  is 'lua' to control display from script or 'default'
-- to return control to the default instrument application
-- @usage
-- device.lcdControl('default')     -- let the display control itself
-- ...
-- device.lcdControl('lua')         -- switch on Lua display
function _M.lcdControl(mode)
    mode = mode or 'default'
    local m = lcdModes[mode]
    if m == nil then
        dbg.error("K400LCD: unknown lcd mode: ", mode)
        m = lcdModes.default
    end
    private.exReg(REG_LCDMODE, m)
end

-------------------------------------------------------------------------------
-- Remove the timer associated with sliding the display, if present and
-- clean up
local function removeSlideTimer(f)
    timers.removeTimer(f.slideTimer)
    f.slideTimer = nil
end

-------------------------------------------------------------------------------
-- Query the auto register for a display field
-- @param f Display field
-- @return Register name
-- @local
local function readAuto(f)
    if f == nil or f.regAuto == nil then
        return nil
    end
    local reg = private.readRegDec(f.regAuto)
    reg = tonumber(reg)
    f.auto = reg
    return private.getRegisterName(reg)
end

-------------------------------------------------------------------------------
-- Set the auto register for a display field
-- @param f Display field
-- @param register Register name
-- @local
local function writeAuto(f, register)
    if f ~= nil and register ~= nil then
        local reg = private.getRegisterNumber(register)

        if f.regAuto ~= nil and reg ~= f.auto then
            removeSlideTimer(f)
            f.current = nil
            f.currentReg = nil
            private.writeRegHexAsync(f.regAuto, reg)
            f.saveAuto = f.auto
            f.auto = reg
        end
    end
end

-------------------------------------------------------------------------------
-- Decode the time argument to the write function.
-- The input argument can be a number which is interpreted as a time,
-- it can be nil for all defaults or it can be a table which is returned
-- unchanged.
-- @param t Input time/param value
-- @local
local function writeArgs(t)
    if t == nil then
        return {}
    elseif type(t) == 'number' then
        return { time = t }
    elseif type(t) == 'string' then
        local r = writeArgPat:match(t)
        if r == nil then
            dbg.error("K400LCD: unparsable display parameter:", t)
            return {}
        end
        return r
    elseif type(t) == 'table' then
        return deepcopy(t)
    end
    dbg.error("K400LCD: unknown display parameter:", tostring(t))
    return {}
end

-------------------------------------------------------------------------------
-- Write a message to the given display field.
-- @param f Display field.
-- @param s String to write
-- @param params Display parameters
-- @local
local function write(f, s, params)
    if f and f.reg ~= nil then
        removeSlideTimer(f)
        if s then
            local t = writeArgs(params)
            local wait = t.wait
            local clear = t.clear
            local once = t.once or wait or clear
            local time = math.max(t.time or 0.8, 0.2)

            writeAuto(f, 0)
            f.params, f.current = t, tostring(s)
            local slidePos, slideWords = 1, splitWords(f, f.current, t.align)

            local function writeToDisplay(s)
                if f.currentReg ~= s then
                    f.currentReg = s
                    private.writeRegHexAsync(f.reg, s)
                end
            end
            writeToDisplay(slideWords[1])

            f.slideTimer = timers.addTimer(time, time, function()
                slidePos = private.addModBase1(slidePos, 1, #slideWords, true)
                if slidePos == 1 and once then
                    removeSlideTimer(f)
                    wait = false
                    if clear then
                        private.writeRegHexAsync(f.reg, xform({''}, f.finalFormat)[1])
                        f.params, f.current, f.currentReg = nil, '', nil
                    end
                elseif #slideWords == 1 then
                    removeSlideTimer(f)
                else
                    writeToDisplay(slideWords[slidePos])
                end
            end)
            _M.app.delayUntil(function() return not wait end)
        elseif f.auto == 0 then
            writeAuto(f, f.saveAuto)
        end
    end
end

-------------------------------------------------------------------------------
-- Write the specified units value to the specified display field
-- @param f Display field
-- @param v Unit value to write
-- @local
local function units(f, v)
    if f and f.regUnits ~= nil and f.units ~= v then
        private.writeReg(f.regUnits, v)
        f.units = v
    end
end

-------------------------------------------------------------------------------
-- Apply a map to selected members of the display list
-- @param p Predicate that selects which elements to act on
-- @param f Function to apply
-- @local
local function map(p, f)
    for _, v in pairs(display) do
        if p(v) then f(v) end
    end
end

-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- @return Function that restores the bottom fields to their current values
-- @usage
-- local restoreBottom = device.saveBottom()
-- device.writeBotLeft('fnord')
-- restoreBottom()
function _M.saveBottom()
    local restorations = {}
    map(function(v) return v.bottom end,
        function(v)
            table.insert(restorations, { f=v, c=v.current, p=v.params, u=v.units })
        end)
    return function()
        for _, v in ipairs(restorations) do
            write(v.f, v.c, v.p)
            units(v.f, v.u)
        end
    end
end

-------------------------------------------------------------------------------
-- Save the top and bottom left field auto settings
-- @return Function that restores the left auto fields to their current values
-- @usage
-- device.saveAutoLeft()
function _M.saveAutoLeft()
    local restorations = {}
    map(function(v) return v.left end,
        function(v)
            table.insert(restorations, { f=v, a=v.auto })
            v.saveAuto = v.auto
        end)
    return function()
        for _, v in ipairs(restorations) do
            writeAuto(v.f, v.a)
        end
    end
end

-------------------------------------------------------------------------------
-- Write string to thsi specified display section
-- @param where which display section to write to
-- @param s string to display
-- @param params displayControl parameter
-- @see displayField
-- @see displayControl
-- @usage
-- device.write('TopLeft', 'HELLO WORLD', 0.6)
function _M.write(where, s, params)
    write(naming.convertNameToValue(where, display), s, params)
end

-----------------------------------------------------------------------------
-- Link register address with display field to update automatically.
-- Not all fields support this functionality.
-- @param where which display section to write to
-- @param register address of register to link display to.
-- Set to 0 to enable direct control of the area
-- @see displayField
-- @usage
-- device.writeAuto('topLeft', 'grossnet')
function _M.writeAuto(where, register)
    return writeAuto(naming.convertNameToValue(where, display), register)
end

-----------------------------------------------------------------------------
-- Reads the current auto update register for the specified field
-- @return register that is being used for auto update, 0 if none
-- @see displayField
-- @usage
-- local old = device.readAuto('topLeft')
-- device.writeAuto('topLeft', 'none')
-- ...
-- device.writeAuto('topLeft', old)
function _M.readAuto(where)
    return readAuto(naming.convertNameToValue(where, display))
end

-------------------------------------------------------------------------------
-- Write string to Top Left of LCD.  The write interface is preferred.
-- @function writeTopLeft
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeTopLeft('HELLO WORLD', 0.6)
function _M.writeTopLeft(s, params)
    return _M.write('topleft', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Top Right of LCD.  The write interface is preferred.
-- @function writeTopRight
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeTopRight('ABCD')
function _M.writeTopRight(s, params)
    return _M.write('topright', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Bottom Left of LCD.  The write interface is preferred.
-- @function writeBotLeft
-- @param s string to display
-- @param params displayControl parameter
-- @see write
-- @see displayControl
-- @usage
-- device.writeBotLeft('AARDVARK BOTHER HORSES')
function _M.writeBotLeft(s, params)
    return _M.write('bottomleft', s, params)
end

-------------------------------------------------------------------------------
-- Write string to Bottom Right of LCD.  The write interface is preferred.
-- @function writeBotRight
-- @param s string to display
-- @param params deldisplayControl parameterssage
-- @see write
-- @see displayControl
-- @usage
-- device.writeBotRight('HORSES BOTHER AARDVARK')
function _M.writeBotRight(s, params)
    return _M.write('bottomright', s, params)
end

-----------------------------------------------------------------------------
-- Link register address with Top Left display to update automatically.
-- The writeAuto interface is preferred.
-- @function writeAutoTopLeft
-- @param register address of register to link Top Left display to.
-- Set to 0 to enable direct control of the area
-- @see writeAuto
-- @usage
-- device.writeAutoTopLeft('grossnet')
function _M.writeAutoTopLeft(param)
    return _M.writeAuto('topLeft', param)
end

-----------------------------------------------------------------------------
-- Reads the current Top Left auto update register
-- The readAuto interface is preferred.
-- @function readAutoTopLeft
-- @return register that is being used for auto update, 0 if none
-- @see readAuto
-- @usage
-- local old = device.readAutoTopLeft()
-- device.writeAuto('topLeft', 0)
-- ...
-- device.writeAuto('topLeft', old)
function _M.readAutoTopLeft()
    return _M.readAuto('topLeft')
end

-----------------------------------------------------------------------------
-- Link register address with Bottom Left display to update automatically
-- The writeAuto interface is preferred.
-- @function writeAutoBotLeft
-- @param register address of register to link Bottom Left display to.
-- Set to 0 to enable direct control of the area
-- @see writeAuto
-- @usage
-- device.writeAutoBotLeft('grossnet')
function _M.writeAutoBotLeft(param)
    return _M.writeAuto('bottomLeft', param)
end

-----------------------------------------------------------------------------
-- Reads the current Bottom Left auto update register
-- The readAuto interface is preferred.
-- @function readAutoBotLeft
-- @return register that is being used for auto update, 0 if none
-- @see readAuto
-- @usage
-- local old = device.readAutoBotLeft()
-- device.writeAuto('bottomLeft', 0)
-- ...
-- device.writeAuto('bottomLeft', old)
function _M.readAutoBotLeft()
    return _M.readAuto('bottomLeft')
end

-----------------------------------------------------------------------------
-- Set the bottom annunciators directly.
-- @local
local function writeBotAnnuns()
    private.writeRegHexAsync(REG_DISP_BOTTOM_ANNUN, botAnnunState)
end
if REG_DISP_BOTTOM_ANNUN == nil then
    writeBotAnnuns = function() end
end

-----------------------------------------------------------------------------
-- Set the top annunciators directly.
-- @local
local function writeTopAnnuns()
    private.writeRegHexAsync(REG_DISP_TOP_ANNUN, topAnnunState)
end
if REG_DISP_TOP_ANNUN == nil then
    writeTopAnnuns = function() end
end

-----------------------------------------------------------------------------
-- Link register address with Top annunciators to update automatically
-- @function writeAutoTopAnnun
-- @param register address of register to link Top Annunciator state to.
-- Set to 0 to enable direct control of the area.
-- @usage
-- device.writeAutoTopAnnun(0)
local writeAutoTopAnnun = private.exposeFunction('writeAutoTopAnnun', REG_DISP_AUTO_TOP_ANNUN, function(register)
    local r = private.getRegisterNumber(register)
    private.writeRegHexAsync(REG_DISP_AUTO_TOP_ANNUN, r)
end)

--- LCD Annunciators
-- These are the definitions of all the annunciators top and bottom.
--@table Annunciators
-- @field sigma (top)
-- @field balance (top)
-- @field coz (top)
-- @field hold (top)
-- @field motion (top)
-- @field net (top)
-- @field range (top)
-- @field zero (top)
-- @field bal_sega (top)
-- @field bal_segb (top)
-- @field bal_segc (top)
-- @field bal_segd (top)
-- @field bal_sege (top)
-- @field bal_segf (top)
-- @field bal_segg (top)
-- @field range_segadg (top)
-- @field range_segc (top)
-- @field range_sege (top)
-- @field battery (bottom)
-- @field clock (bottom)
-- @field bat_lo (bottom)
-- @field bat_midl (bottom)
-- @field bat_midh (bottom)
-- @field bat_hi (bottom)
-- @field bat_full (bottom)
-- @field wait (bottom)
-- @field wait45 (bottom)
-- @field wait90 (bottom)
-- @field wait135 (bottom)
-- @field waitall (bottom)
-- @field all All annunciators top and bottom

-- REG_DISP_BOTTOM_ANNUN BIT SETTINGS
local WAIT      = 0x0040
local WAIT45    = 0x0100
local WAIT90    = 0x0200
local WAIT135   = 0x0080
local WAITALL   = 0x03C0
local WAIT_SEGS = { WAIT, WAIT45, WAIT90, WAIT135 }

-- REG_DISP_TOP_ANNUN BIT SETTINGS
local annunciatorMap = {
    sigma           = { v=0x00001,  locn='top' },
    balance         = { v=0x00002,  locn='top' },
    coz             = { v=0x00004,  locn='top' },
    hold            = { v=0x00008,  locn='top' },
    motion          = { v=0x00010,  locn='top' },
    net             = { v=0x00020,  locn='top' },
    range           = { v=0x00040,  locn='top' },
    zero            = { v=0x00080,  locn='top' },
    bal_sega        = { v=0x00100,  locn='top' },
    bal_segb        = { v=0x00200,  locn='top' },
    bal_segc        = { v=0x00400,  locn='top' },
    bal_segd        = { v=0x00800,  locn='top' },
    bal_sege        = { v=0x01000,  locn='top' },
    bal_segf        = { v=0x02000,  locn='top' },
    bal_segg        = { v=0x04000,  locn='top' },
    range_segadg    = { v=0x08000,  locn='top' },
    range_segc      = { v=0x10000,  locn='top' },
    range_sege      = { v=0x20000,  locn='top' },
    battery         = { v=0x0001,   locn='bottom' },
    clock           = { v=0x0002,   locn='bottom' },
    bat_lo          = { v=0x0004,   locn='bottom' },
    bat_midl        = { v=0x0008,   locn='bottom' },
    bat_midh        = { v=0x0010,   locn='bottom' },
    bat_hi          = { v=0x0020,   locn='bottom' },
    bat_full        = { v=0x003D,   locn='bottom' },
    wait            = { v=WAIT,     locn='bottom' },
    wait45          = { v=WAIT45,   locn='bottom' },
    wait90          = { v=WAIT90,   locn='bottom' },
    wait135         = { v=WAIT135,  locn='bottom' },
    waitall         = { v=WAITALL,  locn='bottom' },
    all             = { v=1,        locn='all'  }
}
--- Main Units
--@table Units
-- @field none No annunciator selected
-- @field kg Kilogram annunciator
-- @field lb Pound  annunciator
-- @field t Ton/Tonne  annunciator
-- @field g Gramme  annunciator
-- @field oz Ounce annunciator
-- @field n
-- @field arrow_l
-- @field p
-- @field l
-- @field arrow_h
local unitAnnunciators = {
    none      = 0,
    kg        = 0x01,
    lb        = 0x02,
    t         = 0x03,
    g         = 0x04,
    oz        = 0x05,
    n         = 0x06,
    arrow_l   = 0x07,
    p         = 0x08,
    l         = 0x09,
    arrow_h   = 0x0A
}

--- Additional modifiers on bottom display
--@table Other
-- @field none No annuciator selected
-- @field hour Hour annunciator
-- @field minute Minute annunciator
-- @field second Second annunicator
-- @field slash Slash line
-- @field per_h Per hour annunciator
-- @field per_m Per meter annunciator
-- @field per_s Per second annuicator
-- @field percent Percent annunciator
-- @field total Total annunciator
local otherAunnuncitors = {
    none    = 0,
    per_h   = 0x14,
    per_m   = 0x11,
    per_s   = 0x12,
    percent = 0x30,     pc  = 0x30,
    total   = 0x08,     tot = 0x08,
    second  = 0x02,     s = 0x02,
    minute  = 0x01,     m = 0x01,
    hour    = 0x04,     h = 0x04,
    slash   = 0x10
}

-------------------------------------------------------------------------------
-- Convert the annunciator bit maps to a list of values
-- @param l List of annunciators
-- @return table of bit mask values for 'top' and 'bottom'
-- @local
local function convertAnnunciatorBits(l)
    local res = { top = 0, bottom = 0, unknown = 0, all = 0 }
    local missing = { v=1, locn='unknown' }

    for _, v in pairs(l) do
        local bit = naming.convertNameToValue(v, annunciatorMap, missing)
        res[bit.locn] = bit32.bor(res[bit.locn], bit.v)
    end
    if res.all ~= 0 then
        for k, _ in pairs(res) do
            local a = 0
            for b, v in pairs(annunciatorMap) do
                if k == v.locn then
                    res[k] = bit32.bor(res[k], v.v)
                end
            end
        end
    end
    return res
end

-------------------------------------------------------------------------------
-- Turns the annunciators on
-- @param ... holds annunciator names
-- @usage
-- device.setAnnunciators('battery', 'clock', 'balance')
function _M.setAnnunciators(...)
    local bits = convertAnnunciatorBits{...}

    if bits.bottom ~= 0 then
        botAnnunState = bit32.bor(botAnnunState, bits.bottom)
        writeBotAnnuns()
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.bor(topAnnunState, bits.top)
        writeTopAnnuns()
    end
end

-------------------------------------------------------------------------------
-- Turns the annunciators off
-- @param ... holds annunciator names
-- @usage
-- device.clearAnnunciators('net', 'battery', 'hold')
function _M.clearAnnunciators(...)
    local bits = convertAnnunciatorBits{...}

    if bits.bottom ~= 0 then
        botAnnunState = bit32.band(botAnnunState, bit32.bnot(bits.bottom))
        writeBotAnnuns()
    end

    if bits.top ~= 0 then
        topAnnunState = bit32.band(topAnnunState, bit32.bnot(bits.top))
        writeTopAnnuns()
    end
end

-------------------------------------------------------------------------------
-- Rotate the WAIT annunciator
-- @param dir 1 clockwise, -1 anticlockwise 0 no change
-- @usage
-- while true do
--     device.rotWAIT(-1)
--     rinApp.delay(0.7)
-- end
function _M.rotWAIT(dir)
    if dir ~= 0 then
        waitPos = (waitPos - dir / math.abs(dir)) % #WAIT_SEGS
        if waitPos == 0 then waitPos = #WAIT_SEGS end
    end

    botAnnunState = bit32.band(botAnnunState, bit32.bnot(WAITALL))
    botAnnunState = bit32.bor(botAnnunState, WAIT_SEGS[waitPos])
    writeBotAnnuns()
end

-------------------------------------------------------------------------------
-- Set units for specified field.
-- The other field isn't always supported.  Likewise, not all fields have units.
-- @param where which display section to write to
-- @param unts Unit to display
-- @param other ('per_h', 'per_m', 'per_s', 'pc', 'tot')
-- @see displayField
-- @usage
-- device.writeUnits('topLeft', 'kg')
function _M.writeUnits(where, unts, other)
    local u = naming.convertNameToValue(unts, unitAnnunciators, 0x00)
    local o = naming.convertNameToValue(other, otherAunnuncitors, 0x00)
    local v = bit32.bor(bit32.lshift(o, 8), u)

    return units(naming.convertNameToValue(where, display), v)
end

-------------------------------------------------------------------------------
-- Set top units.  The writeUnits interface is preferred.
-- @param unts Unit to display
-- @see writeUnits
-- @usage
-- device.writeTopUnits('kg')
function _M.writeTopUnits(unts)
    return _M.writeUnits('topLeft', unts)
end

-------------------------------------------------------------------------------
-- Set bottom units.  The writeUnits interface is preferred.
-- @param unts Unit to display
-- @param other ('per_h', 'per_m', 'per_s', 'pc', 'tot')
-- @see writeUnits
-- @usage
-- device.writeBotUnits('oz', 'per_m')
function _M.writeBotUnits(unts, other)
    return _M.writeUnits('bottomLeft', unts, other)
end

-------------------------------------------------------------------------------
-- Called to restore the LCD to its default state
-- @usage
-- device.restoreLcd()
function _M.restoreLcd()
    map(function(v) return true end, function(v) write(v, '') end)
    writeAuto(display.topleft, 'grossnet')
    writeAuto(display.bottomright, 0)

    writeAutoTopAnnun(0)
    writeBotAnnuns(0)
    _M.writeUnits('bottomLeft')
end

-------------------------------------------------------------------------------
-- Notify the library that there is a remote display attached
-- @param name Name to be assigned to this display
-- @param type Type of the display
-- @param port Port used to communicate with the display
function _M.addRemoteDisplay(name, type, port)
    local d = nil
    display[canonical(name)] = d
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_LCDMODE                  = REG_LCDMODE
deprecated.REG_DISP_BOTTOM_LEFT         = REG_DISP_BOTTOM_LEFT
deprecated.REG_DISP_BOTTOM_RIGHT        = REG_DISP_BOTTOM_RIGHT
deprecated.REG_DISP_TOP_LEFT            = REG_DISP_TOP_LEFT
deprecated.REG_DISP_TOP_RIGHT           = REG_DISP_TOP_RIGHT
deprecated.REG_DISP_TOP_ANNUN           = REG_DISP_TOP_ANNUN
deprecated.REG_DISP_TOP_UNITS           = REG_DISP_TOP_UNITS
deprecated.REG_DISP_BOTTOM_ANNUN        = REG_DISP_BOTTOM_ANNUN
deprecated.REG_DISP_BOTTOM_UNITS        = REG_DISP_BOTTOM_UNITS
deprecated.REG_DISP_AUTO_TOP_ANNUN      = REG_DISP_AUTO_TOP_ANNUN
deprecated.REG_DISP_AUTO_TOP_LEFT       = REG_DISP_AUTO_TOP_LEFT
deprecated.REG_DISP_AUTO_BOTTOM_LEFT    = REG_DISP_AUTO_BOTTOM_LEFT

deprecated.setAutoTopAnnun              = _M.writeAutoTopAnnun
deprecated.setAutoTopLeft               = _M.writeAutoTopLeft
deprecated.writeBotAnnuns               = function(s) botAnnunState = s writeBotAnnuns() end
deprecated.writeTopAnnuns               = function(s) topAnnunState = s writeTopAnnuns() end
deprecated.setAutoBotLeft               = _M.writeAutoBotLeft
deprecated.setBitsTopAnnuns             = setAnnunciators
deprecated.clrBitsTopAnnuns             = clearAnnunciators
deprecated.setBitsBotAnnuns             = setAnnunciators
deprecated.clrBitsBotAnnuns             = clearAnnunciators

-- Support the released function names with spelling errors :(
deprecated.setAnnunicators              = setAnnunciators
deprecated.clearAnnunicators            = clearAnnunciators

deprecated.BATTERY                      = annunciatorMap.battery.v
deprecated.CLOCK                        = annunciatorMap.clock.v
deprecated.BAT_LO                       = annunciatorMap.bat_lo.v
deprecated.BAT_MIDL                     = annunciatorMap.bat_midl.v
deprecated.BAT_MIDH                     = annunciatorMap.bat_midh.v
deprecated.BAT_HI                       = annunciatorMap.bat_hi.v
deprecated.BAT_FULL                     = annunciatorMap.bat_full.v
deprecated.WAIT                         = annunciatorMap.wait.v
deprecated.WAIT45                       = annunciatorMap.wait45.v
deprecated.WAIT90                       = annunciatorMap.wait90.v
deprecated.WAIT135                      = annunciatorMap.wait135.v
deprecated.WAITALL                      = annunciatorMap.waitall.v
deprecated.SIGMA                        = annunciatorMap.sigma.v
deprecated.BALANCE                      = annunciatorMap.balance.v
deprecated.COZ                          = annunciatorMap.coz.v
deprecated.HOLD                         = annunciatorMap.hold.v
deprecated.MOTION                       = annunciatorMap.motion.v
deprecated.NET                          = annunciatorMap.net.v
deprecated.RANGE                        = annunciatorMap.range.v
deprecated.ZERO                         = annunciatorMap.zero.v
deprecated.BAL_SEGA                     = annunciatorMap.bal_sega.v
deprecated.BAL_SEGB                     = annunciatorMap.bal_segb.v
deprecated.BAL_SEGC                     = annunciatorMap.bal_segc.v
deprecated.BAL_SEGD                     = annunciatorMap.bal_segd.v
deprecated.BAL_SEGE                     = annunciatorMap.bal_sege.v
deprecated.BAL_SEGF                     = annunciatorMap.bal_segf.v
deprecated.BAL_SEGG                     = annunciatorMap.bal_segg.v
deprecated.RANGE_SEGADG                 = annunciatorMap.range_segadg.v
deprecated.RANGE_SEGC                   = annunciatorMap.range_segc.v
deprecated.RANGE_SEGE                   = annunciatorMap.range_sege.v
deprecated.UNITS_NONE                   = unitAnnunciators.none
deprecated.UNITS_KG                     = unitAnnunciators.kg
deprecated.UNITS_LB                     = unitAnnunciators.lb
deprecated.UNITS_T                      = unitAnnunciators.t
deprecated.UNITS_G                      = unitAnnunciators.g
deprecated.UNITS_OZ                     = unitAnnunciators.oz
deprecated.UNITS_N                      = unitAnnunciators.n
deprecated.UNITS_ARROW_L                = unitAnnunciators.arrow_l
deprecated.UNITS_P                      = unitAnnunciators.p
deprecated.UNITS_L                      = unitAnnunciators.l
deprecated.UNITS_ARROW_H                = unitAnnunciators.arrow_h
deprecated.UNITS_OTHER_PER_H            = otherAunnuncitors.per_h
deprecated.UNITS_OTHER_PER_M            = otherAunnuncitors.per_m
deprecated.UNITS_OTHER_PER_S            = otherAunnuncitors.per_s
deprecated.UNITS_OTHER_PC               = otherAunnuncitors.pc
deprecated.UNITS_OTHER_TOT              = otherAunnuncitors.tot

deprecated.rightJustify                 = rightJustify

-------------------------------------------------------------------------------
-- Save the bottom left and right fields and units.
-- Don't use this function, use saveBottom instead.
-- @function saveBot
-- @see saveBottom
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function deprecated.saveBot()
    map(function(v) return v.bottom end,
        function(v)
            v.saveCurrent = v.current
            v.saveParams = v.params
            v.saveUnits = v.units
        end)
end

-------------------------------------------------------------------------------
-- Restore the bottom left and right fields and units.
-- Don't use this function, use saveBottom instead.
-- @function restoreBot
-- @see saveBottom
-- @usage
-- device.saveBot()
-- device.writeBotLeft('fnord')
-- device.restoreBot()
function deprecated.restoreBot()
    map(function(v) return v.bottom end,
        function(v)
            write(v, v.saveCurrent, v.saveParams)
            units(v, v.saveUnits)
        end)
end

if _TEST then
    _M.strLenR400 = strLenR400
    _M.strSubR400 = strSubR400
    _M.padDots    = padDots
    _M.splitWords = splitWords
    _M.convertAnnunciatorBits = convertAnnunciatorBits
end

end

