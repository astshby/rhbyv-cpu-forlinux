// Module: tb_decoder
// Description: Checks representative RV32I decode and illegal encodings.
module tb_decoder;
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
        $display("PASS tb_decoder");
        $finish;
    end
endmodule
