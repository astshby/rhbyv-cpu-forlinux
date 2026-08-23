// Module: tb_core_rv32i
// Description: Runs a directed RV32I program covering RAW, load-use, branch, JAL, and JALR.
module tb_core_rv32i;
    import core_config_pkg::*;
    import rv_asm_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic commit_valid;
    logic [XLEN-1:0] commit_pc;
    logic [31:0] commit_inst;
    logic [4:0] commit_rd;
    logic commit_rd_we;
    logic [XLEN-1:0] commit_rd_data;
    logic commit_exception;
    logic test_done;
    logic test_pass;
    logic [31:0] test_code;
    integer idx;
    integer cycles;

    always #5 clk = ~clk;

    sim_cpu_top dut (.*);

    initial begin
        if (XLEN != 32) begin
            $display("PASS tb_core_rv32i SKIP RV%0d", XLEN);
            $finish;
        end
        for (idx = 0; idx < 128; idx = idx + 1)
            dut.u_imem.mem[idx] = nop();
        dut.u_imem.mem[0]  = enc_i(5,  5'd0, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[1]  = enc_i(7,  5'd1, 3'b000, 5'd2, 7'b0010011);
        dut.u_imem.mem[2]  = enc_r(7'b0, 5'd1, 5'd2, 3'b000, 5'd3, 7'b0110011);
        dut.u_imem.mem[3]  = enc_s(0,  5'd3, 5'd0, 3'b010);
        dut.u_imem.mem[4]  = enc_i(0,  5'd0, 3'b010, 5'd4, 7'b0000011);
        dut.u_imem.mem[5]  = enc_i(1,  5'd4, 3'b000, 5'd5, 7'b0010011);
        dut.u_imem.mem[6]  = enc_i(18, 5'd0, 3'b000, 5'd6, 7'b0010011);
        dut.u_imem.mem[7]  = enc_b(56, 5'd6, 5'd5, 3'b001);
        dut.u_imem.mem[8]  = enc_b(8, 5'd6, 5'd5, 3'b000);
        dut.u_imem.mem[9]  = enc_j(48, 5'd0);
        dut.u_imem.mem[10] = enc_j(8, 5'd7);
        dut.u_imem.mem[11] = enc_i(-1, 5'd0, 3'b000, 5'd9, 7'b0010011);
        dut.u_imem.mem[12] = enc_i(60, 5'd0, 3'b000, 5'd9, 7'b0010011);
        dut.u_imem.mem[13] = enc_i(0, 5'd9, 3'b000, 5'd8, 7'b1100111);
        dut.u_imem.mem[14] = enc_i(-1, 5'd0, 3'b000, 5'd10, 7'b0010011);
        dut.u_imem.mem[15] = enc_i(56, 5'd0, 3'b000, 5'd10, 7'b0010011);
        dut.u_imem.mem[16] = enc_b(20, 5'd10, 5'd8, 3'b001);
        dut.u_imem.mem[17] = enc_u(20'h10000, 5'd11, 7'b0110111);
        dut.u_imem.mem[18] = enc_i(1, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[19] = enc_s(0, 5'd12, 5'd11, 3'b010);
        dut.u_imem.mem[20] = enc_j(0, 5'd0);
        dut.u_imem.mem[21] = enc_u(20'h10000, 5'd11, 7'b0110111);
        dut.u_imem.mem[22] = enc_i(2, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[23] = enc_s(0, 5'd12, 5'd11, 3'b010);
        dut.u_imem.mem[24] = enc_j(0, 5'd0);

        repeat (4) @(posedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < 500; cycles = cycles + 1) begin
            @(posedge clk);
            if (commit_exception)
                $fatal(1, "unexpected exception at pc=%h inst=%h", commit_pc, commit_inst);
            if (test_done) begin
                assert (test_pass) else $fatal(1, "directed program failed code=%0d", test_code);
                $display("PASS tb_core_rv32i cycles=%0d", cycles);
                $finish;
            end
        end
        $fatal(1, "directed program timeout");
    end
endmodule
