-------------------------------------------------------------------------------
-- myApp
-- 
-- Application template
--    
-- Copy this file to your project directory and insert the specific code of 
-- your application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 
-------------------------------------------------------------------------------
local rinApp = require "rinApp"     --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use 
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
local load = rinApp.addK400("K401","172.17.1.27")



--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
--  Callback to capture changes to current weight
local curWeight = 0
local function handleNewWeight(data, err)
   curWeight = data
end
dwi.addStream(dwi.REG_GROSSNET, handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor motion status  
local function handleMotion(status, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then 
     rinApp.dbg.info('','motion')
  else 
     rinApp.dbg.info('stable',curWeight)     
   end   
end
dwi.setStatusCallback(dwi.STAT_MOTION, handleMotion)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation 
--=============================================================================
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

-------------------------------------------------------------------------------


local VOLT_0MVV  = 1.3
local VOLT_2MVV  = 4.48  
local function convertMVV(mvv)
   return (VOLT_0MVV + VOLT_2MVV * mvv / 2.0)
end  
  
function checkWeight(wgt, lower, upper)
    return (wgt >= lower) and (wgt <= upper)
end



--=============================================================================
-- Main Application Loop
--=============================================================================
-- Define your application loop
-- mainLoop() gets called by the framework after any event has been processed
-- Main Application logic goes here
local function mainLoop()

    load.setAnalogVolt(convertMVV(0.0))
    dwi.delay(0.2)
    dwi.waitStatus(dwi.STAT_NOTMOTION)  
    rinApp.dbg.info('Zero Correct',checkWeight(curWeight,-2,2))
    
    load.setAnalogVolt(convertMVV(2.5))
    dwi.delay(0.2)
    dwi.waitStatus(dwi.STAT_NOTMOTION)  
    rinApp.dbg.info('FullScale',checkWeight(curWeight,9998,10002))
    

end

--=============================================================================
-- Clean Up 
--=============================================================================
-- Define anything for the Application to do when it exits
-- cleanup() gets called by framework when the application finishes
local function cleanup()
     
end

--=============================================================================
-- run the application 
rinApp.setMainLoop(mainLoop)
rinApp.setCleanup(cleanup)
rinApp.run()                       
--=============================================================================
