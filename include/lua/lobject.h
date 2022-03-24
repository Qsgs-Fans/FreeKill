# 1 "./lua/lobject.h"







#ifndef lobject_h
#define lobject_h 


#include <stdarg.h>


#include "llimits.h"
#include "lua.h"





#define LUA_TUPVAL LUA_NUMTYPES
#define LUA_TPROTO (LUA_NUMTYPES+1)
#define LUA_TDEADKEY (LUA_NUMTYPES+2)






#define LUA_TOTALTYPES (LUA_TPROTO + 2)
# 42 "./lua/lobject.h"
#define makevariant(t,v) ((t) | ((v) << 4))






typedef union Value {
  struct GCObject *gc;
  void *p;
  lua_CFunction f;
  lua_Integer i;
  lua_Number n;
} Value;







#define TValuefields Value value_; lu_byte tt_

typedef struct TValue {
  TValuefields;
} TValue;


#define val_(o) ((o)->value_)
#define valraw(o) (val_(o))



#define rawtt(o) ((o)->tt_)


#define novariant(t) ((t) & 0x0F)


#define withvariant(t) ((t) & 0x3F)
#define ttypetag(o) withvariant(rawtt(o))


#define ttype(o) (novariant(rawtt(o)))



#define checktag(o,t) (rawtt(o) == (t))
#define checktype(o,t) (ttype(o) == (t))





#define righttt(obj) (ttypetag(obj) == gcvalue(obj)->tt)







#define checkliveness(L,obj) \
 ((void)L, lua_longassert(!iscollectable(obj) || \
  (righttt(obj) && (L == NULL || !isdead(G(L),gcvalue(obj))))))





#define settt_(o,t) ((o)->tt_=(t))



#define setobj(L,obj1,obj2) \
 { TValue *io1=(obj1); const TValue *io2=(obj2); \
          io1->value_ = io2->value_; settt_(io1, io2->tt_); \
   checkliveness(L,io1); lua_assert(!isnonstrictnil(io1)); }







#define setobjs2s(L,o1,o2) setobj(L,s2v(o1),s2v(o2))

#define setobj2s(L,o1,o2) setobj(L,s2v(o1),o2)

#define setobjt2t setobj

#define setobj2n setobj

#define setobj2t setobj
# 146 "./lua/lobject.h"
typedef union StackValue {
  TValue val;
  struct {
    TValuefields;
    unsigned short delta;
  } tbclist;
} StackValue;



typedef StackValue *StkId;


#define s2v(o) (&(o)->val)
# 170 "./lua/lobject.h"
#define LUA_VNIL makevariant(LUA_TNIL, 0)


#define LUA_VEMPTY makevariant(LUA_TNIL, 1)


#define LUA_VABSTKEY makevariant(LUA_TNIL, 2)



#define ttisnil(v) checktype((v), LUA_TNIL)



#define ttisstrictnil(o) checktag((o), LUA_VNIL)


#define setnilvalue(obj) settt_(obj, LUA_VNIL)


#define isabstkey(v) checktag((v), LUA_VABSTKEY)





#define isnonstrictnil(v) (ttisnil(v) && !ttisstrictnil(v))







#define isempty(v) ttisnil(v)



#define ABSTKEYCONSTANT {NULL}, LUA_VABSTKEY



#define setempty(v) settt_(v, LUA_VEMPTY)
# 226 "./lua/lobject.h"
#define LUA_VFALSE makevariant(LUA_TBOOLEAN, 0)
#define LUA_VTRUE makevariant(LUA_TBOOLEAN, 1)

#define ttisboolean(o) checktype((o), LUA_TBOOLEAN)
#define ttisfalse(o) checktag((o), LUA_VFALSE)
#define ttistrue(o) checktag((o), LUA_VTRUE)


#define l_isfalse(o) (ttisfalse(o) || ttisnil(o))


#define setbfvalue(obj) settt_(obj, LUA_VFALSE)
#define setbtvalue(obj) settt_(obj, LUA_VTRUE)
# 249 "./lua/lobject.h"
#define LUA_VTHREAD makevariant(LUA_TTHREAD, 0)

#define ttisthread(o) checktag((o), ctb(LUA_VTHREAD))

#define thvalue(o) check_exp(ttisthread(o), gco2th(val_(o).gc))

#define setthvalue(L,obj,x) \
  { TValue *io = (obj); lua_State *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(LUA_VTHREAD)); \
    checkliveness(L,io); }

