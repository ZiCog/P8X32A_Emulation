// hub_mem

/*
-------------------------------------------------------------------------------
Copyright 2014 Parallax Inc.

This file is part of the hardware description for the Propeller 1 Design.

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
//
// Magnus Karlsson 20140818     RAM is now 64KB
//
// RR20140816   ROM to use new unscrambled code and preset with $readmemh
//              ROM is now 4KB ($F000..$FFFF) and preset with interpreter/booter/runner
//              RAM may be expanded to fill available space up to 60KB
// RR20140816   Bigger Hub RAM & No ROM
//              RAM is 48KB and remaps 48-64KB to 32-48KB

module              hub_mem
(
input               clk_cog,
input               ena_bus,

input               w,
input        [3:0]  wb,
input       [13:0]  a,
input       [31:0]  d,

output      [31:0]  q
);


// 16KB x 32 (64KB) ram with byte-write enables ($0000..$FFFF)
reg [7:0] ram3 [16*1024-1:0];   // 4 x 16KB
reg [7:0] ram2 [16*1024-1:0];
reg [7:0] ram1 [16*1024-1:0];
reg [7:0] ram0 [16*1024-1:0];

// pre-load ROM
initial
begin
    $readmemh ("ROM_$F000-$FFFF_BYTE_0.spin", ram0, 15*1024);
    $readmemh ("ROM_$F000-$FFFF_BYTE_1.spin", ram1, 15*1024);
    $readmemh ("ROM_$F000-$FFFF_BYTE_2.spin", ram2, 15*1024);
    $readmemh ("ROM_$F000-$FFFF_BYTE_3.spin", ram3, 15*1024);
end

reg [7:0] ram_q3;
reg [7:0] ram_q2;
reg [7:0] ram_q1;
reg [7:0] ram_q0;


always @(posedge clk_cog)
begin
    if (ena_bus && w && wb[3])
        ram3[a[13:0]] <= d[31:24];
    if (ena_bus)
        ram_q3 <= ram3[a[13:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && w && wb[2])
        ram2[a[13:0]] <= d[23:16];
    if (ena_bus)
        ram_q2 <= ram2[a[13:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && w && wb[1])
        ram1[a[13:0]] <= d[15:8];
    if (ena_bus)
        ram_q1 <= ram1[a[13:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && w && wb[0])
        ram0[a[13:0]] <= d[7:0];
    if (ena_bus)
        ram_q0 <= ram0[a[13:0]];
end

assign q        = {ram_q3, ram_q2, ram_q1, ram_q0};
endmodule
