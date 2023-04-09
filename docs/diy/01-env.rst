.. SPDX-License-Identifier: GFDL-1.3-or-later

Fk DIY - 环境搭建
=================

DIY总览
-------

正如项目README所言，FreeKill“试图打造一个最适合diy玩家游玩的民间三国杀”。即便是最开始游戏功能尚未完善，FreeKill也已经具备了对DIY的支持。所有拓展包都列在packages/文件夹下，感兴趣者可以自行查看。

欲为FreeKill进行DIY，需要使用的编程语言为Lua。若您对Lua语言完全不熟悉，推荐去\ `菜鸟教程 <https://www.runoob.com/lua/lua-tutorial.html>`__\ 速通一遍基本语法。剩下的就基本是在实践中慢慢领会了。

FreeKill本体中自带有标准包和标准卡牌包，可作为DIY时候的例子。事实上，其他DIY包也是像这样子组织的。

接下来讲述如何配置环境。

--------------

环境搭建
--------

Fk
~~

Fk是游戏本身，也是拓展包运行的平台。事实上这份文档应该与Fk一同发布的，如果您正在阅读这份文档，那么您理应已经接收到了Fk本身。

代码编辑器
~~~~~~~~~~

代码编辑器任选一种即可，但一定要确保以下几点：

-  至少要是一款\ **代码**\ 编辑器，要有语法高亮功能
-  需要有EmmyLua插件的支持
-  需要默认UTF-8格式保存代码文件

.. note::

   EmmyLua是一种特别的Lua注释方式，可以为本来弱类型的Lua语言提供类型支持，这对于像FreeKill这种稍有规模的Lua项目是十分必要的。目前能提供开箱即用的EmmyLua插件编辑器主要有IntelliJ IDEA和Visual Studio Code。EmmyLua也能以LSP的方式运行，因此支持LSP的编辑器（这种就多了,比如vim, sublime）也能符合条件。

编辑器的具体安装以及插件配置不在此赘述。

.. hint::

   出于易用性和免费的考虑，推荐用VSCode进行拓展。下文将以VSCode为编辑器进行进一步说明。

git
~~~

git就不必多介绍了吧，这里说说为什么需要配置git。这是因为在Fk中，拓展包拥有在线安装/在线更新的功能，这种功能都是依托于git进行的，因此如果你打算将自己的拓展包发布出去的话，就需要将其创建git仓库，并托管到git托管网站去。

.. hint::

   考虑到国内绝大部分人的访问速度，综合国内几家git托管平台，建议使用gitee。

大多数人可能从未用过git，并且git上手的门槛并不低，因此以下会对涉及git的操作进行详尽的解说。

安装git
^^^^^^^

前往\ `官网 <https://git-scm.com/download/win>`__\ 下载git，下载64-bit
Git for Windows Setup。这样应该会为您下载一个exe安装包。

考虑到官网的下载链接实际上指向github，而且可能连官网的都进不去，所以也考虑\ `从清华源下载Git <https://mirrors.tuna.tsinghua.edu.cn/github-release/git-for-windows/git/>`__\ 。

欲验证安装是否完成，可以按下Win+R ->
cmd弹出命令行窗口，输入git命令，如果出来一长串英文说明安装成功了。

--------------

新增mod
-------

这只是新增mod的一个例子。当然了，以后有啥要做的实例也会继续用这个拓展包的。

首先前往packages下，新建名为fk_study的文件夹。

再在fk_study下新建init.lua文件，写入以下内容：

.. code:: lua

   local extension = Package("fk_study")

   Fk:loadTranslationTable{
     ["fk_study"] = "fk学习包",
   }

   return { extension }

保存退出，打开Fk，进武将一览。你现在应该能在武将一览里面看到“fk学习包”了，但也仅此而已了，毕竟这还只是个空壳包而已。

至此我们已经创建了最为简单的mod。mod的文件结构如下：

::

   fk_study
   └── init.lua

--------------

发布mod
-------

一种最常见的发布mod方式是把mod打包成zip，发到公共平台上供玩家下载。这种办法虽然可行，但并不是fk推荐的做法。

.. hint::

   以下介绍的其实就是新建仓库并推送到gitee的办法，熟悉git者请跳过。

下面着重介绍用git发布mod的办法。使用git进行发布的话，就可以让用户体验在线安装、在线更新等便捷之处。

以下假设你使用vscode进行代码编辑。你是先用vscode打开了整个FreeKill文件夹，再在其中新建文件夹和文件、然后进行编辑的。

菜单栏 -> 终端 -> 新建终端。我们接下来的工作都在终端中完成。

将终端切换为Git Bash
~~~~~~~~~~~~~~~~~~~~

启动终端后，终端的内容大概是：

.. code::

   Mincrosoft Windows 10 [版本号啥的]
   xxxxxxxx 保留所有权利。

   C:\FreeKill>

