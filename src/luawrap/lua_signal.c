#include "lua52comp.h"

#include <signal.h>
#include <errno.h>
#include <string.h>

static int status (lua_State *L, int s)
{
    if (s)
    {
        lua_pushboolean(L, 1);
        return 1;
    }
    else
    {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
}

static int _signal_ignore(lua_State *L)
{
    if (signal(SIGPIPE, SIG_IGN)) return status(L, 0);
    return 0;
}

static const struct luaL_Reg lib[] =
{
    {"ignore", _signal_ignore},

    {NULL,NULL}
};

int luaopen_signal(lua_State *L)
{
    luaL_newlib(L, lib);
    return 1;
}