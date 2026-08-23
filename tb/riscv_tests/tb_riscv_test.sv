// Module: tb_riscv_test
// Description: Loads an upstream riscv-test image and reports its MMIO PASS/FAIL result.
module tb_riscv_test;
    import core_config_pkg::*;

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
    string imem_path;
    string dmem_path;
    string test_name;
    integer max_cycles;
    integer cycles;
    logic trace_enable;

    always #5 clk = ~clk;
    sim_cpu_top dut (.*);

    initial begin
        if (!$value$plusargs("IMEM=%s", imem_path))
            $fatal(1, "missing +IMEM=<path>");
        if (!$value$plusargs("DMEM=%s", dmem_path))
            $fatal(1, "missing +DMEM=<path>");
        if (!$value$plusargs("TEST=%s", test_name))
            test_name = "unnamed";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 200000;
        trace_enable = $test$plusargs("TRACE");

        $readmemh(imem_path, dut.u_imem.mem);
        $readmemh(dmem_path, dut.u_dmem.mem);
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        for (cycles = 0; cycles < max_cycles; cycles = cycles + 1) begin
            @(posedge clk);
            if (trace_enable && commit_valid)
                $display("COMMIT pc=%h inst=%h rd=%0d we=%0b data=%h exc=%0b",
                         commit_pc, commit_inst, commit_rd, commit_rd_we,
                         commit_rd_data, commit_exception);
            if (test_done) begin
                assert (test_pass)
                    else $fatal(1, "FAIL %s code=%0d pc=%h inst=%h",
                                test_name, test_code, commit_pc, commit_inst);
                $display("PASS %s RV%0d cycles=%0d", test_name, XLEN, cycles);
                $finish;
            end
        end
        $fatal(1, "TIMEOUT %s cycles=%0d pc=%h inst=%h",
               test_name, max_cycles, commit_pc, commit_inst);
    end

    logic unused_commit;
    assign unused_commit = ^{commit_rd, commit_rd_we, commit_rd_data,
                             commit_exception};
endmodule
