#include "lua52comp.h"

#include "tcp.h"

#include <arpa/inet.h>
#include <stdlib.h>

static int _tcp_listen(lua_State *L)
{
	const char * host = luaL_checkstring(L, 1);
	int port = luaL_checkint(L, 2);
	int backlog = luaL_optint(L, 3, 128);

	int fd = tcp_listen(host, port, backlog);
	lua_pushinteger(L, fd);
	return 1;
}

static int _tcp_connect(lua_State* L)
{
	const char * addr = luaL_checkstring(L, 1);
	int port = luaL_checkint(L, 2);
	int fd = tcp_connect(addr, port);
	lua_pushinteger(L, fd);
	return 1;
}

static int _tcp_accept(lua_State *L)
{
	int svrfd = luaL_checkint(L, 1);
	char ip[INET6_ADDRSTRLEN] = {0};
	int port = -1;
	int fd = tcp_accept(svrfd, ip, INET6_ADDRSTRLEN, &port);
	lua_pushinteger(L, fd);
	lua_pushstring(L, ip);
	lua_pushinteger(L, port);
	return 3;
}

static int _tcp_write(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	size_t count;
	const char* buf = luaL_checklstring(L, 2, &count);

	int ret = tcp_write(fd, buf, count);
	lua_pushinteger(L, ret);
	return 1;
}

static int _tcp_read(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	int count = luaL_optint(L, 2, 1024);

	char *data = malloc(count);
	int ret = tcp_read(fd, data, count);
	lua_pushinteger(L, ret);
	if(ret <= 0 )
	{
		free(data);
		return 1;
	}
	lua_pushlightuserdata(L, data);
	return 2;
}

static int _tcp_close(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	int ret = tcp_close(fd);
	lua_pushinteger(L, ret);
	return 1;
}

static int _tcp_nonblock(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	int non_block = lua_toboolean(L, 2);
	int ret = tcp_nonblock(fd, non_block);
	lua_pushinteger(L, ret);
	return 1;
}

static int _tcp_keepalive(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	int keep_alive = lua_toboolean(L, 2);
	int ret = tcp_keepalive(fd, keep_alive);
	lua_pushinteger(L, ret);
	return 1;
}

static int _tcp_nodelay(lua_State *L)
{
	int fd = luaL_checkint(L, 1);
	int keep_alive = lua_toboolean(L, 2);
	int ret = tcp_nodelay(fd, keep_alive);
	lua_pushinteger(L, ret);
	return 1;
}

static const struct luaL_Reg lib[] =
{
	{"listen", _tcp_listen},
	{"accept", _tcp_accept},

	{"connect", _tcp_connect},

	{"write", _tcp_write},
	{"read", _tcp_read},

	{"close", _tcp_close},
	{"nonblock", _tcp_nonblock},
	{"keepalive", _tcp_keepalive},
	{"nodelay", _tcp_nodelay},

	{NULL,NULL}
};

int luaopen_tcp(lua_State *L)
{
	luaL_newlib(L, lib);
	return 1;
}
