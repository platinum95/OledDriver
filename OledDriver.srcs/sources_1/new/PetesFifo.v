`timescale 1ns / 1ps

// FIFO with synchronous output.
 
module PetesFifo(
    input wire i_clk,
    input wire i_rst,
    input wire i_wrEn,
    input wire[ WIDTH-1:0 ] i_wrData,
    input wire i_rdEn,
    output reg[ WIDTH-1:0 ] o_rdData = 0,
    output reg o_empty = 1,
    output reg o_full = 0
);

parameter
    WIDTH=8,
    DEPTH=32;

localparam p_INDEX_WIDTH = 7;

// Data storage
reg [ WIDTH-1:0 ] r_data[ DEPTH-1:0 ];
reg [ WIDTH-1:0 ] r_data_nxt = 0;

reg[ WIDTH-1:0 ] r_rdData_nxt = 0;

// TODO - register widths should fit parameters
reg[ p_INDEX_WIDTH:0 ] r_readIndex = 0;
reg[ p_INDEX_WIDTH:0 ] r_writeIndex = 0;

reg[ p_INDEX_WIDTH:0 ] r_readIndex_nxt = 0;
reg[ p_INDEX_WIDTH:0 ] r_writeIndex_nxt = 0;

// Wrap-around logic for getting next-counter values.
wire[ p_INDEX_WIDTH:0 ] w_nextWriteIndex;
assign w_nextWriteIndex = ( r_writeIndex == DEPTH - 1 ) ? ( 0 ) : ( r_writeIndex + 1 );

wire[ p_INDEX_WIDTH:0 ] w_nextReadIndex;
assign w_nextReadIndex = ( r_readIndex == DEPTH - 1 ) ? ( 0 ) : ( r_readIndex + 1 );

localparam[ 1:0 ]
    EMPTY   = 0,
    PARTIAL = 1,
    FULL    = 2;

reg[ 1:0 ] r_state = EMPTY;
reg[ 1:0 ] r_state_nxt = EMPTY;

reg r_full_nxt = 0;
reg r_empty_nxt = 1;

// Next-state logic, with asynchronous data output
always @( * )
begin
    r_state_nxt = r_state;
    r_data_nxt = r_data[ r_writeIndex ];
    r_rdData_nxt = o_rdData;

    if ( i_wrEn && i_rdEn && r_state == EMPTY )
    begin
        // Read/write with bypass.
        // No state change.
        // Output data mirrors input data
        r_rdData_nxt = i_wrData;
    end
    else if ( i_wrEn && i_rdEn )
    begin
        // Read-write, no bypass.
        // No state change.
        r_data_nxt = i_wrData;
        r_writeIndex_nxt = w_nextWriteIndex;
        r_readIndex_nxt = w_nextReadIndex;

        // Output state comes from buffer
        r_rdData_nxt = r_data[ r_readIndex ];
    end
    else if ( !i_wrEn && i_rdEn && r_state != EMPTY )
    begin
        // Read-only.
        // Next-state depends on read-position.
        r_state_nxt = ( w_nextReadIndex == r_writeIndex ) ? EMPTY : PARTIAL;
        r_readIndex_nxt = w_nextReadIndex;

        // Output state comes from buffer.
        r_rdData_nxt = r_data[ r_readIndex ];
    end
    else if ( i_wrEn && !i_rdEn && r_state != FULL )
    begin
        // Write-only.
        // Next-state depends on write-position
        r_state_nxt = ( w_nextWriteIndex == r_readIndex ) ? FULL : PARTIAL;
        r_data_nxt = i_wrData;
        r_writeIndex_nxt = w_nextWriteIndex;
    end
end

// (A)Synchronous outputs
always @( * )
begin
    r_full_nxt  = ( r_state_nxt == FULL );
    r_empty_nxt = ( r_state_nxt == EMPTY );
end

always @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        r_data[ 0 ] <= 0;
        r_writeIndex <= 0;
        r_readIndex <= 0;
        o_full <= 1'b0;
        o_empty <= 1'b1;
        r_state <= EMPTY;
        o_rdData <= 0;
    end
    else
    begin
        r_state <= r_state_nxt;
        r_data[ r_writeIndex ] <= r_data_nxt;
        r_writeIndex <= r_writeIndex_nxt;
        r_readIndex <= r_readIndex_nxt;
        o_full <= r_full_nxt;
        o_empty <= r_empty_nxt;
        o_rdData <= r_rdData_nxt;
    end
end
    
endmodule

