这个是Windows自带的cmd，我们不使用这个，而是去用git
bash。此时终端上面应该有这么一条：

.. code::

   问题 输出 调试控制台 _终端_      cmd  + v 分屏 删除
                                      注意这个加号

这时候点击加号右边那个下拉箭头，选择”Git Bash”。这样就成功的切换到了git
bash中，终端看起来应该像这样：

.. code::

   xxx@xxxxx MINGW64 /c/FreeKill
   $

配置ssh key
~~~~~~~~~~~

你应该已经注册好了自己的gitee账号。首先在Git
bash中输入这些命令（#号后面的是命令注释，不用照搬；命令开头的$符号是模拟shell的界面，不要输入进去）：

.. code:: bash

   $ cd ~/.ssh
   $ ssh-keygen -t rsa -C "你注册用的邮箱地址" # 换成自己真正的邮箱
     # 出来一堆东西，一路点回车就是了
   $ cat id_rsa.pub
     # 出来一堆乱七八糟的东西：ssh-rsa <一大堆乱七八糟的内容> <你的邮箱>
   $ cd -

在cat
id_rsa.pub中，出来的那一堆以ssh-rsa的输出，就是这里要用到的“公钥”。然后在gitee中：

1. 点右上角你的头像，点账号设置
2. 点左侧栏中 安全设置 - SSH公钥
3. 此时弹出公钥添加界面，标题任选，下面公钥那一栏中，将刚刚生成的公钥复制粘贴上去
4. 点确定

这样就配置好了ssh公钥。进行验证，在bash中使用命令：

::

   $ ssh -T git@gitee.com
   Hi xxxx! You've successfully authenticated, but GITEE.COM does not provide shell access.

输出像Hi
xxx!这样的信息，就说明配置成功了。否则需要进一步检查自己的操作，上网查一下吧。

新建git仓库
~~~~~~~~~~~

现在终端的工作目录应该还是FreeKill根目录，我们先切换到mod的目录去，然后再在shell中进行一系列操作。

.. code:: sh

   $ cd packages/fk_study
   $ git init # 创建新的空仓库
   $ git add .  # 将文件夹中所有的文件都加入暂存区
   $ git commit -m "init" # 提交目前所有的文件，这样文件就正式存在于仓库里面了
   作者身份未知
   *** 请告诉我您是谁。
   运行
     git config --global user.email "you@example.com"
     git config --global user.name "Your Name"

   来设置您账号的缺省身份标识。如果仅在本仓库设置身份标识，则省略 --global 参数。

看来我们初次安装Git，Git还不知道我们的身份呢，不过git已经告诉了配置所需的命令了。运行前一条命令告知自己的名字，运行后一条命令告知自己的邮箱。如此就OK了，然后再commit一次。

然后在gitee中也新建一个仓库，取名为fk_study。接下来回到终端里面：

.. code:: sh

   $ git remote add origin git@gitee.com:xxx/fk_study # 其中这个xxx是你的用户名
   $ git push -u origin master

OK了，刷新你新建的那个仓库的页面，可以看到里面已经有init.lua了。此时距离发布mod只有最后一步，那就是把仓库设置为开源。请自行在gitee中设置吧。

让他人安装并游玩你的mod
~~~~~~~~~~~~~~~~~~~~~~~

注意到Fk初始界面里面的“管理拓展包”了不？这个就是让你安装、删除、更新拓展包用的。在那个页面里面有个输入框，在浏览器中复制仓库的地址（比如https://gitee.com/xxx/fk_study/
），粘贴到输入框，然后单击“从URL安装”即可安装拓展包了。

更新mod
~~~~~~~

现在mod要发生更新了，更新内容为一个武将。先在init.lua中新增武将吧。

.. code:: lua

   local study_sunce = General(extension, "study_sunce", "wu", 4)
   Fk:loadTranslationTable{
     ["study_sunce"] = "孙伯符",
   }

保存，此时注意vscode左侧栏变成了：

::

   v fk_study
   └── init.lua            M

init.lua后面出现了“M”，并且文件名字也变成了黄色，这表示这个文件已经被修改过了，接下来我们把修改文件提交到仓库中：

.. code:: sh

   $ git add . # 将当前目录下的文件暂存
   $ git commit -m "add general sunce" # 提交更改，提交说明为add general sunce
   $ git push # “推”到远端，也就是把本地的更新传给远端

不喜欢用命令行的话，也可以用vscode自带的git支持完成这些操作，这里就不赘述了。做完git
push后，实际上就已经完成更新了，可以让大伙点点更新按钮来更新你的新版本了。

--------------

以上介绍了大致的创建mod以及更新的流程。至于资源文件组织等等杂七杂八的问题，请参考已有的例子拓展包。
