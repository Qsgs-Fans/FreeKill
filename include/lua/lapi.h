# 1 "./lua/lapi.h"






#ifndef lapi_h
#define lapi_h 


#include "llimits.h"
#include "lstate.h"



#define api_incr_top(L) {L->top++; api_check(L, L->top <= L->ci->top, \
    "stack overflow");}







#define adjustresults(L,nres) \
    { if ((nres) <= LUA_MULTRET && L->ci->top < L->top) L->ci->top = L->top; }



#define api_checknelems(L,n) api_check(L, (n) < (L->top - L->ci->func), \
      "not enough elements in the stack")
# 43 "./lua/lapi.h"
#define hastocloseCfunc(n) ((n) < LUA_MULTRET)


#define codeNresults(n) (-(n) - 3)
#define decodeNresults(n) (-(n) - 3)

#endif