#define setthvalue2s(L,o,t) setthvalue(L,s2v(o),t)
# 275 "./lua/lobject.h"
#define CommonHeader struct GCObject *next; lu_byte tt; lu_byte marked



typedef struct GCObject {
  CommonHeader;
} GCObject;



#define BIT_ISCOLLECTABLE (1 << 6)

#define iscollectable(o) (rawtt(o) & BIT_ISCOLLECTABLE)


#define ctb(t) ((t) | BIT_ISCOLLECTABLE)

#define gcvalue(o) check_exp(iscollectable(o), val_(o).gc)

#define gcvalueraw(v) ((v).gc)

#define setgcovalue(L,obj,x) \
  { TValue *io = (obj); GCObject *i_g=(x); \
    val_(io).gc = i_g; settt_(io, ctb(i_g->tt)); }
# 310 "./lua/lobject.h"
#define LUA_VNUMINT makevariant(LUA_TNUMBER, 0)
#define LUA_VNUMFLT makevariant(LUA_TNUMBER, 1)

#define ttisnumber(o) checktype((o), LUA_TNUMBER)
#define ttisfloat(o) checktag((o), LUA_VNUMFLT)
#define ttisinteger(o) checktag((o), LUA_VNUMINT)

#define nvalue(o) check_exp(ttisnumber(o), \
 (ttisinteger(o) ? cast_num(ivalue(o)) : fltvalue(o)))
#define fltvalue(o) check_exp(ttisfloat(o), val_(o).n)
#define ivalue(o) check_exp(ttisinteger(o), val_(o).i)

#define fltvalueraw(v) ((v).n)
#define ivalueraw(v) ((v).i)

#define setfltvalue(obj,x) \
  { TValue *io=(obj); val_(io).n=(x); settt_(io, LUA_VNUMFLT); }

#define chgfltvalue(obj,x) \
  { TValue *io=(obj); lua_assert(ttisfloat(io)); val_(io).n=(x); }

#define setivalue(obj,x) \
  { TValue *io=(obj); val_(io).i=(x); settt_(io, LUA_VNUMINT); }

#define chgivalue(obj,x) \
  { TValue *io=(obj); lua_assert(ttisinteger(io)); val_(io).i=(x); }
# 347 "./lua/lobject.h"
#define LUA_VSHRSTR makevariant(LUA_TSTRING, 0)
#define LUA_VLNGSTR makevariant(LUA_TSTRING, 1)

#define ttisstring(o) checktype((o), LUA_TSTRING)
#define ttisshrstring(o) checktag((o), ctb(LUA_VSHRSTR))
#define ttislngstring(o) checktag((o), ctb(LUA_VLNGSTR))

#define tsvalueraw(v) (gco2ts((v).gc))

#define tsvalue(o) check_exp(ttisstring(o), gco2ts(val_(o).gc))

#define setsvalue(L,obj,x) \
  { TValue *io = (obj); TString *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(x_->tt)); \
    checkliveness(L,io); }


#define setsvalue2s(L,o,s) setsvalue(L,s2v(o),s)


#define setsvalue2n setsvalue





typedef struct TString {
  CommonHeader;
  lu_byte extra;
  lu_byte shrlen;
  unsigned int hash;
  union {
    size_t lnglen;
    struct TString *hnext;
  } u;
  char contents[1];
} TString;






#define getstr(ts) ((ts)->contents)



#define svalue(o) getstr(tsvalue(o))


#define tsslen(s) ((s)->tt == LUA_VSHRSTR ? (s)->shrlen : (s)->u.lnglen)


#define vslen(o) tsslen(tsvalue(o))
# 416 "./lua/lobject.h"
#define LUA_VLIGHTUSERDATA makevariant(LUA_TLIGHTUSERDATA, 0)

#define LUA_VUSERDATA makevariant(LUA_TUSERDATA, 0)

#define ttislightuserdata(o) checktag((o), LUA_VLIGHTUSERDATA)
#define ttisfulluserdata(o) checktag((o), ctb(LUA_VUSERDATA))

#define pvalue(o) check_exp(ttislightuserdata(o), val_(o).p)
#define uvalue(o) check_exp(ttisfulluserdata(o), gco2u(val_(o).gc))

#define pvalueraw(v) ((v).p)

#define setpvalue(obj,x) \
  { TValue *io=(obj); val_(io).p=(x); settt_(io, LUA_VLIGHTUSERDATA); }

