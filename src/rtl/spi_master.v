`timescale 1ns / 1ps

module spi_master (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,          // 1-cycle pulse to trigger
    input  wire [7:0]  tx_data,        // Byte to send
    input  wire [15:0] clk_div,        // SCLK divider (e.g. 2 for sim)
    input  wire        miso,           // Master In Slave Out
    output reg         mosi,           // Master Out Slave In
    output reg         sclk,           // SPI Clock
    output reg         cs_n,           // Active-low Chip Select
    output reg  [7:0]  rx_data,        // Byte received
    output reg         busy            // 1 when transfer is active
);

    localparam IDLE     = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  tx_shifter;
    reg [7:0]  rx_shifter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            sclk       <= 1'b0;
            cs_n       <= 1'b1;
            mosi       <= 1'b0;
            busy       <= 1'b0;
            clk_cnt    <= 16'd0;
            bit_cnt    <= 3'd7;
            rx_data    <= 8'd0;
            tx_shifter <= 8'd0;
            rx_shifter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    sclk    <= 1'b0;
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    clk_cnt <= 16'd0;
                    if (start) begin
                        busy       <= 1'b1;
                        cs_n       <= 1'b0;
                        tx_shifter <= tx_data;
                        bit_cnt    <= 3'd7;
                        mosi       <= tx_data[7]; // MSB first
                        state      <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (clk_cnt < clk_div) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 16'd0;
                        sclk    <= ~sclk;

                        if (sclk == 1'b0) begin
                            // Rising edge: Sample MISO
                            rx_shifter <= {rx_shifter[6:0], miso};
                        end else begin
                            // Falling edge: Shift next bit out to MOSI
                            if (bit_cnt == 0) begin
                                state <= DONE;
                            end else begin
                                bit_cnt    <= bit_cnt - 1;
                                tx_shifter <= {tx_shifter[6:0], 1'b0};
                                mosi       <= tx_shifter[6];
                            end
                        end
                    end
                end

                DONE: begin
                    sclk    <= 1'b0;
                    cs_n    <= 1'b1;
                    rx_data <= rx_shifter;
                    busy    <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
