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

finger_d=25;

tab_size=13;
min_tabs=2;
max_tabs=6;

corner_r=3;
finger_padding=3;

divider_handle_limit = 1/6;

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
// finger_holes can be a boolean or an array of sides. Cuts out finger holes for the tray
// side_cuts cuts down the sides, leaving posts at the corners; and optionally in the middle; also optionally with finger holes
//  Parameter is: [depth, size of end posts, max cut length (creates extra posts in the middle), array of sides (default is all),
//      boolean if to put finger holes in center posts, boolean if to put a post in dividers in the middle]
module lasercutBox(width=0, height=0, depth=0, thickness=0, kerf=0, empty_sides=[], horizontal_dividers=[],
    vertical_dividers=[], finger_holes=false, side_cuts=[])
{
    fh_top = finger_holes == true || len(finger_holes) && has_item(finger_holes, TOP);
    fh_bottom = finger_holes == true || len(finger_holes) && has_item(finger_holes, BOTTOM);
    fh_left = finger_holes == true || len(finger_holes) && has_item(finger_holes, LEFT);
    fh_right = finger_holes == true || len(finger_holes) && has_item(finger_holes, RIGHT);
    fh_front = finger_holes == true || len(finger_holes) && has_item(finger_holes, FRONT);
    fh_back = finger_holes == true || len(finger_holes) && has_item(finger_holes, BACK);

    inner_depth = side_cuts[0] ? depth-side_cuts[0] : depth;
    wt = tabCount(width);
    w_tabs = (fh_front || fh_back) && (wt % 2 == 0) ? wt+1 : wt;
    ht = tabCount(height);
    h_tabs = (fh_left || fh_right) && (ht % 2 == 0) ? ht-1 : ht;
    d_tabs = tabCount(inner_depth);
    corner_d_tabs = tabCount(depth);
    inner_tab_w = tabWidth(inner_depth, d_tabs);

    h_dividers = quicksortSubVectors(standardDividers(horizontal_dividers));
    v_dividers = quicksortSubVectors(standardDividers(vertical_dividers));

    has_top = !has_item(empty_sides, TOP);
    has_bottom = !has_item(empty_sides, BOTTOM);
    has_left = !has_item(empty_sides, LEFT);
    has_right = !has_item(empty_sides, RIGHT);
    has_front = !has_item(empty_sides, FRONT);
    has_back = !has_item(empty_sides, BACK);

    module floor(isTop = false) {
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
                    side_offset=ratioLocation(v, width, thickness)
                    )]])
        ),
        circles_remove = isTop && fh_top || !isTop && fh_bottom ? [[finger_d/2, width/2, height/2]] : []);
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
        floor(true);
    }

    function fingerSlit(fh) = [ fh && !has_top ? [[TOP, 1/2, finger_d,
        depth-finger_d/2-thickness*(has_bottom && has_top ? 2 : has_bottom || has_top ? 1 : 0)]] : [] ];
    function fingerSlitBottom(fh, dim) = [fh ? [[finger_d/2, dim/2, (has_bottom ? thickness : 0)+finger_d/2]] : []];

    sc_fingers = side_cuts[4];
    sc_end_post_size = side_cuts[1] ? side_cuts[1] : min(height, width)*0.1;
    sc_mid_post_size = max(sc_end_post_size, sc_fingers ? finger_d+finger_padding*2 : 0);
    sc_max_cut = side_cuts[2];
    function sideCutNum(dim) = sc_max_cut ? ceil((dim-sc_end_post_size*2) / (sc_max_cut+sc_mid_post_size)) : 1;
    function sideCutSize(dim, num) = (dim-sc_end_post_size*2-sc_mid_post_size*(num-1))/num;
    function sideCut(dim) = let(
            num_c = sideCutNum(dim),
            cut_size = sideCutSize(dim, num_c)
        )
        [ side_cuts[0] ? [for (i=[1:num_c]) [TOP, sc_end_post_size+sc_mid_post_size*(i-1)+cut_size*(i-1)+cut_size/2, cut_size, side_cuts[0]]] : []];
    function sideCutFingers(dim, dim2) = [ side_cuts[0] && sc_fingers && (sideCutNum(dim) > 1) ? [for (i=[1:sideCutNum(dim)-1])
        [finger_d/2, sideCutSize(dim, sideCutNum(dim))*i + sc_end_post_size+sc_mid_post_size*(i-0.5), dim2-finger_d/2-finger_padding]] : []];
    function isSideCut(side) = side_cuts[0] && (!len(side_cuts[3]) || has_item(side_cuts[3], side));

    module sideWall(isRight=false) {
        fh = isRight && fh_right || !isRight && fh_left;
        lasercutSquare(thickness=thickness, kerf=kerf, x=height, y=depth,
            tabs=concat([ has_front ? tab(LEFT, TAB, corner_d_tabs) : [], has_back ? tab(RIGHT, TAB, corner_d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, h_tabs) : [], has_top ? tab(UP, TAB, h_tabs) : [] ],
                flatten([for (h=h_dividers)
                    // Dividers may not have tab slots if they're not full-width
                    [!isRight && h[1] && h[1] > 0 || isRight && h[2] && h[2] != 0 ? [] :
                        tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, tab_width=inner_tab_w,
                            side_offset=ratioLocation(h, height, thickness))]])
            ),
            edge_slits = flatten(concat(fingerSlit(fh), isSideCut(isRight ? RIGHT : LEFT) ? sideCut(height) : [])),
            circles_remove = flatten(concat(fingerSlitBottom(fh, height), isSideCut(isRight ? RIGHT : LEFT) ? sideCutFingers(height, depth) : []))
        );
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
        fh = isBack && fh_back || !isBack && fh_front;
        lasercutSquare(thickness=thickness, kerf=kerf, x=width, y=depth,
            tabs=concat([ has_left ? tab(LEFT, SLOT, corner_d_tabs) : [], has_right ? tab(RIGHT, SLOT, corner_d_tabs) : [],
                has_bottom ? tab(DOWN, TAB, w_tabs) : [], has_top ? tab(UP, TAB, w_tabs) : []],
            flatten([for (v=v_dividers)
                // Dividers may not have tab slots if they're not full-width
                [!isBack && v[1] && v[1] > 0 || isBack && v[2] && v[2] != 0 ? [] :
                    tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, tab_width=inner_tab_w,
                        side_offset=ratioLocation(v, width, thickness))]])),
            edge_slits = flatten(concat(fingerSlit(fh), isSideCut(isBack ? BACK : FRONT) ? sideCut(width) : [])),
            circles_remove = flatten(concat(fingerSlitBottom(fh, width), isSideCut(isBack ? BACK : FRONT) ? sideCutFingers(width, depth) : []))
        );
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

    div_handle = side_cuts[0] && sc_fingers && side_cuts[5] ? dividerHandle(h_dividers, width, v_dividers, height, thickness) : [];
    div_handle_r = (min(finger_d+finger_padding, depth-inner_depth)-finger_padding)/2;
    module horizDivider(div_loc, start_div, end_div, i) {
        is_div_handle = div_handle ? div_handle[2] == "h" && div_handle[1] == i : false;
        // Grab the start and end of the divider
        start_loc = dividerStart(start_div, width, thickness, v_dividers);
        end_loc = dividerEnd(end_div, width, thickness, v_dividers);
        hd_tw = tabWidth(width, w_tabs);
        x=end_loc-start_loc;
        hes_w=(x-div_handle_r*2-finger_padding*2)/2;
        rotate([90, 0, 0])
        translate([start_loc, 0, -ratioLocation(div_loc, height, thickness)-thickness])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=x, y=is_div_handle ? depth : inner_depth,
            tabs=concat([ has_bottom ? tab(DOWN, SLOT, w_tabs, hd_tw, -start_loc) : [],
                has_top ? tab(UP, SLOT, w_tabs, hd_tw, -start_loc) : [],
                // Check for aligning at beginning of box, or intersecting the divider where it starts
                has_left && (start_div==0 || v_dividers[start_div-1][1]-1 < i &&
                    v_dividers[start_div-1][2]+len(h_dividers) > i) ?
                    tab(LEFT, SLOT, d_tabs, inner_tab_w) : [],
                // Check for aligning at end of box, or intersecting the divider where it ends
                has_right && (end_div==0 || v_dividers[end_div+len(v_dividers)][1]-1 <  i &&
                    v_dividers[end_div+len(v_dividers)][2]+len(h_dividers) > i) ?
                    tab(RIGHT, SLOT, d_tabs, inner_tab_w) : []],
                // Check if vertical dividers start/end here
                flatten([for(v=v_dividers)
                    [v[1]-1 == i || v[2]+len(h_dividers) == i ?
                        tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, tab_width=inner_tab_w,
                            side_offset=ratioLocation(v, width, thickness)-start_loc) : []]])),
            cutouts=(start_div > len(v_dividers)+end_div-1) ? [] :
                // Add intersection slots of dividers only if they intersect
                flatten([for (vi=[start_div : max(start_div, len(v_dividers)+end_div-1)]) let(v=v_dividers[vi])
                [v[1] <= i && len(h_dividers)+v[2] > i ?
                intersectionSlot(total_width=width, total_height=inner_depth, thickness=thickness, direction=div_handle && div_handle[2] == "v" ? UP : DOWN,
                    start_offset=start_loc, location=v[0]) : []]]),
            circles_remove = is_div_handle ? [[div_handle_r, width/2, depth-div_handle_r-finger_padding]] : [],
            edge_slits = is_div_handle ? [[TOP, hes_w/2, hes_w, depth-inner_depth], [TOP, x-hes_w/2, hes_w, depth-inner_depth]] : []
        );
    };
    if (h_dividers)
    {
        for (hi=[0: max(0, len(h_dividers)-1)]) let (h = h_dividers[hi])
        { horizDivider(h[0], h[1], h[2], hi); }
    }

    module vertDivider(div_loc, start_div, end_div, i) {
        is_div_handle = div_handle ? div_handle[2] == "v" && div_handle[1] == i : false;
        start_loc = dividerStart(start_div, height, thickness, h_dividers);
        end_loc = dividerEnd(end_div, height, thickness, h_dividers);
        vd_tw = tabWidth(height, h_tabs);
        x=end_loc-start_loc;
        hes_w=(x-div_handle_r*2-finger_padding*2)/2;
        rotate([90, 0, 90])
        translate([start_loc, 0, ratioLocation(div_loc, width, thickness)])
        laserimprovedSquare(thickness=thickness, kerf=kerf, x=x, y=is_div_handle ? depth : inner_depth,
            tabs=concat([ has_bottom ? tab(DOWN, SLOT, h_tabs, vd_tw, -start_loc) : [],
                has_top ? tab(UP, SLOT, h_tabs, vd_tw, -start_loc) : [],
                // Check for aligning at bottom of box, or intersecting the horizontal divider where it starts
                has_front && (start_div==0 || h_dividers[start_div-1][1]-1 <= i &&
                    h_dividers[start_div-1][2]+len(v_dividers) > i) ? tab(LEFT, SLOT, d_tabs, inner_tab_w) : [],
                // Check for aligning at top of box, or intersecting the divider where it ends
                has_back && (end_div==0 || h_dividers[end_div+len(h_dividers)][1]-1 <=  i &&
                    h_dividers[end_div+len(h_dividers)][2]+len(v_dividers) > i) ?
                    tab(RIGHT, SLOT, d_tabs, inner_tab_w) : []],
                // Check if horizontal dividers start/end here
                flatten([for(j=[0:max(0, len(h_dividers)-1)]) let(h=h_dividers[j])
                    [h[1]-1 == i && j != start_div-1 &&
                            j != end_div+len(h_dividers) ||
                        h[2]+len(v_dividers) == i && j != start_div-1 &&
                            j != end_div+len(h_dividers) ?
                        tab(direction=LEFT, start_type=TAB, num_tabs=d_tabs, tab_width=inner_tab_w,
                            side_offset=ratioLocation(h, height, thickness)-start_loc) : []]])),
            cutouts=(start_div > len(h_dividers)+end_div-1) ? [] :
                // Add intersection slots only if divider intersects
                flatten([for (hi=[start_div : len(h_dividers)+end_div-1]) let(h=h_dividers[hi])
                [h[1] <= i && len(v_dividers)+h[2] > i ?
                intersectionSlot(total_width=height, total_height=inner_depth, thickness=thickness, direction=div_handle && div_handle[2] == "v" ? DOWN : UP,
                    start_offset=start_loc, location=h[0]) : []]]),
            circles_remove = is_div_handle ? [[div_handle_r, height/2, depth-div_handle_r-finger_padding]] : [],
            edge_slits = is_div_handle ? [[TOP, hes_w/2, hes_w, depth-inner_depth], [TOP, x-hes_w/2, hes_w, depth-inner_depth]] : []
        );
    };
    if (v_dividers)
    {
        for (vi=[0: max(0, len(v_dividers)-1)]) let (v = v_dividers[vi])
        { vertDivider(v[0], v[1], v[2], vi); }
    }
};

