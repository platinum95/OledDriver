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

module OledProject_tb;

reg r_clk = 0;
reg r_rst = 0;
reg r_driverEn = 0;

wire[ 7:0 ] w_pmod;
wire w_driverReady;
wire w_driverOff;

OledProject m_oledProject(
    .i_clk( r_clk ),
    .i_rst( r_rst ),
    .i_driverEn( r_driverEn ),
    .o_pmod( w_pmod ),
    .o_driverReady( w_driverReady ),
    .o_driverOff( w_driverOff )
);

initial
begin
    #1;
    forever begin
        #4
        r_clk = ~r_clk;
    end
end

initial begin
    #100;
    r_rst = 1;
    #100;
    r_rst = 0;
    #100;

    `assert( w_driverOff, 1'b1 );
    `assert( w_driverReady, 1'b0 );

    `waitForNegEdge( r_clk );
    r_driverEn = 1'b1;
    #8;
    r_driverEn = 1'b0;

    #100;
    `assert( w_driverOff, 1'b0 );
    `waitForPosEdge( w_driverReady );
    `assert( w_driverOff, 1'b0 );

    r_rst = 1;
    #100;
    r_rst = 0;
    #100;
    `assert( w_driverOff, 1'b1 );
    `assert( w_driverReady, 1'b0 );

    $finish;
end


endmodule
