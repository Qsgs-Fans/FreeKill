# 1 "./lua/llimits.h"






#ifndef llimits_h
#define llimits_h 


#include <limits.h>
#include <stddef.h>


#include "lua.h"







#if defined(LUAI_MEM)
typedef LUAI_UMEM lu_mem;
typedef LUAI_MEM l_mem;
#elif LUAI_IS32INT
typedef size_t lu_mem;
typedef ptrdiff_t l_mem;
#else
typedef unsigned long lu_mem;
typedef long l_mem;
#endif



typedef unsigned char lu_byte;
typedef signed char ls_byte;



#define MAX_SIZET ((size_t)(~(size_t)0))


#define MAX_SIZE (sizeof(size_t) < sizeof(lua_Integer) ? MAX_SIZET \
                          : (size_t)(LUA_MAXINTEGER))


#define MAX_LUMEM ((lu_mem)(~(lu_mem)0))

#define MAX_LMEM ((l_mem)(MAX_LUMEM >> 1))


#define MAX_INT INT_MAX






#define log2maxs(t) (sizeof(t) * 8 - 2)





#define ispow2(x) (((x) & ((x) - 1)) == 0)



#define LL(x) (sizeof(x)/sizeof(char) - 1)







#define point2uint(p) ((unsigned int)((size_t)(p) & UINT_MAX))




typedef LUAI_UACNUMBER l_uacNumber;
typedef LUAI_UACINT l_uacInt;





#if defined LUAI_ASSERT
#undef NDEBUG
#include <assert.h>
#define lua_assert(c) assert(c)
#endif

#if defined(lua_assert)
#define check_exp(c,e) (lua_assert(c), (e))

#define lua_longassert(c) ((c) ? (void)0 : lua_assert(0))
#else
#define lua_assert(c) ((void)0)
#define check_exp(c,e) (e)
#define lua_longassert(c) ((void)0)
#endif




#if !defined(luai_apicheck)
#define luai_apicheck(l,e) ((void)l, lua_assert(e))
#endif

#define api_check(l,e,msg) luai_apicheck(l,(e) && msg)



#if !defined(UNUSED)
#define UNUSED(x) ((void)(x))
#endif



#define cast(t,exp) ((t)(exp))

#define cast_void(i) cast(void, (i))
#define cast_voidp(i) cast(void *, (i))
#define cast_num(i) cast(lua_Number, (i))
#define cast_int(i) cast(int, (i))
#define cast_uint(i) cast(unsigned int, (i))
#define cast_byte(i) cast(lu_byte, (i))
#define cast_uchar(i) cast(unsigned char, (i))
#define cast_char(i) cast(char, (i))
#define cast_charp(i) cast(char *, (i))
#define cast_sizet(i) cast(size_t, (i))



#if !defined(l_castS2U)
#define l_castS2U(i) ((lua_Unsigned)(i))
#endif






#if !defined(l_castU2S)
#define l_castU2S(i) ((lua_Integer)(i))
#endif





#if !defined(l_noret)

#if defined(__GNUC__)
#define l_noret void __attribute__((noreturn))
#elif defined(_MSC_VER) && _MSC_VER >= 1200
#define l_noret void __declspec(noreturn)
#else
#define l_noret void
#endif

#endif





#if !defined(LUA_USE_C89)
#define l_inline inline
#elif defined(__GNUC__)
#define l_inline __inline__
#else
#define l_inline 
#endif

#define l_sinline static l_inline






#if LUAI_IS32INT
typedef unsigned int l_uint32;
#else
typedef unsigned long l_uint32;
#endif

typedef l_uint32 Instruction;
# 202 "./lua/llimits.h"
#if !defined(LUAI_MAXSHORTLEN)
#define LUAI_MAXSHORTLEN 40
#endif
# 213 "./lua/llimits.h"
#if !defined(MINSTRTABSIZE)
#define MINSTRTABSIZE 128
#endif







#if !defined(STRCACHE_N)
#define STRCACHE_N 53
#define STRCACHE_M 2
#endif



#if !defined(LUA_MINBUFFER)
#define LUA_MINBUFFER 32
#endif
# 241 "./lua/llimits.h"
#if !defined(LUAI_MAXCCALLS)
#define LUAI_MAXCCALLS 200
#endif






#if !defined(lua_lock)
#define lua_lock(L) ((void) 0)
#define lua_unlock(L) ((void) 0)
#endif





#if !defined(luai_threadyield)
#define luai_threadyield(L) {lua_unlock(L); lua_lock(L);}
#endif






#if !defined(luai_userstateopen)
#define luai_userstateopen(L) ((void)L)
#endif

#if !defined(luai_userstateclose)
#define luai_userstateclose(L) ((void)L)
#endif

#if !defined(luai_userstatethread)
#define luai_userstatethread(L,L1) ((void)L)
#endif

#if !defined(luai_userstatefree)
#define luai_userstatefree(L,L1) ((void)L)
#endif

#if !defined(luai_userstateresume)
#define luai_userstateresume(L,n) ((void)L)
#endif

#if !defined(luai_userstateyield)
#define luai_userstateyield(L,n) ((void)L)
#endif
# 299 "./lua/llimits.h"
#if !defined(luai_numidiv)
#define luai_numidiv(L,a,b) ((void)L, l_floor(luai_numdiv(L,a,b)))
#endif


#if !defined(luai_numdiv)
#define luai_numdiv(L,a,b) ((a)/(b))
#endif
# 319 "./lua/llimits.h"
#if !defined(luai_nummod)
#define luai_nummod(L,a,b,m) \
  { (void)L; (m) = l_mathop(fmod)(a,b); \
    if (((m) > 0) ? (b) < 0 : ((m) < 0 && (b) > 0)) (m) += (b); }
#endif


#if !defined(luai_numpow)
#define luai_numpow(L,a,b) \
  ((void)L, (b == 2) ? (a)*(a) : l_mathop(pow)(a,b))
#endif


#if !defined(luai_numadd)
#define luai_numadd(L,a,b) ((a)+(b))
#define luai_numsub(L,a,b) ((a)-(b))
#define luai_nummul(L,a,b) ((a)*(b))
#define luai_numunm(L,a) (-(a))
#define luai_numeq(a,b) ((a)==(b))
#define luai_numlt(a,b) ((a)<(b))
#define luai_numle(a,b) ((a)<=(b))
#define luai_numgt(a,b) ((a)>(b))
#define luai_numge(a,b) ((a)>=(b))
#define luai_numisnan(a) (!luai_numeq((a), (a)))
#endif
# 352 "./lua/llimits.h"
#if !defined(HARDSTACKTESTS)
#define condmovestack(L,pre,pos) ((void)0)
#else

#define condmovestack(L,pre,pos) \
  { int sz_ = stacksize(L); pre; luaD_reallocstack((L), sz_, 0); pos; }
#endif

#if !defined(HARDMEMTESTS)
#define condchangemem(L,pre,pos) ((void)0)
#else
#define condchangemem(L,pre,pos) \
 { if (gcrunning(G(L))) { pre; luaC_fullgc(L, 0); pos; } }
#endif

#endif
