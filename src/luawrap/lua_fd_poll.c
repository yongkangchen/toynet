#include "lua52comp.h"

#include "fd_poll.h"

static int _poll_create(lua_State *L)
{
	int poll_fd = poll_create();
	lua_pushinteger(L, poll_fd);
	return 1;
}

static int _poll_close(lua_State *L)
{
	int poll_fd = luaL_checkint(L, 1);
	poll_close(poll_fd);
	return 0;
}

static int _poll_add(lua_State *L)
{
	int poll_fd = luaL_checkint(L, 1);
	int sock_fd = luaL_checkint(L, 2);
	int ret = poll_add(poll_fd, sock_fd);
	lua_pushinteger(L, ret);
	return 1;
}

static int _poll_mod(lua_State *L)
{
	int poll_fd = luaL_checkint(L, 1);
	int sock_fd = luaL_checkint(L, 2);
	bool read_enable = lua_toboolean(L, 3);
	bool write_enable = lua_toboolean(L, 4);
	int ret = poll_mod(poll_fd, sock_fd, read_enable, write_enable);
	lua_pushinteger(L, ret);
	return 1;
}

static int _poll_del(lua_State *L)
{
	int poll_fd = luaL_checkint(L, 1);
	int sock_fd = luaL_checkint(L, 2);
	poll_del(poll_fd, sock_fd);
	return 0;
}

static int _poll_wait(lua_State *L)
{
	int poll_fd = luaL_checkint(L, 1);
	time_t timeout = luaL_checkint(L, 2);
	luaL_checktype(L, 3, LUA_TFUNCTION);
	int max = luaL_optint(L, 4, 1024);
	
	struct event e[max];
	
	int n = poll_wait(poll_fd, timeout, e, max);
	int i;
	for(i = 0; i< n; i++)
	{
		lua_pushvalue(L, 3);
		lua_pushinteger(L, e[i].fd);
		lua_pushboolean(L, e[i].read);
		lua_pushboolean(L, e[i].write);
		lua_call(L, 3, 0);
	}
	return 0;
}

static const struct luaL_Reg lib[] =
{
	{"create", _poll_create},
	{"close", _poll_close},
	
	{"add", _poll_add},
	{"mod", _poll_mod},	
	{"del", _poll_del},
	
	{"wait", _poll_wait},

	{NULL,NULL}
};

int luaopen_fd_poll(lua_State *L)
{
	luaL_newlib(L, lib);
	return 1;
}
