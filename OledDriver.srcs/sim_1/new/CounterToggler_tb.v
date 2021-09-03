`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/23/2021 09:54:35 PM
// Design Name: 
// Module Name: CounterToggler_tb
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


module CounterToggler_tb;

wire w_level;
reg r_clk = 0;

CounterToggler m_toggler (
    .i_clk( r_clk ),
    .o_level( w_level )
);

initial
begin
    #1;
    forever begin
        #8
        r_clk = ~r_clk;
    end
end


endmodule
