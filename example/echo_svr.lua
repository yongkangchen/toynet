package.cpath = package.cpath .. ";./libc/?.so"
package.path = package.path .. ";./lib/?.lua"

local log = require "log"
local LLOG = log.log

local tcp_svr = require "tcp_svr"
local timer = require "timer"

LLOG("add time: %d", os.time())
timer.add_timeout(3, function()
	LLOG("timeout end: %d", os.time())
end)

LLOG("listen: 0.0.0.0:9999")
tcp_svr("0.0.0.0", 9999, function(client)
	LLOG("accept: ", client.fd, client.ip, client.port)
	coroutine.wrap(function()
		while true do
			local msg = client:read_line()
			LLOG("recv [%s]: [%s]", client.ip, msg)
			client:write("you said: " .. msg.."\r\n")
		end
	end)()
end)
