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
reg r_DATACONTROL_nxt = 1'b0;

wire w_SCLK;
wire w_SDIN;
wire w_CS;

wire w_bufferFull;
wire w_spiIdle;

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
    .o_bufferFull( w_bufferFull ),
    .o_spiIdle( w_spiIdle )
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
    DELAY = 4,
    WAIT_FOR_SPI_IDLE = 5;

// Screen buffer
(* rom_style = "distributed" *) reg[ 7:0 ] r_screenBuffer[ 511:0 ];

initial
begin
    $readmemb( "bitmap.mem", r_screenBuffer, 0, 511 );
end

//(* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem[0:2**ADDR_WIDTH-1];

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
reg[ 8:0 ] r_clrscrCount = 0;
reg[ 8:0 ] r_clrscrCount_nxt = 0;

// SHUTDOWN nested state
reg[ 1:0 ] r_shutdownState = 0;
reg[ 1:0 ] r_shutdownState_nxt = 0;

// Registers for sending data to SPI
reg[ 7:0 ] r_internalCommand = 0;
reg r_internalDataReady = 0;
reg r_internalDataReady_nxt = 0;

// Assignments for driving the data input to the SPI driver
assign w_driverDataEn = ( ( r_state == INITIALISE || r_state == SHUTDOWN ) && r_internalDataReady_nxt ) || ( r_state == READY && i_dataEn );
assign w_driverData = ( r_state == INITIALISE || r_state == SHUTDOWN ) ? r_internalCommand : ( r_state == READY ) ? i_data : 0;

// Synchronous logic for OLED control outputs (not SPI)
always @( posedge i_clk )
begin
    r_VBATC <= r_VBATC_nxt;
    r_RES <= r_RES_nxt;
    r_VDDC <= r_VDDC_nxt;
    r_DATACONTROL <= r_DATACONTROL_nxt;
end

localparam INIT_COMMANDS_DONE = 25;
// Initialise send-command nested state logic. No huge need to name the states.
always @( * )
begin
    r_internalCommand = 0;
    if ( r_state == INITIALISE )
    begin
        if ( r_initState == INIT_COMMANDS )
        begin
            case( r_initSequenceNumber )
                0: r_internalCommand = 8'hAE; // Set display OFF
                1: r_internalCommand = 8'hD5; // Set display clock divider & oscillator frequency
                2: r_internalCommand = 8'h80; //    -> Osc = b1000, Div = b1
                3: r_internalCommand = 8'hA8; // Set multiplex ratio
                4: r_internalCommand = 8'h1F; //    -> b011111
                5: r_internalCommand = 8'hD3; // Set display offset
                6: r_internalCommand = 8'h00; //    -> b000000
                7: r_internalCommand = 8'h40; // Set display start line (b000000)
                8: r_internalCommand = 8'h8D; // Charge pump setting
                9: r_internalCommand = 8'h14; //    -> Enable charge pump (internal VCC) 
                10: r_internalCommand = 8'hA1; // Set segment re-map (col 127 mapped to SEG0)
                11: r_internalCommand = 8'hC8; // Set COM output scan direction (remapped mode, scan from COM[N-1] to COM0)
                12: r_internalCommand = 8'hDA; // Set COM pins h/w conf
                13: r_internalCommand = 8'h02; //   -> Sequential COM, disable COM left/right remap
                14: r_internalCommand = 8'h81; // Set contrast control
                15: r_internalCommand = 8'h8F; //   -> Set to 0x8F
                16: r_internalCommand = 8'hD9; // Set pre-charge period
                17: r_internalCommand = 8'hF1; //   -> 15 phase 2, 1 phase 1
                18: r_internalCommand = 8'hDB; // Set COMH deselect level
                19: r_internalCommand = 8'h40; //   -> Value not documented, possibly ~ 1xVCC. 
                20: r_internalCommand = 8'hA4; // ?? Oled doc says "Set Entire Display ON/OFF", chip doc says "Entire Display ON". Chip doc has other option at hex 0xAE/0xAF
                21: r_internalCommand = 8'hA6; // Set normal (non-inverse) display
                22: r_internalCommand = 8'h20; // Set addressing mode
                23: r_internalCommand = 8'h00; //   -> Horizontal mode
                24: r_internalCommand = 8'hAF; // Set Display ON
            endcase
        end
        else if ( r_initState == INIT_CLRSCR )
        begin
            r_internalCommand = r_screenBuffer[ r_clrscrCount/*[ 8:0 ]*/ ];
        end
    end
    else if ( r_state == SHUTDOWN )
    begin
        r_internalCommand = 8'hAE;
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

// SHUTDOWN nested FSM states
localparam[ 1:0 ]
    SHUTDOWN_COMMAND    = 0,
    SHUTDOWN_VCCL       = 1,
    SHUTDOWN_WAIT0      = 2,
    SHUTDOWN_VDDL       = 3;

// Output logic
always @( * )
begin
    r_VBATC_nxt = 1'b0;
    r_VDDC_nxt = 1'b0;
    r_RES_nxt = 1'b1;
    r_DATACONTROL_nxt = 1'b0;

    if ( ( ( r_state_nxt == INITIALISE || r_postCounterState == INITIALISE ) && r_initState >= INIT_VDDH )
        || ( r_state_nxt == READY )
        || ( ( r_state_nxt == INITIALISE || r_postCounterState == INITIALISE ) && r_shutdownState_nxt < SHUTDOWN_VDDL ) )
    begin
        r_VDDC_nxt = 1'b1;
    end

    if ( ( ( r_state_nxt == INITIALISE || r_postCounterState == INITIALISE ) && r_initState >= INIT_VBATH )
        || ( r_state_nxt == READY )
        || ( ( r_state_nxt == INITIALISE || r_postCounterState == INITIALISE ) && r_shutdownState_nxt < SHUTDOWN_VCCL ) )
    begin
        r_VBATC_nxt = 1'b1;
    end

    if ( ( r_state_nxt == INITIALISE || r_postCounterState == INITIALISE ) && r_initState >= INIT_RESET0 && r_initState <= INIT_RESET1 )
    begin
        r_RES_nxt = 1'b0;
    end

    if ( r_state_nxt == INITIALISE && r_initState_nxt == INIT_CLRSCR )
    begin
        r_DATACONTROL_nxt = 1'b1;
    end
