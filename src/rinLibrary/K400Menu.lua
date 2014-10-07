-------------------------------------------------------------------------------
--- Menuing Functions.
-- An easy to use menuing subsystem.
--
-- Look at the <a href="../examples/menu.lua.html">menu.lua</a> example file
-- for a more detailed usage example of this subsystem.
--
-- @module rinLibrary.K400Menu
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local canonical = require('rinLibrary.namings').canonicalisation
local deepcopy = require 'rinLibrary.deepcopy'
local callable = require('rinSystem.utilities').callable

-------------------------------------------------------------------------------
-- Return a callback if it is callable, return the default if not.
-- @param callback User supplied callback
-- @param default System suplied default
-- @return callback if callable, default if not
-- @local
local function cb(callback, default)
    return callable(callback) and callback or default
end

-------------------------------------------------------------------------------
-- A null function for use as a dummy callback
-- @return nil
-- @local
local function null()
    return nil
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--- Fields Definition Arguments.
--
-- All of these field arguments are optional with sensible defaults.  Not all of these
-- fields are meaningful for all field kinds.  For example, getValue doesn't make sense
-- for a field without a value.  Likewise, run is replaced by all fields (except item) and
-- cannot be overridden.
--
-- @table FieldDefinition
-- @field default Default item in a list selection.
-- @field getValue Function to return the value of a field's contents.
-- @field hide Function to execute when field is moved away from.
-- @field leave Function to execute when leaving the top level menu, it is passed a boolean
-- which indicates if the menu exited via an EXIT field item (true) or by cancelling at the
-- top level (false).
-- @field loop Should a list or menu item loop from bottom to top?
-- @field max Maximum value a numeric, integer or passcode  field can take
-- @field min Minimum value a numeric, integer or passcode field can take
-- @field prompt Prompt to be displayed when this field is being edited or viewed.
-- @field ref Reference name used to identify a field.
-- @field run Function to execute when field is activated.
-- @field setList Function to set the contents of a list field.
-- @field setValue Function to set the field's contents.
-- @field show Function to execute when field is displayed.
-- @field unitsOther Extra units annunciators to display when active.
-- @field units Units annunciators to display when this field is active.
-- @field update Function that is called repeatedly while field is displayed.
-- @field value Value to set field to (usually the second positional argumnet would be used for this)
-- @field length Length of a string field (usually the third positional argumnet would be used for this)
-- @field register Register to use with field (usually the second positional argumnet would be used for this)
-- @field name Name of field (usually the first positional argumnet would be used for this)

-------------------------------------------------------------------------------
-- Create a new empty menu
-- @param args Menu field arguments
-- @param parent Menu's parent menu
-- @param fields Table of all fields defined
-- @return The menu
-- @see FieldDefinition
-- @local
local function makeMenu(args, parent, fields)
    local posn, menu = 1

-------------------------------------------------------------------------------
-- Initialise a new item to the defaults
-- @param args arguments passed in by user
-- @return New item
-- @local
    local function newItem(args)
        local name = args[1] or args.name
        local prompt = args.prompt or name
        if type(prompt) == 'string' then
            prompt = string.upper(prompt)
        end

        local r
        r = {
            name = name,
            ref = canonical(args.ref or name),
            prompt = prompt,
            units = args.units or 'none',
            unitsOther = args.unitsOther or 'none',
            loop = args.loop,

            run = cb(args.run, function() print(r.name .. ' has no run function') end),
            show = cb(args.show, function()
                _M.write('bottomRight', r.prompt)
                _M.writeUnits('bottomLeft', r.units, r.unitsOther)
            end),
            hide = cb(args.hide, null),
            update = cb(args.update, function()
                _M.write('bottomLeft', string.upper(menu[posn].name))
            end),
            getValue = cb(args.getValue, null),
            setValue = cb(args.setValue, null)
        }
        return r
    end
    menu = newItem(args)

-------------------------------------------------------------------------------
-- Add an item to this menu
-- @param item Item to add to this menu
-- @return This menu
-- @local
    local function add(item)
        table.insert(menu, item)
        fields[item.ref] = item
        return menu
    end

-------------------------------------------------------------------------------
-- Create one of the numeric fields
-- @param args Field arguments
-- @param type Type of field (interger, number or passcode)
-- @return The containing menu
-- @see FieldDefinition
-- @local
    local function numericEdit(args, type)
        local item = newItem(args)
        local value = args[2] or args.value or 0
        local min, max = args.min, args.max

        item.run = function()
            local v, ok = _M.edit(item.prompt, value, type, item.units, item.unitsOther)
            if ok then
                if min then v = math.max(min, v) end
                if max then v = math.min(max, v) end
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add an integer field to a menu
-- @function integer
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . integer { 'NUMBER', 3 }
    function menu.integer(args)
        return numericEdit(args, 'integer')
    end

-------------------------------------------------------------------------------
-- Add a real field to a menu
-- @function number
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . number { 'PI', 3.14 }
    function menu.number(args)
        return numericEdit(args, 'number')
    end

-------------------------------------------------------------------------------
-- Add a pass code field to a menu
-- @function passcode
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . passcode { 'PI', 1234 }
    function menu.passcode(args)
        return numericEdit(args, 'passcode')
    end

