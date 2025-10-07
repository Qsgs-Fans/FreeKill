#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

rm -rf res/mipmap assets

if [ ! -e res/mipmap ]; then
  mkdir -p res/mipmap
fi
cp ../image/icon.png res/mipmap

if [ ! -e assets/res ]; then
  mkdir -p assets/res
fi

cp -r ../audio assets/res
cp -r ../fonts assets/res
cp -r ../image assets/res
cp -r ../lua assets/res
# TODO: Windows hosts machine
cp -r /etc/ca-certificates/extracted/cadir assets/res/certs
chmod 644 assets/res/certs/*
mkdir assets/res/packages
cp -r ../packages/standard assets/res/packages
cp -r ../packages/standard_cards assets/res/packages
cp -r ../packages/maneuvering assets/res/packages
cp -r ../packages/test assets/res/packages
rm assets/res/packages/test/test.lua
cp ../packages/*.sql assets/res/packages
cp -r ../Fk assets/res
mkdir assets/res/server
cp ../server/*.sql assets/res/server
mkdir assets/res/client
cp ../client/*.sql assets/res/client
cp ../LICENSE assets/res
cp ../zh_CN.qm assets/res
cp ../en_US.qm assets/res
cp ../vi_VN.qm assets/res
cp ../fk_ver assets/res
cp ../waiting_tips.txt assets/res

# Due to Qt Android's bug, we need make sure every directory has a subfile (not subdir)
function fixDir() {
  cd $1
  hasSubfile=false
  for f in $(ls); do
    if [ -f $f ]; then
      hasSubfile=true
      break
    fi
  done

  if ! $hasSubfile; then
    echo "辣鸡Qt" > bug.txt
  fi

  for f in $(ls); do
    if [ -d $f ]; then
      fixDir $f
    fi
  done
  cd ..
}

fixDir assets/res

