local mt = {}
mt.__index = mt

function mt:add(format, ...)
    self.hexs[#self.hexs+1] = (format):pack(...)
end

--版本
mt.version = 11

--地形类型：L，
mt.tileset = 76

--地面纹理
mt.tileset_ids =  {
    'Ldrt',
    'Ldro',
    'Ldrg',
    'Lrok',
    'Lgrs',
    'Lgrd',
}

--悬崖纹理
mt.cliffset_ids = {
    'CLdi',
    'CLgr',
}

--[[
    在we中，64*64的地图里面，实际上是16*16个大格子
    也就是比例1=128码
]]

--这个保存仅能够补充缺失而使用
return function(self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

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

    --需要写出的单位个数
    local count = #self.model_map_obj_list
    local col = math.ceil( math.sqrt(count) )
    local interval = 256
    local size = col * interval

    --宽高=格子数+1
    local width = math.ceil( size / (32*128) ) * 32 + 1
    local height = width

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
