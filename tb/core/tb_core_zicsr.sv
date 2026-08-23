// Module: tb_core_zicsr
// Description: Runs dependent register and immediate Zicsr operations through the full pipeline.
module tb_core_zicsr;
    import core_config_pkg::*;
    import riscv_isa_pkg::*;
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
        for (idx = 0; idx < 128; idx = idx + 1)
            dut.u_imem.mem[idx] = nop();
        dut.u_imem.mem[0]  = enc_i(16'h55, 5'd0, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[1]  = enc_csr(CSR_MSCRATCH, 5'd1, 3'b001, 5'd2);
        dut.u_imem.mem[2]  = enc_csr(CSR_MSCRATCH, 5'd1, 3'b010, 5'd3);
        dut.u_imem.mem[3]  = enc_i(16'h0f, 5'd0, 3'b000, 5'd4, 7'b0010011);
        dut.u_imem.mem[4]  = enc_csr(CSR_MSCRATCH, 5'd4, 3'b011, 5'd5);
        dut.u_imem.mem[5]  = enc_csr(CSR_MSCRATCH, 5'd0, 3'b010, 5'd6);
        dut.u_imem.mem[6]  = enc_i(16'h50, 5'd0, 3'b000, 5'd7, 7'b0010011);
        dut.u_imem.mem[7]  = enc_b(76, 5'd7, 5'd6, 3'b001);
        dut.u_imem.mem[8]  = enc_csr(CSR_MSCRATCH, 5'd3, 3'b101, 5'd8);
        dut.u_imem.mem[9]  = enc_csr(CSR_MSCRATCH, 5'd4, 3'b110, 5'd9);
        dut.u_imem.mem[10] = enc_csr(CSR_MSCRATCH, 5'd1, 3'b111, 5'd10);
        dut.u_imem.mem[11] = enc_csr(CSR_MSCRATCH, 5'd0, 3'b010, 5'd11);
        dut.u_imem.mem[12] = enc_i(6, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[13] = enc_b(52, 5'd12, 5'd11, 3'b001);
        dut.u_imem.mem[14] = enc_i(16'h50, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[15] = enc_b(44, 5'd12, 5'd8, 3'b001);
        dut.u_imem.mem[16] = enc_i(3, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[17] = enc_b(36, 5'd12, 5'd9, 3'b001);
        dut.u_imem.mem[18] = enc_i(7, 5'd0, 3'b000, 5'd12, 7'b0010011);
        dut.u_imem.mem[19] = enc_b(28, 5'd12, 5'd10, 3'b001);
        dut.u_imem.mem[20] = enc_csr(CSR_MCYCLE, 5'd0, 3'b010, 5'd13);
        dut.u_imem.mem[21] = enc_b(20, 5'd0, 5'd13, 3'b000);
        dut.u_imem.mem[22] = enc_u(20'h10000, 5'd14, 7'b0110111);
        dut.u_imem.mem[23] = enc_i(1, 5'd0, 3'b000, 5'd15, 7'b0010011);
        dut.u_imem.mem[24] = enc_s(0, 5'd15, 5'd14, 3'b010);
        dut.u_imem.mem[25] = enc_j(0, 5'd0);
        dut.u_imem.mem[26] = enc_u(20'h10000, 5'd14, 7'b0110111);
        dut.u_imem.mem[27] = enc_i(2, 5'd0, 3'b000, 5'd15, 7'b0010011);
        dut.u_imem.mem[28] = enc_s(0, 5'd15, 5'd14, 3'b010);
        dut.u_imem.mem[29] = enc_j(0, 5'd0);

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < 800; cycles = cycles + 1) begin
            @(posedge clk);
            if (commit_exception)
                $fatal(1, "unexpected exception at pc=%h inst=%h", commit_pc, commit_inst);
            if (test_done) begin
                assert (test_pass) else $fatal(1, "Zicsr program failed code=%0d", test_code);
                $display("PASS tb_core_zicsr RV%0d cycles=%0d", XLEN, cycles);
                $finish;
            end
        end
        $fatal(1, "Zicsr directed program timeout");
    end
endmodule
