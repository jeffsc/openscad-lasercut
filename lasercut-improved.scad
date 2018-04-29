// requires https://github.com/bmsleight/lasercut
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

    h_dividers = quicksortSubVectors(standardDividers(horizontal_dividers));
    v_dividers = quicksortSubVectors(standardDividers(vertical_dividers));

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
            flatten([for(h=h_dividers)
                [tab(direction=DOWN, start_type=TAB, num_tabs=w_tabs,
                    // Divider tabs may be clipped if the divider is not full-width
                    start_clip=h[1] ? dividerStart(h[1], width, thickness, v_dividers)+thickness : 0,
                    end_clip=h[2] ? dividerEnd(h[2], width, thickness, v_dividers)-thickness : 0,
                    side_offset=ratioLocation(h, height, thickness))]]),
            flatten([for(v=v_dividers)
                [tab(direction=LEFT, start_type=TAB, num_tabs=h_tabs,
                    start_clip=v[1] ? dividerStart(v[1], height, thickness, h_dividers)+thickness : 0,
                    end_clip=v[2] ? dividerEnd(v[2], height, thickness, h_dividers)-thickness : 0,
                    side_offset=ratioLocation(v, width, thickness))]])
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

    module sideWall(isRight=false) {
        lasercutSquare(thickness=thickness, kerf=kerf, x=height, y=depth,
            tabs=concat([ has_front ? tab(LEFT, TAB, d_tabs) : [], has_back ? tab(RIGHT, TAB, d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, h_tabs) : [], has_top ? tab(UP, TAB, h_tabs) : [] ],
            flatten([for (h=h_dividers)
                // Dividers may not have tab slots if they're not full-width
                [!isRight && h[1] && h[1] > 0 || isRight && h[2] && h[2] != 0 ? [] :
                    tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs,
                        side_offset=ratioLocation(h, height, thickness))]])
        ));
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
        sideWall(true);
    }

    module frontWall(isBack=false) {
        lasercutSquare(thickness=thickness, kerf=kerf, x=width, y=depth,
            tabs=concat([ has_left ? tab(LEFT, SLOT, d_tabs) : [], has_right ? tab(RIGHT, SLOT, d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, w_tabs) : [], has_top ? tab(UP, TAB, w_tabs) : []],
            flatten([for (v=v_dividers)
                // Dividers may not have tab slots if they're not full-width
                [!isBack && v[1] && v[1] > 0 || isBack && v[2] && v[2] != 0 ? [] :
                    tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs,
                        side_offset=ratioLocation(v, width, thickness))]])));
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
        frontWall(true);
    }

    module horizDivider(div_loc, start_div, end_div, i) {
        // Grab the start and end of the divider
        start_loc = dividerStart(start_div, width, thickness, v_dividers);
        end_loc = dividerEnd(end_div, width, thickness, v_dividers);
        hd_tw = tabWidth(width, w_tabs);
        rotate([90, 0, 0])
        translate([start_loc, 0, -ratioLocation(div_loc, height, thickness)-thickness])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=(end_loc-start_loc), y=depth,
            tabs=concat([ has_bottom ? tab(DOWN, SLOT, w_tabs, hd_tw, -start_loc) : [],
                has_top ? tab(UP, SLOT, w_tabs, hd_tw, -start_loc) : [],
                // Check for aligning at beginning of box, or intersecting the divider where it starts
                has_left && (start_div==0 || v_dividers[start_div-1][1]-1 < i &&
                    v_dividers[start_div-1][2]+len(h_dividers) > i) ?
                    tab(LEFT, SLOT, d_tabs) : [],
                // Check for aligning at end of box, or intersecting the divider where it ends
                has_right && (end_div==0 || v_dividers[end_div+len(v_dividers)][1]-1 <  i &&
                    v_dividers[end_div+len(v_dividers)][2]+len(h_dividers) > i) ?
                    tab(RIGHT, SLOT, d_tabs) : []],
                // Check if vertical dividers start/end here
                flatten([for(v=v_dividers)
                    [v[1]-1 == i || v[2]+len(h_dividers) == i ?
                        tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs,
                            side_offset=ratioLocation(v, width, thickness)-start_loc) : []]])),
            cutouts=(start_div > len(v_dividers)+end_div-1) ? [] :
                // Add intersection slots of dividers only if they intersect
                flatten([for (vi=[start_div : max(start_div, len(v_dividers)+end_div-1)]) let(v=v_dividers[vi])
                [v[1] <= i && len(h_dividers)+v[2] > i ?
                intersectionSlot(total_width=width, total_height=depth, thickness=thickness, direction=DOWN,
                    start_offset=start_loc, location=v[0]) : []]])
        );
    };
    for (hi=[0: max(0, len(h_dividers)-1)]) let (h = h_dividers[hi])
    { horizDivider(h[0], h[1], h[2], hi); }

    module vertDivider(div_loc, start_div, end_div, i) {
        start_loc = dividerStart(start_div, height, thickness, h_dividers);
        end_loc = dividerEnd(end_div, height, thickness, h_dividers);
        vd_tw = tabWidth(height, h_tabs);
        rotate([90, 0, 90])
        translate([start_loc, 0, ratioLocation(div_loc, width, thickness)])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=(end_loc-start_loc), y=depth,
            tabs=concat([ has_bottom ? tab(DOWN, SLOT, h_tabs, vd_tw, -start_loc) : [],
                has_top ? tab(UP, SLOT, h_tabs, vd_tw, -start_loc) : [],
                // Check for aligning at bottom of box, or intersecting the horizontal divider where it starts
                has_front && (start_div==0 || h_dividers[start_div-1][1]-1 <= i &&
                    h_dividers[start_div-1][2]+len(v_dividers) > i) ? tab(LEFT, SLOT, d_tabs) : [],
                // Check for aligning at top of box, or intersecting the divider where it ends
                has_back && (end_div==0 || h_dividers[end_div+len(h_dividers)][1]-1 <=  i &&
                    h_dividers[end_div+len(h_dividers)][2]+len(v_dividers) > i) ?
                    tab(RIGHT, SLOT, d_tabs) : []],
                // Check if horizontal dividers start/end here
                flatten([for(j=[0:max(0, len(h_dividers)-1)]) let(h=h_dividers[j])
                    [h[1]-1 == i && j != start_div-1 &&
                            j != end_div+len(h_dividers) ||
                        h[2]+len(v_dividers) == i && j != start_div-1 &&
                            j != end_div+len(h_dividers) ?
                        tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs,
                            side_offset=ratioLocation(h, height, thickness)-start_loc) : []]])),
            cutouts=(start_div > len(h_dividers)+end_div-1) ? [] :
                // Add intersection slots only if divider intersects
                flatten([for (hi=[start_div : len(h_dividers)+end_div-1]) let(h=h_dividers[hi])
                [h[1] <= i && len(v_dividers)+h[2] > i ?
                intersectionSlot(total_width=height, total_height=depth, thickness=thickness, direction=UP,
                    start_offset=start_loc, location=h[0]) : []]])
        );
    };
    for (vi=[0: max(0, len(v_dividers)-1)]) let (v = v_dividers[vi])
    { vertDivider(v[0], v[1], v[2], vi); }
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
    tabs=[], circles_remove=[], circles_add=[], slits=[], cutouts=[])
{
    function tabCutout(num_t=0, tab_width=0, start=START_TAB, direction=UP,
        start_offset=0, tab_thickness, side_offset=0, start_clip=0, end_clip=0) =
        [ for ( i = [0 : totalTabs(num_t, (direction==RIGHT||direction==LEFT)?y:x,
                tab_width)] )
            [(direction==RIGHT||direction==LEFT) ?
                slotY(direction, x, side_offset, tab_thickness, kerf) :
                slotX(tab_width, start, start_offset, start_clip, i, kerf),
            (direction==RIGHT||direction==LEFT) ?
                slotX(tab_width, start, start_offset, start_clip, i, kerf) :
                slotY(direction, y, side_offset, tab_thickness, kerf),
            (direction==RIGHT||direction==LEFT) ? slotDepth(tab_thickness, kerf) :
                slotWidth(x, tab_width, num_t, start, start_offset, start_clip, end_clip, i, kerf),
            (direction==RIGHT||direction==LEFT) ?
                slotWidth(y, tab_width, num_t, start, start_offset, start_clip, end_clip, i, kerf) :
                slotDepth(tab_thickness, kerf)]
        ];

    new_cutouts = flatten([ for ( t = tabs )
        tabCutout((t[1]==START_TAB ? t[2] : t[2]+1),
            (t[3] ? t[3] : tabWidth((t[0]==RIGHT||t[0]==LEFT)?y:x, t[2])),
            t[1], t[0], t[4], t[5] ? t[5] : thickness, t[6], t[7], t[8]) ]);
    lasercutoutSquare(thickness=thickness, x=x, y=y,
        cutouts = concat(new_cutouts, cutouts),
        circles_remove=circles_remove, circles_add=circles_add,
        slits=slits
    );
};

