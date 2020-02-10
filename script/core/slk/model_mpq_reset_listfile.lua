local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_sub = string.sub
local select = select
local string_unpack = string.unpack
local lang = require 'lang'

--搜索文件 function
local search_file, scan_file

--存放当前mpq中存在的文件的列表
local listfile

--需要分析的mpq地图
local w2l, input_archive

---读二进制文件时，下一个字节的起始位
local unpack_pos
local function set_pos(...)
    unpack_pos = select(-1, ...)
    return ...
end
local function unpack(str, unpack_buf)
    return set_pos(string_unpack(str, unpack_buf, unpack_pos))
end


local function is_has( filename )
    return listfile[filename]
end
local index = 0
local function add_file( filename )
    index = index + 1
    -- Log.info('添加'..index..':', filename)
    listfile[filename] = true
end

local function load_file(path, mode)
    local f = io.open(path, mode )
    if f then
        local buf = f:read 'a'
        f:close()
        return buf
    end
    return nil
end


---从mdx文件中，分析结构解析贴图
local function analyse_blp_form_mdx( filename )
    if filename:sub(-4, -1) == '.mdx' or filename:sub(-4, -1) == '.mdl' then
        local buf = input_archive:get(filename)
        local start = buf:find('TEXS')
        unpack_pos = start
        local flag = unpack( 'c4', buf )
        local size = unpack( 'L', buf)

        local Texture_size = 268
        local current_size = 0

        while (current_size<size) do
            current_size = current_size + Texture_size

            local replaceableId = unpack('L', buf)
            local texture_name = unpack('c256', buf):gsub('%z', '')
            local unknow = unpack('L', buf)
            local wraps = unpack('L', buf)
            local warp_width = wraps & 1
            local warp_height = wraps & 2
           
            if not is_has(texture_name) then
                if input_archive:has_file(texture_name) then
                    add_file(texture_name)
                else
                    -- Log.info('缺少blp', texture_name)
                end
            end
           
        end
    end
end


---搜索文件 function
search_file = function(filename)
    if input_archive:has_file(filename) then
        if not is_has(filename) then
            add_file(filename)

            --通用分析
            local buf = input_archive:get(filename)

            --格式一
            for str in buf:gmatch('[\\#%*+%._%-%a%d]+') do
                scan_file(str)
            end
            --格式二
            for str in string_gmatch(buf, '=[^\n]+\n') do
                local s = str:sub(-2)
                str = str:sub(2)
                str = string_gsub(str, '\n', '')
                str = string_gsub(str, '\r', '')
                scan_file(str)
            end
            --格式三
            for str in string_gmatch(buf, '"[^"]-"') do
                str = string_sub( str, 2, -2 )
                str = string_gsub(str, '\\\\', '\\')
                scan_file(str)
            end

            --分析mdx数据
            if filename:sub(-4, -1) == '.mdx' or filename:sub(-4, -1) == '.mdl' then
                for str in buf:gmatch('[\\+%._%-%a%d]+') do
                    scan_file(str)
                end
            end
        end
    end
end

--扫描文件，会对str做一些修改，并在此查找
scan_file = function (str)
    search_file(str)
    if str:sub(-4, -1) == '.mdl' then
        str = str:gsub('.mdl', '.mdx')
        search_file(str)
    end
end



---搜索已知的listfile
local function scan_defined_list_files()
    local total = input_archive:number_of_files()
    local count = 0
    local clock = os.clock()

    local buf = load_file 'defined\\listfile.txt'
    for str in buf:gmatch('[^\n]+\n') do
        str = str:gsub('\r', '')
        str = str:gsub('\n', '')
        search_file(str)
        count = count + 1
        if os.clock() - clock > 0.1 then
            clock = os.clock()
            w2l.messager.text(lang.script.LOAD_MAP_FILE:format(count, total))
            w2l.progress(count / total)
        end
    end
end


--搜索lua文件
local function san_lua_list_files()
    local buf
    local jass = { 'war3map.j','Scripts\\war3map.j' }
    for _, name in ipairs(jass) do
        if input_archive:has_file(name) then
            buf = input_archive:get(name)
            break
        end
    end

    if buf then
        local lua_find

        for str in buf:gmatch('Cheat[%s]*%([%s]*"($1)"[%s]*%)') do
            Log.info(str)
            lua_find = true
        end

        --搜索一下内置
        if not lua_find then
            if input_archive:has_file('callback') then
                
            end
        end
    end
end



local function save( name, buf )
    local lname = name:lower()
    input_archive.case[lname] = name
    input_archive.cache[lname] = buf
end

--还原 缺少的(listfile)
return function ( _w2l, _input_archive )

    w2l = _w2l
    listfile = {}
    input_archive = _input_archive
    w2l.messager.text('还原listfile：开始')

    scan_defined_list_files()
    san_lua_list_files()

    local list = {}
    for name in pairs(listfile) do
        list[#list+1] = name
    end

    table.sort(list, function (sec, fir)
        return sec < fir
    end)
    list[#list+1] = ''

    local buf = table.concat(list, '\r\n')
    local name = '(listfile)'
    save(name, buf)

    w2l.messager.text('还原listfile：结束')



end