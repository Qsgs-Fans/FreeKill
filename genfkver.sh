#!/bin/sh

# 为fk_ver文件追加编译时相关文件列表
# 类似其他项目中flist.txt的功能

cd $(dirname $0)
sed -i '2,$d' ./fk_ver

fn() {
  for f in $(ls -1 $1 | sort); do
    if [ -d $1/$f ]; then
      fn $1/$f
    else
      echo $1/$f >> ./fk_ver
    fi
  done
}

fn lua
fn Fk
cd -
