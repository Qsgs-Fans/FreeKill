#!/bin/sh

if [ ! -e assets/res ]; then
  mkdir -p assets/res
fi

cp -r ../fonts assets/res
cp -r ../image assets/res
cp -r ../lua assets/res
cp -r ../packages assets/res
cp -r ../qml assets/res
cp -r ../server assets/res
rm assets/res/server/users.db
cp ../LICENSE assets/res

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

