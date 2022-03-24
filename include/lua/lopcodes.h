# 1 "./lua/lopcodes.h"






#ifndef lopcodes_h
#define lopcodes_h 

#include "llimits.h"
# 32 "./lua/lopcodes.h"
enum OpMode {iABC, iABx, iAsBx, iAx, isJ};





#define SIZE_C 8
#define SIZE_B 8
#define SIZE_Bx (SIZE_C + SIZE_B + 1)
#define SIZE_A 8
#define SIZE_Ax (SIZE_Bx + SIZE_A)
#define SIZE_sJ (SIZE_Bx + SIZE_A)

#define SIZE_OP 7

#define POS_OP 0

#define POS_A (POS_OP + SIZE_OP)
#define POS_k (POS_A + SIZE_A)
#define POS_B (POS_k + 1)
#define POS_C (POS_B + SIZE_B)

#define POS_Bx POS_k

#define POS_Ax POS_A

#define POS_sJ POS_A
# 68 "./lua/lopcodes.h"
#define L_INTHASBITS(b) ((UINT_MAX >> ((b) - 1)) >= 1)


#if L_INTHASBITS(SIZE_Bx)
#define MAXARG_Bx ((1<<SIZE_Bx)-1)
#else
#define MAXARG_Bx MAX_INT
#endif

#define OFFSET_sBx (MAXARG_Bx>>1)


#if L_INTHASBITS(SIZE_Ax)
#define MAXARG_Ax ((1<<SIZE_Ax)-1)
#else
#define MAXARG_Ax MAX_INT
#endif

#if L_INTHASBITS(SIZE_sJ)
#define MAXARG_sJ ((1 << SIZE_sJ) - 1)
#else
#define MAXARG_sJ MAX_INT
#endif

#define OFFSET_sJ (MAXARG_sJ >> 1)


#define MAXARG_A ((1<<SIZE_A)-1)
#define MAXARG_B ((1<<SIZE_B)-1)
#define MAXARG_C ((1<<SIZE_C)-1)
#define OFFSET_sC (MAXARG_C >> 1)

#define int2sC(i) ((i) + OFFSET_sC)
#define sC2int(i) ((i) - OFFSET_sC)



#define MASK1(n,p) ((~((~(Instruction)0)<<(n)))<<(p))


#define MASK0(n,p) (~MASK1(n,p))





#define GET_OPCODE(i) (cast(OpCode, ((i)>>POS_OP) & MASK1(SIZE_OP,0)))
#define SET_OPCODE(i,o) ((i) = (((i)&MASK0(SIZE_OP,POS_OP)) | \
  ((cast(Instruction, o)<<POS_OP)&MASK1(SIZE_OP,POS_OP))))

#define checkopm(i,m) (getOpMode(GET_OPCODE(i)) == m)


#define getarg(i,pos,size) (cast_int(((i)>>(pos)) & MASK1(size,0)))
#define setarg(i,v,pos,size) ((i) = (((i)&MASK0(size,pos)) | \
                ((cast(Instruction, v)<<pos)&MASK1(size,pos))))

#define GETARG_A(i) getarg(i, POS_A, SIZE_A)
#define SETARG_A(i,v) setarg(i, v, POS_A, SIZE_A)

#define GETARG_B(i) check_exp(checkopm(i, iABC), getarg(i, POS_B, SIZE_B))
#define GETARG_sB(i) sC2int(GETARG_B(i))
#define SETARG_B(i,v) setarg(i, v, POS_B, SIZE_B)

#define GETARG_C(i) check_exp(checkopm(i, iABC), getarg(i, POS_C, SIZE_C))
#define GETARG_sC(i) sC2int(GETARG_C(i))
#define SETARG_C(i,v) setarg(i, v, POS_C, SIZE_C)

#define TESTARG_k(i) check_exp(checkopm(i, iABC), (cast_int(((i) & (1u << POS_k)))))
#define GETARG_k(i) check_exp(checkopm(i, iABC), getarg(i, POS_k, 1))
#define SETARG_k(i,v) setarg(i, v, POS_k, 1)

#define GETARG_Bx(i) check_exp(checkopm(i, iABx), getarg(i, POS_Bx, SIZE_Bx))
#define SETARG_Bx(i,v) setarg(i, v, POS_Bx, SIZE_Bx)

#define GETARG_Ax(i) check_exp(checkopm(i, iAx), getarg(i, POS_Ax, SIZE_Ax))
#define SETARG_Ax(i,v) setarg(i, v, POS_Ax, SIZE_Ax)

#define GETARG_sBx(i) \
 check_exp(checkopm(i, iAsBx), getarg(i, POS_Bx, SIZE_Bx) - OFFSET_sBx)
