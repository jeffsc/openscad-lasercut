include <lasercut/lasercut.scad>

START_TAB=0;
START_SLOT=1;
TAB=START_TAB;
SLOT=START_SLOT;

TOP=0;
BOTTOM=1;
FRONT=2;
BACK=3;

tab_size=13;
min_tabs=2;
max_tabs=6;


// Generates a box or tray that can be laser-cut
// width is the x-axis, height is the y-axis, and depth is the z-axis
// width measures left wall to right wall; height measures front wall to back wall; depth measures bottom to top
// thickness is the material thickness
// kerf is how much the laser removes (for adjusting tabs)
// empty_sides is an array to specify what sides are open. Options are TOP, BOTTOM, FRONT, BACK, LEFT, RIGHT
// horizontal_dividers is an array of numbers to specify where dividers running horizontaly (across the width) go
//   These values may be less than 1, in which case they are treated as a ratio of the height of the box; or greater
//   than 1, in which case they are treated as absolute measurements
// vertical_dividers is the same as horizontal_dividers, but running vertically, front to back
module lasercutBox(width=0, height=0, depth=0, thickness=0, kerf=0, empty_sides=[], horizontal_dividers=[],
    vertical_dividers=[])
{
    w_tabs = tabCount(width);
    h_tabs = tabCount(height);
    d_tabs = tabCount(depth);

    has_top = !has_item(empty_sides, TOP);
    has_bottom = !has_item(empty_sides, BOTTOM);
    has_left = !has_item(empty_sides, LEFT);
    has_right = !has_item(empty_sides, RIGHT);
    has_front = !has_item(empty_sides, FRONT);
    has_back = !has_item(empty_sides, BACK);

    module floor() {
        lasercutSquare(thickness=thickness, kerf=kerf, x=width, y=height,
            tabs=concat([ has_front ? tab(DOWN, SLOT, w_tabs) : [], has_back ? tab(UP, SLOT, w_tabs) : [],
                has_left ? tab(LEFT, SLOT, h_tabs) : [], has_right ? tab(RIGHT, SLOT, h_tabs) : [] ],
            flatten([for(h=horizontal_dividers)
                [tab(direction=DOWN, start_type=TAB, num_tabs=w_tabs, side_offset=ratioLocation(h, height, thickness))]]),
            flatten([for(v=vertical_dividers)
                [tab(direction=LEFT, start_type=TAB, num_tabs=h_tabs, side_offset=ratioLocation(v, width, thickness))]])
        ));
    };
    // floor
    if (has_bottom)
    {
        floor();
    }
    // top
    if (has_top)
    {
        translate([0, 0, depth-thickness])
        floor();
    }

    module sideWall() {
        lasercutSquare(thickness=thickness, kerf=kerf, x=height, y=depth,
            tabs=concat([ has_front ? tab(LEFT, TAB, d_tabs) : [], has_back ? tab(RIGHT, TAB, d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, h_tabs) : [], has_top ? tab(UP, TAB, h_tabs) : [] ],
            flatten([for (h=horizontal_dividers)
                [tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, side_offset=ratioLocation(h, height, thickness))]])));
    };
    // left wall
    if (has_left)
    {
        rotate([90, 0, 90])
        sideWall();
    }
    // right wall
    if (has_right)
    {
        rotate([90, 0, 90])
        translate([0, 0, width-thickness])
        sideWall();
    }

    module frontWall() {
        lasercutSquare(thickness=thickness, kerf=kerf, x=width, y=depth,
            tabs=concat([ has_left ? tab(LEFT, SLOT, d_tabs) : [], has_right ? tab(RIGHT, SLOT, d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, w_tabs) : [], has_top ? tab(UP, TAB, w_tabs) : []],
            flatten([for (v=vertical_dividers)
                [tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, side_offset=ratioLocation(v, width, thickness))]])));
    };
    // front wall
    if (has_front)
    {
        rotate([90, 0, 0])
        translate([0, 0, -thickness])
        frontWall();
    }
    // back wall
    if (has_back)
    {
        rotate([90, 0, 0])
        translate([0, 0, -height])
        frontWall();
    }

    module horizDivider(div_loc) {
        rotate([90, 0, 0])
        translate([0, 0, -ratioLocation(div_loc, height, thickness)-thickness])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=width, y=depth,
            tabs=[ has_bottom ? tab(DOWN, SLOT, w_tabs) : [], has_top ? tab(UP, SLOT, w_tabs) : [],
                has_left ? tab(LEFT, SLOT, d_tabs) : [], has_right ? tab(RIGHT, SLOT, d_tabs) : []],
            cutouts=flatten([for (v=vertical_dividers)
                [intersectionSlot(total_width=width, total_height=depth, thickness=thickness, direction=DOWN, location=v)]])
        );
    };
    for (h=horizontal_dividers)
    { horizDivider(h); }

    module vertDivider(div_loc) {
        rotate([90, 0, 90])
        translate([0, 0, ratioLocation(div_loc, width, thickness)])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=height, y=depth,
            tabs=[ has_bottom ? tab(DOWN, SLOT, h_tabs) : [], has_top ? tab(UP, SLOT, h_tabs) : [],
                has_front ? tab(LEFT, SLOT, d_tabs) : [], has_back ? tab(RIGHT, SLOT, d_tabs) : []],
            cutouts=flatten([for (h=horizontal_dividers)
                [intersectionSlot(total_width=height, total_height=depth, thickness=thickness, direction=UP, location=h)]])
        );
    };
    for (v=vertical_dividers)
    { vertDivider(v); }
};

