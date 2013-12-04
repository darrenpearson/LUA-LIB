-------------------------------------------------------------------------------
-- Module manager for L401
-- @module rinApp
-- @author Darren Pearson
-- @author Merrick Heley
-- @author Sean Liddle
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local assert = assert
local string = string
local pairs = pairs
local require = require
local dofile = dofile
local bit32 = require "bit"

local socks = require "rinSystem.rinSockets.Pack"

local _M = {}
_M.running = false

-- Create the rinApp resources
_M.system = require "rinSystem.Pack"
_M.userio = require "IOSocket.Pack"
_M.dbg    = require "rinLibrary.rinDebug"
_M.dbgconfig = require "debugConfig"

package.loaded["rinLibrary.rinDebug"] = nil

--"Usage: lua SCRIPTNAME [-- dbgconfig=PATH/TO/FILE]"
local function handleArgs(args)
    
    for i=1,#args do
    
        local mid = string.find(args[i], "=")
        
        if mid == nil then
            -- do nothing, because lua has no continue statement
        elseif "dbgconfig" == string.sub(args[i], 1, mid - 1) then
        
            _M.dbconfig = dofile(string.sub(args[i], mid + 1, #args[i]))
            
            _M.dbg.configureDebug(_M.dbconfig, 'Application')
            _M.dbg.printVar('', _M.dbg.LEVELS[_M.dbg.level])
        end
    end
end

_M.devices = {}
_M.dbg.configureDebug(_M.dbgconfig, 'Application')
handleArgs(arg)

-- captures input from terminal to change debug level
local function userioCallback(sock)
    local data = sock:receive("*l")
       
    if data == nil then
        sock.close()
        socks.removeSocket(sock)
    elseif data == 'exit' then
        _M.running = false
    else
        local level = nil
        
        -- Get the level that corresponds to the text (should be UPPERCASE)
        for k,v in pairs(_M.dbg.LEVELS) do
            if data == v then
                level = k
            end
        end
        
        if level ~= nil then
            -- Set the level in all devices connected
            for k,v in pairs(_M.devices) do
                v.dbg.config.logger:setLevel(level)
            end
            _M.dbg.config.logger:setLevel(level)
        end
    end  
end

-------------------------------------------------------------------------------
-- Called to connect to the K400 instrument, and establish the timers,
-- streams and other services
-- @param model Software model expected for the instrument (eg "K401")
-- @param ip IP address for the socket, "127.1.1.1" used as a default
-- @param port port address for the socket 2222 used as default
-- @return device object for this instrument

function _M.addK400(model, ip, port)
    
    -- Create the socket
    local ip = ip or "127.1.1.1"
    local port = port or 2222
    local app = app or ""
    
    local device = require "rinLibrary.K400"
    
    package.loaded["rinLibrary.L401"] = nil

    _M.devices[#_M.devices+1] = device
  
    
    local s = assert(require "socket".tcp())
    s:connect(ip, port)
    s:settimeout(0.1)
    
    -- Connect to the K400, and attach system if using the system library
    device.connect(app, s, _M)
   
    -- Register the L401 with system
    _M.system.sockets.addSocket(device.socket, device.socketCallback)
    -- Add a timer to send data every 5ms
    _M.system.timers.addTimer(5, 100, device.sendQueueCallback)
    -- Add a timer for the heartbeat (every 5s)
    _M.system.timers.addTimer(5000, 1000, device.sendMsg, "20110001:", true)

    _M.system.sockets.addSocket(_M.userio.connectDevice(), userioCallback)
    
    device.streamCleanup()  -- Clean up any existing streams on connect
    device.setupKeys()
    device.setupStatus()
    device.lcdControl('lua')
    device.configure(model)
    return device 
end


    
-------------------------------------------------------------------------------
-- Called to restore the system to initial state by shutting down services
-- enabled by configure() 
function _M.cleanup()
    for k,v in pairs(_M.devices) do
        v.restoreLcd()
        v.lcdControl('default')

        v.streamCleanup()
        v.endKeys()
        v.delay(50)
     end 
    _M.dbg.printVar('------   Application Finished  ------','', _M.dbg.INFO)
end

_M.running = true
_M.dbg.printVar('------   Application Started   -----', '', _M.dbg.INFO)

return _M