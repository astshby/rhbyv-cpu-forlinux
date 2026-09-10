// Module: ex_stage
// Description: Applies forwarding and executes ALU, address, branch, and JALR operations.
module ex_stage (
    input  pipeline_pkg::d2_ex_t      in_packet,
    // 包含了mem阶段与wb阶段的forward信息,有效位是始终的判据,以及给d2的前递（写穿透）
    input  logic                      mem_forward_valid,
    input  core_types_pkg::gpr_addr_t mem_forward_addr,
    input  core_types_pkg::xlen_t     mem_forward_data,
    input  logic                      wb_forward_valid,
    input  core_types_pkg::gpr_addr_t wb_forward_addr,
    input  core_types_pkg::xlen_t     wb_forward_data,
    output pipeline_pkg::ex_mem_t     out_packet,
    output pipeline_pkg::redirect_t   redirect,
    output pipeline_pkg::pred_update_t pred_update
);
    import core_types_pkg::*;
    import pipeline_pkg::*;

    xlen_t operand_a;
    xlen_t operand_b;
    xlen_t alu_result;
    logic branch_taken;
    xlen_t branch_target;
    logic control_op;
    logic mispredict;
    xlen_t forwarded_rs1;
    xlen_t forwarded_rs2;

    // 对rs1和rs2进行前递选择
    operand_bypass u_rs1_bypass (
        .source_addr(in_packet.rs1),
        .source_used(in_packet.uop.rs1_used),
        .original_data(in_packet.rs1_data),
        .mem_valid(mem_forward_valid),
        .mem_addr(mem_forward_addr),
        .mem_data(mem_forward_data),
        .wb_valid(wb_forward_valid),
        .wb_addr(wb_forward_addr),
        .wb_data(wb_forward_data),
        .forwarded_data(forwarded_rs1)
    );

    operand_bypass u_rs2_bypass (
        .source_addr(in_packet.rs2),
        .source_used(in_packet.uop.rs2_used),
        .original_data(in_packet.rs2_data),
        .mem_valid(mem_forward_valid),
        .mem_addr(mem_forward_addr),
        .mem_data(mem_forward_data),
        .wb_valid(wb_forward_valid),
        .wb_addr(wb_forward_addr),
        .wb_data(wb_forward_data),
        .forwarded_data(forwarded_rs2)
    );

    // 经过前递后选择操作数
    always_comb begin
        unique case (in_packet.uop.op_a_sel)
            OP_A_RS1:  operand_a = forwarded_rs1;
            OP_A_PC:   operand_a = in_packet.pc;
            default:   operand_a = '0;
        endcase
        operand_b = (in_packet.uop.op_b_sel == OP_B_IMM)
                  ? in_packet.imm : forwarded_rs2;
    end

    // 连接alu和branch_unit模块
    alu u_alu (
        .operand_a,
        .operand_b,
        .operation(in_packet.uop.alu_op),
        .op_width(in_packet.uop.op_width),
        .result(alu_result)
    );

    branch_unit u_branch_unit (
        .branch_op(in_packet.uop.branch_op),
        .pc(in_packet.pc),
        .seq_pc(in_packet.seq_pc),
        .operand_a(forwarded_rs1),
        .operand_b(forwarded_rs2),
        .imm(in_packet.imm),
        .taken(branch_taken),
        .target(branch_target)
    );

    // 判断是否发生分支预测错误，并生成给 BTB/GShare 的实际执行结果。
    // control_op判断分支（除jal），mispredict判断预测是否正确，redirect用于指示流水线需要跳转到新的PC
    always_comb begin
        control_op = (in_packet.uop.branch_op != BR_NONE) &&
                     (in_packet.uop.branch_op != BR_JAL);
        mispredict = control_op &&
                     ((in_packet.pred.taken != branch_taken) ||
                      (branch_taken && (in_packet.pred.target != branch_target)));

        pred_update = '0;
        if (in_packet.valid && control_op) begin
            pred_update.valid = 1'b1;
            pred_update.kind = in_packet.uop.branch_op;
            pred_update.pc = in_packet.pc;
            pred_update.taken = branch_taken;
            pred_update.target = branch_target;
            pred_update.pred = in_packet.pred;
        end

        redirect = '0;
        if (in_packet.valid && mispredict) begin
            redirect.valid = 1'b1;
            redirect.pc = branch_taken ? branch_target : in_packet.seq_pc;
            redirect.reason = REDIR_EX_BRANCH;
        end
    end

    // 每个模块必有的打包输出结果
    always_comb begin
        out_packet = '0;
        out_packet.valid = in_packet.valid;
        out_packet.pc = in_packet.pc;
        out_packet.seq_pc = in_packet.seq_pc;
        out_packet.inst = in_packet.inst;
        out_packet.rd = in_packet.rd;
        out_packet.result = alu_result;
        out_packet.store_data = forwarded_rs2; //rs1计算地址
        out_packet.csr_addr = in_packet.csr_addr;
        out_packet.uop = in_packet.uop;
        out_packet.pred = in_packet.pred;
        out_packet.exc = in_packet.exc;

    end
endmodule
