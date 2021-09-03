`timescale 1ns / 1ps

// Cycles      1    2     3     4      5     6     7    8      9    10   
// Edges     1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20
// EdgeCnt   19 18 17 16 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0     At time falling/rising edge is handled. +1 for time edge is generated 
// SCLK _____|^^|__|^^|__|^^|__|^^|__|^^|__|^^|__|^^|__|^^|__|^^|__|^^|_____
// CS   ^^^^^^^^|_______________________________________________|^^^^^^^^^^^
// SDIN ________X=====X=====X=====X=====X=====X=====X=====X=====X___________

module SpiDriver(
    input wire i_clk,
    input wire i_rst,
    input wire i_dataSetEn,
    input wire[ 7:0 ] i_data,
    output wire o_SCLK,
    output wire o_SDIN,
    output wire o_CS,
    output wire o_ready
    );

parameter MSB_FIRST = 1'b1;

// Clock at 125MHz, max 10MHz clock for OLED.
// /16 -> 7.8125 MHz
reg[ 3 : 0 ] r_clkDiv = 0;
reg r_spiClk = 0;

localparam p_CYCLES_PER_HALF_CLOCK = 8;

// Intermediate buffer
reg r_bufferHasData = 1'b0; // May be a latch?
reg[ 7:0 ] r_dataBuffer = 0;

reg[ 4:0 ] r_edgeCount = 0;
reg[ 2:0 ] r_dataCount = MSB_FIRST ? 7 : 0;

reg r_fallingEdge = 0;
reg r_risingEdge = 0;

reg r_SDIN = 0;
reg r_OSCLK = 0;
reg r_CS = 1;

assign o_SCLK = r_OSCLK;
assign o_SDIN = r_SDIN;
assign o_CS = r_CS;
assign o_ready = ( r_edgeCount == 0 );

// SPI Clock generation and input-capture
always @( posedge i_clk, negedge i_rst )
begin
    r_fallingEdge <= 0;
    r_risingEdge <= 0;
    r_dataBuffer <= r_dataBuffer;
    r_edgeCount <= r_edgeCount;
    r_clkDiv <= r_clkDiv;

    if ( ~i_rst )
    begin
        r_fallingEdge <= 0;
        r_risingEdge <= 0;
        r_dataBuffer <= 0;
        r_edgeCount <= 0;
        r_clkDiv <= 0;
        r_spiClk <= 0;
    end
    else
    begin
        if ( i_dataSetEn && r_edgeCount == 0 )
        begin
            r_dataBuffer <= i_data;
            r_edgeCount <= 20;
            r_spiClk <= 1'b0; // Assuming idle-low
        end
        else if ( r_edgeCount > 0 )
        begin
            r_clkDiv <= r_clkDiv + 1;
            if ( r_clkDiv == p_CYCLES_PER_HALF_CLOCK )
            begin
                r_clkDiv <= 0;
                r_edgeCount <= r_edgeCount - 1;
                r_spiClk <= ~r_spiClk;
                if ( r_spiClk )
                begin
                    r_fallingEdge <= 1;
                end
                else
                begin
                    r_risingEdge <= 1;
                end
            end
        end
        else
        begin
            r_spiClk <= 1'b0; // Assuming idle-low
        end
    end
end

// SDIN/CLK generation
always @( posedge i_clk )
begin
    r_SDIN <= r_SDIN;
    r_dataCount <= r_dataCount;

    if ( ~i_rst )
    begin
        r_SDIN <= 1'b0;
        r_dataCount <= MSB_FIRST ? 7 : 0;
        r_CS <= 1'b1;
        r_OSCLK <= 1'b0;
    end
    else
    begin
        if ( r_edgeCount < 19 && r_edgeCount > 2 )
            begin
            if ( r_fallingEdge )
            begin
                r_SDIN <= r_dataBuffer[ r_dataCount ];
                if ( MSB_FIRST )
                begin
                    r_dataCount <= r_dataCount - 1;
                end
                else
                begin
                    r_dataCount <= r_dataCount + 1;
                end
                r_CS <= 1'b0;
            end
            else if ( r_risingEdge )
            begin
                // Nothing to do
            end
        end
        else
        begin
            r_CS <= 1'b1;
            r_SDIN <= 1'b0;
        end

        // Clock generation
        r_OSCLK <= r_spiClk;
    end
end
 
endmodule




















