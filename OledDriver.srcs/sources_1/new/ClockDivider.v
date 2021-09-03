`timescale 1ns / 1ps

module ClockDivider(
    input wire i_clk,
    output wire o_div
    );

localparam p_CYCLES_PER_HALF_CLOCK = 0;

reg[ 7 : 0 ] r_clkDiv = 0;
reg r_oClk = 0;

assign o_div = r_oClk;

always @( posedge i_clk )
begin
    r_clkDiv <= r_clkDiv + 1;

    if ( r_clkDiv == p_CYCLES_PER_HALF_CLOCK )
    begin
        r_clkDiv <= 0;
        r_oClk <= ~r_oClk;
    end
end

endmodule
