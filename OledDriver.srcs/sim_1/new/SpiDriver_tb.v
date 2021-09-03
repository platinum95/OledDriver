`timescale 1ns / 1ps


module SpiDriver_tb;
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

reg r_dataEn = 0;
reg[ 7:0 ] r_data = 0;

wire w_SCLK;
wire w_SDIN;
wire w_CS;
wire w_idle;

SpiDriver spiDriver(
    .i_clk( clk ),
    .i_dataSetEn( r_dataEn ),
    .i_data( r_data ),
    .o_SCLK( w_SCLK ),
    .o_SDIN( w_SDIN ),
    .o_CS( w_CS ),
    .o_idle( w_idle )
);


initial
begin
    #5;
    r_data = 8'h00;
    r_dataEn = 1'b1;
    #16;
    r_dataEn = 1'b0;

    while ( w_idle == 0 ) begin #100; end
    #200;
    
    r_data = 8'hFF;
    r_dataEn = 1'b1;
    #16;
    r_dataEn = 1'b0;
    
    while ( w_idle == 0 ) begin #100; end
    #200;
    
    r_data = 8'b01010101;
    r_dataEn = 1'b1;
    #16;
    r_dataEn = 1'b0;
    
    while ( w_idle == 0 ) begin #100; end
    #200;
    
    $finish;
end

endmodule
