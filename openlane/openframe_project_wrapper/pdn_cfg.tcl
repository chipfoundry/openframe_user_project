# SPDX-FileCopyrightText: 2025 UmbraLogic Technologies LLC
# SPDX-License-Identifier: Apache-2.0
#
# Openframe wrapper PDN.
#
# Every net in VDD_NETS/GND_NETS gets its own core ring and its own straps in
# the met4/met5 mesh. After pdngen, each padframe power pin of those nets
# (copied from FP_DEF_TEMPLATE by Odb.ApplyDEFTemplate, which the wrapper
# config moves in front of OpenROAD.GeneratePDN) is tied to the ring of the
# same net with a strap on the pin layer and a via stack. Padframe supplies
# that are not in VDD_NETS/GND_NETS stay unconnected. The same hook also grows
# the padframe signal pins into the die so the detailed router can reach them.

source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

set secondary []
foreach vdd $::env(VDD_NETS) gnd $::env(GND_NETS) {
    if { $vdd != $::env(VDD_NET)} {
        lappend secondary $vdd

        set db_net [[ord::get_db_block] findNet $vdd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $vdd]
            $net setSpecial
            $net setSigType "POWER"
        }
    }

    if { $gnd != $::env(GND_NET)} {
        lappend secondary $gnd

        set db_net [[ord::get_db_block] findNet $gnd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $gnd]
            $net setSpecial
            $net setSigType "GROUND"
        }
    }
}

set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET) \
    -secondary_power $secondary

define_pdn_grid \
    -name stdcell_grid \
    -starts_with POWER \
    -voltage_domain CORE

add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(PDN_VERTICAL_LAYER) \
    -width $::env(PDN_VWIDTH) \
    -pitch $::env(PDN_VPITCH) \
    -offset $::env(PDN_VOFFSET) \
    -spacing $::env(PDN_VSPACING) \
    -starts_with POWER -extend_to_core_ring

add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(PDN_HORIZONTAL_LAYER) \
    -width $::env(PDN_HWIDTH) \
    -pitch $::env(PDN_HPITCH) \
    -offset $::env(PDN_HOFFSET) \
    -spacing $::env(PDN_HSPACING) \
    -starts_with POWER -extend_to_core_ring

add_pdn_connect \
    -grid stdcell_grid \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

add_pdn_ring \
    -grid stdcell_grid \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)" \
    -widths "$::env(PDN_CORE_RING_VWIDTH) $::env(PDN_CORE_RING_HWIDTH)" \
    -spacings "$::env(PDN_CORE_RING_VSPACING) $::env(PDN_CORE_RING_HSPACING)" \
    -core_offset "$::env(PDN_CORE_RING_VOFFSET) $::env(PDN_CORE_RING_HOFFSET)"

define_pdn_grid \
    -macro \
    -default \
    -name macro \
    -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"

add_pdn_connect \
    -grid macro \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

namespace eval openframe_pdn {
    variable via_count 0

    proc fail {msg} {
        utl::error ODB 9500 "Openframe PDN: $msg"
    }

    proc overlaps {a b} {
        lassign $a ax0 ay0 ax1 ay1
        lassign $b bx0 by0 bx1 by1
        return [expr {$ax0 < $bx1 && $bx0 < $ax1 && $ay0 < $by1 && $by0 < $ay1}]
    }

