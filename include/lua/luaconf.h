# 1 "./lua/luaconf.h"







#ifndef luaconf_h
#define luaconf_h 

#include <limits.h>
#include <stddef.h>
# 50 "./lua/luaconf.h"
#if !defined(LUA_USE_C89) && defined(_WIN32) && !defined(_WIN32_WCE)
#define LUA_USE_WINDOWS 
#endif


#if defined(LUA_USE_WINDOWS)
#define LUA_DL_DLL 
#define LUA_USE_C89 
#endif


#if defined(LUA_USE_LINUX)
#define LUA_USE_POSIX 
#define LUA_USE_DLOPEN 
#endif


#if defined(LUA_USE_MACOSX)
#define LUA_USE_POSIX 
#define LUA_USE_DLOPEN 
#endif





#define LUAI_IS32INT ((UINT_MAX >> 30) >= 3)
# 101 "./lua/luaconf.h"
#define LUA_INT_INT 1
#define LUA_INT_LONG 2
#define LUA_INT_LONGLONG 3


#define LUA_FLOAT_FLOAT 1
#define LUA_FLOAT_DOUBLE 2
#define LUA_FLOAT_LONGDOUBLE 3



#define LUA_INT_DEFAULT LUA_INT_LONGLONG
#define LUA_FLOAT_DEFAULT LUA_FLOAT_DOUBLE





#define LUA_32BITS 0







#if defined(LUA_USE_C89) && !defined(LUA_USE_WINDOWS)
#define LUA_C89_NUMBERS 1
#else
#define LUA_C89_NUMBERS 0
#endif


#if LUA_32BITS



#if LUAI_IS32INT
#define LUA_INT_TYPE LUA_INT_INT
#else
#define LUA_INT_TYPE LUA_INT_LONG
#endif
#define LUA_FLOAT_TYPE LUA_FLOAT_FLOAT

#elif LUA_C89_NUMBERS



#define LUA_INT_TYPE LUA_INT_LONG
#define LUA_FLOAT_TYPE LUA_FLOAT_DOUBLE

#else


#define LUA_INT_TYPE LUA_INT_DEFAULT
#define LUA_FLOAT_TYPE LUA_FLOAT_DEFAULT

#endif
# 178 "./lua/luaconf.h"
#define LUA_PATH_SEP ";"
#define LUA_PATH_MARK "?"
#define LUA_EXEC_DIR "!"
# 193 "./lua/luaconf.h"
#define LUA_VDIR LUA_VERSION_MAJOR "." LUA_VERSION_MINOR
#if defined(_WIN32)




#define LUA_LDIR "!\\lua\\"
#define LUA_CDIR "!\\"
#define LUA_SHRDIR "!\\..\\share\\lua\\" LUA_VDIR "\\"

#if !defined(LUA_PATH_DEFAULT)
#define LUA_PATH_DEFAULT \
  LUA_LDIR"?.lua;" LUA_LDIR"?\\init.lua;" \
  LUA_CDIR"?.lua;" LUA_CDIR"?\\init.lua;" \
  LUA_SHRDIR"?.lua;" LUA_SHRDIR"?\\init.lua;" \
  ".\\?.lua;" ".\\?\\init.lua"
#endif

#if !defined(LUA_CPATH_DEFAULT)
#define LUA_CPATH_DEFAULT \
  LUA_CDIR"?.dll;" \
  LUA_CDIR"..\\lib\\lua\\" LUA_VDIR "\\?.dll;" \
  LUA_CDIR"loadall.dll;" ".\\?.dll"
#endif

#else

#define LUA_ROOT "/usr/local/"
#define LUA_LDIR LUA_ROOT "share/lua/" LUA_VDIR "/"
#define LUA_CDIR LUA_ROOT "lib/lua/" LUA_VDIR "/"

#if !defined(LUA_PATH_DEFAULT)
#define LUA_PATH_DEFAULT \
  LUA_LDIR"?.lua;" LUA_LDIR"?/init.lua;" \
  LUA_CDIR"?.lua;" LUA_CDIR"?/init.lua;" \
  "./?.lua;" "./?/init.lua"
#endif

#if !defined(LUA_CPATH_DEFAULT)
#define LUA_CPATH_DEFAULT \
  LUA_CDIR"?.so;" LUA_CDIR"loadall.so;" "./?.so"
