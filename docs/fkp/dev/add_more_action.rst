.. SPDX-License-Identifier: GFDL-1.3-or-later

添加更多的动作语句
==================

动作语句曾经每一种作为一个单独的类出现，但自从函数功能被实现后，向fkparse中加入自定义action已经不是难事。下面带着例子简要介绍一下向fkparse添加动作语句的办法。

在fkparser.lua中添加接应的函数
------------------------------

下面以添加broadcastSkillInvoke为例。要调用这个函数需要room对象、技能名、音频的编号。由于fkparse中没有Room类型（因为没必要让用户知道这种类型的存在），因此改为需要ServerPlayer类型。

据此在fkparser.lua下面的\ ``fkp.functions``\ 表中添加以下内容：

::

   broadcastSkillInvoke = function(player, skill, index)
     player:getRoom():broadcastSkillInvoke(skill, index)
   end,

在builtin.c中添加内置函数
-------------------------

然后进入到builtin.c的\ ``builtin_func``\ 数组下，在两个NULL那一行上面插入以下内容：

::

   {"__broadcastSkillInvoke", "fkp.functions.broadcastSkillInvoke", TNone, 3, {
     {"玩家", TPlayer, false, {.s = NULL}},
     {"技能名", TString, false, {.s = NULL}},
     {"音频编号", TNumber, true, {.n = -1}},
   }},

这些东西是基于前面对结构体的定义而编写的。第一个字符串表示fkparse内部使用的函数名称，第二个表示将要被翻译成的名称，第三个表示函数的返回值类型，第四个表示函数的参数数量，接下来的数组表示函数的各种参数（最多10个参数）。

参数的数组中，参数的顺序必须合乎在fkparser.lua中所定义的那样，各个参数的类型也一样，至于参数的名称随意，但是像“skill”这种需要被翻译的技能名的话，参数的名称中必须包含“技能”这两个字，不然的话程序会将用户输入参数的字符串原封不动复制到lua中。

关于每个参数，第一个字符串是参数的名称，第二个是ExpVType枚举类型，表示参数的类型，第三个布尔类型表示参数是不是有默认值。第四个联合体中，如果没有默认值，那么一律\ ``{.s = NULL}``\ ，否则根据他的类型决定初始化字符串s或者整数n。这里“音频编号”的默认值是-1，所以就那么填写了。

设计语法规则
------------

下面来设计新action的语法规则。

首先，语法句子中必须包含好所有非默认参数，然后语法尽可能要简明易懂，但一定不能让分析器出现移入/归约冲突之类的错误。（只要不去使用“<表达式>
的”这样的组成，这种冲突通常可以避免）。

比如将broadcastSkillInvoke的语法设计为：

::

   <表达式> 说出 <字符串> 的台词

这种语法看似可行，包含了参数ServerPlayer和String。

补充词法单元
------------

绝大多数情况下设计的语法包含有fkparse无力处理的词语，比如这里的词语“说出”和“台词”，在lex.l没有定义过。

总之去lex.l中间的部分找一块地，然后输入定义词法单元的内容：

::

   "说出"    { return SPEAK; }
   "台词"    { return ACT_LINE; }

return后随便跟一个全大写的就行了，只要不和lex.l中已经有的重复。然后前面字符串也不能是lex.l已有的，也就是说不能重复定义词法规则。

然后现在return后面跟随着的全大写其实尚未定义，那么去grammar.y下面，将未定义词语加入：

::

   %token INVOKE HAVE
   %token BECAUSE THROW TIMES
   // 注释：前面两行是已有的，仅用来提示位置，下面一行是新加的
   %token SPEAK ACT_LINE

这样就完成了词法单元的补充。

添加设计的文法
--------------

接下来就是在grammar.y中将设计好的文法加入。首先决定好文法对应非终结符号的名字，自然就叫broadcastSkillInvoke了。

去grammar.y中“%%”前面一行，输入文法的定义：

::

   broadcastSkillInvoke  : exp SPEAK STRING FIELD ACT_LINE
                         ;

   // 注释：下面的%%和函数定义仅用来指示位置
   %%

   static int yyreport_syntax_error(const yypcontext_t *ctx) {
   // ...

接下来是为文法加入动作语句，告诉程序该生成怎么样的\ ``func_call``\ 。参考前面已经写好的，在合适位置写下如下内容：

::

   broadcastSkillInvoke  : exp SPEAK STRING FIELD ACT_LINE {
                             tempExp = newExpression(ExpStr, 0, 0, NULL, NULL);
                             tempExp->strvalue = $3;
                             $$ = newFunccall(
                                   strdup("__broadcastSkillInvoke"),
                                   newParams(2, "玩家", $1, "技能名", tempExp)
                                 );
                           }
                         ;

这里稍微说明一下动作语句：动作语句其实就是C语句，但是加入了$$和$n这样的符号。$$表示的是当前文法左半边，$n表示的是文法右半边的第n个符号。比如这段代码中的$3就表示第三个符号，即STRING，$1就是第一个符号exp了。

| newFunccall的意思是创建一个新的函数调用，这是fkparse用来分析的内部结构体之一。第一个参数字符串必须用strdup复制一次（内存管理方便），第二个参数接受一个哈希表，表示这个函数调用的参数。我已经写好了一个方便的函数newParams，直接构造需要的哈希表，第一个参数是调用时的参数数量，往后就是每一个参数，名字、值、名字、值...其中值必须是ExpressionObj
  \*类型，所以这边需要手动造个。
| 至此还有最后一步：加入新文法的类型声明和推导规则。这里创建的是新action，自然要从\ ``action_stat``\ 推导出来。

添加类型声明：

::

     %type <func_call> throwCardsBySkill getUsedTimes
   + %type <func_call> broadcastSkillInvoke

     %type <exp> exp prefixexp opexp

添加推导规则：

::

               | throwCardsBySkill { $$ = $1; yycopyloc($$, &@$); }
               | getUsedTimes { $$ = $1; yycopyloc($$, &@$); }
   +           | broadcastSkillInvoke { $$ = $1; yycopyloc($$, &@$); }
               ;

前面带加号的行表示这是插入的新行。

编写测试例并测试
----------------

去basic.txt的某处将语句写进去：

::

     使用后: 你摸1张牌。
   +   你说出"生有"的台词。
   +   你说出"生有"的台词{'音频编号':1}。

重新编译出可执行文件（参考README.md），然后编译一下新的basic.txt，打开生成的basic.lua看看效果：

::

   on_use = function(self, player, targets, cards)
     local room = player:getRoom()
     local locals = {}
     global_self = self

     fkp.functions.drawCards(player, 1)
     fkp.functions.broadcastSkillInvoke(player, 'basic_s_6', -1)
     fkp.functions.broadcastSkillInvoke(player, 'basic_s_6', 1)
   end,

至此我们已经成功的新建了一个action语句，剩下的就是实机测试了，别忘了把改过了的fkparser.lua也复制进游戏里面。

补充文档
--------

| 新的动作语句不能没有文档，切记最后去\ ``all_action.tex``\ 中把新建的语法补充进去。
| 附注：本章中介绍的内容已经在代码中实际体现，请随意参考。
