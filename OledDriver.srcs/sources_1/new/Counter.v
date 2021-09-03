`timescale 1ns / 1ps

module Counter(
    input wire i_clk,
    input wire i_rst,
    input wire[ 31:0 ] i_count,
    input wire i_en,
    output wire o_done
    );

localparam
    IDLE = 0,
    COUNTING = 1;

reg[ 31:0 ] r_counter = 0;
reg[ 31:0 ] r_counter_nxt = 0;
reg r_state = IDLE;
reg r_state_nxt = IDLE;

assign o_done = ( r_state == IDLE );

always @( * )
begin
    case( r_state )
        IDLE:
        begin
            if ( i_en )
            begin
                r_state_nxt = COUNTING;
                r_counter_nxt = i_count;
            end
            else
            begin
                r_state_nxt = IDLE;
                r_counter_nxt = 0;
            end
        end

        COUNTING:
        begin
            if ( !i_en || r_counter == 0 )
            begin
                r_state_nxt = IDLE;
                r_counter_nxt = 0;
            end
            else
            begin
                r_counter_nxt = r_counter - 1;
                r_state_nxt = COUNTING;
            end
        end
    endcase
end

always @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        r_state <= IDLE;
        r_counter <= 0;
    end
    else
    begin
        r_state <= r_state_nxt;
        r_counter <= r_counter_nxt;
    end
end

endmodule