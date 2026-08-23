// Package: core_types_pkg
// Description: Strongly typed execution controls shared by core modules.
package core_types_pkg;
    import core_config_pkg::*;

    typedef logic [XLEN-1:0] xlen_t;
    typedef logic [GPR_ADDR_W-1:0] gpr_addr_t;
    typedef logic [CSR_ADDR_W-1:0] csr_addr_t;

    typedef enum logic [3:0] {
        ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
        ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND
    } alu_op_e;

    typedef enum logic [3:0] {
        BR_NONE, BR_EQ, BR_NE, BR_LT, BR_GE,
        BR_LTU, BR_GEU, BR_JAL, BR_JALR
    } branch_op_e;

    typedef enum logic [2:0] {
        FU_NONE, FU_ALU, FU_BRANCH, FU_LSU, FU_CSR, FU_MULDIV
    } fu_sel_e;

    typedef enum logic [1:0] { OP_A_RS1, OP_A_PC, OP_A_ZERO } op_a_sel_e;
    typedef enum logic       { OP_B_RS2, OP_B_IMM } op_b_sel_e;
    typedef enum logic       { OP_WIDTH_XLEN, OP_WIDTH_WORD } op_width_e;
    typedef enum logic [1:0] { MEM_BYTE, MEM_HALF, MEM_WORD, MEM_DWORD } mem_size_e;
    typedef enum logic [2:0] { WB_NONE, WB_ALU, WB_LOAD, WB_SEQ_PC, WB_CSR } wb_sel_e;
    typedef enum logic [1:0] { CSR_RW, CSR_RS, CSR_RC } csr_cmd_e;

    typedef struct packed {
        fu_sel_e       fu;
        alu_op_e       alu_op;
        branch_op_e    branch_op;
        op_a_sel_e     op_a_sel;
        op_b_sel_e     op_b_sel;
        op_width_e     op_width;
        mem_size_e     mem_size;
        wb_sel_e       wb_sel;
        csr_cmd_e      csr_cmd;
        logic          rs1_used;
        logic          rs2_used;
        logic          gpr_write;
        logic          mem_read;
        logic          mem_write;
        logic          load_unsigned;
        logic          csr_valid;
        logic          csr_imm;
        logic          csr_write;
        logic          is_ecall;
        logic          is_ebreak;
        logic          is_mret;
        logic          illegal;
    } uop_t;
endpackage