end

// Next main FSM state logic
always @( * )
begin
    r_timerCount = 32'd0;
    r_internalDataReady_nxt = 1'b0;
    r_initSequenceNumber_nxt = r_initSequenceNumber;
    r_initState_nxt = r_initState;
    r_postCounterState_nxt = r_postCounterState;

    r_state_nxt = r_state;
    r_shutdownState_nxt = r_shutdownState;
    r_clrscrCount_nxt = 0;

    case ( r_state )
        OFF:
        begin
            if ( i_en )
            begin
                r_state_nxt = INITIALISE;
                r_initSequenceNumber_nxt = 0;
                r_initState_nxt = INIT_WAIT0;
                r_postCounterState_nxt = OFF;
                r_shutdownState_nxt = SHUTDOWN_COMMAND;
                r_internalDataReady_nxt = 1'b0;
                r_clrscrCount_nxt = 0;
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
                    //r_timerCount = 32'd1250;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_VDDH;
                end

                INIT_VDDH:
                begin
                    r_initState_nxt = INIT_WAIT1;
                end

                INIT_WAIT1:
                begin
                    r_timerCount = 32'd1250000;
                    //r_timerCount = 32'd1250;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_RESET0;
                end

                INIT_RESET0:
                begin
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
                    r_initState_nxt = INIT_COMMANDS;
                end

                INIT_COMMANDS:
                begin
                    // Nested state - wait for commands to complete
                    if ( r_initSequenceNumber == INIT_COMMANDS_DONE )
                    begin
                        r_initState_nxt = w_spiIdle ? INIT_CLRSCR : INIT_COMMANDS;
                    end
                    else
                    begin
                        // Handle the current command, stay in this state
                        r_initState_nxt = INIT_COMMANDS;
                        if ( !w_bufferFull )
                        begin
                            // Can send item
                            r_internalDataReady_nxt = 1'b1;
                            r_initSequenceNumber_nxt = r_initSequenceNumber + 1;
                        end
                        else
                        begin
                            r_internalDataReady_nxt = 1'b0;
                        end
                    end
                end

                INIT_CLRSCR:
                begin
                    if ( r_clrscrCount == 511 )
                    begin
                        r_initState_nxt = INIT_VBATH;
                    end
                    else
                    begin
                        r_initState_nxt = INIT_CLRSCR;
                        if ( !w_bufferFull )
                        begin
                            r_internalDataReady_nxt = 1'b1;
                            r_clrscrCount_nxt = r_clrscrCount + 1;
                        end
                        else
                        begin
                            r_clrscrCount_nxt = r_clrscrCount;
                            r_internalDataReady_nxt = 1'b0;
                        end
                    end
                    
                end

                INIT_VBATH:
                begin
                    r_initState_nxt = INIT_WAIT3;
                end

                INIT_WAIT3:
                begin
                    r_timerCount = 32'd12500000;
                    //r_timerCount = 32'd1250;
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = INITIALISE;
                    r_initState_nxt = INIT_DONE;
                end

                INIT_DONE:
                begin
                    r_initState_nxt = INIT_WAIT0;
                    r_postCounterState_nxt = READY;
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
            r_state_nxt = i_en ? READY : SHUTDOWN;
        end

        SHUTDOWN:
        begin
            case ( r_shutdownState )
                SHUTDOWN_COMMAND:
                begin
                    r_internalDataReady_nxt = 1'b1;
                    r_postCounterState_nxt = SHUTDOWN;
                    r_shutdownState_nxt = SHUTDOWN_VCCL;
                    r_state_nxt = WAIT_FOR_SPI_IDLE;
                end

                SHUTDOWN_VCCL:
                begin
                    r_shutdownState_nxt = SHUTDOWN_WAIT0;
                end

                SHUTDOWN_WAIT0:
                begin
                    r_timerCount = 32'd12500000; //100ms
                    r_state_nxt = DELAY;
                    r_postCounterState_nxt = SHUTDOWN;
                    r_shutdownState_nxt = SHUTDOWN_VDDL;
                end

                SHUTDOWN_VDDL:
                begin
                    r_shutdownState_nxt = SHUTDOWN_COMMAND;
                    r_state_nxt = OFF;
                end
            endcase
        end

        DELAY:
        begin
            r_state_nxt = w_counterDone ? r_postCounterState : DELAY;
        end

        WAIT_FOR_SPI_IDLE:
        begin
            r_state_nxt = w_spiIdle ? r_postCounterState : WAIT_FOR_SPI_IDLE;
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
        r_clrscrCount <= 0;
        r_postCounterState <= OFF;
        r_shutdownState <= SHUTDOWN_COMMAND;
        r_internalDataReady <= 1'b0;
    end
    else
    begin
        r_state <= r_state_nxt;
        r_postCounterState <= r_postCounterState_nxt;
        r_internalDataReady <= r_internalDataReady_nxt;
        r_initSequenceNumber <= r_initSequenceNumber_nxt;
        r_initState <= r_initState_nxt;
        r_clrscrCount <= r_clrscrCount_nxt;
        r_shutdownState <= r_shutdownState_nxt;
    end
end

endmodule
