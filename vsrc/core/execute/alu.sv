// Module: alu
// Description: Combinational RV32/RV64 integer arithmetic and logic unit.
// alu使用的operand实质经过了前递选择与数据选择，统一为a，b
module alu (
    input  core_types_pkg::xlen_t      operand_a,
    input  core_types_pkg::xlen_t      operand_b,
    input  core_types_pkg::alu_op_e    operation,
    input  core_types_pkg::op_width_e  op_width,  // 64/32位操作,需要给出op_width
    output core_types_pkg::xlen_t      result
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    // 提前定义位移量（lui已经移动过，对应a=0）
    localparam int unsigned SHAMT_W = $clog2(XLEN);
    logic [SHAMT_W-1:0] shamt;

    always_comb begin
        shamt = operand_b[SHAMT_W-1:0];
        unique case (operation)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_SLL:  result = operand_a << shamt;
            ALU_SLT:  result = xlen_t'($signed(operand_a) < $signed(operand_b)); //比较置位要扩展,$signed临时转换为有符号数
            ALU_SLTU: result = xlen_t'(operand_a < operand_b);
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_SRL:  result = operand_a >> shamt;
            ALU_SRA:  result = xlen_t'($signed(operand_a) >>> shamt); // >>> 表示算数右移，但是需要将operand_a转换为有符号数
            ALU_OR:   result = operand_a | operand_b;
            ALU_AND:  result = operand_a & operand_b;
            default:  result = '0;
        endcase
    end

    // 暂时用于占位，防lint（端口）检查
    logic unused_width;
    assign unused_width = op_width;

endmodule