#endif

#endif







#if !defined(LUA_DIRSEP)

#if defined(_WIN32)
#define LUA_DIRSEP "\\"
#else
#define LUA_DIRSEP "/"
#endif

#endif
# 272 "./lua/luaconf.h"
#if defined(LUA_BUILD_AS_DLL)

#if defined(LUA_CORE) || defined(LUA_LIB)
#define LUA_API __declspec(dllexport)
#else
#define LUA_API __declspec(dllimport)
#endif

#else

#define LUA_API extern

#endif





#define LUALIB_API LUA_API
#define LUAMOD_API LUA_API
# 308 "./lua/luaconf.h"
#if defined(__GNUC__) && ((__GNUC__*100 + __GNUC_MINOR__) >= 302) && \
    defined(__ELF__)
#define LUAI_FUNC __attribute__((visibility("internal"))) extern
#else
#define LUAI_FUNC extern
#endif

#define LUAI_DDEC(dec) LUAI_FUNC dec
#define LUAI_DDEF 
# 332 "./lua/luaconf.h"
#if defined(LUA_COMPAT_5_3)







#define LUA_COMPAT_MATHLIB 
# 349 "./lua/luaconf.h"
#define LUA_COMPAT_APIINTCASTS 






#define LUA_COMPAT_LT_LE 
# 366 "./lua/luaconf.h"
#define lua_strlen(L,i) lua_rawlen(L, (i))

#define lua_objlen(L,i) lua_rawlen(L, (i))

#define lua_equal(L,idx1,idx2) lua_compare(L,(idx1),(idx2),LUA_OPEQ)
#define lua_lessthan(L,idx1,idx2) lua_compare(L,(idx1),(idx2),LUA_OPLT)

#endif
# 403 "./lua/luaconf.h"
#define l_floor(x) (l_mathop(floor)(x))

#define lua_number2str(s,sz,n) \
 l_sprintf((s), sz, LUA_NUMBER_FMT, (LUAI_UACNUMBER)(n))
# 417 "./lua/luaconf.h"
#define lua_numbertointeger(n,p) \
  ((n) >= (LUA_NUMBER)(LUA_MININTEGER) && \
   (n) < -(LUA_NUMBER)(LUA_MININTEGER) && \
      (*(p) = (LUA_INTEGER)(n), 1))




#if LUA_FLOAT_TYPE == LUA_FLOAT_FLOAT

#define LUA_NUMBER float

#define l_floatatt(n) (FLT_ ##n)

#define LUAI_UACNUMBER double

#define LUA_NUMBER_FRMLEN ""
#define LUA_NUMBER_FMT "%.7g"

#define l_mathop(op) op ##f

#define lua_str2number(s,p) strtof((s), (p))


#elif LUA_FLOAT_TYPE == LUA_FLOAT_LONGDOUBLE

#define LUA_NUMBER long double

#define l_floatatt(n) (LDBL_ ##n)

#define LUAI_UACNUMBER long double

#define LUA_NUMBER_FRMLEN "L"
#define LUA_NUMBER_FMT "%.19Lg"

#define l_mathop(op) op ##l

#define lua_str2number(s,p) strtold((s), (p))

#elif LUA_FLOAT_TYPE == LUA_FLOAT_DOUBLE

#define LUA_NUMBER double

#define l_floatatt(n) (DBL_ ##n)

#define LUAI_UACNUMBER double

#define LUA_NUMBER_FRMLEN ""
#define LUA_NUMBER_FMT "%.14g"

#define l_mathop(op) op

#define lua_str2number(s,p) strtod((s), (p))

#else

#error "numeric float type not defined"

#endif
# 494 "./lua/luaconf.h"
#define LUA_INTEGER_FMT "%" LUA_INTEGER_FRMLEN "d"

#define LUAI_UACINT LUA_INTEGER

#define lua_integer2str(s,sz,n) \
 l_sprintf((s), sz, LUA_INTEGER_FMT, (LUAI_UACINT)(n))





#define LUA_UNSIGNED unsigned LUAI_UACINT




#if LUA_INT_TYPE == LUA_INT_INT

#define LUA_INTEGER int
#define LUA_INTEGER_FRMLEN ""

#define LUA_MAXINTEGER INT_MAX
#define LUA_MININTEGER INT_MIN

