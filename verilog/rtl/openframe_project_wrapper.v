// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * openframe_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user openframe project.
 *
 * Written by Tim Edwards
 * March 27, 2023
 * Efabless Corporation
 *
 *-------------------------------------------------------------
 */

module openframe_project_wrapper (
`ifdef USE_POWER_PINS
    inout vdda,		// User area 0 3.3V supply
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa,		// User area 0 analog ground
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd,		// Common 1.8V supply
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd,		// Common digital ground
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
    inout vddio,	// Common 3.3V ESD supply
    inout vssio,	// Common ESD ground
`endif

    /* Signals exported from the frame area to the user project */
    /* The user may elect to use any of these inputs.		*/

    input	 porb_h,	// power-on reset, sense inverted, 3.3V domain
    input	 porb_l,	// power-on reset, sense inverted, 1.8V domain
    input	 por_l,		// power-on reset, noninverted, 1.8V domain
    input	 resetb_h,	// master reset, sense inverted, 3.3V domain
    input	 resetb_l,	// master reset, sense inverted, 1.8V domain
    input [31:0] mask_rev,	// 32-bit user ID, 1.8V domain

    /* GPIOs.  There are 44 GPIOs (19 left, 19 right, 6 bottom). */
    /* These must be configured appropriately by the user project. */

    /* Basic bidirectional I/O.  Input gpio_in_h is in the 3.3V domain;  all
     * others are in the 1.8v domain.  OEB is output enable, sense inverted.
     */
    input  [`OPENFRAME_IO_PADS-1:0] gpio_in,
    input  [`OPENFRAME_IO_PADS-1:0] gpio_in_h,
    output [`OPENFRAME_IO_PADS-1:0] gpio_out,
    output [`OPENFRAME_IO_PADS-1:0] gpio_oeb,
    output [`OPENFRAME_IO_PADS-1:0] gpio_inp_dis,	// a.k.a. ieb

    /* Pad configuration.  These signals are usually static values.
     * See the documentation for the sky130_fd_io__gpiov2 cell signals
     * and their use.
     */
    output [`OPENFRAME_IO_PADS-1:0] gpio_ib_mode_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_vtrip_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_slow_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_holdover,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_en,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_pol,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm2,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm1,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm0,

    /* These signals correct directly to the pad.  Pads using analog I/O
     * connections should keep the digital input and output buffers turned
     * off.  Both signals connect to the same pad.  The "noesd" signal
     * is a direct connection to the pad;  the other signal connects through
     * a series resistor which gives it minimal ESD protection.  Both signals
     * have basic over- and under-voltage protection at the pad.  These
     * signals may be expected to attenuate heavily above 50MHz.
     */
    inout  [`OPENFRAME_IO_PADS-1:0] analog_io,
    inout  [`OPENFRAME_IO_PADS-1:0] analog_noesd_io,

    /* These signals are constant one and zero in the 1.8V domain, one for
     * each GPIO pad, and can be looped back to the control signals on the
     * same GPIO pad to set a static configuration at power-up.
     */
    input  [`OPENFRAME_IO_PADS-1:0] gpio_loopback_one,
    input  [`OPENFRAME_IO_PADS-1:0] gpio_loopback_zero
);
        wire clk;
	wire rst;
	wire [10:0] out;

	user_proj_timer mprj (
`ifdef USE_POWER_PINS
		.vccd1(vccd1),
		.vssd1(vssd1),
`endif
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .io_out(out[10:0])

	    /* NOTE:  Openframe signals not used in picosoc:	*/
	    /* porb_h:    3.3V domain signal			*/
	    /* resetb_h:  3.3V domain signal			*/
	    /* gpio_in_h: 3.3V domain signals			*/
	    /* analog_io: analog signals			*/
	    /* analog_noesd_io: analog signals			*/
	);

	(* keep *) vccd1_connection vccd1_connection ();
	(* keep *) vssd1_connection vssd1_connection ();

	// CF_gpio_config modes
	// 0: analog
	// 1: input
	// 2: input pull down
	// 3: input pull up
	// 4: output
	// 5: bidirectional

        CF_gpio_config #(.MODE(3'd1)) gpio_clk_config ( // clk input at gpio 0
          .io_out(),
          .io_in(clk),
          .io_oeb(),
          .gpio_zero(gpio_loopback_zero[0]),
          .gpio_one(gpio_loopback_one[0]),
          .gpio_in(gpio_in[0]),
          .gpio_dm({gpio_dm2[0], gpio_dm1[0], gpio_dm0[0]}),
          .gpio_inp_dis(gpio_inp_dis[0]),
          .gpio_oeb_out(gpio_oeb[0]),
          .gpio_out_val(gpio_out[0]),
          .gpio_analog_en(gpio_analog_en[0]),
          .gpio_analog_sel(gpio_analog_sel[0]),
          .gpio_analog_pol(gpio_analog_pol[0]),
          .gpio_ib_mode_sel(gpio_ib_mode_sel[0]),
          .gpio_vtrip_sel(gpio_vtrip_sel[0]),
          .gpio_slow_sel(gpio_slow_sel[0]),
          .gpio_holdover(gpio_holdover[0])
        );
        
	CF_gpio_config #(.MODE(3'd3)) gpio_rst_config ( // rst pull up input at gpio 1
          .io_out(),
          .io_in(rst),
          .io_oeb(),
          .gpio_zero(gpio_loopback_zero[1]),
          .gpio_one(gpio_loopback_one[1]),
          .gpio_in(gpio_in[1]),
          .gpio_dm({gpio_dm2[1], gpio_dm1[1], gpio_dm0[1]}),
          .gpio_inp_dis(gpio_inp_dis[1]),
          .gpio_oeb_out(gpio_oeb[1]),
          .gpio_out_val(gpio_out[1]),
          .gpio_analog_en(gpio_analog_en[1]),
          .gpio_analog_sel(gpio_analog_sel[1]),
          .gpio_analog_pol(gpio_analog_pol[1]),
          .gpio_ib_mode_sel(gpio_ib_mode_sel[1]),
          .gpio_vtrip_sel(gpio_vtrip_sel[1]),
          .gpio_slow_sel(gpio_slow_sel[1]),
          .gpio_holdover(gpio_holdover[1])
        );

	genvar i;
        generate
          for (i = 0; i <= 10; i = i + 1) begin : gpio_out_config
            CF_gpio_config #(.MODE(3'd4)) u_cfg (
              .io_out(out[i]),
              .io_in(),
              .io_oeb(),
              .gpio_zero(gpio_loopback_zero[i + 2]),
              .gpio_one(gpio_loopback_one[i + 2]),
              .gpio_in(gpio_in[i + 2]),
              .gpio_dm({gpio_dm2[i + 2], gpio_dm1[i + 2], gpio_dm0[i + 2]}),
              .gpio_inp_dis(gpio_inp_dis[i + 2]),
              .gpio_oeb_out(gpio_oeb[i + 2]),
              .gpio_out_val(gpio_out[i + 2]),
              .gpio_analog_en(gpio_analog_en[i + 2]),
              .gpio_analog_sel(gpio_analog_sel[i + 2]),
              .gpio_analog_pol(gpio_analog_pol[i + 2]),
              .gpio_ib_mode_sel(gpio_ib_mode_sel[i + 2]),
              .gpio_vtrip_sel(gpio_vtrip_sel[i + 2]),
              .gpio_slow_sel(gpio_slow_sel[i + 2]),
              .gpio_holdover(gpio_holdover[i + 2])
            );
          end
        endgenerate

        genvar j;
        generate
          for (j = 13; j < `OPENFRAME_IO_PADS; j = j + 1) begin : gpio_unused
            CF_gpio_config #(.MODE(3'd0)) u_cfg (
              .io_out(),
              .io_in(),
              .io_oeb(),
              .gpio_zero(gpio_loopback_zero[j]),
              .gpio_one(gpio_loopback_one[j]),
              .gpio_in(gpio_in[j]),
              .gpio_dm({gpio_dm2[j], gpio_dm1[j], gpio_dm0[j]}),
              .gpio_inp_dis(gpio_inp_dis[j]),
              .gpio_oeb_out(gpio_oeb[j]),
              .gpio_out_val(gpio_out[j]),
              .gpio_analog_en(gpio_analog_en[j]),
              .gpio_analog_sel(gpio_analog_sel[j]),
              .gpio_analog_pol(gpio_analog_pol[j]),
              .gpio_ib_mode_sel(gpio_ib_mode_sel[j]),
              .gpio_vtrip_sel(gpio_vtrip_sel[j]),
              .gpio_slow_sel(gpio_slow_sel[j]),
              .gpio_holdover(gpio_holdover[j])
            );
          end
        endgenerate

endmodule	// openframe_project_wrapper
