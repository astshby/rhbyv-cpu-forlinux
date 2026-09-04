// Package: riscv_unpriv_pkg
// Description: RISC-V unprivileged instruction encodings.
// 非特权指令集编码，包含基础指令、Zicsr 以及环境调用相关编码
package riscv_unpriv_pkg;
    localparam logic [6:0] OPCODE_LOAD      = 7'b0000011;
    localparam logic [6:0] OPCODE_MISC_MEM  = 7'b0001111; // FENCE 等杂项内存指令
    localparam logic [6:0] OPCODE_OP_IMM    = 7'b0010011; // I_ALU-XLEN
    localparam logic [6:0] OPCODE_AUIPC     = 7'b0010111;
    localparam logic [6:0] OPCODE_OP_IMM_32 = 7'b0011011; // I_ALU-32
    localparam logic [6:0] OPCODE_STORE     = 7'b0100011;
    localparam logic [6:0] OPCODE_OP        = 7'b0110011; // R-XLEN
    localparam logic [6:0] OPCODE_LUI       = 7'b0110111;
    localparam logic [6:0] OPCODE_OP_32     = 7'b0111011; // R-32
    localparam logic [6:0] OPCODE_BRANCH    = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR      = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL       = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM    = 7'b1110011;

    localparam logic [31:0] INST_ECALL  = 32'h0000_0073;
    localparam logic [31:0] INST_EBREAK = 32'h0010_0073;
endpackage
