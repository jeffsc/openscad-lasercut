#!/usr/bin/zsh
openscad $1 -D generate=2 -o $1.csg 2>&1 >/dev/null  | sed 's/ECHO: \"\[LC\] //' | sed 's/"$//' | sed '$a;' >./2d_$1
sed -i "1iuse <lasercut-improved/lasercut-improved.scad>; \$fn=60; \n projection(cut = false) \n"  ./2d_$1
openscad ./2d_$1 -o ./2d_$1.svg
rm $1.csg 2d_$1
