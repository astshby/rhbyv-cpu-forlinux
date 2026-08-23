// Module: tb_core_predictor
// Description: Runs a branch-heavy loop and checks that trained prediction reduces redirects.
module tb_core_predictor;
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
    integer branch_count;
    integer redirect_count;

    always #5 clk = ~clk;
    sim_cpu_top dut (.*);

    always_ff @(posedge clk) begin
        if (rst) begin
            branch_count <= 0;
            redirect_count <= 0;
        end else begin
            if (commit_valid && (commit_inst[6:0] == 7'b1100011))
                branch_count <= branch_count + 1;
            if (dut.u_core.selected_redirect.valid)
                redirect_count <= redirect_count + 1;
        end
    end

    initial begin
        for (idx = 0; idx < 128; idx = idx + 1)
            dut.u_imem.mem[idx] = nop();
        dut.u_imem.mem[0]  = enc_i(0, 5'd0, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[1]  = enc_i(20, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.u_imem.mem[2]  = enc_i(1, 5'd1, 3'b000, 5'd1, 7'b0010011);
        dut.u_imem.mem[3]  = enc_b(-4, 5'd2, 5'd1, 3'b100);
        dut.u_imem.mem[4]  = enc_b(24, 5'd2, 5'd1, 3'b001);
        dut.u_imem.mem[5]  = enc_j(8, 5'd3);
        dut.u_imem.mem[6]  = enc_j(16, 5'd0);
        dut.u_imem.mem[7]  = enc_u(20'h10000, 5'd4, 7'b0110111);
        dut.u_imem.mem[8]  = enc_i(1, 5'd0, 3'b000, 5'd5, 7'b0010011);
        dut.u_imem.mem[9]  = enc_s(0, 5'd5, 5'd4, 3'b010);
        dut.u_imem.mem[10] = enc_u(20'h10000, 5'd4, 7'b0110111);
        dut.u_imem.mem[11] = enc_i(2, 5'd0, 3'b000, 5'd5, 7'b0010011);
        dut.u_imem.mem[12] = enc_s(0, 5'd5, 5'd4, 3'b010);
        dut.u_imem.mem[13] = enc_j(0, 5'd0);

        repeat (4) @(posedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < 800; cycles = cycles + 1) begin
            @(posedge clk);
            if (commit_exception)
                $fatal(1, "unexpected exception at pc=%h", commit_pc);
            if (test_done) begin
                assert (test_pass) else $fatal(1, "predictor program failed code=%0d", test_code);
                assert (branch_count >= 20) else $fatal(1, "branch loop did not execute");
                assert (redirect_count < 12)
                    else $fatal(1, "predictor did not converge redirects=%0d", redirect_count);
                $display("PASS tb_core_predictor branches=%0d redirects=%0d", branch_count, redirect_count);
                $finish;
            end
        end
        $fatal(1, "predictor program timeout");
    end
endmodule
