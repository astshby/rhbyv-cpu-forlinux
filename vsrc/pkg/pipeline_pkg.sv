// Package: pipeline_pkg
// Description: Packed packets carried across the six pipeline boundaries.
package pipeline_pkg;
    import core_config_pkg::*;
    import core_types_pkg::*;

    typedef enum logic [4:0] {
        EXC_INST_ADDR_MISALIGNED  = 5'd0,
        EXC_ILLEGAL_INST          = 5'd2,
        EXC_BREAKPOINT            = 5'd3,
        EXC_LOAD_ADDR_MISALIGNED  = 5'd4,
        EXC_STORE_ADDR_MISALIGNED = 5'd6,
        EXC_ECALL_M               = 5'd11
    } exc_cause_e;

    typedef struct packed {
        logic       valid;
        exc_cause_e cause;
        xlen_t      tval;
    } exception_t;

    typedef struct packed {
        logic                  hit;
        logic                  taken;
        xlen_t                 target;
        logic [BTB_IDX_W-1:0]  btb_idx;
        logic [PHT_IDX_W-1:0]  pht_idx;
    } pred_info_t;

    typedef struct packed {
        logic       valid;
        branch_op_e kind;
        xlen_t      pc;
        logic       taken;
        xlen_t      target;
        pred_info_t pred;
    } pred_update_t;

    typedef enum logic [2:0] {
        REDIR_NONE, REDIR_D1_JAL, REDIR_EX_BRANCH, REDIR_TRAP, REDIR_MRET
    } redirect_reason_e;

    typedef struct packed {
        logic             valid;
        xlen_t            pc;
        redirect_reason_e reason;
    } redirect_t;

    typedef struct packed {
        logic        valid;
        xlen_t       pc;
        xlen_t       seq_pc;
        logic [31:0] inst;
        pred_info_t  pred;
    } if_d1_t;

    typedef struct packed {
        logic        valid;
        xlen_t       pc;
        xlen_t       seq_pc;
        logic [31:0] inst;
        gpr_addr_t   rs1;
        gpr_addr_t   rs2;
        gpr_addr_t   rd;
        xlen_t       imm;
        csr_addr_t   csr_addr;
        uop_t        uop;
        pred_info_t  pred;
        exception_t  exc;
    } d1_d2_t;

    typedef struct packed {
        logic        valid;
        xlen_t       pc;
        xlen_t       seq_pc;
        logic [31:0] inst;
        gpr_addr_t   rs1;
        gpr_addr_t   rs2;
        gpr_addr_t   rd;
        xlen_t       rs1_data;
        xlen_t       rs2_data;
        xlen_t       imm;
        csr_addr_t   csr_addr;
        uop_t        uop;
        pred_info_t  pred;
        exception_t  exc;
    } d2_ex_t;

    typedef struct packed {
        logic        valid;
        xlen_t       pc;
        xlen_t       seq_pc;
        logic [31:0] inst;
        gpr_addr_t   rd;
        xlen_t       result;
        xlen_t       store_data;
        csr_addr_t   csr_addr;
        xlen_t       csr_old;
        xlen_t       csr_new;
        logic        csr_we;
        uop_t        uop;
        pred_info_t  pred;
        exception_t  exc;
    } ex_mem_t;

    typedef struct packed {
        logic        valid;
        xlen_t       pc;
        xlen_t       seq_pc;
        logic [31:0] inst;
        gpr_addr_t   rd;
        xlen_t       wb_data;
        csr_addr_t   csr_addr;
        xlen_t       csr_old;
        xlen_t       csr_new;
        logic        csr_we;
        uop_t        uop;
        exception_t  exc;
    } mem_wb_t;
endpackage
