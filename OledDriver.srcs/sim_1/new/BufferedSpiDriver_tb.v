`timescale 1ns / 1ps

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

`define waitForNegEdge( signal ) \
    wait( signal == 1 ); \
    wait ( signal == 0 );

`define waitForPosEdge( signal ) \
    wait( signal == 0 ); \
    wait ( signal == 1 );

module BufferedSpiDriver_tb;
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

reg r_dataWrEn = 0;
reg[ 7:0 ] r_data = 0;

wire w_SCLK;
wire w_SDIN;
wire w_CS;
wire w_bufferFull;

BufferedSpiDriver #( .BUFFER_SIZE( 4 ) ) m_bufferedSpiDriver(
    .i_clk( clk ),
    .i_dataWrEn( r_dataWrEn ),
    .i_data( r_data ),
    .o_SCLK( w_SCLK ),
    .o_SDIN( w_SDIN ),
    .o_CS( w_CS ),
    .o_bufferFull( w_bufferFull )
);

wire w_spiDataClk;
assign w_spiDataClk = w_SCLK && !w_CS;
reg[ 3:0 ] r_spiReaderCount = 0;
reg[ 7:0 ] r_spiReaderData = 0;

always @( posedge w_spiDataClk )
begin
    if ( !w_CS )
    begin
        r_spiReaderData[ r_spiReaderCount ] <= w_SDIN;
        r_spiReaderCount <= r_spiReaderCount + 1;
    end
end

initial
begin
    #5;
    
    // Test single entry
    r_data = 8'h00;
    r_dataWrEn = 1'b1;
    #8;
    r_dataWrEn = 1'b0;
    `waitForPosEdge( w_CS );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h00 );
    `assert( w_bufferFull, 1'b0 );
    
    // Wait for SPI to complete (shouldn't be necessary)
    #500;
    
    `waitForNegEdge( clk );
    
    // Test 2 entries
    r_data = 8'h01;
    r_dataWrEn = 1'b1;
    #16
    r_data = 8'h02;
    #16;
    r_dataWrEn = 1'b0;
    `assert( w_bufferFull, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h01 );
    `assert( w_bufferFull, 1'b0 );
   // `assert( w_CS, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h02 );
    `assert( w_bufferFull, 1'b0 );
    wait( w_CS == 1'b1 );
    
    `waitForNegEdge( clk );
    
    // Test 5 entries (should fill out the FIFO of size 4)
    r_data = 8'h01;
    r_dataWrEn = 1'b1;
    #16
    r_data = 8'h02;
    #16
    r_data = 8'h03;
    #16;
    r_data = 8'h04;
    #16;
    r_data = 8'h05;
    #16;
    
    r_dataWrEn = 1'b0;
    `assert( w_bufferFull, 1'b1 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h01 );
    `assert( w_bufferFull, 1'b0 );
    //`assert( w_CS, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h02 );
    `assert( w_bufferFull, 1'b0 );
    //`assert( w_CS, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h03 );
    `assert( w_bufferFull, 1'b0 );
    //`assert( w_CS, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h04 );
    `assert( w_bufferFull, 1'b0 );
    //`assert( w_CS, 1'b0 );
    wait( r_spiReaderCount == 8 );
    r_spiReaderCount = 0;
    `assert( r_spiReaderData, 8'h05 );
    `assert( w_bufferFull, 1'b0 );
    wait( w_CS == 1'b1 );
    
    $finish;
    
end


endmodule





































