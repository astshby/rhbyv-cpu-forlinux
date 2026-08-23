// Module: trap_controller
// Description: Converts a faulting or MRET commit into the oldest redirect event.
module trap_controller (
    input  pipeline_pkg::mem_wb_t      commit_packet,
    input  core_types_pkg::xlen_t     mtvec,
    input  core_types_pkg::xlen_t     mepc,
    output logic                       trap_enter,
    output logic                       mret_commit,
    output core_types_pkg::xlen_t     trap_pc,
    output pipeline_pkg::exc_cause_e  trap_cause,
    output core_types_pkg::xlen_t     trap_tval,
    output logic                       retire_valid,
    output pipeline_pkg::redirect_t   redirect
);
    import pipeline_pkg::*;

    always_comb begin
        trap_enter = commit_packet.valid && commit_packet.exc.valid;
        mret_commit = commit_packet.valid && !commit_packet.exc.valid &&
                      commit_packet.uop.is_mret;
        trap_pc = commit_packet.pc;
        trap_cause = commit_packet.exc.cause;
        trap_tval = commit_packet.exc.tval;
        retire_valid = commit_packet.valid && !commit_packet.exc.valid;
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
