# openscad-lasercut
Library to help with modelling and generating lasercut boxes in OpenSCAD

Depends on [<lasercut.scad>](https://github.com/bmsleight/lasercut)

To use, download and add this library to OpenSCAD, along with the one linked above. In your file, `include <lasercut-improved.scad>`

## Box
To create a box, use lasercutBox()
```
include <lasercut-improved.scad>

lasercutBox(width = 200, height = 100, depth = 50, thickness = 3.1, kerf = 0.05);
```
It will generate a tabbed box 200mm wide (along x-axis), 100mm high (along y-axis), and 50mm deep (along z-axis) for a material with a thickness of 3.1mm and with a kerf (material removed by laser on a cut) of 0.05mm

There are three other options to control the box:
* `empty_sides` is an array to specify what sides are open. Options are one or more of `TOP, BOTTOM, FRONT, BACK, LEFT, RIGHT`
* `horizontal_dividers` is an array of numbers to specify where dividers running horizontaly (across the width) go. These values may be less than 1, in which case they are treated as a ratio of the height of the box; or greater than 1, in which case they are treated as absolute measurements from the front wall of the box
* `vertical_dividers` is the same as `horizontal_dividers`, but running vertically, front to back, and placed relative to the width of the box