    proc box_rect {box} {
        return [list [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
    }

    # Cut size, cut spacing and enclosures of the default via between two
    # adjacent routing layers, taken from the technology LEF.
    proc via_geometry {bottom top} {
        set tech [ord::get_db_tech]
        foreach tv [$tech getVias] {
            if { ![$tv isDefault] } { continue }
            if { [[$tv getBottomLayer] getName] != [$bottom getName] } { continue }
            if { [[$tv getTopLayer] getName] != [$top getName] } { continue }
            set rects [dict create]
            foreach box [$tv getBoxes] {
                dict set rects [[$box getTechLayer] getName] [box_rect $box]
            }
            set cut_layer [$bottom getUpperLayer]
            lassign [dict get $rects [$cut_layer getName]] cx0 cy0 cx1 cy1
            lassign [dict get $rects [$bottom getName]] bx0 by0 bx1 by1
            lassign [dict get $rects [$top getName]] tx0 ty0 tx1 ty1
            set rule_name ""
            foreach rule [$tech getViaGenerateRules] {
                if { [$rule getName] == [$tv getName] } { set rule_name [$rule getName] }
            }
            if { $rule_name == "" } {
                fail "no VIARULE GENERATE named [$tv getName] for [$bottom getName]-[$top getName]"
            }
            return [dict create \
                cut_layer $cut_layer \
                rule [$tech findViaGenerateRule $rule_name] \
                cut_x [expr {$cx1 - $cx0}] cut_y [expr {$cy1 - $cy0}] \
                spacing [$cut_layer getSpacing] \
                bot_x [expr {$cx0 - $bx0}] bot_y [expr {$cy0 - $by0}] \
                top_x [expr {$cx0 - $tx0}] top_y [expr {$cy0 - $ty0}]]
        }
        fail "no default via between [$bottom getName] and [$top getName]"
    }

    # Places one via array between two adjacent routing layers that fills
    # `rect` with its metal enclosures kept inside it.
    proc add_via_array {swire bottom top rect} {
        variable via_count
        set block [ord::get_db_block]
        set grid [expr {2 * [[ord::get_db_tech] getManufacturingGrid]}]
        set g [via_geometry $bottom $top]
        lassign $rect x0 y0 x1 y1
        set enc_x [expr {max([dict get $g bot_x], [dict get $g top_x])}]
        set enc_y [expr {max([dict get $g bot_y], [dict get $g top_y])}]
        set cut_x [dict get $g cut_x]
        set cut_y [dict get $g cut_y]
        set spacing [dict get $g spacing]
        set cols [expr {int(floor(($x1 - $x0 - 2 * $enc_x - $cut_x) / double($cut_x + $spacing))) + 1}]
        set rows [expr {int(floor(($y1 - $y0 - 2 * $enc_y - $cut_y) / double($cut_y + $spacing))) + 1}]
        if { $cols < 1 || $rows < 1 } {
            fail "region $rect is too small for a [$bottom getName]-[$top getName] via"
        }

        set params [odb::dbViaParams]
        $params setBottomLayer $bottom
        $params setCutLayer [dict get $g cut_layer]
        $params setTopLayer $top
        $params setXCutSize $cut_x
        $params setYCutSize $cut_y
        $params setXCutSpacing $spacing
        $params setYCutSpacing $spacing
        $params setXBottomEnclosure [dict get $g bot_x]
        $params setYBottomEnclosure [dict get $g bot_y]
        $params setXTopEnclosure [dict get $g top_x]
        $params setYTopEnclosure [dict get $g top_y]
        $params setNumCutCols $cols
        $params setNumCutRows $rows

        set via [odb::dbVia_create $block "openframe_pad_via_[incr via_count]"]
        $via setViaGenerateRule [dict get $g rule]
        $via setViaParams $params

        set cx [expr {(($x0 + $x1) / 2 / $grid) * $grid}]
        set cy [expr {(($y0 + $y1) / 2 / $grid) * $grid}]
        odb::dbSBox_create $swire $via $cx $cy STRIPE
    }

    proc ring_boxes {net layer} {
        set boxes {}
        foreach swire [$net getSWires] {
            foreach box [$swire getWires] {
                if { [$box isVia] } { continue }
                if { [$box getWireShapeType] != "RING" } { continue }
                if { [[$box getTechLayer] getName] != [$layer getName] } { continue }
                lappend boxes [box_rect $box]
            }
        }
        return $boxes
    }

    # Every special-net shape on `layer` that belongs to a net other than
    # `net`, used to prove that a new shape does not create a short.
    proc foreign_shapes {net layer} {
        set shapes {}
        foreach other [[ord::get_db_block] getNets] {
            if { [$other getName] == [$net getName] } { continue }
            foreach swire [$other getSWires] {
                foreach box [$swire getWires] {
                    if { [$box isVia] } { continue }
                    if { [[$box getTechLayer] getName] != [$layer getName] } { continue }
                    lappend shapes [list [$other getName] [box_rect $box]]
                }
            }
            foreach bterm [$other getBTerms] {
                foreach bpin [$bterm getBPins] {
                    foreach box [$bpin getBoxes] {
                        if { [[$box getTechLayer] getName] != [$layer getName] } { continue }
                        lappend shapes [list [$other getName] [box_rect $box]]
                    }
                }
            }
        }
        return $shapes
    }

    proc assert_no_short {net layer rect what} {
        foreach shape [foreign_shapes $net $layer] {
            lassign $shape other other_rect
            if { [overlaps $rect $other_rect] } {
                fail "$what for [$net getName] on [$layer getName] ($rect) overlaps net $other ($other_rect)"
            }
        }
    }

    proc connect_pin {net box} {
        set block [ord::get_db_block]
        set die [$block getDieArea]
        set pin_layer [$box getTechLayer]
        set vlayer [[ord::get_db_tech] findLayer $::env(PDN_VERTICAL_LAYER)]
        set hlayer [[ord::get_db_tech] findLayer $::env(PDN_HORIZONTAL_LAYER)]
        lassign [box_rect $box] px0 py0 px1 py1

        if { $px1 >= [$die xMax] } {
            set side right
        } elseif { $px0 <= [$die xMin] } {
            set side left
        } elseif { $py1 >= [$die yMax] } {
            set side top
        } elseif { $py0 <= [$die yMin] } {
            set side bottom
        } else {
            fail "pin shape [box_rect $box] of [$net getName] is not on the die boundary"
        }

        if { $side == "left" || $side == "right" } {
            set ring_layer $vlayer
        } else {
            set ring_layer $hlayer
        }

        # The ring leg on this side of the die that spans the pin.
        set leg ""
        foreach rect [ring_boxes $net $ring_layer] {
            lassign $rect rx0 ry0 rx1 ry1
            if { $side == "left" || $side == "right" } {
                if { $ry0 > $py0 || $ry1 < $py1 } { continue }
                if { $rx1 - $rx0 >= $ry1 - $ry0 } { continue }
            } else {
                if { $rx0 > $px0 || $rx1 < $px1 } { continue }
                if { $ry1 - $ry0 >= $rx1 - $rx0 } { continue }
            }
            if { $leg == "" } {
                set leg $rect
                continue
            }
            switch $side {
                right  { if { $rx1 > [lindex $leg 2] } { set leg $rect } }
                left   { if { $rx0 < [lindex $leg 0] } { set leg $rect } }
                top    { if { $ry1 > [lindex $leg 3] } { set leg $rect } }
                bottom { if { $ry0 < [lindex $leg 1] } { set leg $rect } }
            }
        }
        if { $leg == "" } {
            fail "no [$ring_layer getName] core ring leg of [$net getName] spans the pin at [box_rect $box] ($side edge)"
        }
        lassign $leg rx0 ry0 rx1 ry1

        switch $side {
            right  { set strap [list $rx0 $py0 [$die xMax] $py1] ; set landing [list $rx0 $py0 $rx1 $py1] }
            left   { set strap [list [$die xMin] $py0 $rx1 $py1] ; set landing [list $rx0 $py0 $rx1 $py1] }
            top    { set strap [list $px0 $ry0 $px1 [$die yMax]] ; set landing [list $px0 $ry0 $px1 $ry1] }
            bottom { set strap [list $px0 [$die yMin] $px1 $ry1] ; set landing [list $px0 $ry0 $px1 $ry1] }
        }

        assert_no_short $net $pin_layer $strap "pad strap"

        set swire [odb::dbSWire_create $net ROUTED]
        lassign $strap sx0 sy0 sx1 sy1
        odb::dbSBox_create $swire $pin_layer $sx0 $sy0 $sx1 $sy1 STRIPE

        # Climb from the pin layer to the ring layer one routing layer at a
        # time; intermediate layers get a landing pad the size of the overlap.
        set layer $pin_layer
        while { [$layer getName] != [$ring_layer getName] } {
            set cut [$layer getUpperLayer]
            if { $cut == "NULL" } {
                fail "ring layer [$ring_layer getName] is not above pin layer [$pin_layer getName]"
            }
            set upper [$cut getUpperLayer]
            if { [$upper getName] != [$ring_layer getName] } {
                assert_no_short $net $upper $landing "via landing"
                lassign $landing lx0 ly0 lx1 ly1
                odb::dbSBox_create $swire $upper $lx0 $ly0 $lx1 $ly1 STRIPE
            }
            add_via_array $swire $layer $upper $landing
            set layer $upper
        }
        return $side
    }

    proc pdn_nets {} {
        set block [ord::get_db_block]
        set nets {}
        foreach net_name [concat $::env(VDD_NETS) $::env(GND_NETS)] {
            set net [$block findNet $net_name]
            if { $net == "NULL" } {
                fail "net $net_name from VDD_NETS/GND_NETS does not exist"
            }
            lappend nets $net
        }
        return $nets
    }

    # pdngen deletes every non-FIXED pin of the nets it builds. The padframe
    # pins are fixed by definition, but the DEF template marks them PLACED.
    proc fix_pad_pins {} {
        foreach net [pdn_nets] {
            set count 0
            foreach bterm [$net getBTerms] {
                foreach bpin [$bterm getBPins] {
                    $bpin setPlacementStatus FIRM
                    incr count
                }
            }
            if { $count == 0 } {
                fail "net [$net getName] has no padframe pins. VDD_NETS/GND_NETS must name padframe supplies (pass power.json before config.json), and Odb.ApplyDEFTemplate with FP_TEMPLATE_COPY_POWER_PINS must run before OpenROAD.GeneratePDN."
            }
        }
    }

    # Only 0.3um of each padframe signal pin lies inside the die, and most of
    # them are off the routing grid, so OpenROAD's detailed router finds no
    # access point (DRT-1231). Growing every signal pin 2um into the die gives
    # the router room; cf precheck's XOR only compares geometry outside the die.
    proc extend_signal_pins {} {
        set block [ord::get_db_block]
        set die [$block getDieArea]
        set ext [expr {2 * [[ord::get_db_tech] getDbUnitsPerMicron]}]
        foreach bterm [$block getBTerms] {
            if { [$bterm getSigType] == "POWER" || [$bterm getSigType] == "GROUND" } { continue }
            foreach bpin [$bterm getBPins] {
                foreach box [$bpin getBoxes] {
                    lassign [box_rect $box] x0 y0 x1 y1
                    if { $x0 < [$die xMin] } {
                        set x1 [expr {max($x1, [$die xMin] + $ext)}]
                    } elseif { $x1 > [$die xMax] } {
                        set x0 [expr {min($x0, [$die xMax] - $ext)}]
                    } elseif { $y0 < [$die yMin] } {
                        set y1 [expr {max($y1, [$die yMin] + $ext)}]
                    } elseif { $y1 > [$die yMax] } {
                        set y0 [expr {min($y0, [$die yMax] - $ext)}]
                    } else {
                        fail "signal pin [$bterm getName] at [box_rect $box] is not on the die boundary"
                    }
                    set grown [list $x0 $y0 $x1 $y1]
                    foreach shape [foreign_shapes [$bterm getNet] [$box getTechLayer]] {
                        lassign $shape other other_rect
                        if { [overlaps $grown $other_rect] } {
                            fail "extending pin [$bterm getName] to $grown overlaps net $other ($other_rect)"
                        }
                    }
                    odb::dbBox_create $bpin [$box getTechLayer] $x0 $y0 $x1 $y1
                }
            }
        }
    }

    proc connect_pad_power {} {
        foreach net [pdn_nets] {
            foreach bterm [$net getBTerms] {
                foreach bpin [$bterm getBPins] {
                    foreach box [$bpin getBoxes] {
                        set side [connect_pin $net $box]
                        puts "\[INFO\] Openframe pad power: tied [$net getName] pin at [box_rect $box] ($side edge) to its core ring."
                    }
                }
            }
        }
    }
}

# pdn.tcl calls pdngen right after sourcing this file and then runs
# check_power_grid on every net, so the pad connections must exist by the
# time pdngen returns.
rename pdngen openframe_pdn::pdngen_builtin
proc pdngen {args} {
    openframe_pdn::fix_pad_pins
    openframe_pdn::extend_signal_pins
    openframe_pdn::pdngen_builtin {*}$args
    openframe_pdn::connect_pad_power
}
