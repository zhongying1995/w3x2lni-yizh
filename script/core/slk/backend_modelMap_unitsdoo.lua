local math_floor = math.floor

local mt = {}
mt.__index = mt

function mt:add(format, ...)
    self.hexs[#self.hexs+1] = (format):pack(...)
end

function mt:add_head()
    self:add('c4LL', 'W3do', 8, 11)
end

function mt:add_data()
    self:add('L', 0)
end

--这个保存仅能够补充缺失而使用
return function(self)
    local tbl = setmetatable({}, mt)
    tbl.hexs = {}
    tbl.self = self

    tbl:add('c4', 'W3do')
    tbl:add('L', 8)
    tbl:add('L', 11)

    --需要写出的单位个数
    local count = #self.model_map_obj_list
    tbl:add('L', count)

    local col = math.ceil( math.sqrt(count) )
    local row = math.ceil( math.sqrt(count) )

    --单位与单位的间隔
    local interval = 256
    local width = col * interval
    local height = row * interval
    
    local start_x = -width/2
    local start_y = height/2
    local M_PIl = 3.14159265358979
    local ang = 270* M_PIl / 180

    --Log.info(('count=%s, col=%s, (%s, %s)'):format(count, col, start_x, start_y))
    
    local index = 0
    --写每一个单位
    for _, unit in pairs(self.model_map_obj_list) do
        index = index + 1
        tbl:add('c4', unit.id)
        tbl:add('L', 0)
        local x = start_x + interval * (((index-1)%col)+1)
        local y = start_y - interval * (math_floor((index-1)/col)+1)
        --Log.info(('[%s]=(%s, %s)'):format(index, x, y))
        tbl:add('f', x)
        tbl:add('f', y)
        tbl:add('f', 0)
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


    -- --Log.info(table.concat(tbl.hexs))
    return table.concat(tbl.hexs)
end
