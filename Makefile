all: dir luajit fd_poll tcp buffer signal
dir: 
	mkdir -p libc 

luajit: 
	cd luajit && make


CCFlags := -Wall -Werror -std=gnu99 -g -Wl,-undefined -Wl,dynamic_lookup -I luajit/src -I ./src/net -llua 
fd_poll tcp:
	$(CC) -o libc/$@.so $(CCFlags) src/luawrap/lua_$@.c src/net/$@.c

buffer signal:
	$(CC) -o libc/$@.so $(CCFlags) src/luawrap/lua_$@.c