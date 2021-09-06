`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/23/2021 07:16:21 PM
// Design Name: 
// Module Name: OledProject
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


module OledProject(
    input wire i_clk,
    input wire i_driverEn,
    input wire i_rst,
    output wire[ 7:0 ] o_pmod,
    output wire o_driverReady,
    output wire o_driverOff
);

reg r_dataEn = 0;
reg[ 7:0 ] r_data = 0;

wire w_rstInverted;
assign w_rstInverted = ~i_rst;

OledDriver m_oledDriver (
    .i_clk( i_clk ),
    .i_en( i_driverEn ),
    .i_rst( w_rstInverted ),
    .i_dataEn( r_dataEn ),
    .i_data( r_data ),
    .o_pmod( o_pmod ),
    .o_off( o_driverOff ),
    .o_ready( o_driverReady )
);




endmodule
