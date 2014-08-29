-------------------------------------------------------------------------------
-- myApp
--
-- Application template
--
-- Copy this file to your project directory and insert the specific code of
-- your application
-------------------------------------------------------------------------------

local rinApp = require "rinApp"     --  load in the application framework
local timers = require 'rinSystem.rinTimers.Pack'
local dbg = require "rinLibrary.rinDebug"

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local dwi = rinApp.addK400("K401")     --  make a connection to the instrument
dwi.loadRIS("myApp.RIS")               -- load default instrument settings

local mode = 'idle'

--=============================================================================
-- Register All Event Handlers and establish local application variables
--=============================================================================

-------------------------------------------------------------------------------
--  Callback to capture changes to current weight
local curWeight = 0
local function handleNewWeight(data, err)
   curWeight = data
   print('Weight = ',curWeight)
end
dwi.addStream('grossnet', handleNewWeight, 'change')
-- choose a different register if you want to track other than GROSSNET weight
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to monitor motion status
local function handleMotion(status, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then
     print('motion')
  else
     print('stable')
   end
end
dwi.setStatusCallback('motion', handleMotion)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleIO1(IO, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then
     print('IO 1 is on ')
  else
     print('IO 1 is off ')
  end
end
dwi.setIOCallback(1, handleIO1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

local function handleIO(data)
   dbg.info(' IO: ', string.format('%08X',data))
end
dwi.setAllIOCallback(handleIO)

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleSETP1(SETP, active)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
  if active then
     print ('SETP 1 is on ')
  else
     print ('SETP 1 is off ')
  end
end
dwi.setSETPCallback(1, handleSETP1)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to capture changes to instrument status
local function handleSETP(data)
-- status is a copy of the instrument status bits and active is true or false to show if active or not
   dbg.info('SETP: ',string.format('%04X',data))
end
dwi.setAllSETPCallback(handleSETP)
-- set callback to capture changes on IO1
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callbacks to handle F1 key event
dwi.setKeyCallback('f1', function() print('Long F1 Pressed') return true end, 'long')
dwi.setKeyCallback('f1', function() mode = 'run' return true end, 'short')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callbacks to handle F2 key event
dwi.setKeyCallback('f2', function() print('Long F2 Pressed') return true end, 'long')
dwi.setKeyCallback('f2', function() mode = 'idle' return true end, 'short')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle PWR+ABORT key and end application
dwi.setKeyCallback('pwr_cancel', rinApp.finish, 'long')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback to handle changes in instrument settings
local function settingsChanged(status, active)
end
dwi.setEStatusCallback('init', settingsChanged)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Callback for local timer
local tickerStart = 0.100    -- time in millisec until timer events start triggering
local tickerRepeat = 0.200  -- time in millisec that the timer repeats
local function ticker()
-- insert code here that you want to run on each timer event
    dwi.rotWAIT(1)
end
timers.addTimer(tickerRepeat,tickerStart,ticker)
-------------------------------------------------------------------------------

--=============================================================================
-- Initialisation
--=============================================================================
--  This is a good place to put your initialisation code
-- (eg, setup outputs or put a message on the LCD etc)

-------------------------------------------------------------------------------

--=============================================================================
-- Main Application Loop
--=============================================================================
-- Define your application loop
-- mainLoop() gets called by the framework after any event has been processed
-- Main Application logic goes here
local function mainLoop()
   if mode == 'idle' then
      dwi.writeTopLeft('MY APP')
      dwi.writeBotLeft('F1-START F2-FINISH',1.5)
      dwi.writeBotRight('')
   elseif mode == 'run' then
      dwi.writeTopLeft()
      dwi.writeBotLeft('')
      dwi.writeBotRight('PLACE')
      if dwi.allStatusSet('notzero', 'notmotion') then
         dwi.setUserNumber(3, dwi.toPrimary(curWeight))
         dwi.writeAutoBotLeft('usernum3')
         dwi.writeBotRight('CAPTURED')
         dwi.buzz(2)
         rinApp.delay(1)
         dwi.writeBotRight('...')
         mode = 'wait'
      end
    elseif mode == 'wait' then
       if dwi.anyStatusSet('motion') then
           dwi.writeBotRight('')
           dwi.buzz(1)
           rinApp.delay(0.5)
           mode = 'run'
       end
    end
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
