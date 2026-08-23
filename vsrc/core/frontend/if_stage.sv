// Module: if_stage
// Description: Issues ordered one-cycle fetches, tracks PC metadata, and absorbs redirects.
module if_stage (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              fetch_enable,
    input  logic                              out_ready,
    input  pipeline_pkg::redirect_t          redirect,
    input  pipeline_pkg::pred_info_t         prediction,
    output pipeline_pkg::if_d1_t             out_packet,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0] imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data
);
    import core_config_pkg::*;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    xlen_t pc_q;
    if_d1_t request_q;
    if_d1_t buffer_q;
    logic request_killed_q;
    if_d1_t response_packet;
    logic response_valid;
    logic request_fire;

    always_comb begin
        response_packet = request_q;
        response_packet.inst = imem_rsp_data;
        response_valid = request_q.valid && imem_rsp_valid && !request_killed_q;

        out_packet = buffer_q;
        if (!buffer_q.valid && response_valid)
            out_packet = response_packet;
        if (redirect.valid)
            out_packet.valid = 1'b0;

        imem_req_valid = fetch_enable && out_ready && !redirect.valid &&
                         (!request_q.valid || imem_rsp_valid);
        imem_req_addr = pc_q;
        request_fire = imem_req_valid && imem_req_ready;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pc_q <= RESET_VECTOR;
            request_q.valid <= 1'b0;
            request_killed_q <= 1'b0;
            buffer_q.valid <= 1'b0;
        end else if (redirect.valid) begin
            pc_q <= redirect.pc;
            buffer_q.valid <= 1'b0;
            if (request_q.valid && !imem_rsp_valid) begin
                request_killed_q <= 1'b1;
            end else begin
                request_q.valid <= 1'b0;
                request_killed_q <= 1'b0;
            end
        end else begin
            if (buffer_q.valid && out_ready)
                buffer_q.valid <= 1'b0;

            if (request_q.valid && imem_rsp_valid) begin
                request_q.valid <= 1'b0;
                request_killed_q <= 1'b0;
                if (!request_killed_q) begin
                    if (buffer_q.valid) begin
                        if (out_ready)
                            buffer_q <= response_packet;
                    end else if (!out_ready) begin
                        buffer_q <= response_packet;
                    end
                end
            end

            if (request_fire) begin
                request_q.valid <= 1'b1;
                request_q.pc <= pc_q;
                request_q.seq_pc <= pc_q + xlen_t'(4);
                request_q.inst <= '0;
                request_q.pred <= prediction;
                request_killed_q <= 1'b0;
                pc_q <= prediction.taken ? prediction.target : pc_q + xlen_t'(4);
            end
        end
    end
endmodule
