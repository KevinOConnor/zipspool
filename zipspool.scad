// ZipSpool - Filament spool holder for printing from a sealed bag
//
// Copyright (C) 2019  Kevin O'Connor <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

holder_height = 155;
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
clip_tube_diameter = 4;
clip_height = 10;
clip_depth = 10;
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
    module clip(dir) {
        translate([-dir * holder_width/2, 0, 0])
            rotate(dir * angle, [0, 0, 1])
               translate([dir * holder_clip_offset, holder_clip_width,
                          holder_arm_depth/2])
                  cube(size=[holder_clip_height,
                             2*holder_clip_width,
                             holder_arm_depth], center=true);
    }
    clip(1);
    clip(-1);
}

//
// Spindle
//

module spindle() {
    module pie(angle1, angle2, radius, height) {
        translate([0, 0, -height/2])
            intersection() {
                rotate(a=angle1, v=[0, 0, 1])
                       cube([radius, radius, height]);
                rotate(a=angle1+angle2-90, v=[0, 0, 1])
                       cube([radius, radius, height]);
            }
    }
    module key_channels(edge_height, chan_height) {
        // horizontal channels
        translate([0, 0, chan_height]) {
            intersection() {
                rotate_extrude() {
                    translate([spindle_diameter/2, 0, 0])
                        circle(d=spindle_key_diameter);
                }
                len = (spindle_diameter + spindle_key_diameter)/2;
                angle_swing = holder_key_angle_offset * 1.25;
                union() {
                    for (angle=spindle_key_angles) {
                        pie(angle-angle_swing, angle_swing*2,
                            len, spindle_key_diameter);
                    }
                }
            }
        }
        // vertical channels
        for (angle=spindle_key_angles) {
            hull() {
                translate([0, 0, edge_height])
                    key(angle, spindle_diameter);
                translate([0, 0, chan_height])
                    key(angle, spindle_diameter);
            }
        }
    }
    enclosed_len = holder_bevel_depth+holder_arm_depth - holder_spindle_offset;
    echo(enclosed_len);
    total_height=spindle_spool_length + 2*enclosed_len;
    echo(total_height);
    difference() {
        cylinder(h=total_height, d=spindle_diameter, $fn=100);
        translate([0, 0, -CUT])
            cylinder(h=total_height + 2*CUT,
                     d=spindle_diameter - 2*spindle_thickness);
        key_channels(0, spindle_key_offset);
        key_channels(total_height, total_height-spindle_key_offset);
    }
}

//
// Clip on filament guide
//

module filament_clip() {
    module round_off(radius, degrees, shift) {
        translate(shift) {
            rotate([0, degrees, 0]) {
                translate([-CUT, -CUT, -CUT]) {
                    difference() {
                        cube([radius+CUT, clip_height + 2*CUT, radius+CUT]);
                        translate([radius, 0, radius])
                            rotate([-90, 0, 0])
                                cylinder(h=clip_height+2*CUT, r=radius, $fn=10);
                    }
                }
            }
        }
    }

    clip_width = holder_arm_depth + slack/2;
    module inverse_arm(xpos, zpos, transform) {
        module arm() {
            cube([clip_width, clip_depth + 2*CUT, holder_arm_height + slack/2]);
        }
        module clip() {
            translate([0, (clip_depth-holder_clip_height-slack)/2,
                       CUT-holder_clip_width])
                cube([clip_width, holder_clip_height+slack,
                      holder_clip_width+CUT]);
        }
        translate([xpos, -CUT, zpos]) {
            hull() {
                arm();
                translate(transform)
                    arm();
            }
            clip();
        }
    }
    clip_z = 10;
    clip_inner_height = 5;
    outer_diameter = clip_tube_diameter+5;
    holder_angle = 30;
    holder_offset = 5;
    guide_lift = -1;
    module filament_holder() {
        module base(y) {
            adj_y = y + clip_inner_height/2;
            translate([-outer_diameter, outer_diameter/2 - adj_y, 0])
                cube([2*outer_diameter, y, clip_z]);
        }
        module outer_cylinder() {
            hull() {
                rotate(-holder_angle, v=[1, 0, 0])
                    base(1);
                translate([0, guide_lift, 0])
                    cylinder(h=clip_z, d=outer_diameter);
            }
        }
        translate([0, holder_offset, 0]) {
            intersection() {
                base(99);
                rotate(holder_angle, v=[1, 0, 0])
                    outer_cylinder();
            }
        }
    }
    module filament_tube() {
        // Tip
        hull() {
            translate([0, 0, clip_z - .5 - CUT])
                cylinder(h=.5 + 2*CUT, d=clip_tube_diameter-1);
            translate([0, -1, clip_z - .5 - CUT])
                cylinder(h=.5 + 2*CUT, d=clip_tube_diameter-1);
        }
        // Main channel
        translate([0, 0, -99])
            cylinder(h=clip_z - .5 + 99, d=clip_tube_diameter + slack);
        // Extra diameter at tip
        translate([0, 0, clip_z - .5 - 2])
            cylinder(h=2, d=clip_tube_diameter + 2*slack);
        // Extra diameter at middle
        translate([0, 0, clip_z - .5 - 5])
            cylinder(h=2, d=clip_tube_diameter + 2*slack);
        // Extra diameter at entrance
        translate([0, 0, clip_z - .5 - 6 - 99])
            cylinder(h=99, d=clip_tube_diameter + 2*slack);
    }
    module filament_cutout() {
        translate([0, holder_offset, 0])
            rotate(holder_angle, v=[1, 0, 0])
                translate([0, guide_lift, 0])
                    filament_tube();
    }
    // Basic clip
    base_width = spindle_spool_length+2*(holder_bevel_depth + holder_arm_depth);
    side_extra = 3;
    total_width = base_width + 2*side_extra;
    clip_total_width = clip_width+side_extra+5;
    difference() {
        cube([total_width, clip_height, clip_z]);
        round_off(2, 0, [0, 0, 0]);
        round_off(2, 90, [0, 0, clip_z]);
        round_off(2, 270, [total_width, 0, 0]);
        round_off(2, 180, [total_width, 0, clip_z]);
        inverse_arm(side_extra, 3, [0, 0, 10]);
        inverse_arm(base_width+side_extra-clip_width, 3, [0, 0, 10]);
        translate([clip_total_width, clip_height-clip_inner_height/2, -CUT])
            cube([total_width - 2*clip_total_width,
                  (clip_height-clip_inner_height)/2+CUT, clip_z+2*CUT]);
        translate([clip_total_width, -CUT, -CUT])
            cube([total_width - 2*clip_total_width,
                  (clip_height-clip_inner_height)/2+CUT, clip_z+2*CUT]);
        translate([total_width/2, 0, 0])
            filament_cutout();
    }
    // Add protrusions to lock into base
    translate([side_extra, clip_height/2, 3+holder_arm_height+1])
        sphere(d=2);
    translate([total_width-side_extra, clip_height/2, 3+holder_arm_height+1])
        sphere(d=2);
    // Add filament holder
    translate([total_width/2, 0, 0])
        difference() {
            filament_holder();
            filament_cutout();
        }
}

//
// Object selection
//

holder();
//spindle();
//filament_clip();
