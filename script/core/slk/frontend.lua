local lang = require 'lang'
local pairs = pairs
local type = type
local w2l
local select = select
local string_unpack = string.unpack

local function has_slk(w2l)
    for _, name in ipairs(w2l.info.txt) do
        if w2l:file_load('map', name) then
            return true
        end
    end
    for _, slks in pairs(w2l.info.slk) do
        for _, name in ipairs(slks) do
            if w2l:file_load('map', name) then
                return true
            end
        end
    end
    if w2l:file_load('map', 'war3mapmisc.txt') then
        return true
    end
    return false
end

local function load_slk(w2l)
    if w2l.setting.mode == 'ModelMap' then
        return w2l:get_default(true)
    end
    if w2l.force_slk then
        --物编信息不完整,强制读取slk文件
        w2l.messager.report(lang.report.OTHER, 9, lang.report.FORCE_READ_SLK)
    end
    if (w2l.force_slk or w2l.setting.read_slk) and has_slk(w2l) then
        return w2l:frontend_buildslk(true)
    else
        return w2l:get_default(true)
    end
end

local function load_obj(w2l, wts)
    local objs = {}
    local count = 0
    for _, type in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc'} do
        local name = w2l.info.obj[type]
        local buf = w2l:file_load('map', name)
        local count = count + 1
        if buf then
            w2l.messager.text(lang.script.CONVERT_ONE .. name)
            objs[type] = w2l:frontend_obj(type, buf, wts)
            w2l.progress(count / 8)
        end
    end
    return objs
end

local function load_lni(w2l)
    local lnis = {}
    local count = 0
    for type, name in pairs(w2l.info.lni) do
        count = count + 1
        local buf = w2l:file_load('table', type)
        if buf then
            w2l.messager.text(lang.script.CONVERT_ONE .. type)
            lnis[type] = w2l:frontend_lni(type, buf, type)
            w2l.progress(count / 8)
        end
    end

    local buf = w2l:file_load('table', 'txt')
    if buf then
        lnis['txt'] = w2l:parse_lni(buf, 'txt')
    end
    return lnis
end

local function load_w3i(w2l, slk)
    local buf = w2l:file_load('table', 'w3i')
    if buf then
        Log.info('加载 w3i 使用方式 1')
        return w2l:parse_lni(buf, 'w3i')
    else
        buf = w2l:file_load('map', 'war3map.w3i')
        Log.info('加载 w3i 使用方式 2', buf and 'buf 存在')
        if buf then
            return w2l:frontend_w3i(buf, slk.wts)
        end
    end
    return nil
end

local function update_version(w2l, w3i)
    if not w3i then
        return
    end
    local melee = w3i[lang.w3i.CONFIG][lang.w3i.MELEE_MAP]
    local set   = w3i[lang.w3i.CONFIG][lang.w3i.GAME_DATA_SETTING]
    if set == -1 or set == 0 then
        if melee == 0 then
            w2l.setting.version = 'Custom'
        elseif melee == 1 then
            w2l.setting.version = 'Melee'
        end
    elseif set == 1 then
        w2l.setting.version = 'Custom'
    elseif set == 2 then
        w2l.setting.version = 'Melee'
    end
    w2l:set_setting(w2l.setting)
end

local displaytype = {
    unit = lang.script.UNIT,
    ability = lang.script.ABILITY,
    item = lang.script.ITEM,
    buff = lang.script.BUFF,
    upgrade = lang.script.UPGRADE,
    doodad = lang.script.DOODAD,
    destructable = lang.script.DESTRUCTABLE,
}

local function get_displayname(o)
    local name
    if o._type == 'buff' then
        name = o.bufftip or o.editorname
    elseif o._type == 'upgrade' then
        name = o.name[1]
    elseif o._type == 'doodad' or o._type == 'destructable' then
        name = w2l:get_editstring(o.name or '')
    else
        name = o.name
    end
    return (name:sub(1, 100):gsub('\r\n', ' '))
end

local function mark_keep_obj(type, objs)
    if type ~= 'ability' then
        return
    end
    for id, obj in pairs(objs) do
        for k in pairs(obj) do
            if k:sub(1, 1) ~= '_' then
                goto CONTINUE
            end
        end
        obj._keep_obj = true
        w2l.messager.report(lang.report.INVALID_OBJECT, 6, lang.report.ABILITY_REMOVED:format(id), lang.report.ABILITY_REMOVED_HINT)
        ::CONTINUE::
    end
end


local function update_then_merge(w2l, slks, objs, lnis, slk)
    for _, type in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc', 'txt'} do
        local report, report2
        local data = slks[type]
        local obj = objs[type]
        if obj then
            if type ~= 'misc' then
                report, report2 = w2l:frontend_updateobj(type, obj, data)
            end
        else
            obj = {}
        end
        if lnis[type] then
            w2l:frontend_updatelni(type, lnis[type], data)
            for k, v in pairs(lnis[type]) do
                obj[k] = v
            end
        end
        if w2l.setting.mode == 'slk' then
            mark_keep_obj(type, obj)
        end
        slk[type] = w2l:frontend_merge(type, data, obj)
        if report then
            for i = 1, 10 do
                local data = report[i]
                if not data then
                    break
                end
                local displayname = get_displayname(slk[type][data[1]])
                --无效的物编数据
                w2l.messager.report(lang.report.INVALID_OBJECT_DATA, 6, ('%s %s %s'):format(displaytype[type], data[1], displayname), ('[%s]: %s'):format(data[2], data[3]))
            end
        end
        if report2 then
            for i = 1, 10 do
                if not report2[i] then
                    break
                end
                --无效的物编数据
                w2l.messager.report(lang.report.INVALID_OBJECT_DATA, 6, report2[i][1], report2[i][2])
            end
        end
    end
