// Module: tb_decoder
// Description: Checks representative RV32I/RV64I decode and illegal encodings.
module tb_decoder;
    timeunit 1ns;
    timeprecision 1ps;

    import core_config_pkg::*;
    import core_types_pkg::*;
    import rv_asm_pkg::*;

    logic [31:0] inst;
    uop_t uop;
    gpr_addr_t rs1;
    gpr_addr_t rs2;
    gpr_addr_t rd;
    csr_addr_t csr_addr;

    decoder dut (.*);

    initial begin
        inst = enc_add(5'd1, 5'd2, 5'd3); #1;
        assert (!uop.illegal && uop.alu_op == ALU_ADD && uop.rs2_used && uop.gpr_write)
            else $fatal(1, "ADD decode");
        inst = enc_lw(5'd1, 5'd2, 4); #1;
        assert (!uop.illegal && uop.mem_read && uop.mem_size == MEM_WORD)
            else $fatal(1, "LW decode");
        inst = enc_blt(5'd1, 5'd2, 8); #1;
        assert (!uop.illegal && uop.branch_op == BR_LT) else $fatal(1, "BLT decode");
        inst = 32'hffff_ffff; #1;
        assert (uop.illegal && !uop.gpr_write && !uop.mem_write) else $fatal(1, "illegal decode");

        // 同一编码在 RV64 合法、在 RV32 必须保持非法。
        inst = enc_ld(5'd1, 5'd2, 8); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.mem_read && uop.mem_size == MEM_DWORD)
                else $fatal(1, "LD decode");
        else
            assert (uop.illegal) else $fatal(1, "LD must be illegal in RV32");

        inst = enc_lwu(5'd1, 5'd2, 4); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.mem_size == MEM_WORD && uop.load_unsigned)
                else $fatal(1, "LWU decode");
        else
            assert (uop.illegal) else $fatal(1, "LWU must be illegal in RV32");

        inst = enc_addw(5'd1, 5'd2, 5'd3); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.op_width == OP_WIDTH_WORD && uop.alu_op == ALU_ADD)
                else $fatal(1, "ADDW decode");
        else
            assert (uop.illegal) else $fatal(1, "ADDW must be illegal in RV32");

        // RV64 XLEN 位移允许 shamt[5]，W 类位移仍只允许 5-bit shamt。
        inst = enc_slli(5'd1, 5'd2, 32); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.alu_op == ALU_SLL) else $fatal(1, "RV64 SLLI shamt[5]");
        else
            assert (uop.illegal) else $fatal(1, "RV32 SLLI shamt[5] must be illegal");
        inst = enc_slliw(5'd1, 5'd2, 32); #1;
        assert (uop.illegal) else $fatal(1, "SLLIW shamt[5] must be illegal");

        $display("PASS tb_decoder");
        $finish;
    end
endmodule
