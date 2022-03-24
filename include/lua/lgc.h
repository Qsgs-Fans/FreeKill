# 1 "./lua/lgc.h"






#ifndef lgc_h
#define lgc_h 


#include "lobject.h"
#include "lstate.h"
# 31 "./lua/lgc.h"
#define GCSpropagate 0
#define GCSenteratomic 1
#define GCSatomic 2
#define GCSswpallgc 3
#define GCSswpfinobj 4
#define GCSswptobefnz 5
#define GCSswpend 6
#define GCScallfin 7
#define GCSpause 8


#define issweepphase(g) \
 (GCSswpallgc <= (g)->gcstate && (g)->gcstate <= GCSswpend)
# 54 "./lua/lgc.h"
#define keepinvariant(g) ((g)->gcstate <= GCSatomic)





#define resetbits(x,m) ((x) &= cast_byte(~(m)))
#define setbits(x,m) ((x) |= (m))
#define testbits(x,m) ((x) & (m))
#define bitmask(b) (1<<(b))
#define bit2mask(b1,b2) (bitmask(b1) | bitmask(b2))
#define l_setbit(x,b) setbits(x, bitmask(b))
#define resetbit(x,b) resetbits(x, bitmask(b))
#define testbit(x,b) testbits(x, bitmask(b))







#define WHITE0BIT 3
#define WHITE1BIT 4
#define BLACKBIT 5
#define FINALIZEDBIT 6

#define TESTBIT 7



#define WHITEBITS bit2mask(WHITE0BIT, WHITE1BIT)


#define iswhite(x) testbits((x)->marked, WHITEBITS)
#define isblack(x) testbit((x)->marked, BLACKBIT)
#define isgray(x) \
 (!testbits((x)->marked, WHITEBITS | bitmask(BLACKBIT)))

#define tofinalize(x) testbit((x)->marked, FINALIZEDBIT)

#define otherwhite(g) ((g)->currentwhite ^ WHITEBITS)
#define isdeadm(ow,m) ((m) & (ow))
#define isdead(g,v) isdeadm(otherwhite(g), (v)->marked)

#define changewhite(x) ((x)->marked ^= WHITEBITS)
#define nw2black(x) \
 check_exp(!iswhite(x), l_setbit((x)->marked, BLACKBIT))

#define luaC_white(g) cast_byte((g)->currentwhite & WHITEBITS)



#define G_NEW 0
#define G_SURVIVAL 1
#define G_OLD0 2
#define G_OLD1 3
#define G_OLD 4
#define G_TOUCHED1 5
#define G_TOUCHED2 6

#define AGEBITS 7

#define getage(o) ((o)->marked & AGEBITS)
#define setage(o,a) ((o)->marked = cast_byte(((o)->marked & (~AGEBITS)) | a))
#define isold(o) (getage(o) > G_SURVIVAL)

#define changeage(o,f,t) \
 check_exp(getage(o) == (f), (o)->marked ^= ((f)^(t)))



#define LUAI_GENMAJORMUL 100
#define LUAI_GENMINORMUL 20


#define LUAI_GCPAUSE 200





#define getgcparam(p) ((p) * 4)
#define setgcparam(p,v) ((p) = (v) / 4)

#define LUAI_GCMUL 100


#define LUAI_GCSTEPSIZE 13







#define isdecGCmodegen(g) (g->gckind == KGC_GEN || g->lastatomic != 0)





#define GCSTPUSR 1
#define GCSTPGC 2
#define GCSTPCLS 4
#define gcrunning(g) ((g)->gcstp == 0)
# 167 "./lua/lgc.h"
#define luaC_condGC(L,pre,pos) \
 { if (G(L)->GCdebt > 0) { pre; luaC_step(L); pos;}; \
   condchangemem(L,pre,pos); }


#define luaC_checkGC(L) luaC_condGC(L,(void)0,(void)0)


#define luaC_barrier(L,p,v) ( \
 (iscollectable(v) && isblack(p) && iswhite(gcvalue(v))) ? \
 luaC_barrier_(L,obj2gco(p),gcvalue(v)) : cast_void(0))

#define luaC_barrierback(L,p,v) ( \
 (iscollectable(v) && isblack(p) && iswhite(gcvalue(v))) ? \
 luaC_barrierback_(L,p) : cast_void(0))

#define luaC_objbarrier(L,p,o) ( \
 (isblack(p) && iswhite(o)) ? \
 luaC_barrier_(L,obj2gco(p),obj2gco(o)) : cast_void(0))

LUAI_FUNC void luaC_fix (lua_State *L, GCObject *o);
LUAI_FUNC void luaC_freeallobjects (lua_State *L);
LUAI_FUNC void luaC_step (lua_State *L);
LUAI_FUNC void luaC_runtilstate (lua_State *L, int statesmask);
LUAI_FUNC void luaC_fullgc (lua_State *L, int isemergency);
LUAI_FUNC GCObject *luaC_newobj (lua_State *L, int tt, size_t sz);
LUAI_FUNC void luaC_barrier_ (lua_State *L, GCObject *o, GCObject *v);
LUAI_FUNC void luaC_barrierback_ (lua_State *L, GCObject *o);
LUAI_FUNC void luaC_checkfinalizer (lua_State *L, GCObject *o, Table *mt);
LUAI_FUNC void luaC_changemode (lua_State *L, int newmode);


#endif