// Generate a specification for a tabbed edge. Result is passed in the 'tabs' array for lasercutSquare
// Specify num_tabs or tab_width; the other will be calculated.
// start_offset allows you to shift the tabs along the axis to align with a differently-sized piece
// side_offset pushes the tabs into the shape for dividers
// tab_thickness can be specified if the adjoining piece is a different thickness
function tab(direction=UP, start_type=TAB, num_tabs=0, tab_width=0, start_offset=0, side_offset=0, tab_thickness=0,
    start_clip=0, end_clip=0) =
    [direction, start_type, num_tabs, tab_width, start_offset, tab_thickness, side_offset, start_clip, end_clip];

// Generates a specification for where two dividers intersect. Passed to the 'cutouts' array for lasercutSquare
function intersectionSlot(total_width=0, total_height=0, thickness=0, location=0, start_offset=0, direction=UP) =
        [ratioLocation(location, total_width, thickness)-start_offset, direction==UP ? total_height/2 : 0,
            thickness, total_height/2];

function ratioLocation(loc, size, thickness) = ratioLocCalc(loc[0] ? loc[0] : loc, size, thickness);
function ratioLocCalc(loc, size, thickness) = loc > 1 ? loc : size*loc-thickness/2;
function dividerStart(start_div, total_w, thickness, vertical_dividers) = start_div == 0 ? 0 :
    ratioLocation(vertical_dividers[start_div-1], total_w, thickness);
