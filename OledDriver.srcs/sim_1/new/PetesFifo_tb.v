`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/12/2021 06:50:24 PM
// Design Name: 
// Module Name: PetesFifo_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module PetesFifo_tb;
     
reg clk = 0;
initial
begin
    #1;
    forever
    begin
        #8;
        clk = ~clk;
    end
end

reg dataWriteEn = 0;
reg[ 7:0 ] dataWrite = 0;

reg dataReadEn = 0;
wire[ 7:0 ] dataRead;

wire empty;
wire full; 

PetesFifo #( .DEPTH( 4 ) ) m_fifo(
    .i_clk( clk ),
    .i_wrEn( dataWriteEn ),
    .i_wrData( dataWrite ),
    .i_rdEn( dataReadEn ),
    .o_rdData( dataRead ),
    .o_empty( empty ),
    .o_full( full )
);



initial
begin
    #5;
    `assert( empty, 1 );
    `assert( full, 0 );
    dataWrite = 8'h4A;
    dataWriteEn = 1'b1;
    #8;
    dataWriteEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 0 );
    #8
    dataWrite = 8'h00;
    dataWriteEn = 1'b1;
    #8;
    `assert( empty, 0 );
    `assert( full, 0 );
    dataWriteEn = 1'b0;
    #8
    dataWrite = 8'h03;
    dataWriteEn = 1'b1;
    #8;
    `assert( empty, 0 );
    `assert( full, 0 );
    dataWriteEn = 1'b0;
    #8
    dataWrite = 8'h06;
    dataWriteEn = 1'b1;
    #8
    `assert( empty, 0 );
    `assert( full, 1 );
    dataWriteEn = 1'b0;
    
    #8
    
    dataReadEn = 1'b1;
    #8
    dataReadEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 0 );
    `assert( dataRead, 8'h4A );
    #8
    dataReadEn = 1'b1;
    #8
    dataReadEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 0 );
    `assert( dataRead, 8'h00 );
    #8
    dataReadEn = 1'b1;
    #8
    dataReadEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 0 );
    `assert( dataRead, 8'h03 );
    #8
    dataReadEn = 1'b1;
    #8
    dataReadEn = 1'b0;
    `assert( empty, 1 );
    `assert( full, 0 );
    `assert( dataRead, 8'h06 );
    #8
    
    
    // Test concurrent write.
    //  Base write to make non-empty
    dataWrite = 8'h6A;
    dataWriteEn = 1'b1;
    #8;
    dataWriteEn = 1'b0;
    #8
    //  Write and read, should be non-empty and have 1 left to read
    dataWrite = 8'h0A;
    dataWriteEn = 1'b1;
    dataReadEn = 1'b1;
    #8
    dataWriteEn = 1'b0;
    dataReadEn = 1'b0;
    `assert( dataRead, 8'h6A );
    `assert( empty, 0 );
    #8
    //  Write and read again, should be non-empty and have 1 left to read
    dataWrite = 8'h1A;
    dataWriteEn = 1'b1;
    dataReadEn = 1'b1;
    #8
    dataWriteEn = 1'b0;
    dataReadEn = 1'b0;
    `assert( dataRead, 8'h0A );
    `assert( empty, 0 );
    #8
    dataReadEn = 1'b1;
    #8
    dataReadEn = 1'b0;
    `assert( dataRead, 8'h1A );
    #8
    // Should be empty at this point
    `assert( empty, 1 );
    // Fill up
    dataWrite = 8'h0A;
    dataWriteEn = 1'b1;
    #16;
    dataWrite = 8'h1A;
    #16;
    dataWrite = 8'h2A;
    #16;
    dataWrite = 8'h3A;
    #8
    dataWriteEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 1 );
    #8
    
    // Read 1
    dataReadEn = 1'b1;
    #8;
    dataReadEn = 1'b0;
    `assert( empty, 0 );
    `assert( full, 0 );
    `assert( dataRead, 8'h0A );
    #8;
    //  Read and Write, should be non-full
    dataWrite = 8'h4A;
    dataWriteEn = 1'b1;
    dataReadEn = 1'b1;
    #8
    dataWriteEn = 1'b0;
    dataReadEn = 1'b0;
    `assert( dataRead, 8'h1A );
    `assert( empty, 0 );
    `assert( full, 0 );
    #8
    //  Read and Write again, should be non-full
    dataWrite = 8'h5A;
    dataWriteEn = 1'b1;
    dataReadEn = 1'b1;
    #8
    dataWriteEn = 1'b0;
    dataReadEn = 1'b0;
    `assert( dataRead, 8'h2A );
    `assert( empty, 0 );
    `assert( full, 0 );
    #8
    
    // Read out to empty
    dataReadEn = 1'b1;
    #16;
    `assert( dataRead, 8'h3A );
    `assert( empty, 0 );
    `assert( full, 0 );
    #16;
    `assert( dataRead, 8'h4A );
    `assert( empty, 0 );
    `assert( full, 0 );
    #16;
    `assert( dataRead, 8'h5A );
    `assert( empty, 1 );
    `assert( full, 0 );
    
    
    $finish;
    
    
    
    
    
end

endmodule

























