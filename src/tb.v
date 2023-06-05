`default_nettype none
`timescale 1ns/1ps
`define SIM

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

module tb (
	// testbench is controlled by test.py
	input clk,
	input rst_n,
	input intr,
	input uart_rx,
	input DI,
	
	input [3:0] EF,
	
	output Q,
	output uart_tx,
	output SCLK,
	output DO
);

	// this part dumps the trace to a vcd file that can be viewed with GTKWave
	initial begin
		$dumpfile ("tb.vcd");
		$dumpvars (0, tb);
		#1;
	end
	
	wire IO0_ROM;
	wire IO1_ROM;
	wire IO2_ROM;
	wire IO3_ROM;
	wire IO0_RAM;
	wire IO1_RAM;
	wire IO2_RAM;
	wire IO3_RAM;

	// wire up the inputs and outputs
	wire [7:0] uo_out;
	wire [7:0] uio_out;
	wire [7:0] uio_oe;
	assign Q = uo_out[0];
	wire CS_ROM = uo_out[1];
	wire SCLK_ROM = uo_out[2];
	wire CS_RAM = uo_out[3];
	wire SCLK_RAM = uo_out[4];
	
	assign SCLK = uo_out[6];
	assign DO = uo_out[7];
	
	wire [3:0] ROM_DO = uio_out[3:0];
	wire [3:0] ROM_OE = uio_oe[3:0];
	assign IO0_ROM = ROM_OE[0] ? ROM_DO[0] : 1'bz;
	assign IO1_ROM = ROM_OE[1] ? ROM_DO[1] : 1'bz;
	assign IO2_ROM = ROM_OE[2] ? ROM_DO[2] : 1'bz;
	assign IO3_ROM = ROM_OE[3] ? ROM_DO[3] : 1'bz;
	
	wire [3:0] RAM_DO = uio_out[7:4];
	wire [3:0] RAM_OE = uio_oe[7:4];
	assign IO0_RAM = RAM_OE[0] ? RAM_DO[0] : 1'bz;
	assign IO1_RAM = RAM_OE[1] ? RAM_DO[1] : 1'bz;
	assign IO2_RAM = RAM_OE[2] ? RAM_DO[2] : 1'bz;
	assign IO3_RAM = RAM_OE[3] ? RAM_DO[3] : 1'bz;
	
	assign uart_tx = uo_out[5];
	
	// instantiate the DUT
	tt_um_as1802 as1802(
		`ifdef GL_TEST
			.vccd1( 1'b1),
			.vssd1( 1'b0),
		`endif
		.ena  (1'b1),
		.clk (clk),
		.rst_n(rst_n),
		.ui_in({1'b0, DI, uart_rx, intr, EF}),
		.uo_out(uo_out),
		.uio_in({IO3_RAM, IO2_RAM, IO1_RAM, IO0_RAM, IO3_ROM, IO2_ROM, IO1_ROM, IO0_ROM}),
		.uio_out(uio_out),
		.uio_oe(uio_oe)
		);
		
	W25Q128JVxIM W25Q128JVxIM(
		.CSn(CS_ROM),
		.CLK(SCLK_ROM),
		.DIO(IO0_ROM),
		.DO(IO1_ROM),
		.WPn(IO2_ROM),
		.HOLDn(IO3_ROM)
	);
	
	RAM RAM(
		.CSn(CS_RAM),
		.CLK(SCLK_RAM),
		.IO0(IO0_RAM),
		.IO1(IO1_RAM),
		.IO2(IO2_RAM),
		.IO3(IO3_RAM)
	);

endmodule
