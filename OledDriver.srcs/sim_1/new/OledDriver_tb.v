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

module OledDriver_tb;

reg r_sysclk = 1'b0; // 125MHz
reg r_en = 1'b0;
reg r_dataEn = 1'b0;
reg[ 7:0 ] r_data = 0;

wire[ 7:0 ] w_pmod;
wire w_driverReady;
wire w_off;

OledDriver m_oledDriver(
    .i_clk( r_sysclk ),
    .i_en( r_en ),
    .i_dataEn( r_dataEn ),
    .i_data( r_data ),
    .o_pmod( w_pmod ),
    .o_ready( w_driverReady ),
    .o_off( w_off )
);

initial
begin
    #1;
    forever begin
        #8
        r_sysclk = ~r_sysclk;
    end
end

wire w_CS;
wire w_SDIN;
wire w_GND;
wire w_SCLK;
wire w_DATACONTROL;
wire w_RES;
wire w_VBATC;
wire w_VDDC;

assign w_CS = w_pmod[ 0 ];
assign w_SDIN = w_pmod[ 1 ];
assign w_GND = w_pmod[ 2 ];
assign w_SCLK = w_pmod[ 3 ];
assign w_DATACONTROL = w_pmod[ 4 ];
assign w_RES = w_pmod[ 5 ];
assign w_VBATC = w_pmod[ 6 ];
assign w_VDDC = w_pmod[ 7 ];


wire w_spiDataClk;
assign w_spiDataClk = w_SCLK && !w_CS;
reg[ 2:0 ] r_spiReaderCount = 7;
reg[ 7:0 ] r_spiReaderData = 0;

always @( posedge w_spiDataClk )
begin
    if ( !w_CS )
    begin
        r_spiReaderData[ r_spiReaderCount ] <= w_SDIN;
        r_spiReaderCount <= r_spiReaderCount - 1;
    end
end

reg[6:0] r_initDataCounter = 0;
reg r_initGuard = 1'b0;
always @( posedge w_CS )
begin
    r_initGuard <= 1'b1;
    if ( r_initGuard )
    begin
        case( r_initDataCounter )
            0:  begin `assert( r_spiReaderData, 8'hAE ) end // Set display OFF
            1:  begin `assert( r_spiReaderData, 8'hD5 ) end // Set display clock divider & oscillator frequency
            2:  begin `assert( r_spiReaderData, 8'h80 ) end //    -> Osc = b1000, Div = b1
            3:  begin `assert( r_spiReaderData, 8'hA8 ) end // Set multiplex ratio
            4:  begin `assert( r_spiReaderData, 8'h1F ) end //    -> b011111
            5:  begin `assert( r_spiReaderData, 8'hD3 ) end // Set display offset
            6:  begin `assert( r_spiReaderData, 8'h00 ) end //    -> b000000
            7:  begin `assert( r_spiReaderData, 8'h40 ) end // Set display start line (b000000)
            8:  begin `assert( r_spiReaderData, 8'h8D ) end // Charge pump setting
            9:  begin `assert( r_spiReaderData, 8'h14 ) end //    -> Enable charge pump (internal VCC)
            10: begin `assert( r_spiReaderData, 8'hA1 ) end // Set segment re-map (col 127 mapped to SEG0)
            11: begin `assert( r_spiReaderData, 8'hC8 ) end // Set COM output scan direction (remapped mode, scan from COM[N-1] to COM0)
            12: begin `assert( r_spiReaderData, 8'hDA ) end // Set COM pins h/w conf
            13: begin `assert( r_spiReaderData, 8'h02 ) end //   -> Sequential COM, disable COM left/right remap
            14: begin `assert( r_spiReaderData, 8'h81 ) end // Set contrast control
            15: begin `assert( r_spiReaderData, 8'h8F ) end //   -> Set to 0x8F
            16: begin `assert( r_spiReaderData, 8'hD9 ) end // Set pre-charge period
            17: begin `assert( r_spiReaderData, 8'hF1 ) end //   -> 15 phase 2, 1 phase 1
            18: begin `assert( r_spiReaderData, 8'hDB ) end // Set COMH deselect level
            19: begin `assert( r_spiReaderData, 8'h40 ) end //   -> Value not documented, possibly ~ 1xVCC.
            20: begin `assert( r_spiReaderData, 8'hA4 ) end // ?? Oled doc says "Set Entire Display ON/OFF", chip doc says "Entire Display ON". Chip doc has other option at hex 0xAE/0xAF
            21: begin `assert( r_spiReaderData, 8'hA6 ) end // Set normal (non-inverse) display
            22: begin `assert( r_spiReaderData, 8'hAF ) end // Set Display ON
        endcase
        
        r_initDataCounter <= r_initDataCounter + 1;
    end
end

initial
begin
    #100;
    `waitForNegEdge( r_sysclk );

    // Enable driver
    r_en = 1'b1;
    #16;
    r_en = 1'b0;
    
    // TODO - wait for init sequence

    // TODO - wait for ready

    r_data = 8'b10010100;
    r_dataEn = 1'b1;
    #16;
    r_dataEn = 1'b0;
    
    #100000;
    // TODO - wait for data
    //$finish;
end



endmodule
