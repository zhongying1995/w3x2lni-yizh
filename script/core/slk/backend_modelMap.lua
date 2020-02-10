local math_floor = math.floor
local select = select
local string_unpack = string.unpack
local lang = require 'lang'

local mt = {}
mt.__index = mt

function mt:add(format, ...)
    self.hexs[#self.hexs+1] = (format):pack(...)
end


local INTERVAL
local COUNT
local COL, ROW
local W3E_WIDTH, W3E_HEIGHT



---读二进制文件时，下一个字节的起始位
local unpack_pos
local function set_pos(...)
    unpack_pos = select(-1, ...)
    return ...
end
local function unpack(str, unpack_buf)
    return set_pos(string_unpack(str, unpack_buf, unpack_pos))
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

--[[
    在we中，64*64的地图里面，实际上是16*16个大格子
    也就是比例1=128码
]]
local backend_modelMap_w3e = function (self, old_chunk)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    unpack_pos = 1
    local _unpack = unpack
    local unpack = function ( fmt )
        return _unpack( fmt, old_chunk )
    end

    tbl:add('c4', unpack('c4'))
    
    --版本
    tbl.version = 11
    tbl:add('L', unpack('L'))

    --地形类型
    tbl:add('b', unpack('b'))
    --自定义类型，地形类型
    tbl:add('L', unpack('L'))

    --地面纹理
    local tileset_size = unpack('L')
    tbl:add('L', tileset_size)
    for i = 1, tileset_size do
        tbl:add('c4', unpack('c4'))
    end

    --悬崖纹理
    local cliffset_size = unpack('L')
    tbl:add('L', cliffset_size)
    for i = 1, cliffset_size do
        tbl:add('c4', unpack('c4'))
    end

    --宽高=格子数+1
    unpack('L')
    unpack('L')
    local size_width = W3E_WIDTH
    local size_height = W3E_HEIGHT

    --写入 宽，高
    tbl:add('L', size_width)
    tbl:add('L', size_height)

    --偏移，左下角
    unpack('f')
    unpack('f')
    tbl:add('f',  -(size_width-1)*128/2)
    tbl:add('f', -(size_height-1)*128/2 )

    -- Log.info(('width=%s, height=%s, offset_width = %s, offset_height=%s'):format(size_width, size_height, -(size_width-1)*128/2, -(size_height-1)*128/2))
    --读一个格子的数据好了
        --高度
        local height = (unpack('H')-8192) / 512
        --水面高度
        local water_and_edge = unpack('H')
        local water_height = ((water_and_edge & 0x3FFF) - 8192) / 512
        local map_edge = water_and_edge & 0x4000

        local texture_and_flags = unpack('B')
        local ground_texture = texture_and_flags & 0x0f
        --斜坡
        local ramp = texture_and_flags & 0x10
        local blight = texture_and_flags & 0x20
        local water = texture_and_flags & 0x40
        local boundary = texture_and_flags & 0x80

        --水平变化
        local variation = unpack('B')
        local ground_variation = variation & 0x1f
        local cliff_variation = ((variation) & 0xe0) >> 5

        local misc = unpack('B')
        local cliff_texture = (misc & 0xf0) >> 4
        local layer_height = misc & 0x0f
    --更改数据
        height = 0
        ----水面高度
        water_height = 0
        water = 0
        ----贴图纹理类型
        ground_texture = 1
        ramp = 0
        --水平的变化:凹下凸起
        ground_variation = 0
        cliff_variation = 0
        --msic，悬崖纹理
        layer_height = 0

    --写出每一个点位置的贴图状态等
    for i = 1, size_height do
        for j = 1, size_width do

            --地面高度
            tbl:add('H', height*512 +8192 )

            --水面高度
            local water_and_edge = math_floor( water_height * 512 + 8192 + map_edge )
            tbl:add('H', water_and_edge)

            --贴图纹理类型
            local texture_and_flags = ground_texture + ramp + blight + water + boundary
            tbl:add('B', texture_and_flags)

            --水平的变化:凹下凸起
            local variation = math_floor( ground_variation + (cliff_variation << 5) )
            tbl:add('B', variation)

            --msic，悬崖纹理
            local misc = math_floor( (cliff_texture << 4) + layer_height )
            tbl:add('B', misc)

        end
    end

    --还原数据
    unpack_pos = nil


    return table.concat(tbl.hexs)
end

local backend_modelMap_w3e_origin = function (self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    --版本
    tbl.version = 11

    --地形类型：L，
    tbl.tileset = 76

    --地面纹理
    tbl.tileset_ids =  {
        'Ldrt',
        'Ldro',
        'Ldrg',
        'Lrok',
        'Lgrs',
        'Lgrd',
    }

    --悬崖纹理
    tbl.cliffset_ids = {
        'CLdi',
        'CLgr',
    }

    tbl:add('c4', 'W3E!')

    tbl:add('L', tbl.version)

    tbl:add('b', tbl.tileset)
    tbl:add('L', 0)

    tbl:add('L', #tbl.tileset_ids)
    for i = 1, #tbl.tileset_ids do
        tbl:add('c4', tbl.tileset_ids[i])
    end

    tbl:add('L', #tbl.cliffset_ids)
    for i = 1, #tbl.cliffset_ids do
        tbl:add('c4', tbl.cliffset_ids[i])
    end

    --宽高=格子数+1
    local width = W3E_WIDTH
    local height = W3E_HEIGHT


    --写入 宽，高
    tbl:add('L', width)
    tbl:add('L', height)

    --偏移，左下角
    tbl:add('f', -(width-1)*128/2)
    tbl:add('f', -(height-1)*128/2)

    --写出每一个点位置的贴图状态等
    for i = 1, height do
        for j = 1, width do
            --地面高度
            tbl:add('h', 8192)

            --水面高度
            tbl:add('h', 24576)

            --贴图纹理类型
            tbl:add('b', 0)

            --水平的变化:凹下凸起
            tbl:add('b', 16)

            --msic，悬崖纹理
            tbl:add('b', -14)

        end
    end

    return table.concat(tbl.hexs)
end

local backend_modelMap_shd = function ( self )
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    local width = (W3E_WIDTH-1) * 4
    local height = (W3E_HEIGHT-1)*4

    for i = 1, width * height do
        tbl:add('b', 0)
    end

    return table.concat(tbl.hexs)
end

local backend_modelMap_unitsdoo = function (self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    tbl:add('c4', 'W3do')
    tbl:add('L', 8)
    tbl:add('L', 11)

    --需要写出的单位个数
    local count = COUNT
    tbl:add('L', count)

    local col = COL
    local row = ROW


    local interval = INTERVAL
    local width = col * interval
    local height = row * interval
    
    local start_x = -width/2
    local start_y = height/2
    local M_PIl = 3.14159265358979
    local ang = 270* M_PIl / 180

    --Log.info(('count=%s, col=%s, (%s, %s)'):format(count, col, start_x, start_y))
    local len = (W3E_WIDTH-1)*128/2
    local minx = -len
    local maxx = len
    local miny = -len
    local maxy = len

    local index = 0
    --写每一个单位
    for _, unit in pairs(self.model_map_obj_list) do
        index = index + 1
        tbl:add('c4', unit.id)
        tbl:add('L', 0)
        local x = start_x + interval * (((index-1)%col)+1)
        local y = start_y - interval * (math_floor((index-1)/col)+1)
        if x <= minx then
            x = minx + 32
        elseif x >= maxx then
            x = maxx - 32
        end
        if y <= miny then
            y = miny + 32
        elseif y >= maxy then
            y = maxy - 32
        end

        --对于单位来说，z是没意义的
        local z = 0
        tbl:add('f', x)
        tbl:add('f', y)
        tbl:add('f', z)
        tbl:add('f', ang)
        --大小
        tbl:add('f', 1)
        tbl:add('f', 1)
        tbl:add('f', 1)

        --flags
        tbl:add('b', 0)

        --player
        tbl:add('L', 0)

        --unknown
        tbl:add('b', 0)
        tbl:add('b', 0)
        
        --life mana
        tbl:add('L', 100)
        tbl:add('L', 100)
        
        --item_table_pointer
        tbl:add('L', 0)
        --item_sets
        tbl:add('L', 0)

        --gold
        tbl:add('L', 0)
        tbl:add('f', 0)

        --level, str, agi, int
        tbl:add('L', 1)
        tbl:add('L', 0)
        tbl:add('L', 0)
        tbl:add('L', 0)

        --items size
        tbl:add('L', 0)

        --abilities size
        tbl:add('L', 0)
        
        --random_type
        tbl:add('L', 0)
        tbl:add('b', 0)
        tbl:add('b', 0)
        tbl:add('b', 0)
        tbl:add('b', 0)

        tbl:add('L', 0)
        tbl:add('L', 0)
        tbl:add('L', 0)
    end

    Log.info( ('写出数量：%s，实际数量：%s'):format(COUNT, index) )

    -- --Log.info(table.concat(tbl.hexs))
    return table.concat(tbl.hexs)
end

local backend_modelMap_unitsdoo1 = function (self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    tbl:add('c4LL', 'W3do', 8, 11)
    tbl:add('L', 0)

    return table.concat(tbl.hexs)
end

--这个保存仅能够补充缺失而使用
local backend_modelMap_doo = function (self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    tbl:add('c4LL', 'W3do', 8, 11)
    tbl:add('L', 0)

    --write_special_version
    tbl:add('L', 0)
    --special_doodads
    tbl:add('L', 0)

    return table.concat(tbl.hexs)
end



local restore_wtg = function ()
    local buf = load_file('defined\\war3map.wtg', 'rb')
    return buf
end
local restore_wct = function ()
    local buf = load_file('defined\\war3map.wct', 'rb')
    return buf
end
local restore_imp = function ()
    
end
local restore_w3s = function ()
    
end
local restore_w3r = function ()
    return load_file('defined\\war3map.w3r', 'rb')
end
local restore_w3c = function ()
    local buf = load_file('defined\\war3map.w3c', 'rb')
    return buf
end

local to_be_restored_files = {
    ['war3map.wtg'] = restore_wtg,
    ['war3map.wct'] = restore_wct,
    -- ['war3map.imp'] = restore_imp,
    ['war3map.w3r'] = restore_w3r,
    ['war3map.w3c'] = restore_w3c,
}
---补全文件
local function restore_files(w2l)
    local total = 0
    for _ in pairs(to_be_restored_files) do
        total = total + 1
    end
    local count = 0
    w2l.messager.text('补全缺少的文件：开始')

    for filename, callback in pairs(to_be_restored_files) do
        if not w2l:file_load('map', filename) then
            w2l:file_save('map', filename, callback() )
        end
        w2l.messager.text(lang.script.LOAD_MAP_FILE:format(count, total))
        w2l.progress(count / total)
    end

    w2l.messager.text('补全缺少的文件：结束')
end


---清空物编文件
local function clear_object_files(w2l)
    local list = {
        'war3map.w3a',--技能
        'war3map.w3b',--可破坏物
        'war3map.w3t',--物品
        'war3map.w3d',--地形装饰物
        'war3map.w3h',--buff
        'war3map.w3q',--科技
    }
    for _, filename in ipairs(list) do
        if w2l:file_load('map', filename) then
            w2l:file_remove('map', filename)
        end
    end
end

return function (w2l)

    INTERVAL = 512
    COUNT = #w2l.model_map_obj_list
    COL = math.ceil( math.sqrt(COUNT) )
    ROW = COL

    --宽高=格子数+1，不知道为什么要+1，但数据是这样那就这样吧
    local width = math.ceil( COL*INTERVAL / (32*128) ) * 32 + 1
    W3E_WIDTH = width
    W3E_HEIGHT = width

    w2l.messager.text('根据模型生成doo：开始')
    w2l.progress(0.2)
    if w2l:file_load('map', 'war3map.w3e') then
        local chunk = w2l:file_load('map', 'war3map.w3e')
        w2l:file_remove('map', 'war3map.w3e')
        w2l:file_save('map', 'war3map.w3e', backend_modelMap_w3e(w2l, chunk) )
        Log.info('生成w3e，使用原来的w3e')
    else
        w2l:file_save('map', 'war3map.w3e', backend_modelMap_w3e_origin(w2l) )
        Log.info('生成w3e，原生的')
    end
    w2l.progress(0.4)
    if w2l:file_load('map', 'war3map.shd') then
        w2l:file_remove('map', 'war3map.shd')
    end
    w2l:file_save('map', 'war3map.shd', backend_modelMap_shd(w2l) )
    w2l.progress(0.6)

    if w2l:file_load('map', 'war3mapunits.doo') then
        w2l:file_remove('map', 'war3mapunits.doo')
    end
    w2l:file_save('map', 'war3mapunits.doo', backend_modelMap_unitsdoo(w2l) )
    w2l.progress(0.8)

    if w2l:file_load('map', 'war3map.doo') then
        w2l:file_remove('map', 'war3map.doo')
    end
    w2l:file_save('map', 'war3map.doo', backend_modelMap_doo(w2l) )
    w2l.progress(1)
    w2l.messager.text('根据模型生成doo：结束')

    restore_files(w2l)

    clear_object_files(w2l)

end