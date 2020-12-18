// ZipSpool - Filament spool holder for printing from a sealed bag
//
// Copyright (C) 2019-2020  Kevin O'Connor <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

holder_height = 180;
holder_width = 125;
holder_arm_depth = 10;
holder_arm_height = 5;
holder_spindle_backing = 55;
holder_spindle_offset = 3;
holder_key_angle_offset = 30;
holder_bevel_diameter = 40;
holder_bevel_depth = 5;
holder_clip_height = 5;
holder_clip_width = 2;
holder_clip_offset = 10;
spindle_diameter = 28;
spindle_thickness = 2.5;
spindle_key_diameter = 3;
spindle_key_offset = 5;
spindle_key_angles = [90, 210, 330];
spindle_spool_length = 71;
ptfe_tube_diameter = 4;
clip_beam_width = 10;
clip_beam_height = 5;
slack = 1;
CUT = 0.01;
$fs = 0.5;

//
// Holder
//

module key(angle, diameter) {
    rotate(angle, [0, 0, 1])
        translate([diameter/2, 0, 0])
            sphere(d=spindle_key_diameter);
}

module holder() {
    // Start with triangle "arms" forming the base
    backing_center_y = (holder_height - holder_spindle_backing/2
                        - holder_arm_height/2);
    module arms() {
        module base_cylinder(pos) {
            translate(pos)
                cylinder(h=holder_arm_depth, d=holder_arm_height);
        }
        bot1 = [-holder_width/2, 0];
        bot2 = [holder_width/2, 0];
        top1 = [-spindle_diameter/2, backing_center_y];
        top2 = [spindle_diameter/2, backing_center_y];
        union() {
            hull() {
                base_cylinder(bot1);
                base_cylinder(bot2);
            }
            hull() {
                base_cylinder(bot1);
                base_cylinder(top1);
            }
            hull() {
                base_cylinder(bot2);
                base_cylinder(top2);
            }
        }
    }
    // Add in the spindle backing
    module arms_with_backing() {
        arms();
        translate([0, backing_center_y]) {
            cylinder(h=holder_arm_depth, d=holder_spindle_backing);
            translate([0, 0, holder_arm_depth-CUT])
                cylinder(h=holder_bevel_depth+CUT,
                    d1=holder_bevel_diameter, d2=spindle_diameter);
        }
    }
    // Subtract out space for the spindle
    cut_diameter = spindle_diameter + slack;
    difference() {
        arms_with_backing();
        translate([0, backing_center_y, holder_spindle_offset - slack])
            cylinder(h=holder_arm_depth+holder_bevel_depth, d=cut_diameter);
    }
    // Add in key protrusions on the spindle holder
    translate([0, backing_center_y, holder_spindle_offset+spindle_key_offset]) {
        for (angle=spindle_key_angles)
            key(angle + holder_key_angle_offset, cut_diameter);
    }
    // Add clip holders to the base
    angle = atan(backing_center_y / ((holder_width-spindle_diameter)/2));
    module clip(dir, offset) {
        translate([-dir * holder_width/2, 0, 0])
            rotate(dir * angle, [0, 0, 1])
               translate([dir * offset, holder_clip_width,
                          holder_arm_depth/2])
                  cube(size=[holder_clip_height,
                             2*holder_clip_width,
                             holder_arm_depth], center=true);
    }
    for (clip_num=[1, 2, 3, 4]) {
        clip(1, clip_num * holder_clip_offset);
        clip(-1, clip_num * holder_clip_offset);
    }
}

//
// Spindle
//

module spindle() {
    module key_channels(chan_height) {
        // Horizontal channels
        translate([0, 0, chan_height]) {
            angle_swing = holder_key_angle_offset * 2.5;
            for (angle=spindle_key_angles) {
                rotate(a=angle - angle_swing/2, v=[0, 0, 1])
                    rotate_extrude(angle=angle_swing)
                        translate([spindle_diameter/2, 0, 0])
                            circle(d=spindle_key_diameter);
            }
        }
    }
    enclosed_len = holder_bevel_depth+holder_arm_depth - holder_spindle_offset;
    total_height=spindle_spool_length + 2*enclosed_len;
    cyl_sides = 100;
    module core_spindle(dia) {
        cylinder(h=total_height, d=dia, $fn=cyl_sides);
        bearing_bump = 2;
        step = 15;
        total = 2*360;
        step_height = spindle_spool_length / total;
        for (i=[0:step:total - step]) {
            bb = bearing_bump * (1 - cos(i));
            bb_next = bearing_bump * (1 - cos(i+step));
            translate([0, 0, enclosed_len + i * step_height])
                cylinder(h=step_height*step+CUT, d1=dia+bb, d2=dia+bb_next,
                         $fn=cyl_sides);
        }
    }
    difference() {
        // Main spindle
        core_spindle(spindle_diameter);
        core_spindle(spindle_diameter - 2*spindle_thickness);
        translate([0, 0, -CUT])
            cylinder(h=total_height + 2*CUT,
                     d=spindle_diameter - 2*spindle_thickness);
        // Horizontal channels
        spindle_key2_offset = total_height - spindle_key_offset;
        key_channels(spindle_key_offset);
        key_channels(spindle_key2_offset);
        // Vertical channels
        for (angle=spindle_key_angles)
            rotate(angle, [0, 0, 1]) {
                translate([spindle_diameter/2, 0, -CUT])
                    cylinder(h=spindle_key_offset+CUT, d=spindle_key_diameter);
                translate([spindle_diameter/2, 0, spindle_key2_offset])
                    cylinder(h=spindle_key_offset+CUT, d=spindle_key_diameter);
            }
    }
}