#define setuvalue(L,obj,x) \
  { TValue *io = (obj); Udata *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(LUA_VUSERDATA)); \
    checkliveness(L,io); }



typedef union UValue {
  TValue uv;
  LUAI_MAXALIGN;
} UValue;






typedef struct Udata {
  CommonHeader;
  unsigned short nuvalue;
  size_t len;
  struct Table *metatable;
  GCObject *gclist;
  UValue uv[1];
} Udata;
# 467 "./lua/lobject.h"
typedef struct Udata0 {
  CommonHeader;
  unsigned short nuvalue;
  size_t len;
  struct Table *metatable;
  union {LUAI_MAXALIGN;} bindata;
} Udata0;



#define udatamemoffset(nuv) \
 ((nuv) == 0 ? offsetof(Udata0, bindata) \
                    : offsetof(Udata, uv) + (sizeof(UValue) * (nuv)))


#define getudatamem(u) (cast_charp(u) + udatamemoffset((u)->nuvalue))


#define sizeudata(nuv,nb) (udatamemoffset(nuv) + (nb))
# 496 "./lua/lobject.h"
#define LUA_VPROTO makevariant(LUA_TPROTO, 0)





typedef struct Upvaldesc {
  TString *name;
  lu_byte instack;
  lu_byte idx;
  lu_byte kind;
} Upvaldesc;






typedef struct LocVar {
  TString *varname;
  int startpc;
  int endpc;
} LocVar;
# 531 "./lua/lobject.h"
typedef struct AbsLineInfo {
  int pc;
  int line;
} AbsLineInfo;




typedef struct Proto {
  CommonHeader;
  lu_byte numparams;
  lu_byte is_vararg;
  lu_byte maxstacksize;
  int sizeupvalues;
  int sizek;
  int sizecode;
  int sizelineinfo;
  int sizep;
  int sizelocvars;
  int sizeabslineinfo;
  int linedefined;
  int lastlinedefined;
  TValue *k;
  Instruction *code;
  struct Proto **p;
  Upvaldesc *upvalues;
  ls_byte *lineinfo;
  AbsLineInfo *abslineinfo;
  LocVar *locvars;
  TString *source;
  GCObject *gclist;
} Proto;
# 573 "./lua/lobject.h"
#define LUA_VUPVAL makevariant(LUA_TUPVAL, 0)



#define LUA_VLCL makevariant(LUA_TFUNCTION, 0)
#define LUA_VLCF makevariant(LUA_TFUNCTION, 1)
#define LUA_VCCL makevariant(LUA_TFUNCTION, 2)

#define ttisfunction(o) checktype(o, LUA_TFUNCTION)
#define ttisLclosure(o) checktag((o), ctb(LUA_VLCL))
#define ttislcf(o) checktag((o), LUA_VLCF)
#define ttisCclosure(o) checktag((o), ctb(LUA_VCCL))
#define ttisclosure(o) (ttisLclosure(o) || ttisCclosure(o))


#define isLfunction(o) ttisLclosure(o)

#define clvalue(o) check_exp(ttisclosure(o), gco2cl(val_(o).gc))
#define clLvalue(o) check_exp(ttisLclosure(o), gco2lcl(val_(o).gc))
#define fvalue(o) check_exp(ttislcf(o), val_(o).f)
#define clCvalue(o) check_exp(ttisCclosure(o), gco2ccl(val_(o).gc))

#define fvalueraw(v) ((v).f)

#define setclLvalue(L,obj,x) \
  { TValue *io = (obj); LClosure *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(LUA_VLCL)); \
    checkliveness(L,io); }

#define setclLvalue2s(L,o,cl) setclLvalue(L,s2v(o),cl)

#define setfvalue(obj,x) \
  { TValue *io=(obj); val_(io).f=(x); settt_(io, LUA_VLCF); }

#define setclCvalue(L,obj,x) \
  { TValue *io = (obj); CClosure *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(LUA_VCCL)); \
    checkliveness(L,io); }





typedef struct UpVal {
  CommonHeader;
  lu_byte tbc;
  TValue *v;
  union {
    struct {
      struct UpVal *next;
      struct UpVal **previous;
    } open;
    TValue value;
  } u;
} UpVal;



#define ClosureHeader \
 CommonHeader; lu_byte nupvalues; GCObject *gclist

