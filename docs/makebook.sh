#!/bin/bash

TEX_FILE=manual.tex
cd build/latex

sed -i 's/\\chapter/\\part/g' $TEX_FILE
sed -i 's/\\section/\\chapter/g' $TEX_FILE
sed -i 's/\\subsection/\\section/g' $TEX_FILE
sed -i 's/\\subsubsection/\\subsection/g' $TEX_FILE
sed -i 's/\\paragraph/\\subsubsection/g' $TEX_FILE
sed -i 's/\\subparagraph/\\paragraph/g' $TEX_FILE

make

cd ../..
