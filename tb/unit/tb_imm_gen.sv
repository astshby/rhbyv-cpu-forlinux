// Module: tb_imm_gen
// Description: Checks I, S, B, U, and J immediate reconstruction.
module tb_imm_gen;
    import core_config_pkg::*;
    import rv_asm_pkg::*;

    logic [31:0] inst;
    logic [XLEN-1:0] imm;
    imm_gen dut (.*);

    initial begin
        inst = enc_i(-17, 5'd1, 3'b000, 5'd2, 7'b0010011); #1;
        assert ($signed(imm) == -17) else $fatal(1, "I immediate");
        inst = enc_s(-12, 5'd2, 5'd1, 3'b010); #1;
        assert ($signed(imm) == -12) else $fatal(1, "S immediate");
        inst = enc_b(-20, 5'd2, 5'd1, 3'b000); #1;
        assert ($signed(imm) == -20) else $fatal(1, "B immediate");
        inst = enc_u(20'habcde, 5'd3, 7'b0110111); #1;
        assert (imm[31:12] == 20'habcde) else $fatal(1, "U immediate");
        inst = enc_j(2046, 5'd1); #1;
        assert ($signed(imm) == 2046) else $fatal(1, "J immediate");
        $display("PASS tb_imm_gen RV%0d", XLEN);
        $finish;
    end
endmodule
