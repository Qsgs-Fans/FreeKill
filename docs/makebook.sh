# SPDX-License-Identifier: GPL-3.0-or-later

#!/bin/bash

TEX_FILE=manual.tex
cd build/latex

# 给所有的标题加一个层级

if ! grep '\\part' $TEX_FILE; then
  sed -i 's/\\chapter/\\part/g' $TEX_FILE
  sed -i 's/\\section/\\chapter/g' $TEX_FILE
  sed -i 's/\\subsection/\\section/g' $TEX_FILE
  sed -i 's/\\subsubsection/\\subsection/g' $TEX_FILE
  sed -i 's/\\paragraph/\\subsubsection/g' $TEX_FILE
  sed -i 's/\\subparagraph/\\paragraph/g' $TEX_FILE
fi

# webp转jpg
sed -i 's/webp/jpg/g' $TEX_FILE
for webp in *.webp; do
  convert $webp -background white -alpha remove ${webp%%webp}jpg
done

# 好了，开始做pdf
make

cd ../..
