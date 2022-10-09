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

local tcp = require "tcp"
local tcp_write = tcp.write
local tcp_read = tcp.read
local tcp_listen = tcp.listen
local tcp_accept = tcp.accept
local tcp_close = tcp.close
local tcp_keepalive = tcp.keepalive
local tcp_nodelay = tcp.nodelay
local tcp_connect = tcp.connect

local buffer = require "buffer"
local buffer_pool = {}
local buffer_new = buffer.new
local buffer_push = buffer.push
local buffer_size = buffer.size
local buffer_pop = buffer.pop
local buffer_readline = buffer.readline
local buffer_clear = buffer.clear

local timer = require "lib.net.timer"
local timer_update = timer.update

local poll_obj = require "lib.net.poll"()
local poll_obj_watch = poll_obj.watch
local poll_obj_del = poll_obj.del
local poll_obj_wait = poll_obj.wait

local debug_traceback = debug.traceback
local LERR = require "lib.net.log".error
local error = error

local string_sub = string.sub
local assert = assert
local xpcall = xpcall


local function create_client(client_fd, ip, port)
	if client_fd < 0 then
		LERR("invalid client_fd: %d", client_fd)
		return
	end

	if BAN_ENABLE and not BAN_WHITE[ip] and BAN_IP_TBL[ip] then
		tcp_close(client_fd)
		return
	end

	tcp_keepalive(client_fd, true)
	tcp_nodelay(client_fd, true)

	local event_write_enable
	local write_buf = ""
	local on_write_done

	local function write_cb()
		if #write_buf == 0 then
			if client_fd then
				event_write_enable(false)
			end

			if on_write_done then
				on_write_done()
			end
		elseif client_fd then
			local n = tcp_write(client_fd, write_buf)
			write_buf = string_sub(write_buf, n + 1)
		end
	end

	local event = poll_obj_watch(client_fd, write_cb)
	if not event then
		tcp_close(client_fd)
		return
	end

	event_write_enable = event.write_enable

	local event_wait = event.wait
	local function read(n)
		if client_fd == nil then
			return -1
		end
		event_wait()
		if client_fd == nil then
			return -1
		end
		return tcp_read(client_fd, n)
	end

	local read_buf = buffer_new()
	local function read_buf_fill(self)
		local n, data = read(1024)
		if n <= 0 then
			local fd = client_fd
			self:close()
			error("[disconnected]: "..(fd or "nil"))
			return
		end
		buffer_push(read_buf, buffer_pool, data, n)
	end

	local client = {
		fd = client_fd,
		ip = ip,
		port = port,
		read_count = function(self, count, byte)
			if count == 0 then
				return ""
			end

			while true do
				if buffer_size(read_buf) >= count then
					return buffer_pop(read_buf, buffer_pool, count, byte)
				end
				read_buf_fill(self)
			end
		end,
		read_util = function(self, str)
			local data
			while true do
				data = buffer_readline(read_buf, buffer_pool, str)
				if data then
					break
				end
				read_buf_fill(self)
			end
			return data
		end,
		read_line = function(self)
			return self:read_util("\r\n")
		end,

		write = function(_, msg)
			assert(client_fd ~= nil)

			if #write_buf == 0 then
				local n = tcp_write(client_fd, msg)
				if #msg == n then
					if on_write_done then
						on_write_done()
					end
					return
				end
				msg = msg:sub(n+1)
			end

			write_buf = write_buf .. msg
			event_write_enable(true)
		end,

		close = function(self)
			if client_fd == nil then
				return
			end
			poll_obj_del(client_fd)
			tcp_close(client_fd)
			if self.on_close then
				local ok, ret = xpcall(self.on_close, debug_traceback, self, client_fd, buffer_size(read_buf))
				if not ok then
					LERR("handler error: %s", debug_traceback(ret))
				end
			end
			client_fd = nil
			self.fd = nil
			self.ip = nil
			buffer_clear(read_buf, buffer_pool)
			event.dispose()
		end,

		close_after_send = function(self)
			if on_write_done ~= nil then
				return
			end

			if #write_buf == 0 then
				self:close()
			else
				on_write_done = function()
					on_write_done = nil
					self:close()
				end
			end
		end
	}
	return client
end

local function create_server(addr, port)
	local svr_fd = tcp_listen(addr, port)
	assert(svr_fd ~= -1, "listen ".. port .. " failed")

	local event = poll_obj.watch(svr_fd)
	assert(event, "add to poll failed")
	local event_wait = event.wait

	return function()
		event_wait()
		return create_client(tcp_accept(svr_fd))
	end
end

local function loop()
	while true do
		poll_obj_wait(timer_update())
	end
end

local function bind(addr, port, on_accept)
	local accept = create_server(addr, port)
	coroutine.wrap(function()
		while true do
			local client = accept()
			if client then
				on_accept(client)
			end
		end
	end)()
end

return {
	create_client = create_client,
	connect = function(addr, port)
		return create_client(tcp_connect(addr, port))
	end,
	loop = loop,
	bind = bind,
	start = function(addr, port, on_accept)
		bind(addr, port, on_accept)
		local _, err = pcall(loop)
		print(err)
	end
}
