.. SPDX-License-Identifier: GFDL-1.3-or-later

解析：Exppattern
================

所谓Exppattern，类似于各大编程语言中的正则表达式。不过和正则表达式不同的是，正则匹配的是字符串，而Exppattern匹配的对象是一张张卡牌。通过Exppattern可以判断各种卡牌的情况，比如这张牌是否符合“既是红桃，也是点数3-5的牌”等等一系列复杂的规则。

你可能也已经注意到了，在不少Room中的askFor...函数中，出现了很多次pattern参数。这个pattern就是Exppattern，它用来辅助确定询问的卡牌必须满足哪些需求。