module laserimprovedSquare(thickness=0, x=0, y=0, kerf=0,
    tabs=[], circles_remove=[], slits=[], cutouts=[], edge_slits=[], corner_radius=corner_r)
{
    lasercutSquare(thickness=thickness, x=x, y=y, kerf=kerf, tabs=tabs, circles_remove=circles_remove,
        slits=slits, cutouts=cutouts, edge_slits=edge_slits, corner_radius=corner_radius);
};

// Generates a face with tabs and other changes that can be laser-cut
// The 'tabs' array uses specifications generated from the 'tab' function
// edge_slits takes an array of slits to cut: [side (LEFT, RIGHT, TOP, BOTTOM), x (distance along edge), width, depth]
// corner_radius sets the radius of rounded corners in the edge slits. Set to 0 to disable
// circles_remove, slits, and cutouts are all passed directly through to lasercutoutSquare from the base library
module lasercutSquare(thickness=0, x=0, y=0, kerf=0,
    tabs=[], circles_remove=[], circles_add=[], edge_slits=[], slits=[], cutouts=[],
    corner_radius=corner_r)
{
    function tabCutout(num_t=0, tab_width=0, start=START_TAB, direction=UP,
        start_offset=0, tab_thickness, side_offset=0, start_clip=0, end_clip=0) =
        [ for ( i = [0 : totalTabs(num_t, (direction==RIGHT||direction==LEFT)?y:x,
                tab_width)] )
            [(direction==RIGHT||direction==LEFT) ?
                slotY(direction, x, side_offset, tab_thickness, side_offset==0 ? kerf : 0) :
                slotX(tab_width, start, start_offset, start_clip, i, side_offset==0 ? kerf : 0),
            (direction==RIGHT||direction==LEFT) ?
                slotX(tab_width, start, start_offset, start_clip, i, side_offset==0 ? kerf : 0) :
                slotY(direction, y, side_offset, tab_thickness, side_offset==0 ? kerf : 0),
            (direction==RIGHT||direction==LEFT) ? slotDepth(tab_thickness, side_offset==0 ? kerf : 0) :
                slotWidth(x, tab_width, num_t, start, start_offset, start_clip, end_clip, i, side_offset==0 ? kerf : 0),
            (direction==RIGHT||direction==LEFT) ?
                slotWidth(y, tab_width, num_t, start, start_offset, start_clip, end_clip, i, side_offset==0 ? kerf : 0) :
                slotDepth(tab_thickness, side_offset==0 ? kerf : 0)]
        ];

    tab_cutouts = flatten([ for ( t = tabs )
        tabCutout((t[1]==START_TAB ? t[2] : t[2]+1),
            (t[3] ? t[3] : tabWidth((t[0]==RIGHT||t[0]==LEFT)?y:x, t[2])),
            t[1], t[0], t[4], t[5] ? t[5] : thickness, t[6], t[7], t[8]) ]);

    function esXLoc(side, e_x, width, depth) = (side==BOTTOM || side==TOP ? (e_x < 1 ? e_x*x : e_x)-width/2 : side==LEFT ? 0 : x-depth);
    function esYLoc(side, e_x, width, depth) = (side==LEFT || side==RIGHT ? (e_x < 1 ? e_x*y : e_x)-width/2 : side==BOTTOM ? 0 : y-depth);
    function esCutout(side=BOTTOM, e_x=0, width=0, depth=0) =
        [
            esXLoc(side, e_x, width, depth),
            esYLoc(side, e_x, width, depth),
            side==BOTTOM || side==TOP ? width : depth,
            side==LEFT || side==RIGHT ? width : depth
        ];
    slit_cutouts = flatten([ for ( e = edge_slits )
        [esCutout(e[0], e[1], e[2], e[3]), corner_radius > 0 ? esCutout(e[0], e[1], e[2]+corner_radius*2, corner_radius) : []]
    ]);

    union() {
        if (corner_radius > 0)
        {
            for (e = edge_slits)
            {
                rx1=esXLoc(e[0], e[1], e[2], e[3])+(e[0]==RIGHT ? e[3] : 0);
                ry1=esYLoc(e[0], e[1], e[2], e[3]) + (e[0] == TOP ? e[3] : 0);
                if ((e[0]==TOP && rx1 > 0 || e[0]!=TOP && rx1 >= 0) && rx1 <= x &&
                    (e[0]!=BOTTOM && ry1 > 0 || e[0]==BOTTOM && ry1 >= 0) && ry1 <= y)
                    roundedCorner(corner_radius, thickness, x=rx1, y=ry1, left=(e[0]!=LEFT), top=(e[0]==BOTTOM));
                rx2=esXLoc(e[0], e[1], e[2], e[3])+(e[0]==RIGHT ? e[3] : 0) + (e[0] == TOP || e[0] == BOTTOM ? e[2] : 0);
                ry2=esYLoc(e[0], e[1], e[2], e[3]) + (e[0] == TOP ? e[3] : 0) + (e[0] == RIGHT || e[0] == LEFT ? e[2] : 0);
                if (rx2 >= 0 && (e[0]!=RIGHT && rx2 < x || e[0]==RIGHT && rx2 <= x) &&
                    (e[0]!=BOTTOM && ry2 > 0 || e[0]==BOTTOM && ry2 >= 0) && (e[0]==TOP && ry2 <= y || e[0]!=TOP && ry2 < y))
                    roundedCorner(corner_radius, thickness, x=rx2, y=ry2, left=(e[0]==RIGHT), top=(e[0]!=TOP));
            }
        }
        lasercutoutSquare(thickness=thickness, x=x, y=y,
            cutouts = clean_list(concat(slit_cutouts, tab_cutouts, cutouts)),
            circles_remove=circles_remove, circles_add=circles_add,
            slits=slits
        );
    }

    if (generate==2)
    {
        echo(str("[LC] lasercutSquare(x = ",x,", \n    y = ",y,", \n   thickness = ",thickness,", \n   kerf = ",kerf));
        if (tabs)
            echo(str("[LC]  , tabs = ",tabs));
        if (circles_remove)
            echo(str("[LC]  , circles_remove = ",circles_remove));
        if (circles_add)
            echo(str("[LC]  , circles_add = ",circles_add));
        if (edge_slits)
            echo(str("[LC]  , edge_slits = ",edge_slits));
        if (corner_radius)
            echo(str("[LC]  , corner_radius = ",corner_radius));
        if (slits)
            echo(str("[LC]  , slits = ",slits));
        if (cutouts)
            echo(str("[LC]  , cutouts = ",cutouts));
        echo(str("[LC]  ) \n"));
    }
    if ($children) translate([0, y+thickness*2, 0])
        children();
};

