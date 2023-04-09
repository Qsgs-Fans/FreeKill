.. SPDX-License-Identifier: GFDL-1.3-or-later

FreeKill 的UI
=============

概述
----

FreeKill的UI系统使用Qt
Quick开发。UI依赖\ `QmlBackend <../../src/ui/qmlbackend.h>`__\ 调用需要的C++函数。关于这方面也可参考\ `main.cpp <../../src/main.cpp>`__\ 。

   Note: 我感觉QmlBackend这种实现方式很尴尬。

整体UI采用StackView进行页面切换之类的。

--------------

mainStack
---------

mainStack定义于\ `main.qml <../../qml/main.qml>`__\ 中。它以堆栈的形式保存着所有的页面，页面在栈中的顺序需要像这样排布：

-  （栈底）登录界面，Init.qml
-  大厅，Lobby.qml
-  别的什么页面

--------------

config
------

Config.qml存储一些客户端需要用到的设置或者即将发送的数据，（TODO）

--------------

Room和RoomLogic
---------------

这部分是整个UI体系中最复杂的一部分，其中尤以手牌区的操作为甚。下面来整理一下与出牌相关的UI逻辑。

首先要指明一个常用函数：

.. code:: cpp

     Q_INVOKABLE QString callLuaFunction(const QString &func_name,
                                         QVariantList params);

该函数声明位于qmlbackend.h中，第一个参数是函数名，必须是lua的全局函数，第二个列表是参数列表。lua一侧应当返回字符串/数字/布尔值，然后再在这里转成QString并返回qml中。这就是qml调用lua函数的核心。

然后来说说Room。Room中一共有4种状态，分别是：

-  notactive: 平常的不活跃状态。在此期间牌都是暗的，不能操作。
-  playing: 出牌阶段主动出牌状态。
-  responding: 需要选择响应使用/打出的状态。
-  replying: 需要操作对话框以回应服务器的状态。

notactive和replying不是本次的重点，重点在于playing和responding中关于手牌区的操作。

先看Room.qml中关于切换到这两个状态后的动作是什么：

.. code:: js

   Transition {
     from: "*"; to: "playing"
     ScriptAction {
       script: {
         dashboard.enableCards();
         dashboard.enableSkills();
         progress.visible = true;
         okCancel.visible = true;
         endPhaseButton.visible = true;
         respond_play = false;
       }
     }
   },

   Transition {
     from: "*"; to: "responding"
     ScriptAction {
       script: {
         dashboard.enableCards(responding_card);
         dashboard.enableSkills(responding_card);
         progress.visible = true;
         okCancel.visible = true;
       }
     }
   },

其中，涉及到的值得注意的函数是enableCards和enableSkills，这里只关心前者。

这两个函数的定义都是在Dashboard.qml中。其中，enableCards的内容大致是：如果状态是playing（即不提供参数），那么就判断每个card的CanUseCard，如果通过的话就点亮；如果是responding状态，那么就需要卡牌符合当前respond的pattern（即Room.qml中的responding_card属性）。

当一张牌被点击之后，牌的selected属性会变为true。经过一系列信号槽传输后，最终会触发RoomLogic.js中的enableTargets函数。类似的，在选中一个photo后，会触发Logic.updateSelectedTargets。

这两个函数的内容基本上大同小异，都是对能否选择某个目标、能否按下确定键进行判断，判断的依据也都是lua函数的内容。
