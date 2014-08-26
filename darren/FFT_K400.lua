--[[ ********************************************
*       FlowForce XR Controller                 *
*       for Rinstrum M4223 Programmable Module  *
*   ©   This program is copyright by FlowForce  *
*       Unauthorised copying or use of any part *
*       of this program will result in          *
*       legal action                            *
***********************************************]]

local _F = require "rinLibrary.K400"

package.loaded["rinLibrary.K400"] = nil

require 'math'
-- FFT variables
_F.scrUpdTm = 500       -- screen update frequency in mSec
_F.blink = false        -- blink cursor for string editing
_F.inMenu = false       -- true when a menu is active, prevents entering another menu

-- FFT key usage values
_F.KEY_BATCH_RESET  = _F.KEY_TARE
_F.KEY_BATCH_TGT    = _F.KEY_SEL
_F.KEY_MATERIAL     = _F.KEY_F1
_F.KEY_MENU         = _F.KEY_F2
_F.KEY_MAN_FUNC     = _F.KEY_F3


-------------------------------------------------------------------------------
-- Prompts operator to select from a list of options using arrow keys and KEY_OK
-- ==== NOTE: redefined from Rinstrum library - function for FFT controller ====
-- ====       same functionality but up/down keys work opposite             ====
-- @param prompt string to put on bottom right LCD
-- @param options table of option strings
-- @param def default selection string.byte
-- @param loop If true, top option loops to the bottom option and vice versa
-- @return selected string  (default selection if KEY_CANCEL pressed)
function _F.selectOption(prompt, options, def, loop)
    _F.editing = true

    local loop = loop or false
    local options = options or {'cancel'}
    local key = 0
    local index = 1
    
    if def then
        for k,v in ipairs(options) do
            if v == def then
                index = k
            end
        end
    end

    local sel = def or ''
    _F.saveBot()
    _F.writeBotRight(string.upper(prompt))
    _F.writeBotLeft(string.upper(options[index]))
    _F.writeBotUnits(0,0)

    while _F.editing do
        key = _F.getKey(_F.keyGroup.keypad)
        if key == _F.KEY_DOWN then
            index = index + 1
            if index > #options then
                if loop then
                    index = 1
                else
                    index = #options
                end
            end
        elseif key == _F.KEY_UP then
            index = index - 1
            if index <= 0 then
                if loop then
                    index = #options
                else
                    index = 1
                end
            end
        elseif key == _F.KEY_OK then
            sel = options[index]
            _F.editing = false
        elseif key == _F.KEY_CANCEL then
            _F.editing = false
            sel = nil
        end
        _F.writeBotLeft(string.upper(options[index]))
    end

    _F.restoreBot()

    return sel
end

-----------------------------------------------------------------------------------------------
-- return a character for the key pressed, according to the number of times it has been pressed
-- @param k key pressed
-- @param p number of times key has been pressed
-- @return letter, number or symbol character represented on the number key pad
-----------------------------------------------------------------------------------------------