//
// Holder clip and filament carriage platform
//

module base_clip() {
    clip_z = 10;
    clip_width = holder_arm_depth + slack/2;
    side_extra = 3;
    clip_total_width = clip_width+side_extra+5;
    base_width = spindle_spool_length+2*(holder_bevel_depth + holder_arm_depth);
    total_width = base_width + 2*side_extra;
    holder_angle = 30;
    angle_z_offset = 1.5;
    angle_y_offset = 1.5;
    module rounded_cube(x, y, z) {
        edge_radius = 2;
        hull() {
            translate([edge_radius, edge_radius, 0])
                cylinder(h=z, r=edge_radius);
            translate([edge_radius, y-edge_radius, 0])
                cylinder(h=z, r=edge_radius);
            translate([x-edge_radius, edge_radius, 0])
                cylinder(h=z, r=edge_radius);
            translate([x-edge_radius, y-edge_radius, 0])
                cylinder(h=z, r=edge_radius);
        }
    }
    module inverse_arm() {
        z = (clip_z-holder_clip_height-slack)/2 - angle_z_offset;
        inset = 1;
        module arm() {
            translate([side_extra, holder_clip_width+inset, -19])
                cube([clip_width, 19, z+2*19]);
            translate([side_extra, inset, z])
                cube([clip_width, holder_clip_width+CUT,
                      holder_clip_height+slack]);
        }
        difference() {
            arm();
            notch_dia = 2;
            notch_y = (holder_arm_height + slack + notch_dia/2
                       + holder_clip_width+inset);
            translate([side_extra, notch_y, z + notch_dia/2 + .5])
                sphere(d=notch_dia);
            second_z = z + holder_clip_height+slack - notch_dia/2 - .5;
            translate([side_extra, notch_y, second_z])
                sphere(d=notch_dia);
        }
    }
    module grips_and_beam() {
        rounded_cube(total_width, clip_beam_width, clip_beam_height);
        clip_y = clip_beam_width + slack;
        module grip()
            rounded_cube(clip_total_width, clip_y, clip_z - angle_z_offset);
        translate([0, angle_y_offset, 0])
            rotate([holder_angle, 0, 0]) {
                grip();
                translate([total_width, 0, 0])
                    mirror([1, 0, 0])
                        grip();
            }
    }
    module main_platform() {
        difference() {
            grips_and_beam();
            translate([0, angle_y_offset, 0])
                rotate([holder_angle, 0, 0]) {
                    inverse_arm();
                    translate([total_width, 0, 0])
                        mirror([1, 0, 0])
                            inverse_arm();
                }
        }
    }
    intersection() {
        main_platform();
        translate([0, -19, 0])
            rounded_cube(total_width, clip_beam_width+19, 19);
    }
}

//
// Filament tube carriage
//

module carriage() {
    side_thick = 3;
    guide_rad = 1;
    barrier_thick = 1;
    insert_thick = 11;
    carriage_space_x = clip_beam_width + slack + 2*guide_rad;
    total_x = carriage_space_x + 2*side_thick + barrier_thick + insert_thick;
    outer_dia = ptfe_tube_diameter + 5;
    carriage_space_y = clip_beam_height + slack + guide_rad;
    tube_center_y = side_thick + carriage_space_y + ptfe_tube_diameter/2;
    tube_center_z = outer_dia / 2;
    total_y = tube_center_y + outer_dia/2;

    module base() {
        hull() {
            cube([carriage_space_x + 2*side_thick, tube_center_y, outer_dia]);
            translate([0, tube_center_y, tube_center_z])
                rotate([0, 90, 0])
                    cylinder(h=total_x, d=outer_dia);
        }
    }
    module filament_tube() {
        filament_only_dia = ptfe_tube_diameter - .75;
        tube_guide_dia = ptfe_tube_diameter + slack / 2;
        // Main channel
        cylinder(h=total_x + 2*CUT, d=filament_only_dia);
        l1 = carriage_space_x + 2*side_thick + 2 + CUT;
        cylinder(h=l1, d=tube_guide_dia);
        translate([0, 0, l1 + barrier_thick])
            cylinder(h=insert_thick+CUT, d=tube_guide_dia);
    }

    difference() {
        base();
        // cutout for carriage
        translate([side_thick, side_thick, -CUT])
            cube([carriage_space_x, total_y, outer_dia+2*CUT]);
        // cutout for tube
        translate([-CUT, tube_center_y, tube_center_z])
            rotate([0, 90, 0])
                filament_tube();
    }
    // Add in guide protrusions
    p_x1 = side_thick;
    p_x2 = side_thick + carriage_space_x;
    p_x3 = side_thick + 3;
    p_x4 = side_thick + carriage_space_x - 3;
    p_y1 = side_thick + clip_beam_height/2 + guide_rad;
    p_y2 = side_thick;
    p_z1 = 2;
    p_z2 = outer_dia - 2;
    protrusions = [
        [p_x1, p_y1, p_z1], [p_x2, p_y1, p_z1],
        [p_x1, p_y1, p_z2], [p_x2, p_y1, p_z2],
        [p_x3, p_y2, p_z1], [p_x4, p_y2, p_z1],
        [p_x3, p_y2, p_z2], [p_x4, p_y2, p_z2],
    ];
    for (pos=protrusions)
        translate(pos)
            sphere(r=guide_rad);
}

//
// Object selection
//

holder();
//spindle();
//base_clip();
//carriage();
