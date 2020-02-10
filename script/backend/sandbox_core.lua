local config = require 'share.config'
local root = require 'backend.w2l_path'
local data_load_path = root / config.global.data_load
local data_load = assert(load(io.load(data_load_path), '@'..data_load_path:string(), 't'))()

---这个文件用来加载具体功能的，中转站作用，这个东西就是 w2l
return (require 'backend.sandbox')('.\\core\\', io.open, {
    ['w3xparser'] = require 'w3xparser',
    ['lni']       = require 'lni',
    ['lpeg']      = require 'lpeg',
    ['lml']       = require 'lml',
    ['lang']      = require 'share.lang',
    ['data_load'] = data_load,
})
