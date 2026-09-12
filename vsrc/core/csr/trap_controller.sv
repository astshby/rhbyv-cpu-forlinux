// Module: trap_controller
// Description: Converts a faulting or MRET commit into the oldest redirect event.
module trap_controller (
    input  pipeline_pkg::mem_wb_t      commit_packet,
    input  logic                       commit_valid,
    input  core_types_pkg::xlen_t     mtvec,
    input  core_types_pkg::xlen_t     mepc,
    output logic                       trap_enter,
    output logic                       mret_commit,
    output core_types_pkg::xlen_t     trap_pc,
    output riscv_priv_pkg::exc_cause_e trap_cause,
    output core_types_pkg::xlen_t     trap_tval,
    output logic                       retire_valid,
    output pipeline_pkg::redirect_t   redirect
);
    import pipeline_pkg::*;
    import core_types_pkg::*;

    // 只有 WB 包及其存储器响应都完整时才允许退休、进入 trap 或执行 MRET。
    always_comb begin
        trap_enter = commit_valid && commit_packet.exc.valid;
        mret_commit = commit_valid && !commit_packet.exc.valid &&
                      (commit_packet.uop.sys_op == SYS_MRET);
        trap_pc = commit_packet.pc;
        trap_cause = commit_packet.exc.cause;
        trap_tval = commit_packet.exc.tval;
        retire_valid = commit_valid && !commit_packet.exc.valid;
        redirect = '0;
        if (trap_enter) begin
            redirect.valid = 1'b1;
            redirect.pc = mtvec;
            redirect.reason = REDIR_TRAP;
        end else if (mret_commit) begin
            redirect.valid = 1'b1;
            redirect.pc = mepc;
            redirect.reason = REDIR_MRET;
        end
    end
endmodule
