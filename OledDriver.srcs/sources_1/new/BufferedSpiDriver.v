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
reg r_fifoDataReadEn_nxt = 1'b0;
reg r_fifoDataReadEn = 1'b0;
wire w_fifoEmpty;
wire[ 7:0 ] w_fifoDataRead;

// SPI signals
wire w_spiReady;
reg r_spiEn_nxt = 1'b0;
reg r_spiEn = 1'b0;

// Intermediate buffer for passing data into SPI driver
reg[ 7:0 ] r_intermediateDataBuffer_nxt = 0;
reg[ 7:0 ] r_intermediateDataBuffer = 0;

PetesFifo #( .DEPTH( BUFFER_SIZE ) ) m_fifo(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_wrEn( w_fifoDataEn ),//r_fifoDataWriteEn ),
    .i_wrData( i_data ),
    .i_rdEn( r_fifoDataReadEn ),
    .o_rdData( w_fifoDataRead ),
    .o_empty( w_fifoEmpty ),
    .o_full( o_bufferFull )
);

SpiDriver m_spiDriver(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_dataSetEn( r_spiEn ),
    .i_data( r_intermediateDataBuffer ),
    .o_SCLK( o_SCLK ),
    .o_SDIN( o_SDIN ),
    .o_CS( o_CS ),
    .o_ready( w_spiReady )
);

// Read & SPI-write state
localparam 
    IDLE        = 0,
    READING     = 1,
    DATA_READY  = 2,
    DATA_SEND   = 3;

reg[ 1:0 ] r_state_nxt  = IDLE;
reg[ 1:0 ] r_state      = IDLE;

// FIFO-write state
localparam
    WRITE_IDLE  = 0,
    WRITING     = 1;

reg r_writeState_nxt    = WRITE_IDLE;
reg r_writeState        = WRITE_IDLE;

// Internal module, keep it up to date based on next-state logic
assign w_fifoDataEn = ( r_writeState_nxt == WRITING );

// Synchronous logic
always @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        r_state <= IDLE;
        r_writeState <= WRITE_IDLE;

        r_intermediateDataBuffer <= 0;

        r_fifoDataReadEn <= 1'b0;
        r_spiEn <= 1'b0;
    end
    else
    begin
        r_state <= r_state_nxt;
        r_writeState <= r_writeState_nxt;

        r_intermediateDataBuffer <= r_intermediateDataBuffer_nxt;

        r_fifoDataReadEn <= r_fifoDataReadEn_nxt;
        r_spiEn <= r_spiEn_nxt;
    end
end

// Next-state logic
always @( * )
begin
    r_intermediateDataBuffer_nxt = r_intermediateDataBuffer;

    r_writeState_nxt = WRITE_IDLE; // Default value. Will be overridden after if required
    r_state_nxt = IDLE;

    if ( i_dataWrEn )
    begin
        if ( r_state != IDLE || !w_fifoEmpty )
        begin
            if ( !o_bufferFull )
            begin
                // Read-state is not idle (so it's dealing with other data),
                // or the FIFO isn't empty (so it's about to deal with other data),
                // therefore place data into the FIFO. Discard if FIFO full.
                r_writeState_nxt = WRITING;
            end
        end
        else
        begin
            // Read-state is idle, AND the buffer isn't empty, so can read straight
            // to intermediate buffer.
            r_intermediateDataBuffer_nxt = i_data;
            r_state_nxt = DATA_READY;
        end
    end

    if ( ( r_state == IDLE || r_state == DATA_SEND ) && !w_fifoEmpty )
    begin
        // If there's data available and we're idling or about to idle (shortcut past idle state),
        // then start reading the next byte in;
        r_state_nxt = READING;
    end

    if ( r_state == READING )
    begin
        r_intermediateDataBuffer_nxt = w_fifoDataRead;
        r_state_nxt = DATA_READY;
    end

    if ( r_state == DATA_READY )
    begin
        if ( w_spiReady )
        begin
            r_state_nxt = DATA_SEND;
        end
        else
        begin
            r_state_nxt = DATA_READY;
        end
    end

end

// Output logic
always @( * )
begin
    r_spiEn_nxt = ( r_state_nxt == DATA_SEND );
    r_fifoDataReadEn_nxt = ( r_state_nxt == READING );
end

endmodule
