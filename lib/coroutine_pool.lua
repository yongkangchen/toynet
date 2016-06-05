
local table_remove = table.remove
local table_insert = table.insert

local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume

local log = require "log"
local LLOG = log.log
local LERR = log.error

local traceback = debug.traceback

local used_list = {}
local function check_ok(co, ok, err, ...)
    if ok then
        return ok, err, ...
    end
    
    if err:find("[disconnected]", 1, true) ~= nil then
        LLOG(err)
    else
        LERR("resume error: %s", traceback(co, err))
    end
    used_list[co] = nil
end

local function resume(co, ...)
    return check_ok(co, coroutine_resume(co, ...))
end
    
local free_list = {}
local function create( func )
    local co = table_remove(free_list)
    if co == nil then
        co = coroutine_create(function(...)
            func(...)
            while true do
                func = nil
                
                table_insert(free_list, co)
                used_list[co] = nil

                func = coroutine_yield()
                if func == nil then
                    used_list[co] = nil
                    break
                end
                func(coroutine_yield())
            end
        end)
    else
        assert(func ~= nil)
        resume(co, func)
    end
    used_list[co] = true
    return co
end
    
local function wrap(func)
    local co = create(func)
    return function(...)
        resume(co, ...)
    end
end

return {
    create = create,
    wrap = wrap,
    resume = resume
}