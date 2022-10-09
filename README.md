# toynet
A simple event-driven I/O for Lua, coroutine based.

Support epoll and kevent

# build
### build with scons
* set lua/luajit header path in make.sh
* install scons
* run command: sh make.sh

### build with make
* put luajit source code directory in ./luajit/
* run command: make

# run
* with luajit command: luajit example/echo_svr.lua
* with lua command: lua example/echo_svr.lua
