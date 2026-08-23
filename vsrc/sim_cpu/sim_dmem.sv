// Module: sim_dmem
// Description: Non-synthesizable one-cycle byte-write data memory model.
module sim_dmem #(
    parameter int unsigned DEPTH_WORDS = 4096
) (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              req_valid,
    input  logic                              req_write,
    input  logic [core_config_pkg::XLEN-1:0] req_addr,
    input  logic [core_config_pkg::XLEN-1:0] req_wdata,
    input  logic [core_config_pkg::DBUS_BYTES-1:0] req_wstrb,
    output logic                              req_ready,
    output logic                              rsp_valid,
    output logic [core_config_pkg::XLEN-1:0] rsp_rdata
);
    import core_config_pkg::*;
    logic [XLEN-1:0] mem [0:DEPTH_WORDS-1];
    integer byte_idx;

    assign req_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
        end else begin
            rsp_valid <= req_valid && req_ready && !req_write;
            if (req_valid && req_ready) begin
                if (req_write) begin
                    for (byte_idx = 0; byte_idx < DBUS_BYTES; byte_idx = byte_idx + 1) begin
                        if (req_wstrb[byte_idx])
                            mem[req_addr[$clog2(DBUS_BYTES) +: $clog2(DEPTH_WORDS)]][8*byte_idx +: 8]
                                <= req_wdata[8*byte_idx +: 8];
                    end
                end else begin
                    rsp_rdata <= mem[req_addr[$clog2(DBUS_BYTES) +: $clog2(DEPTH_WORDS)]];
                end
            end
        end
    end
endmodule
