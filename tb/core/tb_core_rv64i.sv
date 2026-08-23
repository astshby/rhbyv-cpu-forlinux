// Module: tb_core_rv64i
// Description: Runs RV64I W-operation, 64-bit shift, and LD/SD/LWU directed checks.
module tb_core_rv64i;
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
        if (XLEN != 64) begin
            $display("PASS tb_core_rv64i SKIP RV%0d", XLEN);
            $finish;
        end
        for (idx = 0; idx < 128; idx = idx + 1)
            dut.u_imem.mem[idx] = nop();
        dut.u_imem.mem[0]  = enc_i(-1, 5'd0, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[1]  = enc_u(20'h80000, 5'd3, 7'b0110111);
        dut.u_imem.mem[2]  = enc_i(1, 5'd3, 3'b000, 5'd4, 7'b0011011);
        dut.u_imem.mem[3]  = enc_i(256, 5'd0, 3'b000, 5'd10, 7'b0010011);
        dut.u_imem.mem[4]  = enc_s(0, 5'd4, 5'd10, 3'b011);
        dut.u_imem.mem[5]  = enc_i(0, 5'd10, 3'b011, 5'd5, 7'b0000011);
        dut.u_imem.mem[6]  = enc_b(64, 5'd4, 5'd5, 3'b001);
        dut.u_imem.mem[7]  = enc_i(0, 5'd10, 3'b010, 5'd14, 7'b0000011);
        dut.u_imem.mem[8]  = enc_b(56, 5'd4, 5'd14, 3'b001);
        dut.u_imem.mem[9]  = enc_i(0, 5'd10, 3'b110, 5'd6, 7'b0000011);
        dut.u_imem.mem[10] = enc_i(32, 5'd6, 3'b001, 5'd7, 7'b0010011);
        dut.u_imem.mem[11] = enc_i(32, 5'd7, 3'b101, 5'd7, 7'b0010011);
        dut.u_imem.mem[12] = enc_b(40, 5'd6, 5'd7, 3'b001);
        dut.u_imem.mem[13] = enc_r(7'b0000000, 5'd4, 5'd4, 3'b000, 5'd8, 7'b0111011);
        dut.u_imem.mem[14] = enc_i(2, 5'd0, 3'b000, 5'd9, 7'b0010011);
        dut.u_imem.mem[15] = enc_b(28, 5'd9, 5'd8, 3'b001);
        dut.u_imem.mem[16] = enc_r(7'b0100000, 5'd1, 5'd3, 3'b101, 5'd11, 7'b0111011);
        dut.u_imem.mem[17] = enc_b(20, 5'd1, 5'd11, 3'b001);
        dut.u_imem.mem[18] = enc_u(20'h10000, 5'd12, 7'b0110111);
        dut.u_imem.mem[19] = enc_i(1, 5'd0, 3'b000, 5'd13, 7'b0010011);
        dut.u_imem.mem[20] = enc_s(0, 5'd13, 5'd12, 3'b010);
        dut.u_imem.mem[21] = enc_j(0, 5'd0);
        dut.u_imem.mem[22] = enc_u(20'h10000, 5'd12, 7'b0110111);
        dut.u_imem.mem[23] = enc_i(2, 5'd0, 3'b000, 5'd13, 7'b0010011);
        dut.u_imem.mem[24] = enc_s(0, 5'd13, 5'd12, 3'b010);
        dut.u_imem.mem[25] = enc_j(0, 5'd0);

        repeat (4) @(posedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < 500; cycles = cycles + 1) begin
            @(posedge clk);
            if (commit_exception)
                $fatal(1, "unexpected exception at pc=%h inst=%h", commit_pc, commit_inst);
            if (test_done) begin
                assert (test_pass) else $fatal(1, "RV64 program failed code=%0d", test_code);
                $display("PASS tb_core_rv64i cycles=%0d", cycles);
                $finish;
            end
        end
        $fatal(1, "RV64 directed program timeout");
    end
endmodule
