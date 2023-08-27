#!/bin/bash

dir=FreeKill-${FK_VER}
mkdir $dir
echo Copying
cp -r ./Freekill/.git $dir

cd $dir
git restore .
git checkout v$FK_VER
rm -rf .git lib docker docs android wasm
cd ..

echo Compressing
tar cfz ${dir}-source.tar.gz $dir
