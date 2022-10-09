package.cpath = package.cpath .. ";./libc/?.so"

local tcp_connect = require "lib.net.tcp_svr".connect
local function get(host, path, is_ssl, ip)
	local client = tcp_connect(ip, is_ssl and 443 or 80)
	if not client then
		return
	end

	--TODO: ssl

	local method = "GET"
	local header_content = "host: " .. host .. "\r\n"
	local request = string.format("%s %s HTTP/1.1\r\n%s\r\n\r\n", method, path, header_content)
	client:write(request)

	local body
	-- local code = lines[1]:match "^HTTP/[%d%.]+%s+([%d]+)%s+(.*)$"

	local headers = {}
	while true do
		local line = client:read_util("\r\n")
		if line == "" then
			break
		end

		local name, value = line:match "^(.-):%s*(.*)"
		if name and value then
			headers[name:lower()] = value:lower()
		end
	end

	local content_length = tonumber(headers["content-length"])
	local t = headers["transfer-encoding"]
	if t and t ~= "identity" then
		body = ""
		while true do
			local count = client:read_util("\r\n")
			count = tonumber(count, 16)
			if not count then
				break
			end

			local str = client:read_count(count + 2)

			if count == 0 then
				break
			end
			assert(str:sub(-2) == "\r\n")
			body = body .. str:sub(0, -3)
		end
	elseif content_length then
		body = client:read_count(content_length)
	else
		body = ""

		client.on_close = function(_, _, size)
			body = body .. client:read_count(size)
		end

		while client.fd do
			if not pcall(function()
				body = body .. client:read_count(1024)
			end) then
				break
			end
		end
	end

	client:close()
	return body
end

local function request(url, ip)
	local scheme
	url = string.gsub(url, "^([%w][%w%+%-%.]*)%:", function(s)
		scheme = s
		return ""
	end)

	local host
	url = string.gsub(url, "^//([^/]*)", function(s)
	   host = s
	   return ""
	end)

	if url == "" then
		url = "/"
	end

	return get(host, url, scheme == "https", ip)
end


require "lib.net.timer".add_timeout(0, function()
	coroutine.wrap(function()
		print(request("http://www.baidu.com", "183.232.231.173")) --TODO: host to ip
	end)()
end)

require "lib.net.tcp_svr".loop()
