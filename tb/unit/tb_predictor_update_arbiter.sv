// Module: tb_predictor_update_arbiter
// Description: Checks EX priority and deferred delivery of a simultaneous D1 update.
module tb_predictor_update_arbiter;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    pred_update_t d1_update;
    pred_update_t ex_update;
    pred_update_t update;
    logic overflow;

    always #5 clk = ~clk;
    predictor_update_arbiter dut (.*);

    initial begin
        d1_update = '0;
        ex_update = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        d1_update.valid = 1'b1;
        d1_update.kind = BR_JAL;
        d1_update.pc = core_types_pkg::xlen_t'(32'h20);
        ex_update.valid = 1'b1;
        ex_update.kind = BR_EQ;
        ex_update.pc = core_types_pkg::xlen_t'(32'h10);
        #1;
        assert (update.pc == ex_update.pc && !overflow) else $fatal(1, "EX priority");
        @(posedge clk); #1;
        d1_update.valid = 1'b0;
        ex_update.valid = 1'b0;
        #1;
        assert (update.valid && update.pc == core_types_pkg::xlen_t'(32'h20))
            else $fatal(1, "pending D1 update");
        $display("PASS tb_predictor_update_arbiter");
        $finish;
    end
endmodule
