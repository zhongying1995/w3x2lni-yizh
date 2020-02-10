local table_insert = table.insert
local table_concat = table.concat
require 'filesystem'

Log = {}
local CURRENT_PATH = fs.current_path():parent_path()

local time = os.date("%Y-%m-%d %H-%M-%S", os.time())

Log.path = ('%s\\log\\%s.log'):format(CURRENT_PATH, time):gsub('\\', '\\\\')

local std_print = print

local function write( str )
    if not Log.file then
        require 'filesystem'
        local path = fs.path( ('%s\\Log'):format(CURRENT_PATH) )
        if not fs.exists( path ) then
            fs.create_directory( path )
        end
        Log.file = io.open(Log.path, 'w')

    end
    Log.file:write( str )
    Log.file:write('\n')
end

local function get_string( ... )
    local ss = {}
    local args = { ... }
    for i = 1, #args do
        table_insert(ss, tostring(args[i]))
    end
    return table_concat(ss, '\t')
end


function Log.error(...)
    local s = '[error]:' .. get_string(...)
    local trc = debug.traceback()
	-- std_print(s)
    -- std_print(trc)
    write(s)
    write(trc)
end

function Log.info( ... )
    local s = '[info]:'.. get_string(...)
    -- std_print(s)
    write(s)
end