-------------------------------------------------------------------------------
-- Add a string field to a menu
-- @function string
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . string { 'NAME', 'fred' }
    function menu.string(args)
        local item = newItem(args)
        local value = args[2] or args.value or ''
        local len = args[3] or args.length or #value

        item.run = function()
            local v, ok = _M.sEdit(item.prompt, value, len, item.units, item.unitsOther)
            if ok then
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a register field to a menu.  When invoked, the register will be edited.
-- @function register
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .register { 'USER 1', 'userid1', prompt=true }
    function menu.register(args)
        local item = newItem(args)
        local reg = args[2] or args.register

        item.run = function()
            _M.editReg(reg, item.prompt)
        end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add an auto register field to a menu
-- @function auto
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . auto { 'MVV', 'absmvv' }
    function menu.auto(args)
        local item = newItem(args)
        local reg = args[2] or args.register

        item.run = function()
            local restoreBottom = _M.saveBottom()
            _M.write('bottomRight', item.name)
            _M.writeAuto('bottomLeft', reg)
            _M.getKey()
            restoreBottom()
            _M.writeAuto('bottomLeft', 'none')
        end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a list pick field to a menu
-- @function list
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .list { 'PICK', { 'ABC', 123, 'BYE BYE' }, default=123 }
    function menu.list(args)
        local item = newItem(args)
        local itemList = deepcopy(args[2] or args.value)
        local value = args.default or itemList[1]

        item.run = function()
            local v = _M.selectOption(item.prompt, itemList, value, item.loop, item.units, item.unitsOther)
            if v then
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        item.setList = function(l) itemList = deepcopy(l) end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a sub-menu to a menu
-- @function menu
-- @param args Field arguments
-- @return The sub-menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } .
--                      .menu { 'SUBMENU' }
--                          .number { 'TWO', 2 }
--                      .fin()
    function menu.menu(args)
        local item = makeMenu(args, menu, fields)
        add(item)
        return item
    end

-------------------------------------------------------------------------------
-- Mark the end of a sub-menu
-- @function fin
-- @return The parent menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } .
--                      .menu { 'SUBMENU' }
--                          .integer { 'THREE', 3 }
--                      .fin()
    function menu.fin()
        if parent then
            return parent
        else
            dbg.error('menu:', 'Too many fin elements')
        end
        return menu
    end

-------------------------------------------------------------------------------
-- Add an exit menu item to a menu
-- @function exit
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . exit { 'QUIT' }
    function menu.exit(args)
        local item = newItem(args)
        item.run = function() menu.inProgress = false end
        return add(item)
    end


-------------------------------------------------------------------------------
-- Add a generic user item to a menu
-- @function item
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .item { 'PRESS ME', run=function() print 'hello' end }
    function menu.item(args)
        return add(newItem(args))
    end

-------------------------------------------------------------------------------
-- Return the named field from within the menu heirarchy
-- @function findField
-- @param ref Field reference name
-- @return field table
    menu.findField = function(ref)
        return fields[canonical(ref)]
    end

-------------------------------------------------------------------------------
-- Set a named field to the specified value
-- @function getValue
-- @param ref Name of field
-- @return Value the field is set to
-- @usage
-- local big = menu.getValue('largest')
    function menu.getValue(ref)
        local r = menu.findField(ref)
        return r and r.getValue() or nil
    end

-------------------------------------------------------------------------------
-- Set a named field to the specified value
-- @function setValue
-- @param ref Name of field
-- @param value Value to set field to
-- @usage
-- menu.setValue('largest', 33.4)
    function menu.setValue(ref, value)
        local r = menu.findField(ref)
        if r then r.setValue(value) end
    end


-------------------------------------------------------------------------------
-- Run this menu.
-- See the later definition in createMenu for proper documentation.
-- @see createMenu
-- @local
    function menu.run()
        local okay = true
        menu.inProgress = true
        while _M.app.isRunning() and menu.inProgress do
            menu.update()
            local key = _M.getKey('arrow')
            if not _M.dialogRunning() or key == 'cancel' then
                menu.inProgress = false
                okay = false
            elseif key == 'down' then
                posn = private.addModBase1(posn, 1, #menu, menu.loop)
            elseif key == 'up' then
                posn = private.addModBase1(posn, -1, #menu, menu.loop)
            elseif key == 'ok' then
                menu.hide()
                menu[posn].show()
                menu[posn].run()
                menu[posn].hide()
                menu.show()
            end
        end
        return okay
    end

    return menu
end

-------------------------------------------------------------------------------
-- Create a new empty parent menu
-- @param args Defining menu arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = createMenu('MENU') . string { 'NAME', 'Bob' }
-- mymenu.run()
function _M.createMenu(args)
    local fields = {}
    local menu = makeMenu(args, nil, fields)
    local r, leave = menu.run, cb(args.leave, null)

-------------------------------------------------------------------------------
-- Display and execute a menu
-- @function run
-- @return true if exit via EXIT item, false if exit via cancel
-- @usage
-- local mymenu = device.createMenu('MENU').string { 'NAME', 'Ethyl' }
-- mymenu.run()
    menu.run = function()
        local restoreBottom = _M.saveBottom()
        _M.startDialog()
        menu.show()
        local okay = r()
        menu.hide()
        _M.abortDialog()
        restoreBottom()
        leave(okay)
        return okay
    end

    return menu
end

end
