`timescale 1ns / 1ps

// 1 Main FSM.
// 3 nested FSMs:
//      - Initialise
//          - Initialise command
//      - Shutdown
module OledDriver(
    input wire i_clk,
    input wire i_en,
    input wire i_rst,
    input wire i_dataEn,
    input wire[ 7:0 ] i_data,
    output wire[ 7:0 ] o_pmod,
    output wire o_off,
    output wire o_ready
);

reg r_DATACONTROL = 1'b0;
reg r_GND = 1'b0;
reg r_RES = 1'b1;
reg r_VBATC = 1'b0; // AKA Vcc
reg r_VDDC = 1'b0;

reg r_RES_nxt = 1'b1;
reg r_VBATC_nxt = 1'b0;
reg r_VDDC_nxt = 1'b0;

wire w_SCLK;
wire w_SDIN;
wire w_CS;

wire w_bufferFull;

wire[ 7:0 ] w_driverData;
wire w_driverDataEn;

assign o_off = ( r_state == OFF );
assign o_ready = ( ( r_state == READY ) && !w_bufferFull );

assign o_pmod[ 0 ] = w_CS;
assign o_pmod[ 1 ] = w_SDIN;
assign o_pmod[ 2 ] = r_GND;
assign o_pmod[ 3 ] = w_SCLK;
assign o_pmod[ 4 ] = r_DATACONTROL;
assign o_pmod[ 5 ] = r_RES;
assign o_pmod[ 6 ] = r_VBATC;
assign o_pmod[ 7 ] = r_VDDC;

BufferedSpiDriver #( .BUFFER_SIZE( 32 ) ) m_bufferedSpiDriver(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_dataWrEn( w_driverDataEn ),
    .i_data( w_driverData ),
    .o_SCLK( w_SCLK ),
    .o_SDIN( w_SDIN ),
    .o_CS( w_CS ),
    .o_bufferFull( w_bufferFull )
);

// TIMER control
reg[ 31:0 ] r_timerCount = 0;
wire w_counterEn;
wire w_counterDone;

Counter m_counter(
    .i_clk( i_clk ),
    .i_rst( i_rst ),
    .i_count( r_timerCount ),
    .i_en( w_counterEn ),
    .o_done( w_counterDone )
);

localparam[ 2:0 ]
    OFF = 0,
    INITIALISE = 1,
    READY = 2,
    SHUTDOWN = 3,
    DELAY = 4;

// MAIN state
reg[ 2:0 ] r_state = OFF;
reg[ 2:0 ] r_state_nxt = OFF;
reg[ 2:0 ] r_postCounterState = OFF;
reg[ 2:0 ] r_postCounterState_nxt = OFF;

// Keep counter-enable high while in delay state
assign w_counterEn = ( r_state_nxt == DELAY );

// INITIALISE nested state
reg[ 3:0 ] r_initState = 0;
reg[ 3:0 ] r_initState_nxt = 0;
reg[ 4:0 ] r_initSequenceNumber = 0;
reg[ 4:0 ] r_initSequenceNumber_nxt = 0;
reg[ 7:0 ] r_initSequenceCommand = 0;

// Initialise state sets this when it has a command to send to the SPI driver
reg r_initialiseDataReady = 0;
reg r_initialiseDataReady_nxt = 0;

// Assignments for driving the data input to the SPI driver
assign w_driverDataEn = ( r_state == INITIALISE && r_initialiseDataReady ) || ( r_state == READY && i_dataEn );
assign w_driverData = ( r_state == INITIALISE ) ? r_initSequenceCommand : ( r_state == READY ) ? i_data : 0;

// Synchronous logic for OLED control outputs (not SPI)
always @( posedge i_clk )
begin
    r_VBATC <= r_VBATC_nxt;
    r_RES <= r_RES_nxt;
    r_VDDC <= r_VDDC_nxt;
end

localparam INIT_COMMANDS_DONE = 23;
// Initialise send-command nested state logic. No huge need to name the states.
always @( * )
begin
    if ( r_state == INITIALISE && r_initState == INIT_COMMANDS )
    begin
        case( r_initSequenceNumber )
            0: r_initSequenceCommand = 8'hAE; // Set display OFF
            1: r_initSequenceCommand = 8'hD5; // Set display clock divider & oscillator frequency
            2: r_initSequenceCommand = 8'h80; //    -> Osc = b1000, Div = b1
            3: r_initSequenceCommand = 8'hA8; // Set multiplex ratio
            4: r_initSequenceCommand = 8'h1F; //    -> b011111
            5: r_initSequenceCommand = 8'hD3; // Set display offset
            6: r_initSequenceCommand = 8'h00; //    -> b000000
            7: r_initSequenceCommand = 8'h40; // Set display start line (b000000)
            8: r_initSequenceCommand = 8'h8D; // Charge pump setting
            9: r_initSequenceCommand = 8'h14; //    -> Enable charge pump (internal VCC) 
            10: r_initSequenceCommand = 8'hA1; // Set segment re-map (col 127 mapped to SEG0)
            11: r_initSequenceCommand = 8'hC8; // Set COM output scan direction (remapped mode, scan from COM[N-1] to COM0)
            12: r_initSequenceCommand = 8'hDA; // Set COM pins h/w conf
            13: r_initSequenceCommand = 8'h02; //   -> Sequential COM, disable COM left/right remap
            14: r_initSequenceCommand = 8'h81; // Set contrast control
            15: r_initSequenceCommand = 8'h8F; //   -> Set to 0x8F
            16: r_initSequenceCommand = 8'hD9; // Set pre-charge period
            17: r_initSequenceCommand = 8'hF1; //   -> 15 phase 2, 1 phase 1
            18: r_initSequenceCommand = 8'hDB; // Set COMH deselect level
            19: r_initSequenceCommand = 8'h40; //   -> Value not documented, possibly ~ 1xVCC. 
            20: r_initSequenceCommand = 8'hA4; // ?? Oled doc says "Set Entire Display ON/OFF", chip doc says "Entire Display ON". Chip doc has other option at hex 0xAE/0xAF
            21: r_initSequenceCommand = 8'hA6; // Set normal (non-inverse) display
            22: r_initSequenceCommand = 8'hAF; // Set Display ON
        endcase
    end
end

// INITIALISE nested FSM states
localparam[ 3:0 ]
    INIT_WAIT0      = 0,    // Warmup
    INIT_VDDH       = 1,    // Pull Vdd high
    INIT_WAIT1      = 2,    // Wait for Vdd to come up
    INIT_RESET0     = 3,    // Begin reset
    INIT_WAIT2      = 4,    // Wait for reset
    INIT_RESET1     = 5,    // End reset
    INIT_COMMANDS   = 6,    // Send initialisation commands
    INIT_CLRSCR     = 7,    // Clear the screen
    INIT_VBATH      = 8,    // Pull up Vbat
    INIT_WAIT3      = 9,    // Wait for Vbat to stabilise
    INIT_DONE       = 10;   // Finish


// Next main FSM state logic
always @( * )
begin
    r_timerCount = 32'd0;
    r_initialiseDataReady_nxt = 1'b0;
    r_initSequenceNumber_nxt = r_initSequenceNumber;
    r_VDDC_nxt = ( r_initState >= INIT_VDDH || ( r_state == INITIALISE || r_postCounterState == INITIALISE ) );
    r_RES_nxt = !( r_initState >= INIT_RESET0 && r_initState <= INIT_RESET1 && ( r_state == INITIALISE || r_postCounterState == INITIALISE ) );
    r_initState_nxt = r_initState;

    r_VBATC_nxt = 1'b0;
    r_postCounterState_nxt = r_postCounterState;

    case ( r_state )
        OFF:
        begin
            if ( i_en )
            begin
                r_state_nxt = INITIALISE;
            end
            else
            begin
                r_state_nxt = OFF;
            end
        end

        INITIALISE:
        begin
            r_state_nxt = INITIALISE;
            case( r_initState )
                INIT_WAIT0:
                begin
                    r_timerCount = 32'd1250000;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_VDDH;
                end

                INIT_VDDH:
                begin
                    r_VDDC_nxt = 1;
                    r_initState_nxt = INIT_WAIT1;
                end

                INIT_WAIT1:
                begin
                    r_timerCount = 32'd1250000;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_RESET0;
                end

                INIT_RESET0:
                begin
                    r_RES_nxt = 0;
                    r_initState_nxt = INIT_WAIT2;
                end

                INIT_WAIT2:
                begin
                    r_timerCount = 32'd1250;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_RESET1;
                end

                INIT_RESET1:
                begin
                    r_RES_nxt = 1;
                    r_initState_nxt = INIT_COMMANDS;
                end

                INIT_COMMANDS:
                begin
                    // Nested state - wait for commands to complete
                    if ( r_initSequenceNumber == INIT_COMMANDS_DONE )
                    begin
                        r_initState_nxt = INIT_CLRSCR;
                    end
                    else
                    begin
                        // Handle the current command, stay in this state
                        r_initState_nxt = INIT_COMMANDS;
                        if ( r_initialiseDataReady )
                        begin
                            r_initialiseDataReady_nxt = 1'b0;
                            r_initSequenceNumber_nxt = r_initSequenceNumber + 1;
                        end
                        else
                        if ( !w_bufferFull )
                        begin
                            // Can send item
                            r_initialiseDataReady_nxt = 1'b1;
                        end
                    end
                end

                INIT_CLRSCR:
                begin
                    // TODO
                    r_initState_nxt = INIT_VBATH;
                end

                INIT_VBATH:
                begin
                    // TODO
                    r_VBATC_nxt = 1'b1;
                    r_initState_nxt = INIT_WAIT3;
                end

                INIT_WAIT3:
                begin
                    r_VBATC_nxt = 1'b1;
                    r_timerCount = 32'd12500000;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_DONE;
                end

                INIT_DONE:
                begin
                    r_VBATC_nxt = 1'b1;
                    r_initState_nxt = INIT_DONE;
                    r_state_nxt = READY;
                end

                default:
                begin
                    // Error state
                    r_initState_nxt = INIT_WAIT0;
                end
            endcase
        end

        READY:
        begin
            r_VBATC_nxt = 1'b1;
            r_state_nxt = READY;
        end

        SHUTDOWN:
        begin
            r_VBATC_nxt = 1'b1;
            r_state_nxt = SHUTDOWN;
        end

        DELAY:
        begin
            if ( r_postCounterState == INITIALISE && r_initState >= INIT_VBATH )
            begin
                r_VBATC_nxt = 1'b1;
            end

            if ( w_counterDone )
            begin
                r_state_nxt = r_postCounterState;
            end
            else
            begin
                r_state_nxt = DELAY;
            end

        end

        default:
        begin
            // Error
            r_state_nxt = OFF;
        end
    endcase
end

// Synchronous logic for main FSM
always @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        r_state <= OFF;
        r_initSequenceNumber <= 0;
        r_initState <= INIT_WAIT0;
        r_postCounterState <= OFF;
    end
    else
    begin
        r_state <= r_state_nxt;
        r_postCounterState <= r_postCounterState_nxt;

        if ( r_state == INITIALISE )
        begin
            r_initialiseDataReady <= r_initialiseDataReady_nxt;
            r_initSequenceNumber <= r_initSequenceNumber_nxt;
            r_initState <= r_initState_nxt;
        end
    end
end

endmodule
