local _M = {}

local io = io
local print = print
local tonumber = tonumber
local string = string

local input = require "linux.input"
local ev_lib = require "ev_lib"

-------------------------------------------------------------------------------
local function main(arg)
    local event_device = ev_lib.openEvent(arg[1])
    
    -- Read the keyboard
    while true do
        local ev = ev_lib.getEvent(event_device)
        
        if ev.type == input.EV_SYN and ev.code == input.SYN_CONFIG then
            print "Event: -------------- Config Sync ------------ "
        elseif ev.type == input.EV_SYN and ev.code == input.SYN_REPORT then
            print "Event: -------------- Report Sync ------------ "
        elseif ev.type == input.EV_MSC and (ev.code == input.MSC_RAW or ev.code == input.MSC_SCAN) then
            print(string.format("Event: type %d (%s), code %d (%s), value %02x",
                    ev.type, ev_lib.events[ev.type],
                    ev.code, ev_lib.names[ev.type][ev.code],
                    ev.value))
        else
            print(string.format("Event: type %d (%s), code %d (%s), value %d",
                    ev.type, ev_lib.events[ev.type],
                    ev.code, ev_lib.names[ev.type][ev.code],
                    ev.value))
        end
        
    end
    
end

main(arg)

return _M