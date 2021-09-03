`timescale 1ns / 1ps

module BufferedSpiDriver(
    input wire i_clk,
    input wire i_rst,
    input wire i_dataWrEn,
    input wire[ 7:0 ] i_data,
    output wire o_SCLK,
    output wire o_SDIN,
    output wire o_CS,
    output wire o_bufferFull
);

// Buffer size in bytes
parameter BUFFER_SIZE = 64;

// Signals for FIFO
wire w_fifoDataEn;
wire w_fifoReadAndSpiEn;
wire w_fifoEmpty;

wire[ 7:0 ] w_fifoDataRead;

// SPI signals
wire w_spiReady;

PetesFifo #( .DEPTH( BUFFER_SIZE ) ) m_fifo(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_wrEn( w_fifoDataEn ),//r_fifoDataWriteEn ),
    .i_wrData( i_data ),
    .i_rdEn( w_fifoReadAndSpiEn ),
    .o_rdData( w_fifoDataRead ),
    .o_empty( w_fifoEmpty ),
    .o_full( o_bufferFull )
);

SpiDriver m_spiDriver(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_dataSetEn( w_fifoReadAndSpiEn ),
    .i_data( w_fifoDataRead ),
    .o_SCLK( o_SCLK ),
    .o_SDIN( o_SDIN ),
    .o_CS( o_CS ),
    .o_ready( w_spiReady )
);

assign w_fifoDataEn = ( i_dataWrEn && !o_bufferFull );
assign w_fifoReadAndSpiEn = ( w_spiReady && !w_fifoEmpty );

endmodule
