// Module: wb_stage
// Description: Produces architectural GPR writes and the commit trace.
module wb_stage (
    input  pipeline_pkg::mem_wb_t       in_packet,
    output logic                         gpr_write_enable,
    output core_types_pkg::gpr_addr_t   gpr_write_addr,
    output core_types_pkg::xlen_t       gpr_write_data,
    output logic                         commit_valid,
    output core_types_pkg::xlen_t       commit_pc,
    output logic [31:0]                  commit_inst,
    output core_types_pkg::gpr_addr_t   commit_rd,
    output logic                         commit_rd_we,
    output core_types_pkg::xlen_t       commit_rd_data,
    output logic                         commit_exception
);
    always_comb begin
        gpr_write_enable = in_packet.valid && in_packet.uop.gpr_write &&
                           !in_packet.exc.valid && !in_packet.uop.illegal;
        gpr_write_addr = in_packet.rd;
        gpr_write_data = in_packet.wb_data;
        commit_valid = in_packet.valid;
        commit_pc = in_packet.pc;
        commit_inst = in_packet.inst;
        commit_rd = in_packet.rd;
        commit_rd_we = gpr_write_enable && (in_packet.rd != '0);
        commit_rd_data = in_packet.wb_data;
        commit_exception = in_packet.valid &&
                           (in_packet.exc.valid || in_packet.uop.illegal);
    end
endmodule
