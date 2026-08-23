// Module: tb_core_trap
// Description: Exercises precise synchronous traps and MRET recovery through a machine handler.
module tb_core_trap;
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
    integer exception_count;

    always #5 clk = ~clk;
    sim_cpu_top dut (.*);

    always_ff @(posedge clk) begin
        if (rst)
            exception_count <= 0;
        else if (commit_exception)
            exception_count <= exception_count + 1;
    end

    initial begin
        for (idx = 0; idx < 128; idx = idx + 1)
            dut.u_imem.mem[idx] = nop();
        dut.u_imem.mem[0]  = enc_i(16'h100, 5'd0, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[1]  = enc_csr(CSR_MTVEC, 5'd1, 3'b001, 5'd0);
        dut.u_imem.mem[2]  = enc_i(0, 5'd0, 3'b000, 5'd20, 7'b0010011);
        dut.u_imem.mem[3]  = enc_i(0, 5'd0, 3'b000, 5'd21, 7'b0010011);
        dut.u_imem.mem[4]  = 32'h0000_0073;
        dut.u_imem.mem[5]  = 32'h0010_0073;
        dut.u_imem.mem[6]  = 32'hffff_ffff;
        dut.u_imem.mem[7]  = enc_csr(CSR_MISA, 5'd0, 3'b001, 5'd0);
        dut.u_imem.mem[8]  = enc_i(1, 5'd0, 3'b010, 5'd2, 7'b0000011);
        dut.u_imem.mem[9]  = enc_s(2, 5'd0, 5'd0, 3'b010);
        dut.u_imem.mem[10] = enc_j(2, 5'd0);
        dut.u_imem.mem[11] = enc_i(7, 5'd0, 3'b000, 5'd22, 7'b0010011);
        dut.u_imem.mem[12] = enc_b(28, 5'd22, 5'd20, 3'b001);
        dut.u_imem.mem[13] = enc_i(28, 5'd0, 3'b000, 5'd22, 7'b0010011);
        dut.u_imem.mem[14] = enc_b(20, 5'd22, 5'd21, 3'b001);
        dut.u_imem.mem[15] = enc_u(20'h10000, 5'd23, 7'b0110111);
        dut.u_imem.mem[16] = enc_i(1, 5'd0, 3'b000, 5'd24, 7'b0010011);
        dut.u_imem.mem[17] = enc_s(0, 5'd24, 5'd23, 3'b010);
        dut.u_imem.mem[18] = enc_j(0, 5'd0);
        dut.u_imem.mem[19] = enc_u(20'h10000, 5'd23, 7'b0110111);
        dut.u_imem.mem[20] = enc_i(2, 5'd0, 3'b000, 5'd24, 7'b0010011);
        dut.u_imem.mem[21] = enc_s(0, 5'd24, 5'd23, 3'b010);
        dut.u_imem.mem[22] = enc_j(0, 5'd0);

        dut.u_imem.mem[64] = enc_csr(CSR_MCAUSE, 5'd0, 3'b010, 5'd10);
        dut.u_imem.mem[65] = enc_r(7'b0, 5'd10, 5'd21, 3'b000, 5'd21, 7'b0110011);
        dut.u_imem.mem[66] = enc_csr(CSR_MEPC, 5'd0, 3'b010, 5'd11);
        dut.u_imem.mem[67] = enc_i(4, 5'd11, 3'b000, 5'd11, 7'b0010011);
        dut.u_imem.mem[68] = enc_csr(CSR_MEPC, 5'd11, 3'b001, 5'd0);
        dut.u_imem.mem[69] = enc_i(1, 5'd20, 3'b000, 5'd20, 7'b0010011);
        dut.u_imem.mem[70] = 32'h3020_0073;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < 1600; cycles = cycles + 1) begin
            @(posedge clk);
            if (test_done) begin
                assert (test_pass) else $fatal(1, "trap program failed code=%0d", test_code);
                assert (exception_count == 7)
                    else $fatal(1, "expected seven committed exceptions, got %0d", exception_count);
                $display("PASS tb_core_trap RV%0d exceptions=%0d cycles=%0d",
                         XLEN, exception_count, cycles);
                $finish;
            end
        end
        $fatal(1, "trap directed program timeout exceptions=%0d", exception_count);
    end
endmodule
