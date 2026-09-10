// Package: rv_asm_pkg
// Description: Small instruction encoders for self-contained directed tests.
// 类似于一个解码器,仿真便利化使用
package rv_asm_pkg;
    import riscv_unpriv_pkg::*;

    // function用于‘函数’计算，是零时间计算（通常不包含时序），task可包含，module是标准的模块
    // automatic,每次 function 调用拥有自己独立的局部存储，对于递归/并发很重要
    // 名字赋值，每次返回的都是名字所“调用”的函数

    // 下方的 enc_* 函数生成rv指令的二进制编码
    function automatic logic [31:0] enc_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_i(
        input integer imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_i = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_s(
        input integer imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], OPCODE_STORE};
    endfunction

    function automatic logic [31:0] enc_b(
        input integer imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                 imm[4:1], imm[11], OPCODE_BRANCH};
    endfunction

    function automatic logic [31:0] enc_u(
        input logic [19:0] imm20,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_j(
        input integer imm,
        input logic [4:0] rd
    );
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OPCODE_JAL};
    endfunction

    // 语义化封装按照汇编操作数顺序传参，便于阅读整核测试程序
    function automatic logic [31:0] enc_add(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        enc_add = enc_r(F7_OP_BASE, rs2, rs1, F3_OP_ADD_SUB, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] enc_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input integer imm
    );
        enc_addi = enc_i(imm, rs1, F3_OP_IMM_ADDI, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] enc_lw(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input integer imm
    );
        enc_lw = enc_i(imm, rs1, F3_LOAD_LW, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] enc_sw(
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input integer imm
    );
        enc_sw = enc_s(imm, rs2, rs1, F3_STORE_SW);
    endfunction

    function automatic logic [31:0] enc_beq(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input integer imm
    );
        enc_beq = enc_b(imm, rs2, rs1, F3_BRANCH_BEQ);
    endfunction

    function automatic logic [31:0] enc_bne(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input integer imm
    );
        enc_bne = enc_b(imm, rs2, rs1, F3_BRANCH_BNE);
    endfunction

    function automatic logic [31:0] enc_blt(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input integer imm
    );
        enc_blt = enc_b(imm, rs2, rs1, F3_BRANCH_BLT);
    endfunction

    function automatic logic [31:0] enc_lui(
        input logic [4:0] rd,
        input logic [19:0] imm20
    );
        enc_lui = enc_u(imm20, rd, OPCODE_LUI);
    endfunction

    function automatic logic [31:0] enc_jal(
        input logic [4:0] rd,
        input integer imm
    );
        enc_jal = enc_j(imm, rd);
    endfunction

    function automatic logic [31:0] enc_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input integer imm
    );
        enc_jalr = enc_i(imm, rs1, F3_JALR, rd, OPCODE_JALR);
    endfunction

    function automatic logic [31:0] nop();
        nop = enc_addi(5'd0, 5'd0, 0);
    endfunction
endpackage
