local command = require 'backend.command'
local messager = require 'share.messager'
local lang = require 'share.lang'
local act = command[1]
require 'log'
Log.info('这里是点击了 开始 按钮后的入口')
if not act then
    act = 'help'
end

Log.info('--------------------- 参数>>>')
for k, v in pairs(command) do
    Log.info(('[%s]%s'):format(k, v))
end
Log.info('--------------------- 参数<<<')

if package.searchpath('backend.cli.' .. act, package.path) then
    local fn = require('backend.cli.' .. act)
    if type(fn) == 'function' then
        fn(command)
    end
else
    messager.raw(lang.raw.INVALID:format(act))
end