_F.keyChar = function(k, p)

    local n = math.fmod(p, 4)   -- fmod returns the remainder of the integer division

    if k == _F.KEY_1 then
        if n == 1 then          -- one key press
            return "$"
        elseif n == 2 then      -- two key presses
            return "/"
        elseif n == 3 then      -- three key presses
            return "\\"
        elseif n == 0 then      -- four key presses
            return "1"
        end
    elseif k == _F.KEY_2 then
        if n == 1 then          -- one key press
            return "A"
        elseif n == 2 then      -- two key presses
            return "B"
        elseif n == 3 then      -- three key presses
            return "C"
        elseif n == 0 then      -- four key presses
            return "2"
        end
    elseif k == _F.KEY_3 then
        if n == 1 then          -- one key press
            return "D"
        elseif n == 2 then      -- two key presses
            return "E"
        elseif n == 3 then      -- three key presses
            return "F"
        elseif n == 0 then      -- four key presses
            return "3"
        end
    elseif k == _F.KEY_4 then
        if n == 1 then          -- one key press
            return "G"
        elseif n == 2 then      -- two key presses
            return "H"
        elseif n == 3 then      -- three key presses
            return "I"
        elseif n == 0 then      -- four key presses
            return "4"
        end
    elseif k == _F.KEY_5 then
        if n == 1 then          -- one key press
            return "J"
        elseif n == 2 then      -- two key presses
            return "K"
        elseif n == 3 then      -- three key presses
            return "L"
        elseif n == 0 then      -- four key presses
            return "5"
        end
    elseif k == _F.KEY_6 then
        if n == 1 then          -- one key press
            return "M"
        elseif n == 2 then      -- two key presses
            return "N"
        elseif n == 3 then      -- three key presses
            return "O"
        elseif n == 0 then      -- four key presses
            return "6"
        end
    elseif k == _F.KEY_7 then
        n = math.fmod(p, 5)     -- special case with 5 options
        if n == 1 then          -- one key press
            return "P"
        elseif n == 2 then      -- two key presses
            return "Q"
        elseif n == 3 then      -- three key presses
            return "R"
        elseif n == 4 then      -- four key presses
            return "S"
        elseif n == 0 then      -- five key presses
            return "7"
        end
    elseif k == _F.KEY_8 then
        if n == 1 then          -- one key press
            return "T"
        elseif n == 2 then      -- two key presses
            return "U"
        elseif n == 3 then      -- three key presses
            return "V"
        elseif n == 0 then      -- four key presses
            return "8"
        end
    elseif k == _F.KEY_9 then
        n = math.fmod(p, 5)     -- special case with 5 options
        if n == 1 then          -- one key press
            return "W"
        elseif n == 2 then      -- two key presses
            return "X"
        elseif n == 3 then      -- three key presses
            return "Y"
        elseif n == 4 then      -- three key presses
            return "Z"
        elseif n == 0 then      -- five key presses
            return "9"
        end
    elseif k == _F.KEY_0 then
        n = math.fmod(p, 2)     -- special case with 2 options
        if n == 1 then          -- one key press
            return " "
        elseif n == 0 then      -- two key presses
            return "0"
        end
    end
    return nil      -- key passed to function is not a number key
end

_F.sEditVal = ' '       -- default edit value for sEdit()
_F.sEditIndex = 1       -- starting index for sEdit()
_F.sEditKeyTimer = 0    -- counts time since a key pressed for sEdit() - in _F.scrUpdTm increments
_F.sEditKeyTimeout = 4  -- number of counts before starting a new key in sEdit()

local function blinkCursor()
--  used in sEdit() function below
    _F.sEditKeyTimer = _F.sEditKeyTimer + 1 -- increment key press timer for sEdit()
    local str
    local pre
    local suf
    local max = #_F.sEditVal
    _F.blink = not _F.blink
    if _F.blink then
        pre = string.sub(_F.sEditVal, 1, _F.sEditIndex-1)
        if _F.sEditIndex < max then
            suf = string.sub(_F.sEditVal, _F.sEditIndex+1, -1)
        else
            suf = ''
        end
        str = pre .. "_" .. suf
    else
        str = _F.sEditVal
    end
--  print(str)  -- debug
    _F.writeBotLeft(str)
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a string
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @return value and true if ok pressed at end

_F.sEdit = function(prompt, def, maxLen)

    _F.editing = true               -- is editing occurring
    local key, state                -- instrument key values
    local pKey = nil                -- previous key pressed
    local presses = 0               -- number of consecutive presses of a key
    local bl = _F.curBotLeft        -- bottom left display
    local br = _F.curBotRight       -- bottom right display
    local default = def or ' '      -- default string to edit
    _F.sEditVal = tostring(default) -- edit string
    local sLen = #_F.sEditVal       -- length of string being edited
    _F.sEditIndex = 1               -- index in string of character being edited
    local ok = false                -- OK button was pressed to accept editing
    local strTab = {}               -- temporary table holding edited string characters
    local blink = false             -- cursor display variable
    
    cursorTmr = _F.system.timers.addTimer(_F.scrUpdTm, 0, blinkCursor)  -- add timer to blink the cursor

    if sLen >= 1 then   --check length of string against maxLen *****************************************
        local i = 0
        repeat
            i = i + 1
            strTab[i] = string.sub(_F.sEditVal, i, i)   -- convert the string to a table for easier character manipulation 
        until i >= sLen or i >= maxLen
--      print('strTab = ' .. table.concat(strTab))  -- debug
    end

    _F.writeBotRight(prompt)        -- write the prompt
    _F.writeBotLeft(_F.sEditVal)    -- write the default string to edit

    while _F.editing do
        key, state = _F.getKey(_F.keyGroup.keypad)  -- wait for a key press
        if _F.sEditKeyTimer > _F.sEditKeyTimeout then   -- if a key is not pressed for a couple of seconds
            pKey = 'timeout'                            -- ignore previous key presses and treat this as a different key
        end
        _F.sEditKeyTimer = 0                        -- reset the timeout counter now a key has been pressed
        
        if state == "short" then                            -- short key presses for editing
            if key >= _F.KEY_0 and key <= _F.KEY_9 then     -- keys 0 to 9 on the keypad
