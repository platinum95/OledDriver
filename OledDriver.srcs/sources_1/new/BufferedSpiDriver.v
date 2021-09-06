`timescale 1ns / 1ps

module BufferedSpiDriver(
    input wire i_clk,
    input wire i_rst,
    input wire i_dataWrEn,
    input wire[ 7:0 ] i_data,
    output wire o_SCLK,
    output wire o_SDIN,
    output wire o_CS,
    output wire o_bufferFull,
    output wire o_spiIdle
);

// Buffer size in bytes
parameter BUFFER_SIZE = 64;

// Signals for FIFO
wire w_fifoWrEn;
wire w_fifoEmpty;

reg r_fifoReadEn = 1'b0;
reg r_spiWriteEn = 1'b0;

wire[ 7:0 ] w_fifoDataRead;

// SPI signals
wire w_spiReady;

PetesFifo #( .DEPTH( BUFFER_SIZE ) ) m_fifo(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_wrEn( w_fifoWrEn ),
    .i_wrData( i_data ),
    .i_rdEn( r_fifoReadEn ),
    .o_rdData( w_fifoDataRead ),
    .o_empty( w_fifoEmpty ),
    .o_full( o_bufferFull )
);

SpiDriver m_spiDriver(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_dataSetEn( r_spiWriteEn ),
    .i_data( w_fifoDataRead ),
    .o_SCLK( o_SCLK ),
    .o_SDIN( o_SDIN ),
    .o_CS( o_CS ),
    .o_ready( w_spiReady )
);

assign w_fifoWrEn = ( i_dataWrEn && !o_bufferFull );

assign o_spiIdle = w_fifoEmpty && !i_dataWrEn && w_spiReady;

localparam[ 1:0 ]
    IDLE = 0,
    READ = 1,
    WRITE = 2;

reg[ 1:0 ] r_state = IDLE;
reg[ 1:0 ] r_state_nxt = IDLE;

always @( * )
begin
    r_state_nxt = IDLE;

    if ( r_state == IDLE && !w_fifoEmpty && w_spiReady )
    begin
        r_state_nxt = READ;
    end
    else if ( r_state == READ )
    begin
        r_state_nxt = WRITE;
    end
    else if ( r_state == WRITE )
    begin
        r_state_nxt = IDLE;
    end
end

always @( * )
begin
    r_fifoReadEn = ( r_state_nxt == READ ) ? 1'b1 : 1'b0;
    r_spiWriteEn = ( r_state_nxt == WRITE ) ? 1'b1 : 1'b0;
end


always @( posedge i_clk, negedge i_rst )
begin
    if ( !i_rst )
    begin
        r_state <= IDLE;
    end
    else
    begin
        r_state <= r_state_nxt;
    end
end

endmodule
