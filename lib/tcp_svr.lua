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

local timer = require "timer"
local poll = require "poll"

local debug_traceback = debug.traceback
local LERR = require "log".error

local function create_client(poll_obj, client_fd, ip, port)
	local event_write_enable
	local write_buf = ""
	local on_write_done
	
	local function write_cb()
		if #write_buf == 0 then
			event_write_enable(false)
			if on_write_done then
				on_write_done()
			end
		else
			local n = tcp_write(client_fd, write_buf)
			write_buf = write_buf:sub(n + 1)
		end
	end

	local event = poll_obj.watch(client_fd, write_cb)
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
		return tcp_read(client_fd, n)
	end

	local read_buf = buffer_new()
	local function read_buf_fill(self)
		local n, data = read(1024)
		if n <= 0 then
			local fd = client_fd
			self:close()
			error("[disconnected]: "..fd)
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
			
			poll_obj.del(client_fd)
			tcp.close(client_fd)
			
			if self.on_close then
				local ok, ret = xpcall(self.on_close, debug_traceback, self, client_fd)
				if not ok then
					LERR("handler error: %s", debug_traceback(ret))
				end
			end
			client_fd = nil
			self.fd = nil
			self.ip = nil
			buffer_clear(read_buf, buffer_pool)
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

local function create_server(poll_obj, addr, port)
	local svr_fd = tcp_listen(addr, port)
	assert(svr_fd ~= -1, "listen ".. port .. " failed")
	
	local event = poll_obj.watch(svr_fd)
	assert(event, "add to poll failed")
	local event_wait = event.wait
	
	return {
		keepalive = true,
		nodelay = true,
		accept = function(self)
			while true do
				event_wait()
				local client_fd, client_ip, client_port = tcp_accept(svr_fd)
				if client_fd ~= -1 then
					local client = create_client(poll_obj, client_fd, client_ip, client_port)
					if client then
						if self.keepalive then
							tcp_keepalive(client_fd, true)
						end
						if self.nodelay then
							tcp_nodelay(client_fd, true)
						end
						return client
					end
				end
			end
		end
	}
end

local poll_obj = poll()

return {
	create_server = function(addr, port, on_accept)
		local server = create_server(poll_obj, addr, port)
		
		coroutine.wrap(function()
			while true do
				local client = server:accept()
				on_accept(client)
			end
		end)()
		
		local pre_time = os.time()
		while true do
			local cur_time = os.time()
			local timeout = timer.update(cur_time - pre_time)
			pre_time  = cur_time
			
			poll_obj.wait(timeout)
		end
	end,
	connect = function(...)
		return create_client(poll_obj, tcp_connect(...))
	end,
}