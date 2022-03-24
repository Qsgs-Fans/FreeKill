# 1 "./lua/lvm.h"






#ifndef lvm_h
#define lvm_h 


#include "ldo.h"
#include "lobject.h"
#include "ltm.h"


#if !defined(LUA_NOCVTN2S)
#define cvt2str(o) ttisnumber(o)
#else
#define cvt2str(o) 0
#endif


#if !defined(LUA_NOCVTS2N)
#define cvt2num(o) ttisstring(o)
#else
#define cvt2num(o) 0
#endif







#if !defined(LUA_FLOORN2I)
#define LUA_FLOORN2I F2Ieq
#endif





typedef enum {
  F2Ieq,
  F2Ifloor,
  F2Iceil
} F2Imod;



#define tonumber(o,n) \
 (ttisfloat(o) ? (*(n) = fltvalue(o), 1) : luaV_tonumber_(o,n))



#define tonumberns(o,n) \
 (ttisfloat(o) ? ((n) = fltvalue(o), 1) : \
 (ttisinteger(o) ? ((n) = cast_num(ivalue(o)), 1) : 0))



#define tointeger(o,i) \
  (l_likely(ttisinteger(o)) ? (*(i) = ivalue(o), 1) \
                          : luaV_tointeger(o,i,LUA_FLOORN2I))



#define tointegerns(o,i) \
  (l_likely(ttisinteger(o)) ? (*(i) = ivalue(o), 1) \
                          : luaV_tointegerns(o,i,LUA_FLOORN2I))


#define intop(op,v1,v2) l_castU2S(l_castS2U(v1) op l_castS2U(v2))

#define luaV_rawequalobj(t1,t2) luaV_equalobj(NULL,t1,t2)
# 85 "./lua/lvm.h"
#define luaV_fastget(L,t,k,slot,f) \
  (!ttistable(t) \
   ? (slot = NULL, 0) \
   : (slot = f(hvalue(t), k), \
      !isempty(slot)))






#define luaV_fastgeti(L,t,k,slot) \
  (!ttistable(t) \
   ? (slot = NULL, 0) \
   : (slot = (l_castS2U(k) - 1u < hvalue(t)->alimit) \
              ? &hvalue(t)->array[k - 1] : luaH_getint(hvalue(t), k), \
      !isempty(slot)))






#define luaV_finishfastset(L,t,slot,v) \
    { setobj2t(L, cast(TValue *,slot), v); \
      luaC_barrierback(L, gcvalue(t), v); }




LUAI_FUNC int luaV_equalobj (lua_State *L, const TValue *t1, const TValue *t2);
LUAI_FUNC int luaV_lessthan (lua_State *L, const TValue *l, const TValue *r);
LUAI_FUNC int luaV_lessequal (lua_State *L, const TValue *l, const TValue *r);
LUAI_FUNC int luaV_tonumber_ (const TValue *obj, lua_Number *n);
LUAI_FUNC int luaV_tointeger (const TValue *obj, lua_Integer *p, F2Imod mode);
LUAI_FUNC int luaV_tointegerns (const TValue *obj, lua_Integer *p,
                                F2Imod mode);
LUAI_FUNC int luaV_flttointeger (lua_Number n, lua_Integer *p, F2Imod mode);
LUAI_FUNC void luaV_finishget (lua_State *L, const TValue *t, TValue *key,
                               StkId val, const TValue *slot);
LUAI_FUNC void luaV_finishset (lua_State *L, const TValue *t, TValue *key,
                               TValue *val, const TValue *slot);
LUAI_FUNC void luaV_finishOp (lua_State *L);
LUAI_FUNC void luaV_execute (lua_State *L, CallInfo *ci);
LUAI_FUNC void luaV_concat (lua_State *L, int total);
LUAI_FUNC lua_Integer luaV_idiv (lua_State *L, lua_Integer x, lua_Integer y);
LUAI_FUNC lua_Integer luaV_mod (lua_State *L, lua_Integer x, lua_Integer y);
LUAI_FUNC lua_Number luaV_modf (lua_State *L, lua_Number x, lua_Number y);
LUAI_FUNC lua_Integer luaV_shiftl (lua_Integer x, lua_Integer y);
LUAI_FUNC void luaV_objlen (lua_State *L, StkId ra, const TValue *rb);

#endif
