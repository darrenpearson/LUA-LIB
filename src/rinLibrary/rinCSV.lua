-------------------------------------------------------------------------------
-- Functions for working with .CSV files and creating multi-table databases
-- @module rinLibrary.rinCSV
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local string    = string
local table     = table
local pairs     = pairs
local io        = io
local ipairs    = ipairs
local tostring  = tostring
local error     = error
local xeq       = os.execute
local rename    = os.rename
local stat      = require('posix').stat

local dbg       = require "rinLibrary.rinDebug"
local canonical = require('rinLibrary.namings').canonicalisation
local deepcopy  = require 'rinLibrary.deepcopy'

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- LPEG pattern for parsing a CSV file
local lpeg = require 'rinLibrary.lpeg'
local C, Cs, Ct, P, S = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.P, lpeg.S

local field = '"' * Cs(((P(1) - '"') + P'""' / '"')^0) * '"' +
                    C((1 - S',\r\n"')^0)
local record = Ct(field * (',' * field)^0) * (S('\r\n')^1 + -1)
local sizings = nil

-------------------------------------------------------------------------------
--- CSV Functions.
-- Functions to manage CSV files directly
-- @section CSV

-------------------------------------------------------------------------------
-- Takes an escaped CSV string and returns a line (1d array)
-- @param s CSV string
-- @return table (1d array)
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local fields = csv.fromCSV('1,"hello, there!",14')
function _M.fromCSV(s)
    return record:match(s)
end

-------------------------------------------------------------------------------
-- Function to check if a table is a CSV table
-- @param t Table
-- @return Boolean indicating if this is a CSV table or not
-- @local
local function isCSV(t)
    return t ~= nil and t.labels ~= nil
end

-------------------------------------------------------------------------------
-- Function to check if a table is a CSV table and that it has some data
-- @param t Table
-- @return Boolean indicating if this is a CSV table with data or not
-- @local
local function hasData(t)
    return isCSV(t) and t.data ~= nil
end

-------------------------------------------------------------------------------
-- Adds '"' around s if it contains ',' or '"' and replaces '"' with '""'
-- @param s string to escape
-- @return escaped string
-- @local
local function escapeCSV(s)
    if s ~= nil then
        s = tostring(s)  -- string find & gsub requires a string so make sure we have one
        -- if s has any commas or '"' in it put "   " around string and replace any '"' with '""'
        if string.find(s, '[,"]') then
            s = '"' .. string.gsub(s,'"','""') .. '"'
        end
    end
    return s
end

-------------------------------------------------------------------------------
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- The order of the CSV string returned isn't guaranteed.
-- @param t table to convert
-- @return escaped CSV string
-- @local
local function toCSV(t)
    local s = { }
    if t ~= nil then
        for _, p in pairs(t) do
            table.insert(s, ",")
            table.insert(s, escapeCSV(p))
        end
    end
    s[1] = ""

    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- @param t table to convert
-- @param w is width of each cell
-- @return escaped CSV string padded to w characters in each cell
-- @local
local function padCSV(t, w)
    local s = { }

    if t ~= nil then
        local f = w ~= nil and string.format("%%%ds", w) or '%s'

        for _, p in pairs(t) do
            table.insert(s, ",")
            table.insert(s, escapeCSV(string.format(f, p)))
        end
    end
    s[1] = ''

    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Checks labels to ensure database table is the same structure
-- Tolerant of additional whitespace in labels and ignores case
-- @param labels 1d array of labels from a database table
-- @param check 1d array of labels to check
-- @return true if labels and check are the same, false otherwise
-- @local
local function equalCSV(labels, check)
    if #labels ~= #check then
        return false
    end

    for col,s in ipairs(labels) do
       s = canonical(s)
       local chk = canonical(check[col],'%s','')
       if s ~= chk then
           return false
       end
    end

    return true
end

-------------------------------------------------------------------------------
-- Force a write back of all dirty file system data
-- @param t Table to force to disc
-- @local
local function sync(t)
    xeq("sync")
