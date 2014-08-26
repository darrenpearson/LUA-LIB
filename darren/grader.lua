
-------------------------------------------------------------------------------
-- ISWM_Grader.lua myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"
local rinApp = require "rinApp"
local bit32 = require "bit"

local dwi = rinApp.addK400("K401")  -- replace this with the instrument application name if other than K401

-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
-------------------------------------------------------------------------------
local function handleWeightStream(data, err)
-- insert code here to handle changes in weight
--   print('Weight = ',data)    
end
dwi.addStream(dwi.REG_GROSSNET, handleWeightStream, 'change')
-- choose a different register if you want to track other than GROSSNET weight




local GRADE_1 = 1
local GRADE_2 = 2
local GRADE_3 = 3
local GRADE_4 = 4
local curGRADE = 0


local function handleIOStatus(data, err)
-- insert code here to handle changes in weight
--   if data
  local temp = bit32.rshift(data,4)
  temp = bit32.band(temp,7)
  if temp == 0 then
     curGRADE = GRADE_1
  elseif temp == 1 then
     curGRADE = GRADE_2
  elseif temp == 3 then
     curGRADE = GRADE_3
  elseif temp == 7 then
     curGRADE = GRADE_4
  end      
      
  print(data, curGRADE)    
end
dwi.addStream(dwi.REG_IOSTATUS, handleIOStatus, 'change')



-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status  
-------------------------------------------------------------------------------
local function statusChanged(status, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     dwi.turnOff(GRADE_1)
     dwi.turnOff(GRADE_2)
     dwi.turnOff(GRADE_3)
     dwi.turnOff(GRADE_4)
  else 
     if (curGRADE ~= 0) then
          dwi.turnOnTimed(curGRADE,500)
     end        
   end  
   
end
dwi.setStatusCallback(dwi.STAT_MOTION, statusChanged)
-- dwi.setStatusCallback(dwi.STAT_NET, statusChanged)
-- dwi.setStatusCallback(dwi.STAT_ZERO, statusChanged)
-- statusChanged() called whenever Motion, Gross/Net or Zero status 
-- changes on the instrument
--------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- local timer function runs at the rate set below
-------------------------------------------------------------------------------
local tickerStart = 100    -- time in millisec until timer events start triggering
local tickerRepeat = 5000  -- time in millisec that the timer repeats
local tick = 0

local function ticker()
-- insert code here that you want to run on each timer event
    tick = tick + 1
--    print('Ticks: ', tick)    
end
rinApp.system.timers.addTimer(tickerRepeat,tickerStart,ticker)




-------------------------------------------------------------------------------
-- Key Handler for F1 
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    
    if state == 'long' then
        print('Long F1 Pressed')
    else    
        print('F1 Pressed')
    end  
    return true    -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F2 
-------------------------------------------------------------------------------
local function F2Pressed(key, state)
    if state == 'long' then
        print('Long F2 Pressed')
    else    
        print('F2 Pressed')
    end  
    return true -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F2, F2Pressed)

-------------------------------------------------------------------------------
-- Key Handler for F3 
-------------------------------------------------------------------------------
local function F3Pressed(key, state)
    if state == 'long' then
        print('Long F3 Pressed')
    else    
        print('F3 Pressed')
    end  
    return true -- key handled here so don't send back to instrument for handling
end
dwi.setKeyCallback(dwi.KEY_F3, F3Pressed)

-------------------------------------------------------------------------------
-- Handler to capture PWR+ABORT key and end program
-------------------------------------------------------------------------------
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)


-------------------------------------------------------------------------------
-- Initialisation 
-------------------------------------------------------------------------------
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

dwi.writeBotLeft('GRADER')
dwi.enableOutput(GRADE_1)
dwi.enableOutput(GRADE_2)
dwi.enableOutput(GRADE_3)
dwi.enableOutput(GRADE_4)


-------------------------------------------------------------------------------
-- Main Application Loop
-------------------------------------------------------------------------------
while rinApp.running do
  local k = dwi.getKey()
  if k == dwi.KEY_OK then
     dwi.buzz(2)
  end   
  rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-------------------------------------------------------------------------------
-- cleanup and exit
-------------------------------------------------------------------------------

rinApp.cleanup()                   -- shutdown application resources

