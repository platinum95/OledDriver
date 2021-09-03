`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/02/2021 07:57:05 AM
// Design Name: 
// Module Name: SpiTestWrapper
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


module SpiTestWrapper(
    input wire i_clk,
    input wire i_rst,
    output wire[ 7:0 ] o_pmod
    );

reg r_dataSet = 1'b1;
reg[ 7:0 ] r_data = 8'b01010101;

wire w_CS;
wire w_SDIN;
wire w_SCLK;

assign o_pmod[ 0 ] = w_CS;
assign o_pmod[ 1 ] = w_SDIN;
assign o_pmod[ 2 ] = w_SCLK;

wire w_spiReady;

SpiDriver m_spiDriver(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_dataSetEn( r_dataSet ),
    .i_data( r_data ),
    .o_SCLK( w_SCLK ),
    .o_SDIN( w_SDIN ),
    .o_CS( w_CS ),
    .o_ready( w_spiReady )
);


endmodule
