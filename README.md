# toynet
A simple event-driven I/O for Lua, coroutine based.

Support epoll and kevent

# build
* set lua header path in make.sh
* install scons
* run command: sh make.sh

# run (depends on header path in make.sh is luajit or lua)
* with luajit command: luajit example/echo_svr.lua
* with lua command: lua example/echo_svr.lua