end


local math_floor = math.floor
local char = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local len = #char
local id_index = 1
local function get_temp_id( )
    local index = id_index
	index = index - 1
    local c = math_floor( index / len / len )
	local b = math_floor( (index - c*len*len) / len )
    local a = index - b * len - c*len*len
	a = a + 1
    b = b + 1
    c = c + 1
    id_index = id_index + 1
	return 'u' .. char:sub(c, c) .. char:sub(b, b) .. char:sub(a, a)
end



local function check_mdx_file_second_power( w2l, mdx_filename )
    ---读二进制文件时，下一个字节的起始位
    local unpack_pos
    local function set_pos(...)
        unpack_pos = select(-1, ...)
        return ...
    end
    local function unpack(str, unpack_buf)
        return set_pos(string_unpack(str, unpack_buf, unpack_pos))
    end

    local buf = w2l:file_load('map', mdx_filename)
    if buf then

        --强行绕过这个错误算了，不分析mdx了
        if buf:find('KP2R') then
            Log.info('该模型存在非WE渲染方式[KP2R]:', mdx_filename)
            return 'KP2R\\' .. mdx_filename
        end
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
            
            if w2l:file_load('map', texture_name) then
                local blp_buf = w2l:file_load('map', texture_name)
                unpack_pos = 1
                local flag = unpack('c4', blp_buf)
                local compression = unpack('L', blp_buf)
                local flags = unpack('L', blp_buf)
                local width = unpack('L', blp_buf)
                local height = unpack('L', blp_buf)
                if width & (width-1) ~= 0 or height & (height-1) ~= 0 then
                    --表示该模型存在非2次幂贴图
                    Log.info('该模型存在非2次幂贴图:', mdx_filename)
                    return mdx_filename .. '_2'
                end
            end
        end
    end
    return mdx_filename
end

---读取物编
return function(w2l_, slk)
    w2l = w2l_
    slk = slk or {}
    w2l.slk = slk
    --读取字符串
    slk.wts = w2l:frontend_wts(w2l:file_load('map', 'war3map.wts'))
    w2l.progress(0.2)

    slk.w3i = load_w3i(w2l, slk)
    update_version(w2l, slk.w3i)

    --正在读取物编
    w2l.messager.text(lang.script.LOAD_OBJ)
    w2l.progress:start(0.4)
    local objs = load_obj(w2l, slk.wts)
    w2l.progress:finish()

    --读取lni
    w2l.messager.text(lang.script.LOAD_LNI)
    w2l.progress:start(0.6)
    local lnis = load_lni(w2l)
    w2l.progress:finish()

    --读取slk
    w2l.messager.text(lang.script.LOAD_SLK)
    w2l.progress:start(0.8)
    local slks = load_slk(w2l)
    w2l.progress:finish()

    --伪造一份w3u数据
    if w2l.setting.mode == 'ModelMap' then
        local filenames = {}
        for type, name, buf in w2l:file_pairs() do
            if type == 'resource' and ( name:sub(-4):lower() == '.mdx' or name:sub(-4):lower() == '.mdl') then
                filenames[#filenames+1] = name
            end
        end
        --给他固定顺序，免得每次都不一样的顺序
        table.sort(filenames, function (sec, fir)
            return sec < fir
        end)

        objs.unit = {}
        local list = {}
        for count, name in ipairs(filenames) do
            --检测二进制错误
            local error, new_name = pcall( check_mdx_file_second_power, w2l, name )
            if error then
                name = new_name
            else
                Log.error('检测二进制贴图时，发现错误：', name)
            end
            local id = get_temp_id()
            local obj = {
                _id= id,
                _obj= true,
                _parent= 'hfoo',
                _type= 'unit',
                unam = {
                    ('%.4d'):format(count),
                },
                dshd = {
                    '',
                },
                umvh = {
                    128,
                },
                umdl = {
                    name,
                }
            }
            objs.unit[id] = obj

            --obj这个表好像会被改掉，懒得看了，直接这样吧
            local t = { id = id }
            for _k, _v in pairs(obj) do
                t[_k] = _v
            end
            list[#list+1] = t
        end
        
        w2l.model_map_obj_list = list
    end
    -- Log.info('-------------------------------------- obj')
    -- for name, obj in pairs(objs.unit) do
    --     Log.info( '>>>>', name, obj)
    --     for k, v in pairs(obj) do
    --         if type(v) == 'table' then
    --             for lv, _v in pairs(v) do
    --                 Log.info(('%s=%s(%s)'):format(k, _v, lv))
    --             end
    --         else
    --             Log.info(('%s=%s'):format(k, v))
    --         end
    --     end
    -- end

    
    --合并物编数据
    w2l.messager.text(lang.script.MERGE_OBJECT)
    w2l.progress:start(1)
    update_then_merge(w2l, slks, objs, lnis, slk)
    w2l.progress:finish()

    w2l.messager.text(lang.script.DO_PLUGIN)
    w2l:call_plugin('on_full')
end
