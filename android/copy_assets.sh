#!/bin/sh

rm -rf res assets

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
mkdir assets/res/packages
cp -r ../packages/standard assets/res/packages
cp -r ../packages/standard_cards assets/res/packages
cp -r ../packages/test assets/res/packages
cp ../packages/init.sql assets/res/packages
cp -r ../qml assets/res
cp -r ../server assets/res
rm assets/res/server/users.db
cp ../LICENSE assets/res
cp ../zh_CN.qm assets/res

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

