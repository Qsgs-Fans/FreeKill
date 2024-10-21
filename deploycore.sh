#!/bin/bash

# 游戏依托freekill-core这个特殊仓库进行日常更新与开发
# 在更新版本号之前，需要先把它们与自带的lua/同步一下

PWD=$(pwd)

if ! [ -e packages/freekill-core ]; then
  echo '需要有freekill-core才可执行'
  cd $PWD
  exit 1
fi

rm -r lua/

delcode() {
  cd $1
  find -name '*.lua' -delete
  find -empty -delete
  cd ..
}
cd packages
delcode standard
delcode standard_cards
delcode maneuvering

cp -r freekill-core/lua ..
cp -r freekill-core/standard .
cp -r freekill-core/standard_cards .
cp -r freekill-core/maneuvering .

cd $PWD
