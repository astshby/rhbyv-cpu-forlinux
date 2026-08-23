// Module: sim_imem
// Description: Non-synthesizable one-cycle instruction memory model.
module sim_imem #(
    parameter int unsigned DEPTH_WORDS = 4096
) (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              req_valid,
    input  logic [core_config_pkg::XLEN-1:0] req_addr,
    output logic                              req_ready,
    output logic                              rsp_valid,
    output logic [31:0]                       rsp_data
);
    logic [31:0] mem [0:DEPTH_WORDS-1];

    assign req_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
        end else begin
            rsp_valid <= req_valid && req_ready;
            if (req_valid && req_ready)
                rsp_data <= mem[req_addr[2 +: $clog2(DEPTH_WORDS)]];
        end
    end
endmodule