end

-------------------------------------------------------------------------------
-- Write a row to a file.
-- @param f File to write to
-- @param s Line to write
-- @local
local function writerow(f, s)
    f:write(toCSV(s))
    f:write('\n')
end

-------------------------------------------------------------------------------
-- Append a row to a file.
-- @param t CSV file table to append to
-- @param s Line to write
-- @local
local function appendrow(t, s)
    local f = io.open(t.fname, "a+")
    writerow(f, s)
    f:close()
    sync()
end

-------------------------------------------------------------------------------
-- Naively determine if two tables have any common fields and if so return a
-- cross mapping.  The algorithm used here is O(n . m) when n and m are the number
-- of columns in the respective CSV tables.  It is possible to implement this in
-- O(n log m) time and this should be done if CSV files with large numbers of columns
-- are expected.
-- @param a first table
-- @param b second table
-- @return Number of matching columns
-- @return Column mapping table
-- @local
local function checkCommonFields(a, b)
    local map = {}
    local n = 0
    local bname = {}

    -- Cache the converted field names for the second table to speed things a little
    for j = 1, #b do
        table.insert(bname, canonical(b[j]))
    end

    for i = 1, #a do
        map[i] = ''
        local fname = canonical(a[i])
        for j = 1, #b do
            if fname == bname[j] then
                bname[j] = nil
                map[i] = j
                n = n + 1
                break
            end
        end
    end
    return n, map
end

--- CSV table is in the format:
--@table CSV
-- @field fname name of .csv file associated with table - used to save/restore table contents.
-- @field labels{} 1d array of column labels.
-- @field data{{}} 2d array of data.
-- @field differentOnFileSystem Internal flag to indicate a format mismatch between the file system and the in memory version of the CSV file.

-------------------------------------------------------------------------------
-- Save table t to a .CSV file
-- @param t database table to save.
-- @return table in same format
-- @see loadCSV
-- @usage
-- -- Append a line to the CSV file and write it back to storage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.addLineCSV(csvfile, { 1, 2, 3 })
-- csv.saveCSV(csvfile)
function _M.saveCSV(t)
    if t.differentOnFileSystem then
        dbg.warn("saveCSV: ", string.format("file format is different, overwriting %s", t.fname))
    end

    local f = io.open(t.fname, "w+")
    if f == nil then
        dbg.error("saveCSV: ", string.format("unable to write %s", t.fname))
    else
        writerow(f, t.labels)
        if t.data ~= nil then
            for _, row in ipairs(t.data) do
                writerow(f, row)
            end
        end
        f:close()
        sync()

        t.differentOnFileSystem = nil
    end

    return t
end

-------------------------------------------------------------------------------
-- Reads a .CSV file and returns a table with the loaded contents
-- If no CSV file found or contents different then file created with structure in it.
-- If the source table doesn't include the labels, then all fields will be loaded
-- and the labels will be filled in as per the file.
-- @param t is table, optionally with structure of expected CSV included
-- @return CSV table
-- @return A result code describing what was done (see below for explanation)
-- @see saveCSV
-- @usage
-- -- Append a line to the CSV file and write it back to storage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.addLineCSV(csvfile, { 1, 2, 3 })
-- csv.saveCSV(csvfile)
function _M.loadCSV(t)

    local f = io.open(t.fname,"r")
    local res = nil

    t.differentOnFileSystem = nil

    if f == nil then
         -- no file yet so create new one
         _M.saveCSV(t)
         res = "create"
    else
        local s = f:read("*l")
        if s == nil then
             -- file is empty so setup to hold t
             f:close()
             _M.saveCSV(t)
             res = "empty"
        else
            -- Check the labels are equal
            local fieldnames = _M.fromCSV(s)
            if t.labels == nil then
                t.labels = fieldnames
            end
            if equalCSV(t.labels, fieldnames) then

                -- Clear the current table and read in the existing data
                t.data = {}
                for s in f:lines() do
                    table.insert(t.data, _M.fromCSV(s))
                end
                f:close()
                res = "load"

            -- different format so initialize to new table format
            else
                -- Check if there are any common fields or not
                local n, fieldmap = checkCommonFields(t.labels, fieldnames)
                if n ~= 0 then
                    t.data = {}
                    for s in f:lines() do
                        local fields = _M.fromCSV(s)
                        local row = {}
                        for i = 1, #fieldmap do
                            if fieldmap[i] == '' then
                                table.insert(row, '')
                            else
                                table.insert(row, fields[fieldmap[i]])
                            end
                        end
                        table.insert(t.data, row)
                    end
                    f:close()

                    t.differentOnFileSystem = true

                    -- Figure out the possible return codes based on the field counts
                    if n == _M.numColsCSV(t) then
                        if n == #fieldnames then
                            res = "reordered"
                        else
                            res = "full"
                        end
                    else
                        res = "partial"
                    end
                else
                    f:close()
                    t.differentOnFileSystem = true
                    res = "immiscable"
                end
            end
        end
    end
    return t, res
