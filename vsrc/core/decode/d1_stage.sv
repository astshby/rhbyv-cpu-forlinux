// Module: d1_stage
// Description: Decodes instructions and resolves operand-free JAL control flow.
// 主要包含：获取指令后的初级解码
module d1_stage (
    input  pipeline_pkg::if_d1_t  in_packet,
    output pipeline_pkg::d1_d2_t  out_packet,
    output pipeline_pkg::redirect_t redirect
);
    import core_types_pkg::*;
    import pipeline_pkg::*;

    uop_t uop;
    gpr_addr_t rs1;
    gpr_addr_t rs2;
    gpr_addr_t rd;
    csr_addr_t csr_addr;
    xlen_t imm;
    xlen_t jal_target;

    decoder u_decoder (
        .inst(in_packet.inst),
        .uop,
        .rs1,
        .rs2,
        .rd,
        .csr_addr
    );
    imm_gen u_imm_gen (
        .inst(in_packet.inst),
        .imm
    );

    always_comb begin
        // 唯一的J指令：jal提前处理
        jal_target = in_packet.pc + imm;

        // jal:指令有效+jal+没有跳转/跳转目标有误：重定向
        redirect = '0;
        if (in_packet.valid && (uop.branch_op == BR_JAL) &&
            (!in_packet.pred.taken || (in_packet.pred.target != jal_target))) begin
            redirect.valid = 1'b1;
            redirect.pc = jal_target;
            redirect.reason = REDIR_D1_JAL;
        end
    end

    always_comb begin
        // 默认赋值，decoder的uop没有赋无用的值就是因为有这个，暂时没有exc处理
        out_packet = '0;

        out_packet.valid = in_packet.valid;
        out_packet.pc = in_packet.pc;
        out_packet.seq_pc = in_packet.seq_pc;
        out_packet.inst = in_packet.inst;
        out_packet.rs1 = rs1;
        out_packet.rs2 = rs2;
        out_packet.rd = rd;
        out_packet.imm = imm;
        out_packet.csr_addr = csr_addr;
        out_packet.uop = uop;
        out_packet.pred = in_packet.pred;

    end
endmodule