module laserimprovedSquare(thickness=0, x=0, y=0, kerf=0,
    tabs=[], circles_remove=[], slits=[], cutouts=[])
{
    lasercutSquare(thickness=thickness, x=x, y=y, kerf=kerf, tabs=tabs, circles_remove=circles_remove,
        slits=slits, cutouts=cutouts);
};

// Generates a face with tabs and other changes that can be laser-cut
// The 'tabs' array uses specifications generated from the 'tab' function
// circles_remove, slits, and cutouts are all passed directly through to lasercutoutSquare from the base library
module lasercutSquare(thickness=0, x=0, y=0, kerf=0,
    tabs=[], circles_remove=[], slits=[], cutouts=[])
{
    function tabCutout(num_t=0, tab_width=0, start=START_TAB, direction=UP,
        start_offset=0, tab_thickness, side_offset=0) =
        [ for ( i = [0 : totalTabs(num_t, (direction==RIGHT||direction==LEFT)?y:x,
                tab_width)] )
            [(direction==RIGHT||direction==LEFT) ?
                slotY(direction, x, side_offset, tab_thickness, kerf) :
                slotX(tab_width, start, start_offset, i, kerf),
            (direction==RIGHT||direction==LEFT) ?
                slotX(tab_width, start, start_offset, i, kerf) :
                slotY(direction, y, side_offset, tab_thickness, kerf),
            (direction==RIGHT||direction==LEFT) ? slotDepth(tab_thickness, kerf) :
                slotWidth(x, tab_width, num_t, start, i, kerf),
            (direction==RIGHT||direction==LEFT) ?
                slotWidth(y, tab_width, num_t, start, i, kerf) :
                slotDepth(tab_thickness, kerf)]
        ];

    new_cutouts = flatten([ for ( t = tabs )
        tabCutout((t[1]==START_TAB ? t[2] : t[2]+1),
            (t[3] ? t[3] : tabWidth((t[0]==RIGHT||t[0]==LEFT)?y:x, t[2])),
            t[1], t[0], t[4], t[5] ? t[5] : thickness, t[6]) ]);
    lasercutoutSquare(thickness=thickness, x=x, y=y,
        cutouts = concat(new_cutouts, cutouts),
        circles_remove=circles_remove,
        slits=slits
    );
};

// Generate a specification for a tabbed edge. Result is passed in the 'tabs' array for lasercutSquare
// Specify num_tabs or tab_width; the other will be calculated.
// start_offset allows you to shift the tabs along the axis to align with a differently-sized piece
// side_offset pushes the tabs into the shape for dividers
// tab_thickness can be specified if the adjoining piece is a different thickness
function tab(direction=UP, start_type=TAB, num_tabs=0, tab_width=0, start_offset=0, side_offset=0, tab_thickness=0) =
    [direction, start_type, num_tabs, tab_width, start_offset, tab_thickness, side_offset];

// Generates a specification for where two dividers intersect. Passed to the 'cutouts' array for lasercutSquare
function intersectionSlot(total_width=0, total_height=0, thickness=0, location=0, direction=UP) =
        [ratioLocation(location, total_width, thickness), direction==UP ? total_height/2 : 0,
            thickness, total_height/2];

function ratioLocation(loc, size, thickness) = loc > 1 ? loc : size*loc-thickness/2;

function slotX(tab_width=0, start=START_TAB, start_offset=0, i=0, kerf=0) =
    tab_width*2*i + (start==START_TAB ? tab_width : 0) +
            (start_offset ? start_offset : 0) +
            (i==0 && start==START_SLOT ? 0 : kerf);
function slotY(direction=UP, y=0, side_offset=0, thickness=0, kerf=0) =
    (direction==UP||direction==RIGHT ? y - thickness + kerf: 0) + (side_offset ? side_offset : 0);
function slotWidth(x=0, tab_width=0, num_t=0, start=START_TAB, i=0, kerf=0) =
    tab_width -
    kerf*(((i==0||i==totalTabs(num_t, x, tab_width)) && start==START_SLOT)? 1 : 2);
function slotDepth(thickness=0, kerf=0) = thickness - kerf;

function tabCount(w) = min(max(floor((w/tab_size+1)/2), min_tabs), max_tabs);
function totalTabs(num_t=0, x=0, tab_width=0) =
    (num_t > 1 ? num_t : (x/tab_width+1)/2) - 2;
function tabWidth(total_w = 0, num_t = 0) = total_w/(num_t*2 - 1);

function flatten(l) = [ for (a = l) for (b = a) b ] ;
function has_item(list, item) = [for (i=list) if (i==item) true][0] || false;
