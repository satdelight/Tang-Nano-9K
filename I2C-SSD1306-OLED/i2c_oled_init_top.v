// Top-level for SSD1306 OLED init via I2C (Tang Nano 9K/Tang Nano)
// Ports match standard CST filenames: scl, sda, oled_init_done_n

module i2c_oled_init_top (
    input  wire clk,
    input  wire rst_n,
    output wire scl,
    inout  wire sda,
    output wire oled_init_done_n
);
    wire fsm_init_done;
    assign oled_init_done_n = ~fsm_init_done; // active low output

    wire start, stop, data_valid, data_req, busy;
    wire [7:0] data_out;

    oled_init_multibyte oled_fsm (
        .clk(clk), .rst_n(rst_n),
        .start(start), .stop(stop),
        .data_valid(data_valid), .data_out(data_out),
        .data_req(data_req), .busy(busy),
        .init_done(fsm_init_done)
    );

    i2c_master_multibyte #(
        .CLK_FREQ(27_000_000), // adjust as needed
        .I2C_FREQ(100_000)     // adjust as needed
    ) i2c (
        .clk(clk), .rst_n(rst_n),
        .start(start), .stop(stop),
        .data_valid(data_valid), .data_in(data_out),
        .data_req(data_req), .busy(busy),
        .scl(scl), .sda(sda)
    );
endmodule
