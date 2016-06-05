/*
* modify from https://github.com/cloudwu/skynet/blob/master/lualib-src/lua-socket.c
*/

#include "lua52comp.h"

#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

// 2 ** 12 == 4096
#define LARGE_PAGE_NODE 12

struct buffer_node {
	char * msg;
	int sz;
	struct buffer_node *next;
};

struct socket_buffer {
	int size;
	int offset;
	struct buffer_node *head;
	struct buffer_node *tail;
};

static int
lfreepool(lua_State *L) {
	struct buffer_node * pool = lua_touserdata(L, 1);
	int sz = lua_rawlen(L,1) / sizeof(*pool);
	int i;
	for (i=0;i<sz;i++) {
		struct buffer_node *node = &pool[i];
		if (node->msg) {
			free(node->msg);
			node->msg = NULL;
		}
	}
	return 0;
}

static int
lnewpool(lua_State *L, int sz) {
	struct buffer_node * pool = lua_newuserdata(L, sizeof(struct buffer_node) * sz);
	int i;
	for (i=0;i<sz;i++) {
		pool[i].msg = NULL;
		pool[i].sz = 0;
		pool[i].next = &pool[i+1];
	}
	pool[sz-1].next = NULL;
	if (luaL_newmetatable(L, "buffer_pool")) {
		lua_pushcfunction(L, lfreepool);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lnewbuffer(lua_State *L) {
	struct socket_buffer * sb = lua_newuserdata(L, sizeof(*sb));	
	sb->size = 0;
	sb->offset = 0;
	sb->head = NULL;
	sb->tail = NULL;
	
	return 1;
}

static int lsize(lua_State *L)
{
	struct socket_buffer *sb = lua_touserdata(L,1);
	if (sb == NULL) {
		return luaL_error(L, "need buffer object at param 1");
	}
	lua_pushinteger(L, sb->size);
	return 1;
}

/*
	userdata send_buffer
	table pool
	lightuserdata msg
	int size

	return size
 */
static int
lpushbuffer(lua_State *L) {
	struct socket_buffer *sb = lua_touserdata(L,1);
	if (sb == NULL) {
		return luaL_error(L, "need buffer object at param 1");
	}

	int pool_index = 2;
	luaL_checktype(L, pool_index, LUA_TTABLE);

	luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
	char * msg = lua_touserdata(L, 3);
	if (msg == NULL) {
		return luaL_error(L, "need message block at param 3");
	}
	
	int sz = luaL_checkinteger(L, 4);

	lua_rawgeti(L, pool_index, 1);
	struct buffer_node * free_node = lua_touserdata(L, -1);	// sb poolt msg size free_node
	lua_pop(L,1);

	if (free_node == NULL) {
		int tsz = lua_rawlen(L,pool_index);
		if (tsz == 0)
			tsz++;
		int size = 8;
		if (tsz <= LARGE_PAGE_NODE-3) {
			size <<= tsz;
		} else {
			size <<= LARGE_PAGE_NODE-3;
		}
		lnewpool(L, size);	
		free_node = lua_touserdata(L, -1);
		lua_rawseti(L, pool_index, tsz + 1);
	}

	lua_pushlightuserdata(L, free_node->next);
	lua_rawseti(L, pool_index, 1);	// sb poolt msg size
	free_node->msg = msg;
	free_node->sz = sz;
	free_node->next = NULL;

	if (sb->head == NULL) {
		assert(sb->tail == NULL);
		sb->head = sb->tail = free_node;
	} else {
		sb->tail->next = free_node;
		sb->tail = free_node;
	}
	sb->size += sz;

	lua_pushinteger(L, sb->size);
	return 1;
}

static void
return_free_node(lua_State *L, int pool, struct socket_buffer *sb) {
	struct buffer_node *free_node = sb->head;
	sb->offset = 0;
	sb->head = free_node->next;
	if (sb->head == NULL) {
		sb->tail = NULL;
	}
	lua_rawgeti(L,pool,1);
	free_node->next = lua_touserdata(L,-1);
	lua_pop(L,1);
	free(free_node->msg);
	free_node->msg = NULL;

	free_node->sz = 0;
	lua_pushlightuserdata(L, free_node);
	lua_rawseti(L, pool, 1);
}

static void luaL_pushbytes(lua_State* L, const char* s, int sz)
{
	for (int i=0; i<sz; i++){
    	lua_pushinteger(L, (unsigned char)(s[i]));
	}
}

static void
pop_bytes(lua_State *L, struct socket_buffer *sb, int sz, int skip) {
	struct buffer_node * current = sb->head;
	if (sz < current->sz - sb->offset) {
		luaL_pushbytes(L, current->msg + sb->offset, sz-skip);
		sb->offset+=sz;
		return;
	}
	if (sz == current->sz - sb->offset) {
		luaL_pushbytes(L, current->msg + sb->offset, sz-skip);
		return_free_node(L,2,sb);
		return;
	}

	for (;;) {
		int bytes = current->sz - sb->offset;
		if (bytes >= sz) {
			if (sz > skip) {
				luaL_pushbytes(L, current->msg + sb->offset, sz - skip);
			} 
			sb->offset += sz;
			if (bytes == sz) {
				return_free_node(L,2,sb);
			}
			break;
		}
		int real_sz = sz - skip;
		if (real_sz > 0) {
			luaL_pushbytes(L, current->msg + sb->offset, (real_sz < bytes) ? real_sz : bytes);
		}
		return_free_node(L,2,sb);
		sz-=bytes;
		if (sz==0)
			break;
		current = sb->head;
		assert(current);
	}
}

static void
pop_lstring(lua_State *L, struct socket_buffer *sb, int sz, int skip) {
	struct buffer_node * current = sb->head;
	if (sz < current->sz - sb->offset) {
		lua_pushlstring(L, current->msg + sb->offset, sz-skip);
		sb->offset+=sz;
		return;
	}
	if (sz == current->sz - sb->offset) {
		lua_pushlstring(L, current->msg + sb->offset, sz-skip);
		return_free_node(L,2,sb);
		return;
	}

	luaL_Buffer b;
	luaL_buffinit(L, &b);
	for (;;) {
		int bytes = current->sz - sb->offset;
		if (bytes >= sz) {
			if (sz > skip) {
				luaL_addlstring(&b, current->msg + sb->offset, sz - skip);
			} 
			sb->offset += sz;
			if (bytes == sz) {
				return_free_node(L,2,sb);
			}
			break;
		}
		int real_sz = sz - skip;
		if (real_sz > 0) {
			luaL_addlstring(&b, current->msg + sb->offset, (real_sz < bytes) ? real_sz : bytes);
		}
		return_free_node(L,2,sb);
		sz-=bytes;
		if (sz==0)
			break;
		current = sb->head;
		assert(current);
	}
	luaL_pushresult(&b);
}

/*
	userdata send_buffer
	table pool
	integer sz
	return_type: byte or string
 */
static int
lpopbuffer(lua_State *L) {
	struct socket_buffer * sb = lua_touserdata(L, 1);
	if (sb == NULL) {
		return luaL_error(L, "Need buffer object at param 1");
	}
	luaL_checktype(L,2,LUA_TTABLE);
	
	int sz = luaL_checkinteger(L,3);
	bool return_byte = lua_toboolean(L, 4);
	
	if (sb->size < sz || sz == 0) {
		lua_pushnil(L);
		return 1;
	} else if(return_byte){
		pop_bytes(L, sb, sz, 0);
		sb->size -= sz;
		return sz;
	} else{
		pop_lstring(L,sb,sz,0);
		sb->size -= sz;
		return 1;	
	}
}

/*
	userdata send_buffer
	table pool
 */
static int
lclearbuffer(lua_State *L) {
	struct socket_buffer * sb = lua_touserdata(L, 1);
	if (sb == NULL) {
		return luaL_error(L, "Need buffer object at param 1");
	}
	luaL_checktype(L,2,LUA_TTABLE);
	while(sb->head) {
		return_free_node(L,2,sb);
	}
	return 0;
}

static int
lreadall(lua_State *L) {
	struct socket_buffer * sb = lua_touserdata(L, 1);
	if (sb == NULL) {
		return luaL_error(L, "Need buffer object at param 1");
	}
	luaL_checktype(L,2,LUA_TTABLE);
	luaL_Buffer b;
	luaL_buffinit(L, &b);
	while(sb->head) {
		struct buffer_node *current = sb->head;
		luaL_addlstring(&b, current->msg + sb->offset, current->sz - sb->offset);
		return_free_node(L,2,sb);
	}
	luaL_pushresult(&b);
	sb->size = 0;
	return 1;
}

static bool
check_sep(struct buffer_node * node, int from, const char *sep, int seplen) {
	for (;;) {
		int sz = node->sz - from;
		if (sz >= seplen) {
			return memcmp(node->msg+from,sep,seplen) == 0;
		}
		if (sz > 0) {
			if (memcmp(node->msg + from, sep, sz)) {
				return false;
			}
		}
		node = node->next;
		sep += sz;
		seplen -= sz;
		from = 0;
	}
}

/*
	userdata send_buffer
	table pool , nil for check
	string sep
 */
static int
lreadline(lua_State *L) {
	struct socket_buffer * sb = lua_touserdata(L, 1);
	if (sb == NULL) {
		return luaL_error(L, "Need buffer object at param 1");
	}
	// only check
	bool check = !lua_istable(L, 2);
	size_t seplen = 0;
	const char *sep = luaL_checklstring(L,3,&seplen);
	int i;
	struct buffer_node *current = sb->head;
	if (current == NULL)
		return 0;
	int from = sb->offset;
	int bytes = current->sz - from;
	for (i=0;i<=sb->size - (int)seplen;i++) {
		if (check_sep(current, from, sep, seplen)) {
			if (check) {
				lua_pushboolean(L,true);
			} else {
				pop_lstring(L, sb, i+seplen, seplen);
				sb->size -= i+seplen;
			}
			return 1;
		}
		++from;
		--bytes;
		if (bytes == 0) {
			current = current->next;
			from = 0;
			if (current == NULL)
				break;
			bytes = current->sz;
		}
	}
	return 0;
}

static const struct luaL_Reg lib[] =
{
	{ "new", lnewbuffer },
	{ "push", lpushbuffer },
	{ "pop", lpopbuffer },
	{ "readall", lreadall },
	{ "clear", lclearbuffer },
	{ "readline", lreadline },
	{ "size", lsize},
	{NULL,NULL}
};

int luaopen_buffer(lua_State *L)
{
	luaL_newlib(L, lib);
	return 1;
}
