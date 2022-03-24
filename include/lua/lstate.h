# 1 "./lua/lstate.h"






#ifndef lstate_h
#define lstate_h 

#include "lua.h"

#include "lobject.h"
#include "ltm.h"
#include "lzio.h"
# 99 "./lua/lstate.h"
#define yieldable(L) (((L)->nCcalls & 0xffff0000) == 0)


#define getCcalls(L) ((L)->nCcalls & 0xffff)



#define incnny(L) ((L)->nCcalls += 0x10000)


#define decnny(L) ((L)->nCcalls -= 0x10000)


#define nyci (0x10000 | 1)




struct lua_longjmp;






#if !defined(l_signalT)
#include <signal.h>
#define l_signalT sig_atomic_t
#endif
# 137 "./lua/lstate.h"
#define EXTRA_STACK 5


#define BASIC_STACK_SIZE (2*LUA_MINSTACK)

#define stacksize(th) cast_int((th)->stack_last - (th)->stack)



#define KGC_INC 0
#define KGC_GEN 1


typedef struct stringtable {
  TString **hash;
  int nuse;
  int size;
} stringtable;
# 172 "./lua/lstate.h"
typedef struct CallInfo {
  StkId func;
  StkId top;
  struct CallInfo *previous, *next;
  union {
    struct {
      const Instruction *savedpc;
      volatile l_signalT trap;
      int nextraargs;
    } l;
    struct {
      lua_KFunction k;
      ptrdiff_t old_errfunc;
      lua_KContext ctx;
    } c;
  } u;
  union {
    int funcidx;
    int nyield;
    int nres;
    struct {
      unsigned short ftransfer;
      unsigned short ntransfer;
    } transferinfo;
  } u2;
  short nresults;
  unsigned short callstatus;
} CallInfo;





#define CIST_OAH (1<<0)
#define CIST_C (1<<1)
#define CIST_FRESH (1<<2)
#define CIST_HOOKED (1<<3)
#define CIST_YPCALL (1<<4)
#define CIST_TAIL (1<<5)
#define CIST_HOOKYIELD (1<<6)
#define CIST_FIN (1<<7)
#define CIST_TRAN (1<<8)
#define CIST_CLSRET (1<<9)

#define CIST_RECST 10
#if defined(LUA_COMPAT_LT_LE)
#define CIST_LEQ (1<<13)
#endif
# 228 "./lua/lstate.h"
#define getcistrecst(ci) (((ci)->callstatus >> CIST_RECST) & 7)
#define setcistrecst(ci,st) \
  check_exp(((st) & 7) == (st), \
            ((ci)->callstatus = ((ci)->callstatus & ~(7 << CIST_RECST)) \
                                                  | ((st) << CIST_RECST)))



#define isLua(ci) (!((ci)->callstatus & CIST_C))


#define isLuacode(ci) (!((ci)->callstatus & (CIST_C | CIST_HOOKED)))


#define setoah(st,v) ((st) = ((st) & ~CIST_OAH) | (v))
#define getoah(st) ((st) & CIST_OAH)





typedef struct global_State {
  lua_Alloc frealloc;
  void *ud;
  l_mem totalbytes;
  l_mem GCdebt;
  lu_mem GCestimate;
  lu_mem lastatomic;
  stringtable strt;
  TValue l_registry;
  TValue nilvalue;
  unsigned int seed;
  lu_byte currentwhite;
  lu_byte gcstate;
  lu_byte gckind;
  lu_byte gcstopem;
  lu_byte genminormul;
  lu_byte genmajormul;
  lu_byte gcstp;
  lu_byte gcemergency;
  lu_byte gcpause;
  lu_byte gcstepmul;
  lu_byte gcstepsize;
  GCObject *allgc;
  GCObject **sweepgc;
  GCObject *finobj;
  GCObject *gray;
  GCObject *grayagain;
  GCObject *weak;
  GCObject *ephemeron;
  GCObject *allweak;
  GCObject *tobefnz;
  GCObject *fixedgc;

  GCObject *survival;
  GCObject *old1;
  GCObject *reallyold;
  GCObject *firstold1;
  GCObject *finobjsur;
  GCObject *finobjold1;
  GCObject *finobjrold;
  struct lua_State *twups;
  lua_CFunction panic;
  struct lua_State *mainthread;
  TString *memerrmsg;
  TString *tmname[TM_N];
  struct Table *mt[LUA_NUMTAGS];
  TString *strcache[STRCACHE_N][STRCACHE_M];
  lua_WarnFunction warnf;
  void *ud_warn;
} global_State;





struct lua_State {
  CommonHeader;
  lu_byte status;
  lu_byte allowhook;
  unsigned short nci;
  StkId top;
  global_State *l_G;
  CallInfo *ci;
  StkId stack_last;
  StkId stack;
  UpVal *openupval;
  StkId tbclist;
  GCObject *gclist;
  struct lua_State *twups;
  struct lua_longjmp *errorJmp;
  CallInfo base_ci;
  volatile lua_Hook hook;
  ptrdiff_t errfunc;
  l_uint32 nCcalls;
  int oldpc;
  int basehookcount;
  int hookcount;
  volatile l_signalT hookmask;
};


#define G(L) (L->l_G)





#define completestate(g) ttisnil(&g->nilvalue)
# 348 "./lua/lstate.h"
union GCUnion {
  GCObject gc;
  struct TString ts;
  struct Udata u;
  union Closure cl;
  struct Table h;
  struct Proto p;
  struct lua_State th;
  struct UpVal upv;
};







#define cast_u(o) cast(union GCUnion *, (o))


#define gco2ts(o) \
 check_exp(novariant((o)->tt) == LUA_TSTRING, &((cast_u(o))->ts))
#define gco2u(o) check_exp((o)->tt == LUA_VUSERDATA, &((cast_u(o))->u))
#define gco2lcl(o) check_exp((o)->tt == LUA_VLCL, &((cast_u(o))->cl.l))
#define gco2ccl(o) check_exp((o)->tt == LUA_VCCL, &((cast_u(o))->cl.c))
#define gco2cl(o) \
 check_exp(novariant((o)->tt) == LUA_TFUNCTION, &((cast_u(o))->cl))
#define gco2t(o) check_exp((o)->tt == LUA_VTABLE, &((cast_u(o))->h))
#define gco2p(o) check_exp((o)->tt == LUA_VPROTO, &((cast_u(o))->p))
#define gco2th(o) check_exp((o)->tt == LUA_VTHREAD, &((cast_u(o))->th))
#define gco2upv(o) check_exp((o)->tt == LUA_VUPVAL, &((cast_u(o))->upv))






#define obj2gco(v) check_exp((v)->tt >= LUA_TSTRING, &(cast_u(v)->gc))



#define gettotalbytes(g) cast(lu_mem, (g)->totalbytes + (g)->GCdebt)

LUAI_FUNC void luaE_setdebt (global_State *g, l_mem debt);
LUAI_FUNC void luaE_freethread (lua_State *L, lua_State *L1);
LUAI_FUNC CallInfo *luaE_extendCI (lua_State *L);
LUAI_FUNC void luaE_freeCI (lua_State *L);
LUAI_FUNC void luaE_shrinkCI (lua_State *L);
LUAI_FUNC void luaE_checkcstack (lua_State *L);
LUAI_FUNC void luaE_incCstack (lua_State *L);
LUAI_FUNC void luaE_warning (lua_State *L, const char *msg, int tocont);
LUAI_FUNC void luaE_warnerror (lua_State *L, const char *where);
LUAI_FUNC int luaE_resetthread (lua_State *L, int status);


#endif
