// Module: tb_decoder
// Description: Checks representative RV32I decode and illegal encodings.
module tb_decoder;
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
        inst = enc_r(7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011); #1;
        assert (!uop.illegal && uop.alu_op == ALU_ADD && uop.rs2_used && uop.gpr_write)
            else $fatal(1, "ADD decode");
        inst = enc_i(4, 5'd2, 3'b010, 5'd1, 7'b0000011); #1;
        assert (!uop.illegal && uop.mem_read && uop.mem_size == MEM_WORD)
            else $fatal(1, "LW decode");
        inst = enc_b(8, 5'd2, 5'd1, 3'b100); #1;
        assert (!uop.illegal && uop.branch_op == BR_LT) else $fatal(1, "BLT decode");
        inst = 32'hffff_ffff; #1;
        assert (uop.illegal && !uop.gpr_write && !uop.mem_write) else $fatal(1, "illegal decode");
        inst = enc_i(0, 5'd2, 3'b011, 5'd1, 7'b0000011); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.mem_size == MEM_DWORD) else $fatal(1, "LD decode");
        else
            assert (uop.illegal) else $fatal(1, "LD must be illegal in RV32");
        inst = enc_r(7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0111011); #1;
        if (XLEN == 64)
            assert (!uop.illegal && uop.op_width == OP_WIDTH_WORD) else $fatal(1, "ADDW decode");
        else
            assert (uop.illegal) else $fatal(1, "ADDW must be illegal in RV32");
        inst = 32'h0000_0073; #1;
        assert (!uop.illegal && uop.is_ecall) else $fatal(1, "ECALL decode");
        inst = 32'h0010_0073; #1;
        assert (!uop.illegal && uop.is_ebreak) else $fatal(1, "EBREAK decode");
        inst = 32'h3020_0073; #1;
        assert (!uop.illegal && uop.is_mret) else $fatal(1, "MRET decode");
        inst = enc_csr(12'h340, 5'd2, 3'b001, 5'd1); #1;
        assert (!uop.illegal && uop.csr_valid && uop.csr_write &&
                uop.csr_cmd == CSR_RW && uop.rs1_used && csr_addr == 12'h340)
            else $fatal(1, "CSRRW decode");
        inst = enc_csr(12'h340, 5'd0, 3'b010, 5'd1); #1;
        assert (!uop.illegal && uop.csr_valid && !uop.csr_write && !uop.rs1_used)
            else $fatal(1, "CSRRS read-only form");
        inst = enc_csr(12'h340, 5'd3, 3'b111, 5'd1); #1;
        assert (!uop.illegal && uop.csr_valid && uop.csr_imm &&
                uop.csr_write && uop.csr_cmd == CSR_RC)
            else $fatal(1, "CSRRCI decode");
        inst = 32'h0020_0073; #1;
        assert (uop.illegal) else $fatal(1, "reserved SYSTEM decode");
        $display("PASS tb_decoder");
        $finish;
    end
endmodule
