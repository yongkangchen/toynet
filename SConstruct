LUA_SRC = ARGUMENTS.get('luasrc')

if not LUA_SRC:
	print "please run: scons luasrc='path of lua src'"
	exit(0)

env = Environment(CCFLAGS='-Wall -Werror -std=gnu99 -g')
env.Append(LINKFLAGS = '-Wl,-undefined -Wl,dynamic_lookup')

env.Append(CPPPATH=[LUA_SRC])

SConscript('src/SConscript', variant_dir='build', exports = 'env', duplicate = 0)