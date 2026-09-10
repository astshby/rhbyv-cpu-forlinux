// Module: wb_stage
// Description: Accepts load responses, writes architectural state, and emits commit trace.
// load在wb阶段进行响应
module wb_stage (
    input  pipeline_pkg::mem_wb_t       in_packet,
    input  logic                        dmem_rsp_valid,
    input  core_types_pkg::xlen_t       dmem_rsp_rdata,
    output logic                        dmem_rsp_ready,
    output logic                        wait_for_response,
    output logic                        gpr_write_enable,   //给regfile的数据数据
    output core_types_pkg::gpr_addr_t   gpr_write_addr,
    output core_types_pkg::xlen_t       gpr_write_data,
    output logic                        commit_valid,
    output core_types_pkg::xlen_t       commit_pc,
    output logic [31:0]                 commit_inst,
    output core_types_pkg::gpr_addr_t   commit_rd,
    output logic                        commit_rd_we,
    output core_types_pkg::xlen_t       commit_rd_data,
    output logic                        commit_exception
);
    import core_types_pkg::*;

    logic response_fire;
    logic load_response_needed; // load是否在wb阶段接收数据
    logic packet_complete;
    xlen_t load_data;
    xlen_t writeback_data;

    // load 在 WB 与同步 BRAM/Cache 的返回数据汇合，再完成字节选择和扩展。
    load_unit u_load_unit (
        .bus_data(dmem_rsp_rdata),
        .address(in_packet.result),
        .size(in_packet.uop.mem_size),
        .unsigned_load(in_packet.uop.load_unsigned),
        .load_data
    );

    // dmem响应处理与packet完成：当需要但是没返回才暂停，包完成时不需要/握手成功
    always_comb begin
        load_response_needed = in_packet.valid && in_packet.uop.mem_read &&
                               !in_packet.exc.valid && !in_packet.uop.illegal;
        dmem_rsp_ready = load_response_needed;
        response_fire = dmem_rsp_ready && dmem_rsp_valid;

        wait_for_response = load_response_needed && !response_fire;
        packet_complete = !load_response_needed || response_fire;
    end


    // WB写回，GPR 写口同时作为 WB 前递来源；x0 不产生真实写入。
    always_comb begin
        unique case (in_packet.uop.wb_sel)
            WB_LOAD:   writeback_data = load_data;
            WB_SEQ_PC: writeback_data = in_packet.seq_pc;
            WB_CSR:    writeback_data = in_packet.csr_old;
            default:   writeback_data = in_packet.result;
        endcase

        gpr_write_enable = in_packet.valid && packet_complete &&
                           in_packet.uop.gpr_write && (in_packet.rd != '0) &&
                           !in_packet.exc.valid && !in_packet.uop.illegal;
        gpr_write_addr = in_packet.rd;
        gpr_write_data = writeback_data;
    end

    // commit 仅在指令及其所需响应完整时产生。
    always_comb begin
        commit_valid = in_packet.valid && packet_complete;
        commit_pc = in_packet.pc;
        commit_inst = in_packet.inst;
        commit_rd = in_packet.rd;
        commit_rd_we = gpr_write_enable;
        commit_rd_data = writeback_data;
        commit_exception = commit_valid &&
                           (in_packet.exc.valid || in_packet.uop.illegal);
                           // 异常/指令非法
    end
endmodule
