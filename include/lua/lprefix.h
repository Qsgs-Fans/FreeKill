# 1 "./lua/lprefix.h"






#ifndef lprefix_h
#define lprefix_h 





#if !defined(LUA_USE_C89)

#if !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE 600
#elif _XOPEN_SOURCE == 0
#undef _XOPEN_SOURCE
#endif




#if !defined(LUA_32BITS) && !defined(_FILE_OFFSET_BITS)
#define _LARGEFILE_SOURCE 1
#define _FILE_OFFSET_BITS 64
#endif

#endif





#if defined(_WIN32)

#if !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS 
#endif

#endif

#endif
