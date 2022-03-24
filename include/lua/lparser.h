# 1 "./lua/lparser.h"






#ifndef lparser_h
#define lparser_h 

#include "llimits.h"
#include "lobject.h"
#include "lzio.h"
# 25 "./lua/lparser.h"
typedef enum {
  VVOID,

  VNIL,
  VTRUE,
  VFALSE,
  VK,
  VKFLT,
  VKINT,
  VKSTR,

  VNONRELOC,

  VLOCAL,

  VUPVAL,
  VCONST,

  VINDEXED,


  VINDEXUP,


  VINDEXI,


  VINDEXSTR,


  VJMP,

  VRELOC,

  VCALL,
  VVARARG
} expkind;


#define vkisvar(k) (VLOCAL <= (k) && (k) <= VINDEXSTR)
#define vkisindexed(k) (VINDEXED <= (k) && (k) <= VINDEXSTR)


typedef struct expdesc {
  expkind k;
  union {
    lua_Integer ival;
    lua_Number nval;
    TString *strval;
    int info;
    struct {
      short idx;
      lu_byte t;
    } ind;
    struct {
      lu_byte ridx;
      unsigned short vidx;
    } var;
  } u;
  int t;
  int f;
} expdesc;



#define VDKREG 0
#define RDKCONST 1
#define RDKTOCLOSE 2
#define RDKCTC 3


typedef union Vardesc {
  struct {
    TValuefields;
    lu_byte kind;
    lu_byte ridx;
    short pidx;
    TString *name;
  } vd;
  TValue k;
} Vardesc;




typedef struct Labeldesc {
  TString *name;
  int pc;
  int line;
  lu_byte nactvar;
  lu_byte close;
} Labeldesc;



typedef struct Labellist {
  Labeldesc *arr;
  int n;
  int size;
} Labellist;



typedef struct Dyndata {
  struct {
    Vardesc *arr;
    int n;
    int size;
  } actvar;
  Labellist gt;
  Labellist label;
} Dyndata;



struct BlockCnt;



typedef struct FuncState {
  Proto *f;
  struct FuncState *prev;
  struct LexState *ls;
  struct BlockCnt *bl;
  int pc;
  int lasttarget;
  int previousline;
  int nk;
  int np;
  int nabslineinfo;
  int firstlocal;
  int firstlabel;
  short ndebugvars;
  lu_byte nactvar;
  lu_byte nups;
  lu_byte freereg;
  lu_byte iwthabs;
  lu_byte needclose;
} FuncState;


LUAI_FUNC int luaY_nvarstack (FuncState *fs);
LUAI_FUNC LClosure *luaY_parser (lua_State *L, ZIO *z, Mbuffer *buff,
                                 Dyndata *dyd, const char *name, int firstchar);


#endif
