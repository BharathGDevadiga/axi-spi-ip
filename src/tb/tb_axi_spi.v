`timescale 1ns / 1ps

module tb_axi_spi;

    reg aclk = 0;
    reg aresetn = 0;
    always #5 aclk = ~aclk; // 100MHz clock

    // AXI Bus Signals
    reg  [3:0]  s_axi_awaddr = 0;
    reg  [2:0]  s_axi_awprot = 0;
    reg         s_axi_awvalid = 0;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata = 0;
    reg  [3:0]  s_axi_wstrb = 4'hF;
    reg         s_axi_wvalid = 0;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready = 1;

    reg  [3:0]  s_axi_araddr = 0;
    reg  [2:0]  s_axi_arprot = 0;
    reg         s_axi_arvalid = 0;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready = 1;

    // Loopback
    wire spi_mosi;
    wire spi_sclk;
    wire spi_cs_n;
    wire spi_miso;
    assign spi_miso = spi_mosi; // Loopback: MOSI feeds MISO

    // DUT
    axi_spi_master_v1_0 uut (
        .spi_mosi(spi_mosi),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),
        .s00_axi_aclk(aclk),
        .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr(s_axi_awaddr),
        .s00_axi_awprot(s_axi_awprot),
        .s00_axi_awvalid(s_axi_awvalid),
        .s00_axi_awready(s_axi_awready),
        .s00_axi_wdata(s_axi_wdata),
        .s00_axi_wstrb(s_axi_wstrb),
        .s00_axi_wvalid(s_axi_wvalid),
        .s00_axi_wready(s_axi_wready),
        .s00_axi_bresp(s_axi_bresp),
        .s00_axi_bvalid(s_axi_bvalid),
        .s00_axi_bready(s_axi_bready),
        .s00_axi_araddr(s_axi_araddr),
        .s00_axi_arprot(s_axi_arprot),
        .s00_axi_arvalid(s_axi_arvalid),
        .s00_axi_arready(s_axi_arready),
        .s00_axi_rdata(s_axi_rdata),
        .s00_axi_rresp(s_axi_rresp),
        .s00_axi_rvalid(s_axi_rvalid),
        .s00_axi_rready(s_axi_rready)
    );

    // Watchdog Timer
    initial begin
        #50000;
        $display("\n[FAIL] Simulation Watchdog Timeout! Check handshakes.\n");
        $finish;
    end

    task axi_write(input [3:0] addr, input [31:0] data);
    begin
        @(posedge aclk);
        s_axi_awaddr <= addr; s_axi_awvalid <= 1;
        s_axi_wdata  <= data; s_axi_wvalid  <= 1;
        wait(s_axi_awready && s_axi_wready);
        @(posedge aclk);
        s_axi_awvalid <= 0; s_axi_wvalid <= 0;
        wait(s_axi_bvalid);
        @(posedge aclk);
    end
    endtask

    task axi_read(input [3:0] addr, output [31:0] data);
    begin
        @(posedge aclk);
        s_axi_araddr <= addr; s_axi_arvalid <= 1;
        wait(s_axi_arready);
        @(posedge aclk);
        s_axi_arvalid <= 0;
        wait(s_axi_rvalid);
        data = s_axi_rdata;
        @(posedge aclk);
    end
    endtask

    reg [31:0] read_val;

    initial begin
        #40 aresetn = 1;
        #20;

        $display("=== STARTING AXI SPI MASTER VERIFICATION ===");

        // Set Clock Divider = 2
        axi_write(4'hC, 32'd2);

        // --- TEST 1: SPI Loopback Transfer ---
        $display("[TEST 1] Transmitting 0xA5 over SPI loopback...");
        axi_write(4'h0, 32'h000000A5); // Write TX_DATA = 0xA5
        axi_write(4'h8, 32'h00000001); // Pulse start
        axi_write(4'h8, 32'h00000000); // Clear start

        // Poll BUSY (bit 1) until 0
        read_val = 32'h2;
        while (read_val[1] == 1'b1) begin
            axi_read(4'h8, read_val);
            #40;
        end

        // Read RX_DATA
        axi_read(4'h4, read_val);
        if (read_val[7:0] !== 8'hA5) begin
            $display("[FAIL] Loopback mismatch! Expected 0xA5, got 0x%02X", read_val[7:0]);
            $finish;
        end else begin
            $display("[INFO] Loopback verified: received 0xA5 correctly.");
        end

        // --- TEST 2: Read-Only Register Gating ---
        $display("[TEST 2] Verifying RX_DATA register cannot be overwritten by CPU...");
        axi_write(4'h4, 32'hFFFFFFFF); // Attempt to overwrite RX_DATA
        axi_read(4'h4, read_val);

        if (read_val[7:0] === 8'hA5) begin
            $display("[INFO] Read-only gating verified: write was properly ignored.");
            $display("\n[PASS] All AXI-SPI Master Tests Passed Successfully!\n");
        end else begin
            $display("[FAIL] Read-only bug: CPU overwrite corrupted RX_DATA to 0x%02X", read_val[7:0]);
        end

        $finish;
    end

endmodule
