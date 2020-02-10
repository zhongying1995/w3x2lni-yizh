require 'log'
Log.info('加载 main.lua成功')


if _W2L_MODE == 'CLI' then
    -- w2l.messager.report('运行 main', 0, '执行 CLI', ' ')
    require 'backend'
    return
elseif _W2L_MODE == 'GUI' then
    -- w2l.messager.report('运行 main', 0, '执行 GUI', ' ')
    --双击 exe 时，执行这里
    Log.info('马上加载 gui.new.main')
    require 'gui.new.main'
end
