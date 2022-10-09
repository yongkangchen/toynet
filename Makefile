ifeq (,$(findstring Windows,$(OS)))
  HOST_SYS:= $(shell uname -s)
else
  HOST_SYS= Windows
endif
TARGET_SYS?= $(HOST_SYS)
ifeq (Darwin,$(TARGET_SYS))
  MAKE_FLAG=MACOSX_DEPLOYMENT_TARGET=12.6	
endif

all: dir build_luajit fd_poll tcp buffer signal
dir:
	mkdir -p libc 

build_luajit:
	echo "foo"
	if test -d "./luajit" ; \
	then echo "luajit Dir exists"; \
	else \
		curl -o luajit.tar.gz https://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz; \
		tar -xzvf luajit.tar.gz; \
		mv LuaJIT-2.1.0-beta3 luajit; \
		rm -f luajit.tar.gz; \
		echo "compile luajit"; \
		cd luajit && make $(MAKE_FLAG); \
	fi
	

CCFlags := -Wall -Werror -std=gnu99 -g -fPIC -I luajit/src -I ./src/net -Wl,-undefined -Wl,dynamic_lookup

fd_poll tcp:
	$(CC) -o libc/$@.so $(CCFlags) -dynamiclib src/luawrap/lua_$@.c -dynamiclib src/net/$@.c

buffer signal:
	$(CC) -o libc/$@.so $(CCFlags) -dynamiclib src/luawrap/lua_$@.c

clean:
	rm -rf libc
	cd luajit && make clean

run:
	./luajit/src/luajit ./example/echo_svr.lua 