#define LUA_MAXUNSIGNED UINT_MAX

#elif LUA_INT_TYPE == LUA_INT_LONG

#define LUA_INTEGER long
#define LUA_INTEGER_FRMLEN "l"

#define LUA_MAXINTEGER LONG_MAX
#define LUA_MININTEGER LONG_MIN

#define LUA_MAXUNSIGNED ULONG_MAX

#elif LUA_INT_TYPE == LUA_INT_LONGLONG


#if defined(LLONG_MAX)


#define LUA_INTEGER long long
#define LUA_INTEGER_FRMLEN "ll"

#define LUA_MAXINTEGER LLONG_MAX
#define LUA_MININTEGER LLONG_MIN

#define LUA_MAXUNSIGNED ULLONG_MAX

#elif defined(LUA_USE_WINDOWS)


#define LUA_INTEGER __int64
#define LUA_INTEGER_FRMLEN "I64"

#define LUA_MAXINTEGER _I64_MAX
#define LUA_MININTEGER _I64_MIN

#define LUA_MAXUNSIGNED _UI64_MAX

#else

#error "Compiler does not support 'long long'. Use option '-DLUA_32BITS' \
  or '-DLUA_C89_NUMBERS' (see file 'luaconf.h' for details)"

#endif

#else

#error "numeric integer type not defined"

#endif
# 581 "./lua/luaconf.h"
#if !defined(LUA_USE_C89)
#define l_sprintf(s,sz,f,i) snprintf(s,sz,f,i)
#else
#define l_sprintf(s,sz,f,i) ((void)(sz), sprintf(s,f,i))
#endif
# 594 "./lua/luaconf.h"
#if !defined(LUA_USE_C89)
#define lua_strx2number(s,p) lua_str2number(s,p)
#endif






#define lua_pointer2str(buff,sz,p) l_sprintf(buff,sz,"%p",p)
# 612 "./lua/luaconf.h"
#if !defined(LUA_USE_C89)
#define lua_number2strx(L,b,sz,f,n) \
 ((void)L, l_sprintf(b,sz,f,(LUAI_UACNUMBER)(n)))
#endif
# 624 "./lua/luaconf.h"
#if defined(LUA_USE_C89) || (defined(HUGE_VAL) && !defined(HUGE_VALF))
#undef l_mathop
#undef lua_str2number
#define l_mathop(op) (lua_Number)op
#define lua_str2number(s,p) ((lua_Number)strtod((s), (p)))
#endif
# 638 "./lua/luaconf.h"
#define LUA_KCONTEXT ptrdiff_t

#if !defined(LUA_USE_C89) && defined(__STDC_VERSION__) && \
    __STDC_VERSION__ >= 199901L
#include <stdint.h>
#if defined(INTPTR_MAX)
#undef LUA_KCONTEXT
#define LUA_KCONTEXT intptr_t
#endif
#endif







#if !defined(lua_getlocaledecpoint)
#define lua_getlocaledecpoint() (localeconv()->decimal_point[0])
#endif
# 666 "./lua/luaconf.h"
#if !defined(luai_likely)

#if defined(__GNUC__) && !defined(LUA_NOBUILTIN)
#define luai_likely(x) (__builtin_expect(((x) != 0), 1))
#define luai_unlikely(x) (__builtin_expect(((x) != 0), 0))
#else
#define luai_likely(x) (x)
#define luai_unlikely(x) (x)
#endif

#endif


#if defined(LUA_CORE) || defined(LUA_LIB)

#define l_likely(x) luai_likely(x)
#define l_unlikely(x) luai_unlikely(x)
#endif
# 710 "./lua/luaconf.h"
#if defined(LUA_USE_APICHECK)
#include <assert.h>
#define luai_apicheck(l,e) assert(e)
#endif
# 733 "./lua/luaconf.h"
#if LUAI_IS32INT
#define LUAI_MAXSTACK 1000000
#else
#define LUAI_MAXSTACK 15000
#endif







#define LUA_EXTRASPACE (sizeof(void *))







#define LUA_IDSIZE 60





#define LUAL_BUFFERSIZE ((int)(16 * sizeof(void*) * sizeof(lua_Number)))






#define LUAI_MAXALIGN lua_Number n; double u; void *s; lua_Integer i; long l
# 785 "./lua/luaconf.h"
#endif
