-------------------------------------------------------------------------------
--- Status Monitoring.
-- Functions associated with the status monitoring
-- @module rinLibrary.K400Status
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local pairs = pairs
local ipairs = ipairs
local bit32 = require "bit"
local system = require 'rinSystem.Pack'
local dbg = require "rinLibrary.rinDebug"

-------------------------------------------------------------------------------
-- Function to test if any of the specified bits are set in the data.
-- @param data The value to check against.
-- @param ... The bit positions of interest.
-- @return true iff one of the bits is set.
-- @local
local function anyBitSet(data, ...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(bit32.lshift(0x01, v-1), data) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Function to test if all of the specified bits are set in the data.
-- @param data The value to check against.
-- @param ... The bit positions of interest.
-- @return true iff all of the bits is set.
-- @local
local function allBitSet(data, ...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(bit32.lshift(0x01, v-1), data) == 0 then
            return false
        end
    end
    return true
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--- Status Bits for REG_SYSSTATUS.
--@table sysstatus
-- @field SYS_OVERLOAD Scale overloaded
-- @field SYS_UNDERLOAD Scale underload
-- @field SYS_ERR Error active
-- @field SYS_SETUP Instrument in setup mode
-- @field SYS_CALINPROG Instrument calibration in progress
-- @field SYS_MOTION Weight unstable
-- @field SYS_CENTREOFZERO Centre of Zero (within 0.25 divisions of zero)
-- @field SYS_ZERO Weight within zero band setting
-- @field SYS_NET Instrument in Net mode

_M.SYS_OVERLOAD         = 0x00020000
_M.SYS_UNDERLOAD        = 0x00010000
_M.SYS_ERR              = 0x00008000
_M.SYS_SETUP            = 0x00004000
_M.SYS_CALINPROG        = 0x00002000
_M.SYS_MOTION           = 0x00001000
_M.SYS_CENTREOFZERO     = 0x00000800
_M.SYS_ZERO             = 0x00000400
_M.SYS_NET              = 0x00000200

local REG_LUA_STATUS   = 0x0329
local REG_LUA_ESTAT    = 0x0305
local REG_LUA_STAT_RTC = 0x032A
local REG_SETPSTATUS   = 0x032E
local REG_LUA_STAT_NET = 0x030A

--- Status Bits for REG_LUA_STATUS.
--@table luastatus
-- @field net Displayed weight is in NET mode
-- @field gross Displayed weight is in GROSS mode
-- @field zero Weight is in zero band
-- @field notzero Weight is not in zero band
-- @field coz Weight is in Centre Of Zero (within 0.25 divisions of zero)
-- @field notcoz Weight is not in Centre of Zero
-- @field motion Weight is unstable
-- @field notmotion Weight is stable
-- @field range1 Weight is in range/interval 1
-- @field range2 Weight is in range/interval 2
-- @field pt Tare in use is a preset tare
-- @field notpt Tare in use is not a preset tare
-- @field error There is an error active
-- @field uload Scale is underloaded
-- @field oload Scale is overloaded
-- @field noterror There is no error active
-- @field held Weight is held, not available in batching firmware
-- @field notheld Weight is not held, not available in batching firmware
-- @field idle Batch is idle, only available in batching firmware
-- @field run Batch is running, only available in batching firmware
-- @field pause Batch is paused, only available in batching firmware
-- @field slow Batch is filling at slow speed, only available in batching firmware
-- @field med Batch is filling at medium speed, only available in batching firmware
-- @field fast Batch is filling at fast speed, only available in batching firmware
-- @field time Batch is waiting for a timer to finish, only available in batching firmware
-- @field input Batch is waiting for an input, only available in batching firmware
-- @field no_info None of the 5 status bits above are true, only available in batching firmware
-- @field fill Batch is in a fill stage, only available in batching firmware
-- @field dump Batch is in a dump stage, only available in batching firmware
-- @field pulse Batch is in a pulse stage, only available in batching firmware
-- @field start Batch is in the start stage, only available in batching firmware
-- @field no_type None of the 4 status bits above are true, only available in batching firmware

-- Status
local STAT_NET             = 0x00000001
local STAT_GROSS           = 0x00000002
local STAT_ZERO            = 0x00000004
local STAT_NOTZERO         = 0x00000008
local STAT_COZ             = 0x00000010
local STAT_NOTCOZ          = 0x00000020
local STAT_MOTION          = 0x00000040
local STAT_NOTMOTION       = 0x00000080
local STAT_RANGE1          = 0x00000100
local STAT_RANGE2          = 0x00000200
local STAT_PT              = 0x00000400
local STAT_NOTPT           = 0x00000800
local STAT_ERROR           = 0x00001000
local STAT_ULOAD           = 0x00002000
local STAT_OLOAD           = 0x00004000
local STAT_NOTERROR        = 0x00008000
-- Non-batching status bits
local STAT_HELD            = 0x00010000
local STAT_NOTHELD         = 0x00020000
-- Batching specific status bits
local STAT_IDLE            = 0x00010000
local STAT_RUN             = 0x00020000
local STAT_PAUSE           = 0x00040000
local STAT_SLOW            = 0x00080000
local STAT_MED             = 0x00100000
local STAT_FAST            = 0x00200000
local STAT_TIME            = 0x00400000
local STAT_INPUT           = 0x00800000
local STAT_NO_INFO         = 0x01000000
local STAT_FILL            = 0x02000000
local STAT_DUMP            = 0x04000000
local STAT_PULSE           = 0x08000000
local STAT_START           = 0x10000000
local STAT_NO_TYPE         = 0x20000000

local statusUnmap, statusMap = {}, {
    net         = STAT_NET,
    gross       = STAT_GROSS,
    zero        = STAT_ZERO,
    notzero     = STAT_NOTZERO,
    coz         = STAT_COZ,
    notcoz      = STAT_NOTCOZ,
    motion      = STAT_MOTION,
    notmotion   = STAT_NOTMOTION,
    range1      = STAT_RANGE1,
    range2      = STAT_RANGE2,
    pt          = STAT_PT,
    notpt       = STAT_NOTPT,
    error       = STAT_ERROR,
    uload       = STAT_ULOAD,
    oload       = STAT_OLOAD,
    noterror    = STAT_NOTERROR,
-- Non-batching status bits
    held        = STAT_HELD,
    notheld     = STAT_NOTHELD,
-- Batching specific status bits
    idle        = STAT_IDLE,
    run         = STAT_RUN,
    pause       = STAT_PAUSE,
    slow        = STAT_SLOW,
    med         = STAT_MED,
    fast        = STAT_FAST,
    time        = STAT_TIME,
    input       = STAT_INPUT,
    no_info     = STAT_NO_INFO,
    fill        = STAT_FILL,
    dump        = STAT_DUMP,
    pulse       = STAT_PULSE,
    start       = STAT_START,
    no_type     = STAT_NO_TYPE
}
for k, v in pairs(statusMap) do
    statusUnmap[v] = k
end

--- Status Bits for Extended Status.
--@table luaextendedstatus
-- @field hires Weight is in high resolution (x10) mode
-- @field dispmode Display mode in 2 bits of data, 0 for calibrated units, 1 for piece counting and 2 for alternate units
-- @field range The current range/interval, 0 for range/interval 1, 1 for range/interval 2
-- @field menu_active The user is currently in the menus
-- @field prod_load The product has just been changed/loaded
-- @field prod_save The product has just been updated/saved
-- @field power_off The user is holding the power key down and the power off count-down is currently being displayed
-- @field init The settings have been re-initialised
-- @field rtc When the RTC status has been enabled this value will toggle each second @see writeRTCStatus
-- @field ser1 When network 1 new message is enabled this will be set when there is a new message on network 1 @see writeNetStatus, not available in batching firmware
-- @field ser2 When network 2 new message is enabled this will be set when there is a new message on network 2 @see writeNetStatus, not available in batching firmware

-- Extended status bits
local ESTAT_HIRES           = 0x00000001
local ESTAT_DISPMODE        = 0x00000006
local ESTAT_DISPMODE_RS     = 1
local ESTAT_RANGE           = 0x00000018
local ESTAT_RANGE_RS        = 3
local ESTAT_MENU_ACTIVE     = 0x00000020
local ESTAT_PROD_LOAD       = 0x00000040
local ESTAT_PROD_SAVE       = 0x00000080
local ESTAT_POWER_OFF       = 0x00000100
local ESTAT_INIT            = 0x01000000
local ESTAT_RTC             = 0x02000000
local ESTAT_SER1            = 0x10000000
local ESTAT_SER2            = 0x20000000

local estatusUnmap, estatusMap = {}, {
    hires       = ESTAT_HIRES,
    dispmode    = ESTAT_DISPMODE,
    dispmode_rs = ESTAT_DISPMODE_RS,
    range       = ESTAT_RANGE,
    range_rs    = ESTAT_RANGE_RS,
    menu_active = ESTAT_MENU_ACTIVE,
    prod_load   = ESTAT_PROD_LOAD,
    prod_save   = ESTAT_PROD_SAVE,
    power_off   = ESTAT_POWER_OFF,
    init        = ESTAT_INIT,
    rtc         = ESTAT_RTC,
    ser1        = ESTAT_SER1,
    ser2        = ESTAT_SER2
}
for k, v in pairs(estatusMap) do
    estatusUnmap[v] = k
end

local statBinds = {}
local statID = nil

local eStatBinds = {}
local eStatID = nil

local IOBinds = {}
local IOID = nil

local SETPBinds = {}
local SETPID = nil

local curStatus, curIO, curSETP

local netStatusMap = { net1 = 1, net2 = 2, both = 3, none = 0, ["1"] = 1, ["2"] = 2 }

-------------------------------------------------------------------------------
-- Called when stream data is being renewed
-- @local
function private.renewStatusBinds()
    for _, v in pairs(IOBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(SETPBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(statBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(eStatBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
end

-------------------------------------------------------------------------------
-- Called when status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function statusCallback(data, err)
    curStatus = data
    for k,v in pairs(statBinds) do
       local status = bit32.band(data,k)
       if status ~= v.lastStatus  then
           if v.running then
               dbg.warn('Status Event lost: ',string.format('%08X %08X',k,status))
           else
              v.running = true
              v.lastStatus = status
              v.f(convertValueToName(k, statusunMap), status ~= 0)
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a status bit
-- @param status status name
-- @param callback Function to run when there is an event on change in status
-- @usage
-- device.setStatusCallback('motion', function(stat, value) print('motion of', stat, 'is', value) end)
function _M.setStatusCallback(status, callback)
    local stat = private.convertNameToValue(status, statusMap)
    if stat then
        statBinds[stat] = {
            f = callback,
            lastStatus = 0xFF
        }
    end
end

-------------------------------------------------------------------------------
-- Called when IO status changes are streamed
-- @param data Data on SETP status streamed
-- @param err Potential error message
-- @local
local function IOCallback(data, err)
    curIO = data
    for k,v in pairs(IOBinds) do
       local status = bit32.band(data,k)
       if k == 0 then  --handle the all IO case
          status = curIO
       end
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   dbg.warn('IO Event lost: ',v.IO,string.format('%08X',status))
               else
                   dbg.warn('IO Event lost: ',v.IO,status ~=0)
               end
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.IO, status ~= 0)
              end
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a IO
-- @param IO 1..32
-- @param callback Function taking IO and on/off status as parameters
-- @usage
-- function handleIO1(IO, active)
--     if (active) then
--         print (IO,' is on!')
--     end
-- end
-- device.setIOCallback(1, handleIO1)
function _M.setIOCallback(IO, callback)
    local status = bit32.lshift(0x00000001, IO-1)
    if callback then
        IOBinds[status] = {}
        IOBinds[status]['IO'] = IO
        IOBinds[status]['f'] = callback
        IOBinds[status]['lastStatus'] = 0xFFFFFFFF
    else
        IOBinds[status] = nil
        dbg.warn('','setIOCallback:  nil value for callback function')
    end
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any IO status changes
-- @param callback Function taking current IO status as a parameter
-- @usage
-- function handleIO(data)
--     -- 4 bits of status information for IO 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllIOCallback(handleIO)
function _M.setAllIOCallback(callback)
    if callback ~= nil then
        IOBinds[0] = {}   -- setup a callback for all SETP changes
        IOBinds[0]['IO'] = 'All'
        IOBinds[0]['f'] = callback
        IOBinds[0]['lastStatus'] = 0xFFFFFF
    else
        IOBinds[0] = nil
        dbg.warn('','setIOCallback:  nil value for all callback function')
    end
end

-------------------------------------------------------------------------------
-- Called when SETP status changes are streamed
-- @param data Data on SETP status streamed
-- @param err Potential error message
-- @local
local function SETPCallback(data, err)
    curSETP = bit32.band(data, 0xFFFF)
    for k,v in pairs(SETPBinds) do
       local status = bit32.band(data, k)
       if k == 0 then  --handle the all setp case
          status = curSETP
       end
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   dbg.warn('SETP Event lost: ', v.SETP,string.format('%04X', status))
               else
                   dbg.warn('SETP Event lost: ', v.SETP, status ~=0)
               end
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.SETP, status ~= 0)
              end
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a SETP
-- @param SETP 1..16
-- @param callback Function taking SETP and on/off status as parameters
-- @usage
-- function handleSETP1(SETP, active)
--     if (active) then
--         print (SETP,' is on!')
--     end
-- end
-- device.setSETPCallback(1, handleSETP1)
function _M.setSETPCallback(SETP, callback)
    local status = bit32.lshift(0x00000001, SETP-1)
    SETPBinds[status] = {}
    SETPBinds[status]['SETP'] = SETP
    SETPBinds[status]['f'] = callback
    SETPBinds[status]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any SETP status changes
-- @param callback Function taking current SETP status as a parameter
-- @usage
-- function handleSETP(data)
--     -- 4 bits of status information for SETP 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllSETPCallback(handleSETP)
function _M.setAllSETPCallback(callback)
    SETPBinds[0] = {}   -- setup a callback for all SETP changes
    SETPBinds[0]['SETP'] = 'All'
    SETPBinds[0]['f'] = callback
    SETPBinds[0]['lastStatus'] = 0xFFFFFF
end

-------------------------------------------------------------------------------
-- Called when extended status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function eStatusCallback(data, err)
    private.updateSettings(
        bit32.band(data, ESTAT_HIRES) > 0,
        1 + bit32.rshift(bit32.band(data, ESTAT_DISPMODE), ESTAT_DISPMODE_RS),
        1 + bit32.rshift(bit32.band(data, ESTAT_RANGE), ESTAT_RANGE_RS))

    for k, v in pairs(eStatBinds) do
        local status = bit32.band(data,k)
        if status ~= v.lastStatus  then
            if v.running then
                dbg.warn('Ext Status Event lost: ',string.format('%08X',k),status ~= 0)
            else
                local estatName = private.convertValueToName(k, estatusUnmap, nil)
                v.running = true
                v.lastStatus = status
                if v.mainf then
                    v.mainf(estatName, status ~= 0)
                end
                if v.f then
                    v.f(estatName, status ~= 0)
                end
                v.running = false
            end
         end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an extended status bit
-- @param eStatus Extended status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusCallback(eStatus, callback)
    local eStat = private.convertNameToValue(eStatus, estatusMap)
    if eStat then
        eStatBinds[eStat] = eStatBinds[eStat] or {}
        eStatBinds[eStat]['f'] = callback
        eStatBinds[eStat]['lastStatus'] = 0xFF
    end
end

-------------------------------------------------------------------------------
-- Set the main library callback function for an extended status bit
-- @param eStatus Extended status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusMainCallback(eStatus, callback)
    local eStat = private.convertNameToValue(eStatus, estatusMap)
    if eStat then
        eStatBinds[eStat] = eStatBinds[eStat] or {}
        eStatBinds[eStat]['mainf'] = callback
        eStatBinds[eStat]['lastStatus'] = 0xFF
    end
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @return true if any of the status bits are set in current instrument status
-- @usage
-- device.enableOutput(5)
-- if device.anyStatusSet('motion, 'stat_err', 'oload', 'uload') then
--     device.turnOn(5)  -- turn on output 5 if motion or any errors
-- else
--     device.turnOff(5)
-- end
function _M.anyStatusSet(...)
    if arg.n == 0 then
        return false
    end

    for i, v in pairs({...}) do
        local b = private.convertNameToValue(v, statusMap, 0)
        if bit32.band(curStatus, b) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @return true if all of the status bits are set in cur instrument status
-- @usage
-- device.enableOutput(5)
-- if device.allStatusSet('notmotion', 'notzero', 'gross') then
--     device.turnOn(5)  -- turn on output 5 if stable gross weight not in zero band
-- else
--     device.turnOff(5)
-- end
function _M.allStatusSet(...)
    if arg.n == 0 then
        return false
    end

    for i, v in pairs({...}) do
        local b = private.convertNameToValue(v, statusMap, 0)
        if bit32.band(curStatus, b) == 0 then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO
-- @return 32 bits of IO data
-- @usage
-- print('current IO bits are', device.getCurIO())
function _M.getCurIO()
    return curIO
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @param data The binary integer being converted
-- @param bits The number of significant bits in data
-- @return 32 characters of IO data
-- @local
local function getBitStr(data, bits)
    local s = {}
    for i = bits-1, 0, -1 do
        if bit32.band(data, bit32.lshift(0x01, i)) ~= 0 then
            ch = '1'
        else
            ch = '0'
        end
        table.insert(s,ch)
    end
    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @return 32 characters of IO data
-- @usage
-- print('current IO bits are: ' .. device.getCurIOStr())
function _M.getCurIOStr()
    return getBitStr(curIO, 32)
end

-------------------------------------------------------------------------------
-- Called to check state of current IO
-- @return true if any of the listed IO are active
-- @usage
-- device.enableOutput(3)
-- if not device.anyIOSet(1,2,4,5) then
--     device.turnOn(3)  -- turn on output 3 if no other outputs on
-- else
--     device.turnOff(3)
-- end
function _M.anyIOSet(...)
    return anyBitSet(curIO,...)
end

-------------------------------------------------------------------------------
-- Called to check state of IO
-- @return true if all of the listed IO are active
-- @usage
-- device.enableOutput(3)
-- if device.allIOSet(1,2) then
--     device.turnOn(3)  -- turn on output 3 if IO 1 and 2 both on
-- else
--     device.turnOff(3)
-- end
function _M.allIOSet(...)
    return allBitSet(curIO,...)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 16 setpoints
-- @return 16 bits of SETP status data
-- @usage
-- print('current setpoint bits are', device.getCurSETP())
function _M.getCurSETP()
    return curSETP
end

-------------------------------------------------------------------------------
-- Called to check state of current SETP
-- @return true if any of the listed SETP are active
-- @usage
-- device.enableOutput(1)
-- if not device.anySETPSet(1,2) then
--     device.turnOn(1)  -- turn on output 1 if setpoints 1 and 2 are both inactive
-- else
--     device.turnOff(1)
-- end
function _M.anySETPSet(...)
    return anyBitSet(curSETP,...)
end

-------------------------------------------------------------------------------
-- Called to check state of SETP
-- @return true if all of the listed IO are active
-- @usage
-- device.enableOutput(1)
-- if device.allSETPSet(1, 2) then
--     device.turnOn(1)  -- turn on output 1 if Setpoints 1 and 2 are active
-- else
--     device.turnOff(1)
-- end
function _M.allSETPSet(...)
    return(allBitSet(curSETP,...))
end

-------------------------------------------------------------------------------
-- Wait until selected status bits are true
-- @usage
-- device.waitStatus('notmotion')           -- wait for no motion
-- device.waitStatus('coz')                 -- wait for Centre of zero
-- device.waitStatus('zero', 'notmotion')   -- wait for no motion and zero
function _M.waitStatus(...)
    local stat = 0
    for _, v in pairs({...}) do
        stat = bit32.bor(stat, private.convertNameToValue(v, statusMap, 0))
    end
    while bit32.band(curStatus, stat) ~= stat do
        system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Wait until IO is in a particular state
-- @param IO 1..32
-- @param state true to wait for IO to come on or false to wait for it to go off
-- @usage
-- device.waitIO(1, true) -- wait until IO1 turns on
function _M.waitIO(IO, state)
    local mask = bit32.lshift(0x00000001,(IO-1))
    while _M.app.running do
        local data = bit32.band(curIO, mask)
        if (state and data ~= 0) or (not state and data == 0) then
            break
        end
        system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Wait until SETP is in a particular state
-- @param SETP 1..16
-- @param state true to wait for SETP to come on or false to wait for it to go off
-- @usage
-- device.waitSETP(1, true) -- wait until Setpoint 1 turns on
function _M.waitSETP(SETP, state)
    local mask = bit32.lshift(0x00000001,(SETP-1))
    while _M.app.running do
        local data = bit32.band(curSETP, mask)
        if (state and data ~= 0) or (not state and data == 0) then
            break
        end
        system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Control the use of RTC status bit.
-- The RTC status is enabled as part of the normal initialisation process
-- for the application framework.  You shouldn't need to call this and if
-- in doubt don't.
-- @param s true to enable RTC change monitoring, false to disable
-- @usage
-- device.writeRTCStatus(true)  -- enable RTC monitoring
-- device.writeRTCStatus(false) -- disable RTC monitoring
function _M.writeRTCStatus(s)
    _M.sendRegWait('wrfinalhex', REG_LUA_STAT_RTC, s == false and 0 or 1)
end

-------------------------------------------------------------------------------
-- Process a RTC update tick
-- @param status Status
-- @param active Active?
-- @local
local function handleRTC(status, active)
    private.RTCtick()
end

-------------------------------------------------------------------------------
-- Process initialisation status message
-- @param status Status
-- @param active Active?
-- @local
local function handleINIT(status, active)
--   dbg.info('INIT',string.format('%08X',status),active)
--   if active then
--       private.readSettings()
--       _M.RTCread()
--   end
end

-------------------------------------------------------------------------------
-- Control the use of Net status bits
-- @param status net1, net2, both or none
-- @usage
-- device.writeNetStatus('net1')
-- device.writeNetStatus('none')
-- device.writeNetStatus('both')
function _M.writeNetStatus(status)
    local s = private.convertNameToValue(status, netStatusMap, 0)
    _M.sendRegWait('wrfinalhex', REG_LUA_STAT_NET, s)
end

-------------------------------------------------------------------------------
-- Setup status monitoring via a stream.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.setupStatus()
function _M.setupStatus()
    curStatus = 0
    statID  = private.addStreamLib(REG_LUA_STATUS, statusCallback,  'change')
    eStatID = private.addStreamLib(REG_LUA_ESTAT,  eStatusCallback, 'change')
    IOID    = private.addStreamLib('io_status',  IOCallback,      'change')
    SETPID  = private.addStreamLib(REG_SETPSTATUS, SETPCallback,    'change')
    _M.RTCread()
    _M.setEStatusMainCallback('rtc',  handleRTC)
    _M.setEStatusMainCallback('init', handleINIT)
    _M.writeRTCStatus(true)
end

-------------------------------------------------------------------------------
-- Cancel status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endStatus()
function _M.endStatus()
    private.removeStreamLib(statID)
    private.removeStreamLib(eStatID)
    private.removeStreamLib(IOID)
    private.removeStreamLib(SETPID)
end

-------------------------------------------------------------------------------
-- Cancel IO status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endIOStatus()
function _M.endIOStatus()
    private.removeStreamLib(IOID)
end

-------------------------------------------------------------------------------
-- Cancel SETP status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endSETPStatus()
function _M.endSETPStatus()
    private.removeStreamLib(SETPID)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the deprecated fields
deprecated.REG_LUA_STATUS   = REG_LUA_STATUS
deprecated.REG_LUA_ESTAT    = REG_LUA_ESTAT
deprecated.REG_LUA_STAT_RTC = REG_LUA_STAT_RTC
deprecated.REG_SETPSTATUS   = REG_SETPSTATUS
deprecated.REG_LUA_STAT_NET = REG_LUA_STAT_NET

-- These are strings rather than numerics so that comparisons against them
-- work in call backs
deprecated.STAT_NET         = 'net'
deprecated.STAT_GROSS       = 'gross'
deprecated.STAT_ZERO        = 'zero'
deprecated.STAT_NOTZERO     = 'notzero'
deprecated.STAT_COZ         = 'coz'
deprecated.STAT_NOTCOZ      = 'notcoz'
deprecated.STAT_MOTION      = 'motion'
deprecated.STAT_NOTMOTION   = 'notmotion'
deprecated.STAT_RANGE1      = 'range1'
deprecated.STAT_RANGE2      = 'range2'
deprecated.STAT_PT          = 'pt'
deprecated.STAT_NOTPT       = 'notpt'
deprecated.STAT_ERROR       = 'error'
deprecated.STAT_ULOAD       = 'uload'
deprecated.STAT_OLOAD       = 'oload'
deprecated.STAT_NOTERROR    = 'noterror'
-- Non-batching status bits
deprecated.STAT_HELD        = 'held'
deprecated.STAT_NOTHELD     = 'notheld'
-- Batching specific status bits
deprecated.STAT_IDLE        = 'idle'
deprecated.STAT_RUN         = 'run'
deprecated.STAT_PAUSE       = 'pause'
deprecated.STAT_SLOW        = 'slow'
deprecated.STAT_MED         = 'med'
deprecated.STAT_FAST        = 'fast'
deprecated.STAT_TIME        = 'time'
deprecated.STAT_INPUT       = 'input'
deprecated.STAT_NO_INFO     = 'no_info'
deprecated.STAT_FILL        = 'fill'
deprecated.STAT_DUMP        = 'dump'
deprecated.STAT_PULSE       = 'pulse'
deprecated.STAT_START       = 'start'
deprecated.STAT_NO_TYPE     = 'no_type'

deprecated.ESTAT_HIRES       = 'hires'
deprecated.ESTAT_DISPMODE    = 'dispmode'
deprecated.ESTAT_DISPMODE_RS = 'dispmode_rs'
deprecated.ESTAT_RANGE       = 'range'
deprecated.ESTAT_RANGE_RS    = 'range_rs'
deprecated.ESTAT_MENU_ACTIVE = 'menu_active'
deprecated.ESTAT_PROD_LOAD   = 'prod_load'
deprecated.ESTAT_PROD_SAVE   = 'prod_save'
deprecated.ESTAT_POWER_OFF   = 'power_off'
deprecated.ESTAT_INIT        = 'init'
deprecated.ESTAT_RTC         = 'rtc'
deprecated.ESTAT_SER1        = 'ser1'
deprecated.ESTAT_SER2        = 'ser2'

-------------------------------------------------------------------------------
-- Called to get current instrument status
-- @function getCurStatus
-- @return 32 bits of status data with bits as per STAT_ definitions
-- @usage
-- print('current status bits are', device.getCurStatus())
function deprecated.getCurStatus()
    return curStatus
end

end
