# 1 "./lua/lundump.h"






#ifndef lundump_h
#define lundump_h 

#include "llimits.h"
#include "lobject.h"
#include "lzio.h"



#define LUAC_DATA "\x19\x93\r\n\x1a\n"

#define LUAC_INT 0x5678
#define LUAC_NUM cast_num(370.5)




#define MYINT(s) (s[0]-'0')
#define LUAC_VERSION (MYINT(LUA_VERSION_MAJOR)*16+MYINT(LUA_VERSION_MINOR))

#define LUAC_FORMAT 0


LUAI_FUNC LClosure* luaU_undump (lua_State* L, ZIO* Z, const char* name);


LUAI_FUNC int luaU_dump (lua_State* L, const Proto* f, lua_Writer w,
                         void* data, int strip);

#endif
