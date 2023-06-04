`default_nettype none
`timescale 1ns / 1ps

module tt_um_algofoogle_solo_squash(
    // 8 dedicated user inputs:
    input   wire [7:0]  ui_in,

    // 8 dedicated user outputs:
    output  wire [7:0]  uo_out,

    // 8 bidirectional user IOs:
    input   wire [7:0]  uio_in,     // Input path.
    output  wire [7:0]  uio_out,    // Output path.
    output  wire [7:0]  uio_oe,     // Enable path (active high: 0=input, 1=output)

    // Control:
    input   wire        ena,        // Can be ignored for now.
    input   wire        clk,        // 25.175MHz ideal, but 25.000MHz is good enough.
    input   wire        rst_n       // Active low reset
);

    // Register the RGB outputs for stability:
    wire r, g, b;
    reg qr, qg, qb;
    always @(posedge clk) {qr,qg,qb} <= {r,g,b};
    assign uo_out[2:0] = {qr,qg,qb};
    //NOTE: MAYBE we should also care about registering hsync, vsync, and maybe speaker,
    // but I want to see what happens in the real ASIC if we don't.

    // Hard-wire bidir IOs to make them all outputs:
    assign uio_oe = 8'b11111111;
    // For other experimentation, output the UNregistered (direct combo logic)
    // red and green signals directly out via the upper 2 bits of the bidir IO port,
    // unless switched by pulling ui_in[4] high, in which case red and green are
    // replaced with blue and the 'visible' signal:
    assign uio_out[7] = ui_in[4] ? b : r;
    assign uio_out[6] = ui_in[4] ? visible : g;
    wire visible;

    // Input metastability avoidance. Do we really need this, for this design?
    // I'm playing it extra safe :)
    wire pause_n, new_game_n, down_key_n, up_key_n;
    input_sync pause    (.clk(clk), .d(~ui_in[0]), .q(pause_n   ));
    input_sync new_game (.clk(clk), .d(~ui_in[1]), .q(new_game_n));
    input_sync down_key (.clk(clk), .d(~ui_in[2]), .q(down_key_n));
    input_sync up_key   (.clk(clk), .d(~ui_in[3]), .q(up_key_n  ));

    wire [9:0] h;
    wire [9:0] v;
    wire [4:0] offset; // This is effectively a frame counter.

    // Just for fun, wire up a leading zero counter (with 24-bit input) that takes a concatenation of
    // offset's lower 4 bits, then v, then h.
    lzc24 lzc(.x({offset[3:0], v, h}), .z(uio_out[4:0]), .a(uio_out[5]));

    solo_squash game(
        // --- Inputs ---
        .clk        (clk),
        .reset      (~rst_n),       // Active HIGH reset needed here.
        // Active-low control inputs (but pulled low by the chip BY DEFAULT when not pressed, so inverted here):
        .pause_n    (pause_n),
        .new_game_n (new_game_n),
        .down_key_n (down_key_n),
        .up_key_n   (up_key_n),

        // --- Outputs ---
        .red        (r),
        .green      (g),
        .blue       (b),
        .hsync      (uo_out[3]),
        .vsync      (uo_out[4]),
        .speaker    (uo_out[5]),
        // Debug outputs:
        .col0       (uo_out[6]),
        .row0       (uo_out[7]),
        .h_out      (h),
        .v_out      (v),
        .offset_out (offset),
        .visible_out(visible)
    );

endmodule

// Basic double DFF metastability avoidance:
module input_sync(
    input wire clk,
    input wire d,
    output wire q
);
    reg dff1, dff2;
    assign q = dff2;
    always @(posedge clk) {dff2,dff1} <= {dff1,d};
endmodule
