.. SPDX-License-Identifier: GFDL-1.3-or-later

技巧：调试您的代码
==================

Lua是一门很不错的语言。然而，其在调试上却稍有困难。网上或许能找到一些针对独立运行的Lua脚本的调试器（例如vscode能下载的到的各种Lua debugger），但却不适用于FK。

因此，本文将试图为你扫清Lua调试方面的障碍。

假设你正使用Windows系统，那么启动FK的时候，应该是一个游戏窗口+一个黑色的命令行窗口。调试工作基本就是在黑色窗口进行的。

使用debugger.lua
----------------

这应该是最为推荐的一种做法了，FreeKill在lib中引用了debugger.lua作为调试库。

以下只简要介绍一下用法，最详细的详情请去项目官网查看： https://github.com/slembcke/debugger.lua

当你想要在代码中下断点时，就调用 ``dbg()`` 函数。当执行到这里时，就会停下来并在命令行中显示类似gdb的界面。

例如：

.. code:: lua

   local room = player.room

   dbg() -- 相当于下了断点，后面就可以来此进行调试
   player:drawCards(1)

上面的代码中就调用了debugger.lua，让程序进行了中断，然后命令行就进入了调试界面。

.. hint::

   在默认的双击启用exe带有的命令行中，颜色可能会显示的非常奇怪。

   如果你遇到了颜色不能正常显示的问题，推荐你使用Git Bash或者Windows Terminal之类的终端模拟器，然后在命令行中通过FreeKill.exe来启动游戏。

下面来说说调试的基本用法：使用 ``h`` 命令显示帮助信息。debugger.lua已经被我中文化了。

.. tip::

   其实也可以用lua自带的 ``debug.debug()`` 进行交互式调试，不过功能比debugger.lua弱得多了。

.. warning::

   在Linux上使用FreeKill -s开服时不能用这个调试器！因为stdin已经被服务端shell占用了，所以无法调试。

一些在调试中可能有用的函数
--------------------------

在调试器中直接输入Lua语句就能执行。以下是一些可能用得到的函数：

print
~~~~~

遇事不决print，这是当时没有调试器可用时候的措施。简单但却实用。

现在可以直接用debugger.lua的 p 命令输出表达式的值了，无需再自己写一堆。

p
~~~

``p`` 也是个函数，是inspect库的包装。它能详细输出表中的所有值，包括元表。

因此在使用它输出和类相关的东西的时候还是放弃为好...

json.encode
~~~~~~~~~~~

将不含循环引用的表转换为json字符串。或许会很有用吧。但是不如p就是了。

GameLogic:dumpEventStack()
~~~~~~~~~~~~~~~~~~~~~~~~~~

输出当前的事件栈。在处理插结的时候能派上用场。
