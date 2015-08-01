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
// Andy Silverman  20140903     Provide fully standard Propeller configuration including video rom and full math tables, 32K RAM
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


// 8192 x 32 ram with byte-write enables ($0000..$7FFF)

reg [7:0] ram3 [8191:0];
reg [7:0] ram2 [8191:0];
reg [7:0] ram1 [8191:0];
reg [7:0] ram0 [8191:0];

reg [7:0] ram_q3;
reg [7:0] ram_q2;
reg [7:0] ram_q1;
reg [7:0] ram_q0;

always @(posedge clk_cog)
begin
    if (ena_bus && !a[13] && w && wb[3])
        ram3[a[12:0]] <= d[31:24];
    if (ena_bus && !a[13])
        ram_q3 <= ram3[a[12:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && !a[13] && w && wb[2])
        ram2[a[12:0]] <= d[23:16];
    if (ena_bus && !a[13])
        ram_q2 <= ram2[a[12:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && !a[13] && w && wb[1])
        ram1[a[12:0]] <= d[15:8];
    if (ena_bus && !a[13])
        ram_q1 <= ram1[a[12:0]];
end

always @(posedge clk_cog)
begin
    if (ena_bus && !a[13] && w && wb[0])
        ram0[a[12:0]] <= d[7:0];
    if (ena_bus && !a[13])
        ram_q0 <= ram0[a[12:0]];
end

// 4096 x 32 rom containing character definitions ($8000..$BFFF)

reg [31:0] rom_low [4095:0];
reg [31:0] rom_low_q;

// 4096 x 32 rom containing sin table, log table, booter, and interpreter ($C000..$FFFF)
reg [31:0] rom_high [4095:0];
reg [31:0] rom_high_q;

// pre-load ROM
initial
begin
    $readmemh ("P8X32A_ROM_FONT.spin", rom_low);
    $readmemh ("ROM_$C000-$FFFF_UNSCRAMBLED.spin", rom_high); 
end

always @(posedge clk_cog)
if (ena_bus && a[13:12] == 2'b10)
    rom_low_q <= rom_low[a[11:0]];

always @(posedge clk_cog)
if (ena_bus && a[13:12] == 2'b11)
    rom_high_q <= rom_high[a[11:0]];


// memory output mux

reg [1:0] mem;

always @(posedge clk_cog)
if (ena_bus)
    mem <= a[13:12];

assign q            = !mem[1]   ? {ram_q3, ram_q2, ram_q1, ram_q0}
                    : !mem[0]   ? rom_low_q     // comment out this line for DE0-Nano (sacrifices character rom to fit device)
                                : rom_high_q;
endmodule
