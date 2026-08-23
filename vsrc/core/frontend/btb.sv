// Module: btb
// Description: Direct-mapped target table with synchronous update and explicit lookup bypass.
module btb (
    input  logic                              clk,
    input  logic                              rst,
    input  core_types_pkg::xlen_t            lookup_pc,
    output logic                              lookup_hit,
    output core_types_pkg::xlen_t            lookup_target,
    output core_types_pkg::branch_op_e       lookup_kind,
    output logic [core_config_pkg::BTB_IDX_W-1:0] lookup_idx,
    input  logic                              update_valid,
    input  core_types_pkg::xlen_t            update_pc,
    input  core_types_pkg::xlen_t            update_target,
    input  core_types_pkg::branch_op_e       update_kind
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    logic valid_q [0:BTB_ENTRIES-1];
    xlen_t tag_q [0:BTB_ENTRIES-1];
    xlen_t target_q [0:BTB_ENTRIES-1];
    branch_op_e kind_q [0:BTB_ENTRIES-1];
    logic [BTB_IDX_W-1:0] update_idx;
    integer entry;

    always_comb begin
        lookup_idx = lookup_pc[2 +: BTB_IDX_W];
        update_idx = update_pc[2 +: BTB_IDX_W];
        lookup_hit = valid_q[lookup_idx] && (tag_q[lookup_idx] == lookup_pc);
        lookup_target = target_q[lookup_idx];
        lookup_kind = kind_q[lookup_idx];

        if (update_valid && (update_idx == lookup_idx)) begin
            lookup_hit = (update_pc == lookup_pc);
            lookup_target = update_target;
            lookup_kind = update_kind;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (entry = 0; entry < BTB_ENTRIES; entry = entry + 1)
                valid_q[entry] <= 1'b0;
        end else if (update_valid) begin
            valid_q[update_idx] <= 1'b1;
            tag_q[update_idx] <= update_pc;
            target_q[update_idx] <= update_target;
            kind_q[update_idx] <= update_kind;
        end
    end
endmodule