#define SETARG_sBx(i,b) SETARG_Bx((i),cast_uint((b)+OFFSET_sBx))

#define GETARG_sJ(i) \
 check_exp(checkopm(i, isJ), getarg(i, POS_sJ, SIZE_sJ) - OFFSET_sJ)
#define SETARG_sJ(i,j) \
 setarg(i, cast_uint((j)+OFFSET_sJ), POS_sJ, SIZE_sJ)


#define CREATE_ABCk(o,a,b,c,k) ((cast(Instruction, o)<<POS_OP) \
   | (cast(Instruction, a)<<POS_A) \
   | (cast(Instruction, b)<<POS_B) \
   | (cast(Instruction, c)<<POS_C) \
   | (cast(Instruction, k)<<POS_k))

#define CREATE_ABx(o,a,bc) ((cast(Instruction, o)<<POS_OP) \
   | (cast(Instruction, a)<<POS_A) \
   | (cast(Instruction, bc)<<POS_Bx))

#define CREATE_Ax(o,a) ((cast(Instruction, o)<<POS_OP) \
   | (cast(Instruction, a)<<POS_Ax))

#define CREATE_sJ(o,j,k) ((cast(Instruction, o) << POS_OP) \
   | (cast(Instruction, j) << POS_sJ) \
   | (cast(Instruction, k) << POS_k))


#if !defined(MAXINDEXRK)
#define MAXINDEXRK MAXARG_B
#endif





#define NO_REG MAXARG_A
# 197 "./lua/lopcodes.h"
typedef enum {



OP_MOVE,
OP_LOADI,
OP_LOADF,
OP_LOADK,
OP_LOADKX,
OP_LOADFALSE,
OP_LFALSESKIP,
OP_LOADTRUE,
OP_LOADNIL,
OP_GETUPVAL,
OP_SETUPVAL,

OP_GETTABUP,
OP_GETTABLE,
OP_GETI,
OP_GETFIELD,

OP_SETTABUP,
OP_SETTABLE,
OP_SETI,
OP_SETFIELD,

OP_NEWTABLE,

OP_SELF,

OP_ADDI,

OP_ADDK,
OP_SUBK,
OP_MULK,
OP_MODK,
OP_POWK,
OP_DIVK,
OP_IDIVK,

OP_BANDK,
OP_BORK,
OP_BXORK,

OP_SHRI,
OP_SHLI,

OP_ADD,
OP_SUB,
OP_MUL,
OP_MOD,
OP_POW,
OP_DIV,
OP_IDIV,

OP_BAND,
OP_BOR,
OP_BXOR,
OP_SHL,
OP_SHR,

OP_MMBIN,
OP_MMBINI,
OP_MMBINK,

OP_UNM,
OP_BNOT,
OP_NOT,
OP_LEN,

OP_CONCAT,

OP_CLOSE,
OP_TBC,
OP_JMP,
OP_EQ,
OP_LT,
OP_LE,

OP_EQK,
OP_EQI,
OP_LTI,
OP_LEI,
OP_GTI,
OP_GEI,

OP_TEST,
OP_TESTSET,

OP_CALL,
OP_TAILCALL,

OP_RETURN,
OP_RETURN0,
OP_RETURN1,

OP_FORLOOP,
OP_FORPREP,


OP_TFORPREP,
OP_TFORCALL,
OP_TFORLOOP,

OP_SETLIST,

OP_CLOSURE,

OP_VARARG,

OP_VARARGPREP,

OP_EXTRAARG
} OpCode;


#define NUM_OPCODES ((int)(OP_EXTRAARG) + 1)
# 381 "./lua/lopcodes.h"
LUAI_DDEC(const lu_byte luaP_opmodes[NUM_OPCODES];)

#define getOpMode(m) (cast(enum OpMode, luaP_opmodes[m] & 7))
#define testAMode(m) (luaP_opmodes[m] & (1 << 3))
#define testTMode(m) (luaP_opmodes[m] & (1 << 4))
#define testITMode(m) (luaP_opmodes[m] & (1 << 5))
#define testOTMode(m) (luaP_opmodes[m] & (1 << 6))
#define testMMMode(m) (luaP_opmodes[m] & (1 << 7))


#define isOT(i) \
 ((testOTMode(GET_OPCODE(i)) && GETARG_C(i) == 0) || \
          GET_OPCODE(i) == OP_TAILCALL)


#define isIT(i) (testITMode(GET_OPCODE(i)) && GETARG_B(i) == 0)

#define opmode(mm,ot,it,t,a,m) \
    (((mm) << 7) | ((ot) << 6) | ((it) << 5) | ((t) << 4) | ((a) << 3) | (m))



#define LFIELDS_PER_FLUSH 50

#endif
