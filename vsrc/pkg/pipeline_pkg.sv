// Package: pipeline_pkg
// Description: Packed packets carried across the six pipeline boundaries.
// 保存流水线相关信息，包括：1.异常处理 2.分支预测相关 3.流水级寄存器
package pipeline_pkg;
    import core_config_pkg::*;
    import core_types_pkg::*;
    import riscv_priv_pkg::*;

    // 动态异常信息与uOp静态译码控制分离,也便于流水线扩展（异常与中断可能随时出现）
    typedef struct packed {
        logic       valid;  // 异常有效标记
        exc_cause_e cause; // 异常原因在rv_priv定义
        xlen_t      tval;
    } exception_t;

    // 流水线必备，与btb与预测有关
    // if阶段必须传递的预测信息
    typedef struct packed {
        logic                  hit; //btb命中
        logic                  taken; //pht是否采用
        xlen_t                 target; //btb给出的分支目标
        logic [BTB_IDX_W-1:0]  btb_idx; //btb索引
        logic [PHT_IDX_W-1:0]  pht_idx; //pht索引
    } pred_info_t;

    // if阶段预测信息更新必要的信息
    typedef struct packed {
        logic       valid; // 更新信息有效标记
        branch_op_e kind; // 分支类型
        xlen_t      pc; // 分支指令的PC
        logic       taken; // 分支是否被采用
        xlen_t      target; // 分支目标地址
        pred_info_t pred; // if阶段的预测信息
    } pred_update_t;

    // 流水线重定向信息原因, 用于指示流水线需要跳转到新的PC
    typedef enum logic [2:0] {
        REDIR_NONE, REDIR_D1_JAL, REDIR_EX_BRANCH, REDIR_TRAP, REDIR_MRET
    } redirect_reason_e;

    // 重定向信息包
    typedef struct packed {
        logic             valid;
        xlen_t            pc;
        redirect_reason_e reason;
    } redirect_t;

    // 流水级寄存器
    // special：valid，标记指令有效性，用于bubble（stall与flush）
    // csr后期出现：wb阶段才写回
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