end

--- Result codes from the loadCSV function.
--@table loadCSV
-- @field create File didn't exist, returned an empty CSV table
-- @field empty File was empty, returned an empty CSV table
-- @field load File loaded fine
-- @field full File had all fields but some extra fields too
-- @field reordered File had all fields but in a different order
-- @field partial File had some common fields, returned a populated CSV table
-- @field immiscable File had no common fields, returned an empty CSV table

-------------------------------------------------------------------------------
-- Set the maximum log size before log cycling
-- @param t CSV table
-- @param s Maximum log file size, this can be a number or a sting that can
-- include a suffix 'k' or 'm' for kilobytes and megabytes.
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- csv.setLogSize(csvTable, 10000)
function _M.setLogSize(t, s)
    if t ~= nil then
        if type(s) == 'string' then
            if sizings == nil then
                -- Only build this if required but cache it.
                local r = lpeg.float
                local function m(s, f)
                    return r / function(s) return s*f end * (lpeg.Pi(s) / '')
                end
                sizings = Cs(m('k', 1024) + m('m', 1048576) + C(r))
            end
            s = sizings:match(s)
        end

        t.logMaxSize = math.max(s, 2 + #toCSV(t.labels))
    end
end

-------------------------------------------------------------------------------
-- Query the maximum log size before log cycling occurs
-- @param t CSV table
-- @return Log cycle size
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- print('cycle size is ' .. csv.getLogSize(csvTable))
function _M.getLogSize(t)
    return t and t.logMaxSize or 100000
end

-------------------------------------------------------------------------------
-- Adds line of data to a CSV file but does not update local data in table
-- @param t is table describing CSV data
-- @param line is a row of data (1d array) to save
-- @see addLineCSV
-- @usage
-- -- Append a line to the CSV file in storage but not in memory
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.logLineCSV(csvfile, { 1, 2, 3 })
function _M.logLineCSV(t, line)
    if t ~= nil and line ~= nil then
        if t.differentOnFileSystem then
            dbg.error("logLineCSV: ", "failed due to format incompatibility, try saveCSV first")
        else
            appendrow(t, line)

            if stat(t.fname, 'size') > _M.getLogSize(t) then
                for i = 9, 1, -1 do
                    rename(t.fname .. '.' .. (i-1), t.fname .. '.' .. i)
                end
                rename(t.fname, t.fname .. '.0')
                _M.saveCSV(t)
            end
            t.data = nil
        end
    end
end

-------------------------------------------------------------------------------
-- Adds line of data to a table
-- @param t is table holding CSV data
-- @param line of data (1d array) to add to the table
-- @return row location of line new line in table
-- @see logLineCSV
-- @see remLineCSV
-- @usage
-- -- Append a line to the CSV file and write it back to storage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.addLineCSV(csvfile, { 1, 2, 3 })
-- csv.saveCSV(csvfile)
function _M.addLineCSV(t, line)
    if hasData(t) and line ~= nil then
        if #line ~= _M.numColsCSV(t) then
            dbg.warn("addLineCSV: ", "incorrect number of columns.  Expected " .. _M.numColsCSV(t) .. " have " .. #line)
            return nil
        end
        table.insert(t.data, line)
        return _M.numRowsCSV(t)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Makes a duplicate copy of a line of data
-- @param line is the line of data (1-d array)
-- @return duplicate copy of line
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- local line = { 1, 3, 5, 7, 9 }
-- local newline = csv.dupLineCSV(line)
--
-- if line == newline then
--     print('this is never executed')
-- end
function _M.dupLineCSV(line)
    if line ~= nil then
        local t = {}
        for k,v in pairs(line) do
            t[k] = v
        end
        return t
    end
    return nil
end

-------------------------------------------------------------------------------
-- Removes line of data in a table (does not save .CSV file)
-- @param t is table holding CSV data
-- @param row is row number of table data 1..n to remove.
-- removes last line of data if row is nil
-- @see addLineCSV
-- @usage
-- -- Remove all lines from the CSV table
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- while csv.numRowsCSV(csvfile) > 0 do
--     csv.remLineCSV(csvfile)
-- end
function _M.remLineCSV(t, row)
    if hasData(t) and row ~= nil and row > 0 and row <= _M.numRowsCSV(t) then
        table.remove(t.data, row)  -- remove line from the table
    end
end

-------------------------------------------------------------------------------
-- Look up a column in the passed CSV file
-- @param t CSV table
-- @param c Column number or name
-- @return Column index
-- @local
local function lookupColumn(t, c)
    if type(c) == 'string' then
        return _M.labelCol(t, c)
    end
    c = c or 1
    if c > _M.numColsCSV(t) or c < 1 then
        return nil
    end
    return c
end

-------------------------------------------------------------------------------
-- Returns a line of data from the table with matching val in column col
-- @param t is table holding CSV data
-- @param val is value of the cell to find
-- @param col is the column of data to match (default is col 1)
-- @return row that val found in or nil if not found
-- @return line of data found at that row with matching val data in column col
-- @see getRecordCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
--
-- -- Search for the value 3.14159 in the third column
-- local row, data = csv.getLineCSV(csvfile, 3.14159, 3)
-- print('3.14159 is in the third column in row '..row)
-- print('That row is: ' .. csv.tostringLine(data))
function _M.getLineCSV(t, val, col)
    if hasData(t) then
        col = lookupColumn(t, col)
        val = canonical(val)
        for k, v in ipairs(t.data) do
            if canonical(v[col]) == val then
                return k, v
            end
        end
    end
    return nil, nil
end

-------------------------------------------------------------------------------
-- Return a table containung a row of a CSV file.  Unlike getLineCSV, the
-- fields are named using the column labels.
-- @param t is table holding CSV data
-- @param val is value of the cell to find
-- @param col is the column of data to match (default is col 1)
-- @return table containing the fields index by their canonical names
-- @see getLineCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file', labels = { 'a', 'b', 'c' } }
--
-- csv.loadCSV(csvfile)
--
-- -- Search for the value 3.14159 in the C column
-- local row = csv.getRecordCSV(csvfile, 3.14159, 'c')
-- print('A is', row.a)
function _M.getRecordCSV(t, val, col)
    if hasData(t) then
        local ret, line = {}

        _, line = _M.getLineCSV(t, val, col)
        for i = 1, _M.numColsCSV(t) do
            ret[canonical(t.labels[i])] = line[i]
        end
        return ret
    end
    return nil
end

-------------------------------------------------------------------------------
-- Return a new CSV file that includes all records matching the given field
-- value.
-- @param t table holding CSV data
-- @param val value to match against
-- @param col column to match
-- @see getRecordCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local newTable = csv.selectCSV(oldTable, 'fred', 'name')
function _M.selectCSV(t, val, col)
    if not isCSV(t) then
        return nil
    end
    col = lookupColumn(t, col)
    val = canonical(val)
    local r = { labels = deepcopy(t.labels) }
    if hasData(t) then
        r.data = {}
        for k, v in ipairs(t.data) do
            if canonical(v[col]) == val then
                table.insert(r.data, v)
            end
        end
    end
    return r
end

-------------------------------------------------------------------------------
-- Returns a column of data in a 1-D table
-- @param csvtbl is table holding CSV data
-- @param col is the column of data to match (default is col 1), column names are allowed
-- @return a column of data
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- names = csv.getColCSV(db.material, 'material')           -- gather all material names
-- sel = dwi.selectOption('SELECT', names, names[1], true)  -- chose a material
--
-- -- alternatively, columns can be specified numerically:
--
-- names = csv.getColCSV(db.material, 'material')           -- gather all material names
-- sel = dwi.selectOption('SELECT', names, names[1], true)  -- chose a material
function _M.getColCSV(csvtbl, col)
    local column = {}
    local t, c = csvtbl, lookupColumn(csvtbl, col)

    if not hasData(t) or c == nil then
        return nil
    end

    for k,v in ipairs(t.data) do
        table.insert(column, v[c])
    end
    return column
end

-------------------------------------------------------------------------------
-- Returns the unique different values from a column of data in a 1-D table
-- @param csvtbl is table holding CSV data
-- @param col is the column of data to match (default is col 1), column names are allowed
-- @return a column of data
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- names = csv.getColCSV(db.material, 'material')                       -- gather all material names
-- sel = dwi.selectOption('SELECT', names, names[1], true)              -- chose a material
--
-- -- alternatively, columns can be specified numerically:
--
-- uniqueNames = csv.getUniqueColCSV(db.material, 'material')           -- gather all material names
-- sel = dwi.selectOption('SELECT', uniqueNames, uniqueNames[1], true)  -- chose a material
function _M.getUniqueColCSV(csvtbl, col)
    local c = _M.getColCSV(csvtbl, col)
    if c == nil then
        return nil
    elseif #c < 2 then
        return c
    end

    local s, r = {}, {}
    for _, v in ipairs(c) do
        table.insert(s, { o = v, k = canonical(v) })
    end
    table.sort(s, function(a, b) return a.k < b.k end)
    local i, prev = 0
    for _, v in ipairs(s) do
        if v.k ~= prev then
            prev = v.k
            table.insert(r, v.o)
        end
    end
    return r
end

-------------------------------------------------------------------------------
-- Clean up a CSV table converting all field names and string fields into
-- a canonical form.
-- @param t CSV table to convert
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.cleanCSV(csvTable)
-- csv.saveCSV(csvfile)
function _M.cleanCSV(t)
    if isCSV(t) then
        local d, rowCount = hasData(t), _M.numRowsCSV(t)
        for i = 1, _M.numColsCSV(t) do
            t.labels[i] = canonical(t.labels[i])
            if d then
                for j = 1, rowCount do
                    if type(t.data[j][i]) == 'string' then
                        t.data[j][i] = canonical(t.data[j][i])
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Convert a CSV file into a table indexed by the specified column names.
-- No uniqueness checks are performed for the key field.
-- @param csvtbl CSV table to extract
-- @param column Column name for the key field
-- @return Table containing the rows indexed by the key field.  Each row is
-- indexed by the label names not the label numbers.
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- local t = csv.toTableCSV(csvTable, 'truck')
-- print('The big red truck's tare is: ' .. t.bigred.tare)
function _M.toTableCSV(csvtbl, column)
    if hasData(csvtbl) then
        local c = lookupColumn(csvtbl, column)
        local r, l = {}, {}

        for i = 1, _M.numColsCSV(csvtbl) do
            l[i] = canonical(csvtbl.labels[i])
        end

        for _, v in ipairs(csvtbl.data) do
            local z = {}
            r[canonical(v[c])] = z
            for i = 1, #l do
                z[l[i]] = v[i]
            end
        end
        return r
    elseif isCSV(csvtbl) then
        return {}
    end
    return nil
end

-------------------------------------------------------------------------------
-- Replaces a line of data in the table (does not save the .CSV file)
-- @param t is table holding CSV data
-- @param row is the row number of the line of data
-- @param line is the line of data
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- csv.replaceLineCSV(csvfile, 3, { 1, 4, 9, 16 })
-- csv.saveCSV(csvfile)
function _M.replaceLineCSV(t, row, line)
    if row ~= nil and hasData(t) and row > 0 and row <= _M.numRowsCSV(t) then
        if line == nil then
            _M.remLineCSV(t, row)
        elseif #line == _M.numColsCSV(t) then
            t.data[row] = line
        end
    end
end

-------------------------------------------------------------------------------
-- Returns the column number of a particular label
-- @param t is table holding CSV data
-- @param label is name of column to find (not case sensitive)
-- @return column number of the label or nil if not found
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- print('The materials column is ' .. csv.labelCol(csvfile, 'material'))
function _M.labelCol(t, label)
    if label ~= nil and isCSV(t) then
        local label = canonical(label)

        for k,v in pairs(t.labels) do
            if canonical(v) == label then
                return k
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Converts contents of the CSV table into a print friendly string
-- @param t table to convert
-- @param w width to pad each cell to
-- @return string
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- print(csv.tostringCSV(csvtile))
function _M.tostringCSV(t, w)
    local csvtab = {}
    local w = w or 10

    table.insert(csvtab, 'File: '.. t.fname..'\r\n')
    table.insert(csvtab, padCSV(t.labels,w))
    table.insert(csvtab, '\r\n')
    for _,row in ipairs(t.data) do
         table.insert(csvtab, padCSV(row,w))
         table.insert(csvtab, '\r\n')
     end

    return table.concat(csvtab)
end

-------------------------------------------------------------------------------
-- Converts contents of the 1-D column of data into a print friendly string
-- @param c column of data convert
-- @return string
-- @see tostringLine
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- print('my column is')
-- print(csv.tostringCol({ 2, 3, 5, 7, 11, 13 })
function _M.tostringCol(c)
    if c == nil then
        return nil
    end

    local t = {}
    for _,v in ipairs(c) do
        table.insert(t,v)
        table.insert(t,'\r\n')
    end
    return table.concat(t)
end

-------------------------------------------------------------------------------
-- Converts contents of the row into a print friendly string
-- @param line of data to convert
-- @param w width to pad each cell to
-- @return string
-- @see tostringCol
-- @usage
-- local csv = require('rinLibrary.rinCSV')
--
-- print('perfection:')
-- print('    ' .. csv.tostringCol({ 6, 28, 496, 8128, 33550336, 8589869056 }, 11))
function _M.tostringLine(line, w)
    if line == nil then
        return nil
    end
    return padCSV(line, w or 10)
end

-------------------------------------------------------------------------------
-- returns the number of rows of data in CSV table
-- @param t CSV table
-- @return number of rows
-- @see numColsCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- print("the table has " .. csv.numRowsCSV(csvfile) .. " rows")
function _M.numRowsCSV(t)
    return hasData(t) and #t.data or 0
end

-------------------------------------------------------------------------------
-- returns the number of columns of data in CSV table
-- @param t CSV table
-- @return number of columns
-- @see numRowsCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvfile = { fname = '/tmp/temporary-file' }
--
-- csv.loadCSV(csvfile)
-- print("the table has " .. csv.numRowsCSV(csvfile) .. " columns")
function _M.numColsCSV(t)
    return isCSV(t) and #t.labels or 0
end

-------------------------------------------------------------------------------
--- Database Utilities.
-- Functions to manage multiple tables in a database.
-- A database a collection of CSV tables where each one has a unique name it
-- can be referred to by.  The database allows either selective or group
-- operations on the contained tables.
-- A database is a table containing name, value pairs.  The names are the CSV
-- table names and the values are the CSV tables themselves.
-- @section Database

-----------------------------------------------------------------------------------
-- Adds a database table to the database, updates contents with t if already present
-- @param db is the database table to populate
-- @param name is the name of table
-- @param t is the csv table to add
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'initial table', { fname = '/tmp/initial-file' } }
-- cvs.addTableDB(db, 'temporary table', { fname = '/tmp/temporary-file' })
function _M.addTableDB(db, name, t)
    local created = false

    -- Update existing database table with the new data.
    for k,v in pairs(db) do
        if v.fname == t.fname then
            db[k] = t
            created = true
        end
    end

    -- Add database table to the rinCSV database
    if not created then
        db[name] = t
    end
end

-------------------------------------------------------------------------------
-- Restores database contents from CSV files
-- Only loads in database tables already registered with database
-- @param db database table to populate
-- @see saveDB
-- @see loadCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'temporary table', { fname = '/tmp/temporary-file' } }
-- csv.loadDB(db)
function _M.loadDB(db)
    for k, t in pairs(db) do
       _M.loadCSV(t)
    end
end

-------------------------------------------------------------------------------
-- Adds line of data to a table in the database
-- @param db database table
-- @param name name of table in database to use
-- @param l line (1d array) of data to save
-- @see remLineDB
-- @see addLineCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'temporary table', { fname = '/tmp/temporary-file' } }
-- csv.loadDB(db)
-- csv.addLineDB(db, 'temporary table', { 2, 4, 6, 8, 12 })
function _M.addLineDB(db, name, l)
    _M.addLineCSV(db[name], l)
    _M.saveCSV(db[name])  -- save the table to .CSV file (overwriting the old one)
end

-------------------------------------------------------------------------------
-- Removes last line of data in a database table
-- @param db database table
-- @param name name of table to use
-- @param line is row number of table data 1..n to remove.
-- Removes last line if line is nil
-- @see addLineDB
-- @see remLineCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'temporary table', { fname = '/tmp/temporary-file' } }
-- csv.loadDB(db)
-- csv.remLineDB(db, 'temporary table', 3)
function _M.remLineDB(db, name, line)
    _M.remLineCSV(db[name].data, line)  -- remove last line from the table
    _M.saveCSV(db[name])  -- save the table to .CSV file (overwriting the old one)
