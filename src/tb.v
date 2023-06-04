`default_nettype none
`timescale 1ns/1ps


module tb(
    input wire clk,
    input wire ext_reset_n, // Typically tt03p5's rst_n signal.

    // Button inputs from the outside world; active high
    // (though the innermost solo_squash inverts them, internally, because that's how
    // it was originally designed before it was made part of tt03p5):
    input wire pause,
    input wire new_game,
    input wire down_key,
    input wire up_key,

    // VGA output signals:
    output wire red,
    output wire green,
    output wire blue,
    output wire hsync,
    output wire vsync,

    // Speaker output:
    output wire speaker,

    // Other debug outputs:
    output wire col0,
    output wire row0
);

    localparam PWR = 1'b1;
    localparam GND = 1'b0;

    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    wire [7:0] ui_in;
    wire [7:0] uo_out;

    assign ui_in[0] = pause;
    assign ui_in[1] = new_game;
    assign ui_in[2] = down_key;
    assign ui_in[3] = up_key;

    assign blue     = uo_out[0];
    assign green    = uo_out[1];
    assign red      = uo_out[2];
    assign hsync    = uo_out[3];
    assign vsync    = uo_out[4];
    assign speaker  = uo_out[5];
    assign col0     = uo_out[6];    // Asserted for the first pixel of each line.
    assign row0     = uo_out[7];    // Asserted for the whole of the first line.

    tt_um_algofoogle_solo_squash tt_um_algofoogle_solo_squash(
`ifdef USE_POWER_PINS
        .vccd1  (PWR),
        .vssd1  (GND),
`endif
        .ui_in  (ui_in),
        .uo_out (uo_out),
        //.uio_in(),
        //.uio_out(),
        //.uio_oe(),
        .ena    (1), // Unused?
        .clk    (clk),
        .rst_n  (ext_reset_n)
    );

endmodule
