// Simple Multi-Byte I2C Master (write-only)
// Usage: Load data_in, pulse data_valid for each byte, including address as first byte.
// Assert start at the beginning, stop with data_valid on the last byte.
// data_req pulses high when ready for next byte.
// busy is high until STOP is done.

module i2c_master_multibyte #(
    parameter CLK_FREQ = 27_000_000,
    parameter I2C_FREQ = 100_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,         // Pulse high (1 clk) to begin transaction (before first byte)
    input  wire stop,          // Pulse high (1 clk) with data_valid on last byte
    input  wire data_valid,    // Pulse high (1 clk) to load data_in
    input  wire [7:0] data_in, // Byte to send (address, control, cmd, ...)
    output reg  data_req,      // High when ready for next byte
    output reg  busy,          // High while transaction is running
    output reg  scl,
    inout  wire sda
);
    localparam integer DIVIDER = (CLK_FREQ / (I2C_FREQ * 2));

    reg [15:0] clk_cnt;
    reg [3:0] state;
    reg [7:0] shifter;
    reg [3:0] bit_cnt;
    reg sda_out, sda_oe;
    wire sda_in = sda;

    reg last_byte; // Signals STOP should follow this byte

    localparam
        IDLE    = 4'd0,
        START   = 4'd1,
        LOAD    = 4'd2,
        SEND0   = 4'd3,
        SEND1   = 4'd4,
        ACK0    = 4'd5,
        ACK1    = 4'd6,
        STOP0   = 4'd7,
        STOP1   = 4'd8,
        DONE    = 4'd9;

    assign sda = sda_oe ? sda_out : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl <= 1;
            sda_out <= 1;
            sda_oe <= 1;
            busy <= 0;
            bit_cnt <= 0;
            data_req <= 0;
            state <= IDLE;
            clk_cnt <= 16'd0;
            last_byte <= 0;
        end else begin
            case (state)
                IDLE: begin
                    scl <= 1;
                    sda_out <= 1;
                    sda_oe <= 1;
                    busy <= 0;
                    clk_cnt <= 16'd0;
                    data_req <= 0;
                    last_byte <= 0;
                    if (start) begin
                        busy <= 1;
                        state <= START;
                    end
                end
                START: begin
                    // SDA goes low while SCL high (START condition)
                    sda_out <= 0; sda_oe <= 1; scl <= 1;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        scl <= 0;
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    // Ask for next byte
                    data_req <= 1;
                    if (data_valid) begin
                        shifter <= data_in;
                        bit_cnt <= 4'd7;
                        last_byte <= stop;
                        data_req <= 0;
                        state <= SEND0;
                    end
                end
                SEND0: begin
                    // Place bit, keep SCL low
                    sda_out <= shifter[bit_cnt]; sda_oe <= 1; scl <= 0;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        scl <= 1;
                        state <= SEND1;
                    end
                end
                SEND1: begin
                    // SCL high (sample bit)
                    sda_out <= shifter[bit_cnt]; sda_oe <= 1; scl <= 1;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        if (bit_cnt == 0)
                            state <= ACK0;
                        else begin
                            bit_cnt <= bit_cnt - 4'd1;
                            scl <= 0;
                            state <= SEND0;
                        end
                    end
                end
                ACK0: begin
                    // Release SDA (tristate) for ACK, keep SCL low
                    sda_oe <= 0; scl <= 0;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        scl <= 1;
                        state <= ACK1;
                    end
                end
                ACK1: begin
                    // SCL high (slave drives SDA for ACK)
                    sda_oe <= 0; scl <= 1;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        if (last_byte)
                            state <= STOP0;
                        else begin
                            scl <= 0;
                            sda_oe <= 1;
                            state <= LOAD;
                        end
                    end
                end
                STOP0: begin
                    // SDA low, SCL low
                    sda_out <= 0; sda_oe <= 1; scl <= 0;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        scl <= 1;
                        state <= STOP1;
                    end
                end
                STOP1: begin
                    // SDA high, SCL high (STOP condition)
                    sda_out <= 1; sda_oe <= 1; scl <= 1;
                    clk_cnt <= (clk_cnt + 16'd1);
                    if (clk_cnt == DIVIDER-1) begin
                        clk_cnt <= 16'd0;
                        state <= DONE;
                    end
                end
                DONE: begin
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
