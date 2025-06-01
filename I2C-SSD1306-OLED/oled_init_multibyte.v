// Simple FSM for SSD1306 OLED Initialization using multi-byte I2C master - FIXED WIDTHS
// Sends [address][control][cmd]...[control][cmd]... all in one transaction
module oled_init_multibyte #(
    parameter I2C_ADDR = 8'h78 // 0x3C<<1 for write
) (
    input  wire clk,
    input  wire rst_n,
    output reg  start,        // Pulse high (1 clk) to begin transaction
    output reg  stop,         // Pulse high (1 clk) with last data_valid
    output reg  data_valid,   // Pulse high (1 clk) to send next byte
    output reg  [7:0] data_out,
    input  wire data_req,     // High when I2C master ready for next byte
    input  wire busy,         // High while I2C master is busy
    output reg  init_done
);
    // Command/data sequence: [address][control][cmd/arg]...
    reg [7:0] init_data [0:51];
    initial begin
        init_data[0]  = I2C_ADDR;     // Address byte FIRST
        init_data[1]  = 8'h00;        // Control byte (command mode)
        init_data[2]  = 8'hAE;        // Display OFF
        init_data[3]  = 8'h00; init_data[4]  = 8'hD5; init_data[5]  = 8'h80;
        init_data[6]  = 8'h00; init_data[7]  = 8'hA8; init_data[8]  = 8'h3F;
        init_data[9]  = 8'h00; init_data[10] = 8'hD3; init_data[11] = 8'h00;
        init_data[12] = 8'h00; init_data[13] = 8'h40;
        init_data[14] = 8'h00; init_data[15] = 8'h8D; init_data[16] = 8'h14;
        init_data[17] = 8'h00; init_data[18] = 8'h20; init_data[19] = 8'h00;
        init_data[20] = 8'h00; init_data[21] = 8'hA1;
        init_data[22] = 8'h00; init_data[23] = 8'hC8;
        init_data[24] = 8'h00; init_data[25] = 8'hDA; init_data[26] = 8'h12;
        init_data[27] = 8'h00; init_data[28] = 8'h81; init_data[29] = 8'hCF;
        init_data[30] = 8'h00; init_data[31] = 8'hD9; init_data[32] = 8'hF1;
        init_data[33] = 8'h00; init_data[34] = 8'hDB; init_data[35] = 8'h40;
        init_data[36] = 8'h00; init_data[37] = 8'hA4;
        init_data[38] = 8'h00; init_data[39] = 8'hA6;
        init_data[40] = 8'h00; init_data[41] = 8'h2E;
        init_data[42] = 8'h00; init_data[43] = 8'h00;
        init_data[44] = 8'h00; init_data[45] = 8'h10;
        init_data[46] = 8'h00; init_data[47] = 8'hB0;
        init_data[48] = 8'h00; init_data[49] = 8'hAF;
        init_data[50] = 8'hA5; // Entire Display ON
        init_data[51] = 8'h00;
    end

    reg [7:0] idx;
    reg fsm_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 8'd0;
            start <= 0;
            stop <= 0;
            data_valid <= 0;
            data_out <= 8'h00;
            fsm_active <= 0;
            init_done <= 0;
        end else begin
            if (!fsm_active && !init_done) begin
                if (!busy) begin
                    idx <= 8'd0;
                    fsm_active <= 1;
                    start <= 1; // Pulse to begin
                end
            end else if (fsm_active) begin
                start <= 0;
                if (data_req) begin
                    data_out <= init_data[idx];
                    data_valid <= 1;
                    // Stop on last byte
                    if (idx == 8'd51) stop <= 1;
                end
                if (data_valid) begin
                    data_valid <= 0;
                    stop <= 0;
                    idx <= idx + 8'd1;
                    if (idx == 8'd51) begin
                        fsm_active <= 0;
                        init_done <= 1;
                    end
                end
            end
        end
    end
endmodule
