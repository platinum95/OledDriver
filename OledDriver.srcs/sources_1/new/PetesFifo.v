`timescale 1ns / 1ps
 
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

// TODO - register widths should fit parameters
reg[ p_INDEX_WIDTH:0 ] r_readIndex = 0;
reg[ p_INDEX_WIDTH:0 ] r_writeIndex = 0;

// Wrap-around logic for getting next-counter values.
wire[ p_INDEX_WIDTH:0 ] w_nextWriteIndex;
assign w_nextWriteIndex = ( r_writeIndex == DEPTH - 1 ) ? ( 0 ) : ( r_writeIndex + 1 );

wire[ p_INDEX_WIDTH:0 ] w_nextReadIndex;
assign w_nextReadIndex = ( r_readIndex == DEPTH - 1 ) ? ( 0 ) : ( r_readIndex + 1 );


reg[ WIDTH-1:0 ] o_rdData_nxt = 0;

always @(*)
begin
    if( i_wrEn && i_rdEn && o_empty )
    begin
        // Special case for when we're reading & writing at the same time on an empty buffer:
        // just read-out the write-in data
        o_rdData_nxt <= i_wrData;
    end
    else
    begin
        o_rdData_nxt <= r_data[ r_readIndex ];
    end
end

// Synmchronous Output
always @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        o_rdData <= 0;
    end
    else
    begin
        o_rdData <= o_rdData_nxt;
    end
end

always @( posedge i_clk, negedge i_rst )
begin
    // No latches in this house
    r_data[ r_writeIndex ] <= r_data[ r_writeIndex ];
    r_writeIndex <= r_writeIndex;
    r_readIndex <= r_readIndex;
    o_full <= o_full;
    o_empty <= o_empty;

    if ( ~i_rst )
    begin
        r_writeIndex <= 0;
        r_readIndex <= 0;
        o_full <= 1'b0;
        o_empty <= 1'b1;
    end
    else
    begin
        if ( !( i_wrEn && i_rdEn && o_empty ) )
        begin
            // Write logic
            if ( i_wrEn && !o_full )
            begin
                r_data[ r_writeIndex ] <= i_wrData;
                r_writeIndex <= w_nextWriteIndex;
        
                if ( !( i_rdEn && !o_empty ) )
                begin
                    // If we're writing but not reading, we're definitely not empty
                    o_empty <= 1'b0;
                    
                    // If the next write will write to the read index, and we're not reading this clock, then we're full
                    if ( ( w_nextWriteIndex == r_readIndex ) )
                    begin
                        o_full <= 1'b1;
                    end
                    else
                    begin
                        o_full <= 1'b0;
                    end
                end
            end
        
            // Read logic
            if ( i_rdEn && !o_empty )
            begin
                r_readIndex <= w_nextReadIndex;
                
                if ( !( i_wrEn && !o_full ) )
                begin
                    // If we're reading but not writing, we're definitely not full
                    o_full <= 1'b0;
                
                    // If the next read will read from the write index, and we're not writing this clock, then we're empty    
                    if ( ( w_nextReadIndex == r_writeIndex ) && !( i_wrEn && !o_full ) )
                    begin
                        o_empty <= 1'b1;
                    end
                    else
                    begin
                        o_empty <= 1'b0;
                    end
                end
            end
        end
    end
end
    
endmodule

































