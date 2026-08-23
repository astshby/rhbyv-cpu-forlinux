// Module: sim_test_device
// Description: Simulation-only MMIO sink for PASS/FAIL termination writes.
module sim_test_device (
    input  logic                           clk,
    input  logic                           rst,
    input  logic                           req_valid,
    input  logic                           req_write,
    input  core_types_pkg::xlen_t         req_wdata,
    output logic                           req_ready,
    output logic                           rsp_valid,
    output core_types_pkg::xlen_t         rsp_rdata,
    output logic                           test_done,
    output logic                           test_pass,
    output logic [31:0]                    test_code
);
    assign req_ready = 1'b1;
    assign rsp_rdata = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
            test_done <= 1'b0;
            test_pass <= 1'b0;
            test_code <= '0;
        end else begin
            rsp_valid <= req_valid && !req_write;
            if (req_valid && req_write) begin
                test_done <= 1'b1;
                test_pass <= (req_wdata == core_types_pkg::xlen_t'(1));
                test_code <= req_wdata[31:0];
            end
        end
    end
endmodule
