local _M = {}

local io = io
local print = print
local tonumber = tonumber
local string = string

local input = require "linux.input"
local ev_lib = require "ev_lib"
local kb_lib = require "kb_lib"

-------------------------------------------------------------------------------
local function main(arg)
    local event_device = ev_lib.openEvent(arg[1])
    io.output():setvbuf('no')
    
    -- Read the keyboard
    while true do
        local ev = ev_lib.getEvent(event_device)
        local key = kb_lib.getAscii(ev)
        
        if key then
            io.write(key)
        elseif (ev.code == input.KEY_F1) then
            print("\n" .. ev.code .. " " .. ev.value)
        end
        

    end
    
end

main(arg)

return _M