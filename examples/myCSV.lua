-------------------------------------------------------------------------------
-- myCSV
-- 
-- Show capabilities of the rinCSV library
-- 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 

local csv = require "rinLibrary.rinCSV"
local dbg = require "rinLibrary.rinDebug"
-------------------------------------------------------------------------------
-- Try and find materials.csv and check that it has the format below, 
-- otherwise make a new file with this default format
mat = csv.loadCSV({['fname'] = 'materials.csv',                 -- name of the CSV file
                   ['labels'] = {'Mat.No','Name','Density'},    -- labels defintion
                   ['data'] = {{1,'CEMENT',1.0}}}               -- default data,  use {{}} if none required
                  )
print('Table Contents:')
print(csv.tostringCSV(mat,10))
dbg.info('Material Table structure in Lua: ', mat)

print('Material Table Details')
print(string.format('%d Columns, %d Rows',csv.numColsCSV(mat),csv.numRowsCSV(mat)))
print('Names from Column 2')
print(csv.tostringCol(csv.getColCSV(mat,2)))    -- show all the data from column 2
print("Material Data for material 'CEMENT'")
-- search through the CSV table to find the row of data with 'CEMENT' in column 2
-- return the row index and the actual line of data
local row, line = csv.getLineCSV(mat,'CEMENT',2)    
print(' Row : ', row)
print('Line : ',csv.tostringLine(line,10))
print('Change Density to 5')
line[3] = 5
csv.replaceLineCSV(mat,row,line)
print(csv.tostringCSV(mat,10))

print('---------------------------------------------------')
print('Logging Data to File')

log = csv.loadCSV({['fname'] = 'test1.csv',
                   ['labels'] = {'Target','Actual','Fill Time'},
                   ['data'] = {}})
-- addLineCSV addsline ot the ram copy but does not save to disk
csv.addLineCSV(log,{1000,990,24.5})
csv.addLineCSV(log,{1200,1250,26.5})
csv.saveCSV(log)

-- logLineCSV logs to disk file and does not keep copy in Ram
csv.logLineCSV(log,{1500,1450,30.0})
csv.loadCSV(log)
print(csv.tostringCSV(log,10))