end

-------------------------------------------------------------------------------
-- Save database to multiple CSV files
-- @param db database table
-- @see loadDB
-- @see saveCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'temporary table', { fname = '/tmp/temporary-file' } }
-- csv.loadDB(db)
-- csv.remLineDB(db, 'temporary table', 2)
-- csv.saveDB(db)
function _M.saveDB(db)
    for _, t in pairs(db) do
        _M.saveCSV(t)
    end
end

-------------------------------------------------------------------------------
-- Converts contents of the database into a print friendly string
-- @param db database table
-- @param w width of each cell
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local db = { 'temporary table', { fname = '/tmp/temporary-file' } }
-- csv.loadDB(db)
-- print(csv.tostringDB(db))
function _M.tostringDB(db, w)
    local csvtab = {}
    local w = w or 10

    for k, t in pairs(db) do
        table.insert(csvtab, k..':\r\n')
        table.insert(csvtab, 'File: '.. t.fname..'\r\n')
        table.insert(csvtab, padCSV(t.labels, w))
        table.insert(csvtab, '\r\n')
        for _,row in ipairs(t.data) do
            table.insert(csvtab, padCSV(row, w))
            table.insert(csvtab, '\r\n')
        end
    end
    return table.concat(csvtab)
end


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Expose some extra internals if we're part of the test suite
if _TEST then
    _M.equalCSV = equalCSV
    _M.escapeCSV = escapeCSV
    _M.padCSV = padCSV
    _M.toCSV = toCSV
end

return _M
