.. SPDX-License-Identifier: GFDL-1.3-or-later

Package
==============

.. lua:autoclass:: Package

详细信息
~~~~~~~~~~~~~~

.. _extension name:

``extensionName`` 指的是这个Package所属的mod的名称。

一般来说，一个mod（即packages/下面的一个文件夹）只含有一个拓展包，典型的例子就是fk自带的几个拓展包。FreeKill在寻找武将的图片、配音等素材的时候，就会根据这个mod的名字去寻找。

在大多数情况下，Package的名字和mod的名字都是一致的（默认情况下也是如此），但有时候一个mod可能会含有好几个拓展包，比如神话再临mod里面就含有不少拓展包，这时候就要手动把extensionName设为mod的名字。以下是定义风包的代码：

.. highlight:: lua

::

  local extension = Package:new("wind")
  extension.extensionName = "shzl"

这段代码定义了名为wind的拓展包，但是他所属的mod文件夹名是shzl，所以需要手动指定。