module roundedCorner(circle_r, thickness, x=0, y=0, angle=0, round_d=-1, round_h=-1, top=false, left=false) {
    rd=round_d < 0 ? circle_r : round_d;
    rh=round_h < 0 ? circle_r : round_h;
    local_offset = sin(angle)*(rd/cos(angle))*(top ? 1 : -1);
    translate([x + (left ? -circle_r : rd), y + (top ? (circle_r - local_offset) :
        (-circle_r + local_offset)), 0])
    linear_extrude(thickness) {
        intersection() {
            circle(circle_r);
            translate([left ? 0 : -rd, top ? -circle_r :
                (circle_r-(rh+local_offset)), 0])
            square([rd, rh+local_offset]);
        };
    };
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

function dividerHandleChooser(divs) = clean_list([ for (d=divs) d[0] < divider_handle_limit ? d : []]);
function dividerHandleConv(divs, size, thickness, type) = divs ? [for (i=[0: max(0, len(divs)-1)]) let (d = divs[i])
    d[1] == 0 && d[2] == 0 ? [abs(ratioLocation(d[0], size, thickness)/size-0.5), i, type] : []] : [];
function dividerHandle(h_divs, width, v_divs, height, thickness) = quicksortSubVectors(dividerHandleChooser(concat(
    dividerHandleConv(h_divs, width, thickness, "h"), dividerHandleConv(v_divs, height, thickness, "v"))))[0];

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
    let(tw2=tx < 0 ? tw : min(tw, tx+tw-start_clip))
    end_clip==0 ? tw2 : min(tw2, end_clip-tx);
function slotDepth(thickness=0, kerf=0) = thickness - kerf;

function tabCount(w) = min(max(floor((w/tab_size+1)/2), min_tabs), max_tabs);
function totalTabs(num_t=0, x=0, tab_width=0) =
    (num_t > 1 ? num_t : (x/tab_width+1)/2+1) - 2;
function tabWidth(total_w = 0, num_t = 0) = total_w/(num_t*2 - 1);

function flatten(l) = [ for (a = l) for (b = a) b ] ;
function has_item(list, item) = [for (i=list) if (i==item) true][0] || false;
function clean_list(l) = [ for (a=l) if(a) a ];

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