function dividerEnd(end_div, total_w, thickness, vertical_dividers) = end_div == 0 ? total_w :
    ratioLocation(vertical_dividers[len(vertical_dividers)+end_div], total_w, thickness) + thickness;

function slotX(tab_width=0, start=START_TAB, start_offset=0, start_clip=0, i=0, kerf=0) =
    let(tx=tab_width*2*i + (start==START_TAB ? tab_width : 0) +
            (start_offset ? start_offset : 0) +
            (i==0 && start==START_SLOT ? 0 : kerf))
    start_clip==0 ? tx : max(start_clip, tx);
function slotY(direction=UP, y=0, side_offset=0, thickness=0, kerf=0) =
    (direction==UP||direction==RIGHT ? y - thickness + kerf: 0) + (side_offset ? side_offset : 0);
function slotWidth(x=0, tab_width=0, num_t=0, start=START_TAB, start_offset=0, start_clip=0, end_clip=0, i=0, kerf=0) =
    let(tw=tab_width -
        kerf*(((i==0||i==totalTabs(num_t, x, tab_width)) && start==START_SLOT)? 1 : 2))
    let(tx=slotX(tab_width, start, start_offset, 0, i, kerf))
    let(tw2=min(tw, tx+tw-start_clip))
    end_clip==0 ? tw2 : min(tw2, end_clip-(tx+tw2));
function slotDepth(thickness=0, kerf=0) = thickness - kerf;

function tabCount(w) = min(max(floor((w/tab_size+1)/2), min_tabs), max_tabs);
function totalTabs(num_t=0, x=0, tab_width=0) =
    (num_t > 1 ? num_t : (x/tab_width+1)/2+1) - 2;
function tabWidth(total_w = 0, num_t = 0) = total_w/(num_t*2 - 1);

function flatten(l) = [ for (a = l) for (b = a) b ] ;
function has_item(list, item) = [for (i=list) if (i==item) true][0] || false;

// Standardize the dividers with full arrays and sorted in order
function standardDividers(divs) = [for(d=divs) [d[0] ? d[0] : d, d[1] ? d[1] : 0, d[2] ? d[2] : 0]];
function quicksortSubVectors(arr) = !(len(arr)>0) ? [] : let(
    pivot   = arr[floor(len(arr)/2)][0],
    lesser  = [ for (y = arr) if (y[0] < pivot) y ],
    equal   = [ for (y = arr) if (y[0] == pivot) y ],
    greater = [ for (y = arr) if (y[0] > pivot) y ]
) concat(
    quicksortSubVectors(lesser), equal, quicksortSubVectors(greater)
);
