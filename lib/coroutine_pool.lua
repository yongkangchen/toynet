--[[
https://github.com/yongkangchen/toynet

The MIT License (MIT)

Copyright (c) 2016 Yongkang Chen <lx1988cyk at gmail dot com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local assert = assert
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_create = coroutine.create
local table_remove = table.remove
local table_insert = table.insert
local string_find = string.find
local debug_traceback = debug.traceback

local log = require "lib.net.log"
local LLOG = log.log
local LERR = log.error

local used_list = setmetatable({}, { __mode = "kv" })
local function check_ok(co, ok, err, ...)
    if ok then
        return ok, err, ...
    end

    if string_find(err, "[disconnected]", 1, true) ~= nil then
        LLOG(err)
    else
        LERR("resume error: %s", debug_traceback(co, err))
    end
    used_list[co] = nil
end

local function resume(co, ...)
    return check_ok(co, coroutine_resume(co, ...))
end

local free_list = setmetatable({}, { __mode = "kv" })
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
