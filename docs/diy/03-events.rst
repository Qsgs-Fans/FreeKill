.. SPDX-License-Identifier: GFDL-1.3-or-later

fk中的游戏事件
==============

在进行DIY时，需要对三国杀的规则有一定了解；在编写技能时，也要熟悉游戏提供的各种事件，他的触发方式、触发时机、相关数据。必须要知道这些才能写出正确的代码。

下面的内容介绍的Fk涉及的诸多游戏事件。对于事件具体流程的描述仅限于如何触发各种时机而已。也有可能稍微多聊一些其他方面的事情。

描述触发时机以及事件详细流程的时候，使用的直接就是类似Lua的伪代码，其实你直接看源码都能得到差不多的效果。

.. toctree::
    :maxdepth: 1
    :caption: 事件列表

    event/gameflow.rst
    event/hp.rst
    event/usecard.rst
    event/movecard.rst
    event/misc.rst
