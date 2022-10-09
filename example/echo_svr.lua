package.cpath = package.cpath .. ";./libc/?.so"

local LLOG = require "lib.net.log".log

LLOG("add time: %d", os.time())
require "lib.net.timer".add_timeout(3, function()
	LLOG("timeout end: %d", os.time())
end)

local coroutine_pool_wrap = require "lib.net.coroutine_pool".wrap

LLOG("listen: 0.0.0.0:9999")
require "lib.net.tcp_svr".start("0.0.0.0", 9999, function(client)
	LLOG("accept: ", client.fd, client.ip, client.port)
	coroutine_pool_wrap(function()
		while true do
			local msg = client:read_line()
			LLOG("recv [%s]: [%s]", client.ip, msg)
			client:write("you said: " .. msg.."\r\n")
		end
	end)()
end)