--              print('i:' .. _F.sEditIndex .. ' l:' .. sLen)   -- debug
                if key == pKey then         -- if same as the previous key pressed
                    presses = presses + 1   -- add 1 to number of presses of this key
                else
                    presses = 1             -- otherwise reset presses to 1
                    if pKey and (_F.sEditIndex >= sLen) and (strTab[_F.sEditIndex] ~= " ") then     -- if not first key pressed
                        _F.sEditIndex = _F.sEditIndex + 1       -- new key pressed, increment the character position
                    end
                    pKey = key              -- remember the key pressed
                end
--              print('i:' .. _F.sEditIndex)    -- debug
                strTab[_F.sEditIndex] = _F.keyChar(key, presses)    -- update the string (table) with the new character
            --
            elseif (key == _F.KEY_DP) and (key ~= pKey) then        -- decimal point key (successive decimal points not allowed)
                if (pKey and (_F.sEditIndex >= sLen)) or (strTab[_F.sEditIndex] == " ") then    -- if not first key pressed and not space at end
                    _F.sEditIndex = _F.sEditIndex + 1           -- new key pressed, increment the character position
                end
                strTab[_F.sEditIndex] = "."                 -- update the string (table) with the new character
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _F.KEY_UP then                    -- up key, previous character
                _F.sEditIndex = _F.sEditIndex - 1               -- decrease index
                if _F.sEditIndex < 1 then                       -- if at first character
                    _F.sEditIndex = sLen                            -- go to last character
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _F.KEY_DOWN then          -- down key, next character
                _F.sEditIndex = _F.sEditIndex + 1       -- increment index
                if _F.sEditIndex > sLen then            -- if at last character
                    if strTab[sLen] ~= " " then         -- and last character is not a space
                        if sLen < maxLen then               -- and length of string < maximum
                            sLen = sLen + 1                     -- increase length of string
                            strTab[sLen] = " "                  -- and add a space to the end
                        else                                -- string length = maximum
                            _F.sEditIndex = 1                   -- go to the first character
                        end
                    else                                -- otherwise (last character is a space)
                        if sLen > 1 then                    -- as long as the string is more than 1 character long
                            strTab[sLen] = nil              -- delete the last character
                            sLen = sLen - 1                 -- decrease the length of the string
                            _F.sEditIndex = 1               -- and go to the first character
                        end
                    end
                end
                pKey = key                                  -- remember the key pressed
            --
            elseif key == _F.KEY_PLUSMINUS then     -- plus/minus key - insert a character
                if sLen < maxLen then
                    sLen = sLen + 1                     -- increase the length of the string
                end
                for i = sLen, _F.sEditIndex+1, -1 do
                    strTab[i] = strTab[i-1]             -- shuffle the characters along
                end
                strTab[_F.sEditIndex] = " "             -- insert a space
                pKey = key                          -- remember the key pressed
            --
            elseif key == _F.KEY_OK then        -- OK key
                _F.editing = false                      -- finish editing
                ok = true                           -- accept changes
            --
            elseif key == _F.KEY_CANCEL then    -- cancel key
                if _F.sEditIndex < sLen then
                    for i = _F.sEditIndex, sLen-1 do    -- delete current character
                        strTab[i] = strTab[i+1]         -- shuffle characters along
                    end
                end
                strTab[sLen] = nil                  -- clear last character
                _F.sEditIndex = _F.sEditIndex - 1   -- decrease length of string
                pKey = key                          -- remember the key pressed
            end
        elseif state == "long" then         -- long key press only for cancelling editing
            if key == _F.KEY_CANCEL then    -- cancel key
                _F.sEditVal = default               -- reinstate default string
                _F.editing = false                  -- finish editing
            end
        end
        if _F.editing or ok then                    -- if editing or OK is selected
            _F.sEditVal = table.concat(strTab)      -- update edited string
            sLen = #_F.sEditVal
--          print('eVal = \'' .. _F.sEditVal .. '\'')   -- debug
        end
    end

    _F.writeBotRight(br)    -- restore previously displayed messages
    _F.writeBotLeft(bl)

    _F.system.timers.removeTimer(cursorTmr) -- remove cursor blink timer
    return _F.sEditVal, ok                  -- return edited string and OK status
end

return _F