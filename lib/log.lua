local string_format = string.format
local clog = function(type, file, line, funname, str)
    print(string_format("[%s:%s:%s:LEV_%d] %s", file, line, funname, type, str))
end

local function __FILE__() return debug.getinfo(4,'S').source  end
local function __LINE__() return debug.getinfo(4, 'l').currentline end
local function __FUNC__() return debug.getinfo(4, 'n').name or "*" end

local function llog( type, str)
    clog( type, __FILE__(), __LINE__(), __FUNC__(), str)
end

local function table_dump( object )
    if type(object) == 'table' then
        local s = '{ '
        for k,v in pairs(object) do
            if type(k) ~= 'number' then k = string.format("%q", k) end
            s = s .. '['..k..'] = ' .. table.dump(v) .. ','
        end
        return s .. '} '
    elseif type(object) == 'function' then
        return string.dump(object)
    elseif type(object) == 'string' then
        return string.format("%q", object)
    else
        return tostring(object)
    end
end

local debug_traceback = debug.traceback

local function LSAFE_FORMAT( ... )
    local success,result = pcall(string_format, ...)
    if not success then
        local msg = table_dump{...}
        return 'LOG_ERROR: ' .. result .. msg .. "\n" ..debug_traceback()
    end
    return result
end

local LLOG_TRACE = 2
local LLOG_LOG   = 4
local LLOG_ERR   = 8

local log = {}
function log.trace( ... )
	llog(LLOG_TRACE, LSAFE_FORMAT(...))
end

function log.log( ... )
	llog(LLOG_LOG, LSAFE_FORMAT(...))
end

function log.error( ... )
	llog(LLOG_ERR, LSAFE_FORMAT(...))
end
return log