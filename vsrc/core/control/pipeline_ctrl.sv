// Module: pipeline_ctrl
// Description: Arbitrates redirects and exposes hold/flush decisions by instruction age.
module pipeline_ctrl (
    input  pipeline_pkg::redirect_t wb_redirect,
    input  pipeline_pkg::redirect_t ex_redirect,
    input  pipeline_pkg::redirect_t d1_redirect,
    input  logic                    ex_serialize,
    input  logic                    d1_serialize,
    input  logic                    mem_stall,
    input  logic                    data_stall,
    output pipeline_pkg::redirect_t redirect,
    output logic                    hold_front,
    output logic                    hold_d1_d2,
    output logic                    hold_d2_ex,
    output logic                    hold_ex_mem,
    output logic                    bubble_d2_ex,
    output logic                    flush_if_d1,
    output logic                    flush_d1_d2,
    output logic                    flush_d2_ex,
    output logic                    flush_ex_mem
);
    always_comb begin
        redirect = '0;
        hold_front = 1'b0;
        hold_d1_d2 = 1'b0;
        hold_d2_ex = 1'b0;
        hold_ex_mem = 1'b0;
        bubble_d2_ex = 1'b0;
        flush_if_d1 = 1'b0;
        flush_d1_d2 = 1'b0;
        flush_d2_ex = 1'b0;
        flush_ex_mem = 1'b0;

        if (wb_redirect.valid) begin
            redirect = wb_redirect;
            flush_if_d1 = 1'b1;
            flush_d1_d2 = 1'b1;
            flush_d2_ex = 1'b1;
            flush_ex_mem = 1'b1;
        end else begin
            if (ex_redirect.valid) begin
                redirect = ex_redirect;
                flush_if_d1 = 1'b1;
                flush_d1_d2 = 1'b1;
                flush_d2_ex = 1'b1;
            end else if (ex_serialize) begin
                flush_if_d1 = 1'b1;
                flush_d1_d2 = 1'b1;
                flush_d2_ex = 1'b1;
            end else if (d1_redirect.valid) begin
                redirect = d1_redirect;
                flush_if_d1 = 1'b1;
            end else if (d1_serialize) begin
                flush_if_d1 = 1'b1;
            end

            if (mem_stall) begin
                hold_front = 1'b1;
                hold_d1_d2 = 1'b1;
                hold_d2_ex = 1'b1;
                hold_ex_mem = 1'b1;
            end else if (data_stall) begin
                hold_front = 1'b1;
                hold_d1_d2 = 1'b1;
                bubble_d2_ex = 1'b1;
            end
        end
    end
endmodule
