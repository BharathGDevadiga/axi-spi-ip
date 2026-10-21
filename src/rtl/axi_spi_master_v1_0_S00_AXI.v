`timescale 1 ns / 1 ps

module axi_spi_master_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    // External SPI Ports
    output wire spi_mosi,
    output wire spi_sclk,
    output wire spi_cs_n,
    input  wire spi_miso,

    // AXI4-Lite Clock & Reset
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,

    // AXI4-Lite Write Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,

    // AXI4-Lite Write Data Channel
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,

    // AXI4-Lite Write Response Channel
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,

    // AXI4-Lite Read Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,

    // AXI4-Lite Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY
);

    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg  axi_awready;
    reg  axi_wready;
    reg [1 : 0] axi_bresp;
    reg  axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg  axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
    reg [1 : 0] axi_rresp;
    reg  axi_rvalid;

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 1;

    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // TX_DATA
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2; // CTRL (Start)
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3; // CLK_DIV
    wire slv_reg_rden;
    wire slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    integer byte_index;
    reg aw_en;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // AXI Handshakes
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) axi_awaddr <= 0;
        else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            axi_awaddr <= S_AXI_AWADDR;
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) axi_wready <= 1'b0;
        else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en)
            axi_wready <= 1'b1;
        else axi_wready <= 1'b0;
    end

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    // Register Write Logic with Read-Only Protection on slv_reg1
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            slv_reg0 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;
        end else if (slv_reg_wren) begin
            case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
                2'h0: for ( byte_index = 0; byte_index <= 3; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                2'h1: begin
                    // READ-ONLY: Ignore software writes to RX_DATA
                end
                2'h2: for ( byte_index = 0; byte_index <= 3; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                2'h3: for ( byte_index = 0; byte_index <= 3; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                default: ;
            endcase
        end
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b0;
        end else if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
            axi_bvalid <= 1'b1;
            axi_bresp <= 2'b0;
        end else if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_arready <= 1'b0;
            axi_araddr <= 32'b0;
        end else if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr <= S_AXI_ARADDR;
        end else axi_arready <= 1'b0;
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rvalid <= 0;
            axi_rresp <= 0;
        end else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp <= 2'b0;
        end else if (axi_rvalid && S_AXI_RREADY) axi_rvalid <= 1'b0;
    end

    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

    // Read Multiplexer: Drives live hardware RX_DATA and BUSY flag
    always @(*) begin
        case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            2'h0   : reg_data_out = slv_reg0;
            2'h1   : reg_data_out = {24'h0, spi_rx_data_wire};
            2'h2   : reg_data_out = {slv_reg2[31:2], spi_busy_wire, slv_reg2[0]};
            2'h3   : reg_data_out = slv_reg3;
            default: reg_data_out = 0;
        endcase
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) axi_rdata <= 0;
        else if (slv_reg_rden) axi_rdata <= reg_data_out;
    end

    // --- User SPI Logic & Edge Detector ---
    wire [7:0] spi_rx_data_wire;
    wire       spi_busy_wire;
    reg        start_d;
    reg        start_pulse;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            start_d     <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_d     <= slv_reg2[0];
            start_pulse <= slv_reg2[0] & ~start_d & ~spi_busy_wire;
        end
    end

    spi_master u_spi (
        .clk     (S_AXI_ACLK),
        .rst_n   (S_AXI_ARESETN),
        .start   (start_pulse),
        .tx_data (slv_reg0[7:0]),
        .clk_div (slv_reg3[15:0]),
        .miso    (spi_miso),
        .mosi    (spi_mosi),
        .sclk    (spi_sclk),
        .cs_n    (spi_cs_n),
        .rx_data (spi_rx_data_wire),
        .busy    (spi_busy_wire)
    );

endmodule
