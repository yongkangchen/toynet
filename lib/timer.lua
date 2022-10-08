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

local table_insert = table.insert
local math_min = math.min
local coroutine_pool_wrap = require "lib.net.coroutine_pool".wrap
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort

local timer = {}

local function compare_time(a, b)
	return a.time < b.time
end

local function create_timer(get_current_time)
	local time_wheel = {}
	local function timer_update()
		local now = get_current_time()
		local wait = -1
		local execute_tbl = {}
		for time, tbl in pairs(time_wheel) do
			local diff = (time - now) * 1000
			if diff > 0 then
				wait = wait == -1 and diff or math_min(wait, diff)
			else
				time_wheel[time] = nil
				tbl.time = time
				table_insert(execute_tbl, tbl)
			end
		end

		if #execute_tbl ~= 0 then
			table_sort(execute_tbl, compare_time)
			for _, tbl in ipairs(execute_tbl) do
				tbl.time = nil
				for _, func in ipairs(tbl) do
					coroutine_pool_wrap(func)()
				end
			end
			return timer_update(0)
		end
		return wait
	end

	return function(sec, func)
		local time = get_current_time() + sec
		local pool = time_wheel[time]
		if not pool then
			pool = {}
			time_wheel[time] = pool
		end
		table_insert(pool, func)
	end, timer_update
end

local update

local add_timeout, timer_update = create_timer(os.time)
timer.add_timeout = add_timeout
update = timer_update

timer.update = function()
	return update()
end

local enable_mstime = false
function timer.enable_mstime()
	if enable_mstime then
		return
	end

	enable_mstime = true

	local ffi = require("ffi")
	ffi.cdef[[
	    typedef long time_t;
	    typedef struct timeval {
			time_t tv_sec;
			time_t tv_usec;
		} timeval;

		int gettimeofday(struct timeval* t, void* tzp);
	]]

	local t = ffi.new("timeval")
	local gettimeofday = ffi.C.gettimeofday
	local function getmstime()
		gettimeofday(t, nil)
		return tonumber(t.tv_sec) + tonumber(t.tv_usec)/1000.0/1000.0
	end

	local add_mtimeout, mtimer_update = create_timer(getmstime)
	timer.add_mtimeout = add_mtimeout
	update = function()
		local a = mtimer_update()
        local b = timer_update()
		if a < 0 then
			return b
        end
 		if b < 0 then
			return a
		end
		return math_min(a, b)
	end
end

return timer