typedef struct CClosure {
  ClosureHeader;
  lua_CFunction f;
  TValue upvalue[1];
} CClosure;


typedef struct LClosure {
  ClosureHeader;
  struct Proto *p;
  UpVal *upvals[1];
} LClosure;


typedef union Closure {
  CClosure c;
  LClosure l;
} Closure;


#define getproto(o) (clLvalue(o)->p)
# 665 "./lua/lobject.h"
#define LUA_VTABLE makevariant(LUA_TTABLE, 0)

#define ttistable(o) checktag((o), ctb(LUA_VTABLE))

#define hvalue(o) check_exp(ttistable(o), gco2t(val_(o).gc))

#define sethvalue(L,obj,x) \
  { TValue *io = (obj); Table *x_ = (x); \
    val_(io).gc = obj2gco(x_); settt_(io, ctb(LUA_VTABLE)); \
    checkliveness(L,io); }

#define sethvalue2s(L,o,h) sethvalue(L,s2v(o),h)
# 686 "./lua/lobject.h"
typedef union Node {
  struct NodeKey {
    TValuefields;
    lu_byte key_tt;
    int next;
    Value key_val;
  } u;
  TValue i_val;
} Node;



#define setnodekey(L,node,obj) \
 { Node *n_=(node); const TValue *io_=(obj); \
   n_->u.key_val = io_->value_; n_->u.key_tt = io_->tt_; \
   checkliveness(L,io_); }



#define getnodekey(L,obj,node) \
 { TValue *io_=(obj); const Node *n_=(node); \
   io_->value_ = n_->u.key_val; io_->tt_ = n_->u.key_tt; \
   checkliveness(L,io_); }
# 718 "./lua/lobject.h"
#define BITRAS (1 << 7)
#define isrealasize(t) (!((t)->flags & BITRAS))
#define setrealasize(t) ((t)->flags &= cast_byte(~BITRAS))
#define setnorealasize(t) ((t)->flags |= BITRAS)


typedef struct Table {
  CommonHeader;
  lu_byte flags;
  lu_byte lsizenode;
  unsigned int alimit;
  TValue *array;
  Node *node;
  Node *lastfree;
  struct Table *metatable;
  GCObject *gclist;
} Table;





#define keytt(node) ((node)->u.key_tt)
#define keyval(node) ((node)->u.key_val)

#define keyisnil(node) (keytt(node) == LUA_TNIL)
#define keyisinteger(node) (keytt(node) == LUA_VNUMINT)
#define keyival(node) (keyval(node).i)
#define keyisshrstr(node) (keytt(node) == ctb(LUA_VSHRSTR))
#define keystrval(node) (gco2ts(keyval(node).gc))

#define setnilkey(node) (keytt(node) = LUA_TNIL)

#define keyiscollectable(n) (keytt(n) & BIT_ISCOLLECTABLE)

#define gckey(n) (keyval(n).gc)
#define gckeyN(n) (keyiscollectable(n) ? gckey(n) : NULL)
# 763 "./lua/lobject.h"
#define setdeadkey(node) (keytt(node) = LUA_TDEADKEY)
#define keyisdead(node) (keytt(node) == LUA_TDEADKEY)
# 773 "./lua/lobject.h"
#define lmod(s,size) \
 (check_exp((size&(size-1))==0, (cast_int((s) & ((size)-1)))))


#define twoto(x) (1<<(x))
#define sizenode(t) (twoto((t)->lsizenode))



#define UTF8BUFFSZ 8

LUAI_FUNC int luaO_utf8esc (char *buff, unsigned long x);
LUAI_FUNC int luaO_ceillog2 (unsigned int x);
LUAI_FUNC int luaO_rawarith (lua_State *L, int op, const TValue *p1,
                             const TValue *p2, TValue *res);
LUAI_FUNC void luaO_arith (lua_State *L, int op, const TValue *p1,
                           const TValue *p2, StkId res);
LUAI_FUNC size_t luaO_str2num (const char *s, TValue *o);
LUAI_FUNC int luaO_hexavalue (int c);
LUAI_FUNC void luaO_tostring (lua_State *L, TValue *obj);
LUAI_FUNC const char *luaO_pushvfstring (lua_State *L, const char *fmt,
                                                       va_list argp);
LUAI_FUNC const char *luaO_pushfstring (lua_State *L, const char *fmt, ...);
LUAI_FUNC void luaO_chunkid (char *out, const char *source, size_t srclen);


#endif
