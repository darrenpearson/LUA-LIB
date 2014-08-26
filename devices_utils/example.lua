local print = print

local socket = require "socket"
local dm = require "devicemounter"
local pl = require "pl.pretty"

-- Initialise the devicemounter. Returns a socket for select on.
local fifo = dm.init()

-- Callback that does a pretty print of whatever table is given to it.
local function callback(table)
	print(pl.write(table))
end

-- Register the callback with the devicemounter
dm.register_callback(callback)

-- Do an initial check for any devices that may be mounted.
-- This requires the users callback to already be registered.
dm.checkDev()

-- Main loop. Does socket select and calls the dm.receive_callback when 
-- select returns
for i=1,100 do
	socket.select({fifo}, nil, nil)
	local ret = dm.receive_callback()
end	

