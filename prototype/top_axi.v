`timescale 1ns / 1ps
module systolic_top_axis #
(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 48,
    parameter OUT_WIDTH  = 32,
    parameter N = 9,
    parameter M = 9
)
(
    input  wire clk,
    input  wire rst,

    // ===============================
    // AXI4-Stream SLAVE (DMA → IP)
    // ===============================
    input  wire [DATA_WIDTH*N-1:0] s_axis_tdata,
    input  wire                    s_axis_tvalid,
    output wire                    s_axis_tready,
    input  wire                    s_axis_tlast,

    // ===============================
    // AXI4-Stream MASTER (IP → DMA)
    // ===============================
    output reg  [OUT_WIDTH*N-1:0]  m_axis_tdata,
    output reg                     m_axis_tvalid,
    input  wire                    m_axis_tready,
    output reg                     m_axis_tlast,

    // ===============================
    // NORMAL BRAM PORT (UNCHANGED)
    // ===============================
    input  wire [DATA_WIDTH*M-1:0] bram_read,
    output wire [DATA_WIDTH*M-1:0] bram_write,
    output wire [9:0]              bram_addr,
    output wire [31:0]             bram_wr_en,
    output wire                    bram_en,

    input  wire [DATA_WIDTH*M-1:0] bias_read,
    output wire [DATA_WIDTH*M-1:0] bias_write,
    output wire [9:0]              bias_addr,
    output wire [31:0]             bias_wr_en,
    output wire                    bias_en
);

    // ============================================================
    // AXI INPUT HANDSHAKE
    // ============================================================

    assign s_axis_tready = 1'b1;   // always ready to accept pixel block

    wire start;
    assign start = s_axis_tvalid;  // trigger compute when valid arrives

    // ============================================================
    // INTERNAL SIGNALS
    // ============================================================

    wire [OUT_WIDTH*N-1:0] data_out;
    reg  output_valid;

    // ============================================================
    // CONTROL MODULE (UNCHANGED)
    // ============================================================

    control #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .OUT_WIDTH  (OUT_WIDTH),
        .N          (N),
        .M          (M)
    ) u_control (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .pixel      (s_axis_tdata),

        .bram_read  (bram_read),
        .bram_write (bram_write),
        .bram_addr  (bram_addr),
        .bram_wr_en (bram_wr_en),
        .bram_en    (bram_en),

        .bias_read  (bias_read),
        .bias_write (bias_write),
        .bias_addr  (bias_addr),
        .bias_wr_en (bias_wr_en),
        .bias_en    (bias_en),

        .data_out   (data_out)
    );

    // ============================================================
    // AXI OUTPUT HANDSHAKE (to DMA)
    // ============================================================

    always @(posedge clk) begin
        if (rst) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= 0;
            output_valid  <= 0;
        end
        else begin

            // When computation produces data
            if (start) begin
                output_valid <= 1'b1;
            end

            // Send data when valid
            if (output_valid) begin
                m_axis_tdata  <= data_out;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= 1'b1;  // single transfer per start
            end

            // Handshake complete
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
                m_axis_tlast  <= 0;
                output_valid  <= 0;
            end
        end
    end

endmodule