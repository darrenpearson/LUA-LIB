-------------------------------------------------------------------------------
-- Carbon Copy Printer
-- @author Darren Pearson
-- @copyright 2014 Rinstrum Pty Ltd
-- Takes printout information from SER3B and sends to ser1A keeping a copy
-- Prints the copy out ser1A when F3 pressed
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

-- Add control of an L401 at the given IP and port
local dwi = rinApp.addK400("K401")

-- Write "Hello world" to the LCD screen.
dwi.writeBotLeft("CUSTOM")
dwi.writeBotRight("AUTO")

bump = 0
function printHandler(s)
   dwi.dbg.print('SER3B:',s)
   dwi.printCustomTransmit(dwi.expandCustomTransmit(s)..string.format('%d',bump),dwi.PRINT_SER1A)
   dwi.rotWAIT(1)
   if on then
      dwi.turnOn(4)
      on = false
   else
      dwi.turnOff(4)
      on = true
   end
 end
dwi.setDelimiters('\02','\03')
dwi.setSerBCallback(printHandler)
dwi.enableOutput(4)

-------------------------------------------------------------------------------
-- Key Handler for F3 
-------------------------------------------------------------------------------
local function F3Pressed(key, state)
   bump = bump + 1
   return true
end
dwi.setKeyCallback(dwi.KEY_F3, F3Pressed)


while rinApp.running do
   rinApp.system.handleEvents()
end

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()