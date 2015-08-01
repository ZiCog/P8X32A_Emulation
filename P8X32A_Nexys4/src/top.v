/*
-------------------------------------------------------------------------------

This file is part of the hardware description for the Propeller 1 Design
for Pipistrello LX45.

The Propeller 1 Design is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your option)
any later version.

The Propeller 1 Design is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
the Propeller 1 Design.  If not, see <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------
*/

//  Andy Silverman   20140902  Added support for 100Mhz input clock as on the Digilent 
//                                Nexys4 (Artix7-based board.)
//
// Copyright 2014 Saanlima Electronics
//
// Magnus Karlsson 20140820 Moved reg and wire declarations to top of file
//                          Added PLL or DCM selection option
//                          Added dtr or inp_resn selection option
//
// Magnus Karlsson 20140818 Wrote top level verilog module from scratch based 
//                          on top.tdf and tim.tdf in the Parallax release.


//`define use_pll 1     // comment out for DCM mode
`define use_dtr 1       // comment out for inp_resn instead of dtr
`define Nexys4 1        // comment out for 50Mhz input clock, otherwise 100Mhz input is assumed.

module          top
(
input           clock_50,       // clock input
`ifdef use_dtr
input           dtr,            // serial port DTR input
`else
input           inp_resn,       // reset input (active low)
`endif
inout   [31:0]  pin,            // i/o pins
output  [7:0]   ledg,           // cog leds
output          tx_led,         // tx monitor LED
output          rx_led,         // rx monitor LED
output          p16_led,        // monitor LED for pin 16
output          p17_led         // monitor LED for pin 17
);

//
// reg and wire declarations
//
reg         nres;
wire [7:0]  cfg;
wire [31:0] pin_in, pin_out, pin_dir;
wire        clkfb, clock_160, clk;
reg [31:0]  reset_cnt;
reg         reset_to;
wire        res;
reg [7:0]   cfgx;
reg [12:0]  divide;
wire        clk_pll;
wire        clk_cog;


//
// Clock generation
//

`ifdef use_pll
//
// PLL (50 MHz -> 160 MHz)
//
PLL_BASE # (
     `ifdef Nexys4              //Nexys4 input clock = 100Mhz, not 50.
        .CLKIN_PERIOD(10),
        .CLKFBOUT_MULT(8),
     `else
        .CLKIN_PERIOD(20),
        .CLKFBOUT_MULT(16),
     `endif
    .CLKOUT0_DIVIDE(5),
    .COMPENSATION("INTERNAL")
  ) PLL (
    .CLKFBOUT(clkfb),
    .CLKOUT0(clock_160),
    .CLKOUT1(),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(),
    .CLKFBIN(clkfb),
    .CLKIN(clock_50),
    .RST(1'b0)
  );
`else
//
// DCM (50 MHz -> 160 MHz)
//
DCM_SP DCM_SP_(
    .CLKIN(clock_50),
    .CLKFB(clkfb),
    .RST(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .PSCLK(1'b0),
    .DSSEN(1'b0),
    .CLK0(clkfb),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLKDV(),
    .CLK2X(),
    .CLK2X180(),
    .CLKFX(clock_160),
    .CLKFX180(),
    .STATUS(),
    .LOCKED(),
    .PSDONE());

  defparam DCM_SP_.CLKIN_DIVIDE_BY_2 = "FALSE";
  
  defparam DCM_SP_.CLK_FEEDBACK = "1X";
  defparam DCM_SP_.CLKFX_DIVIDE = 5;
  `ifdef Nexys4
        defparam DCM_SP_.CLKFX_MULTIPLY = 8;
        defparam DCM_SP_.CLKIN_PERIOD = 10;
  `else
        defparam DCM_SP_.CLKFX_MULTIPLY = 16;
        defparam DCM_SP_.CLKIN_PERIOD = 20;
  `endif
`endif

BUFG BUFG_clk(.I(clock_160), .O(clk));

assign clk_pll = ((cfgx[6:5] == 2'b11) && (cfgx[2:0] == 3'b111)) ? clock_160 : divide[11];
assign clk_cog = divide[12];

`ifdef use_dtr
//
// Emulate RC filter on Prop Plug by generating a long reset pulse
// everytime DTR goes high
//
always @ (posedge clk or negedge dtr)
    if (!dtr) begin
        reset_cnt <= 32'd0;
        reset_to <= 1'b0;
    end else begin
        reset_cnt <= reset_to ? reset_cnt : reset_cnt + 1;
        reset_to <= (reset_cnt == 32'h4c4b40) ? 1'b1 : reset_to; //50ms delay value lowered to handle Nexys 4's 100Mhz input clk.
    end

wire inp_resn = ~(dtr & ~reset_to);
`endif

//    
// Clock control (from tim.tdf)
//
assign res = ~inp_resn;

always @ (posedge clk)
    cfgx <= cfg;

always @ (posedge clk)
    divide <= divide + 
        {   (cfgx[6:5] == 2'b11 && cfgx[2:0] == 3'b111) || res,
            cfgx[6:5] == 2'b11 && cfgx[2:0] == 3'b110 && !res,
            cfgx[6:5] == 2'b11 && cfgx[2:0] == 3'b101 && !res,
            ((cfgx[6:5] == 2'b11 && cfgx[2:0] == 3'b100) || cfgx[2:0] == 3'b000) && !res,
            ((cfgx[6:5] == 2'b11 && cfgx[2:0] == 3'b011) || (cfgx[5] == 1'b1 && cfgx[2:0] == 3'b010)) && !res,
            7'b0,
            cfgx[2:0] == 3'b001 && !res
        };

//
// Propeller 1 core module
//

always @ (posedge clk_cog)
    nres <= inp_resn & !cfgx[7];

dig core (  .nres       (nres),
            .cfg        (cfg),
            .clk_cog    (clk_cog),
            .clk_pll    (clk_pll),
            .pin_in     (pin_in),
            .pin_out    (pin_out),
            .pin_dir    (pin_dir),
            .cog_led    (ledg) );

//
// Bidir I/O buffers
//
genvar i;
generate
    for (i=0; i<32; i=i+1)
    begin : iogen
        IOBUF io_ (.IO(pin[i]), .O(pin_in[i]), .I(pin_out[i]), .T(~pin_dir[i]));
    end
endgenerate

//
// Monitor LEDs
//
//assign tx_led = pin_in[30];
//assign rx_led = pin_in[31];
//assign p16_led = pin_in[16];
//assign p17_led = pin_in[17];
endmodule
