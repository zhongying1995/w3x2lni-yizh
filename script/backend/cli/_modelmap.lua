local messager = require 'share.messager'
local core = require 'backend.sandbox_core'
local builder = require 'map-builder'
local lang = require 'share.lang'
local get_report = require 'share.report'
local check_lni_mark = require 'share.check_lni_mark'
local unpack_setting = require 'backend.unpack_setting'
local w2l = core()
local root = require 'backend.w2l_path'
local setting
local input_ar
local output_ar

local report = {}
local messager_report = messager.report
function messager.report(type, level, content, tip)
    messager_report(type, level, content, tip)
    local name = level .. type
    if not report[name] then
        report[name] = {}
    end
    table.insert(report[name], {content, tip})
end

local function default_output(input)
    if w2l.setting.target_storage == 'mpq' then
        if fs.is_directory(input) then
            return input:parent_path() / (input:filename():string() .. '.w3x')
        else
            return input:parent_path() / (input:stem():string() .. '_' .. w2l.setting.mode .. '.w3x')
        end
    end
end

local function get_io_time(map, file_count)
    local io_speed = map:get_type() == 'mpq' and 30000 or 10000
    local io_rate = math.min(0.3, file_count / io_speed)
    return io_rate
end

local function exit(report)
    local err = 0
    local warn = 0
    for k, t in pairs(report) do
        if k:sub(1, 1) == '1' then
            err = #t
        elseif k:sub(1, 1) == '2' then
            warn = #t
        end
    end
    if err > 0 then
        messager.exit('error', lang.script.ERROR_COUNT:format(err, warn))
    elseif warn > 0 then
        messager.exit('warning', lang.script.ERROR_COUNT:format(err, warn))
    else
        messager.exit('success', lang.script.ERROR_COUNT:format(err, warn))
    end
    return err, warn
end


--读取地图
--生成新的w3u和units.doo
--覆盖
--生成地图
---mode = ModelMap
return function ()
    w2l.messager.text(lang.script.INIT)
    w2l.messager.progress(0)

    w2l.messager.title 'ModelMap'
    
    w2l.log_path = root / 'log'
    fs.remove(w2l.log_path / 'report.log')

    setting = unpack_setting(w2l, 'ModelMap')
    
    messager.text(lang.script.OPEN_MAP)
    local err

    --script\map-builder\archive.lua
    input_ar, err = builder.load(setting.input)
    if not input_ar then
        w2l:failed(err)
    end
    if input_ar:get_type() == 'mpq' and not input_ar:get '(listfile)' then
        --不支持没有(listfile)的地图
        w2l:failed(lang.script.UNSUPPORTED_MAP)
    end

    w2l:set_setting(setting)

    w2l.input_ar = input_ar
    output = default_output(setting.input)
    setting.output = output
    output_ar, err = builder.load(output, 'w')
    if not output_ar then
        w2l:failed(err)
    end
    w2l.output_ar = output_ar

    --加载自定义插件
    local plugin_loader = require 'backend.plugin'
    plugin_loader(w2l, function (source, plugin)
        w2l:add_plugin(source, plugin)
    end)

    messager.text(lang.script.CHECK_PLUGIN)
    w2l:call_plugin 'on_convert'

    local slk = {}
    local file_count = input_ar:number_of_files()
    local input_rate = get_io_time(input_ar, file_count)
    local output_rate = get_io_time(output_ar, file_count)
    local frontend_rate = (1 - input_rate - output_rate) * 0.4
    local backend_rate = (1 - input_rate - output_rate) * 0.6

    --读取物编
    messager.text(lang.script.LOAD_OBJECT)
    w2l.progress:start(frontend_rate)
    Log.info('读取物编开始...')
    w2l:frontend(slk)
    Log.info('读取物编结束...')
    w2l.progress:finish()

    --修改数据，生成新的w3u

    --转换
    messager.text(lang.script.DO_CONVERT)
    w2l.progress:start(frontend_rate + backend_rate)
    w2l:backend(slk)
    w2l.progress:finish()

    --读取文件
    messager.text(lang.script.LOAD_FILE)
    w2l.progress:start(frontend_rate + backend_rate + input_rate)
    w2l:save()
    w2l.progress:finish()

    --生成文件
    messager.text(lang.script.SAVE_FILE)
    w2l.progress:start(1)
    builder.save(w2l, slk.w3i, slk.w3f, input_ar, output_ar)
    w2l.progress:finish()

    local clock = os.clock()
    messager.text(lang.script.FINISH:format(clock))
    local err, warn = exit(report)
    fs.create_directories(w2l.log_path)
    io.save(w2l.log_path / 'report.log', get_report(w2l, report, setting, clock, err, warn))
end