// Module: tb_predictor
// Description: Checks BTB allocation, JAL prediction, and saved-index GShare training.
module tb_predictor;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    xlen_t lookup_pc;
    pred_info_t prediction;
    pred_update_t update;
    logic [core_config_pkg::PHT_IDX_W-1:0] saved_idx;

    always #5 clk = ~clk;
    predictor dut (.*);

    initial begin
        lookup_pc = xlen_t'(32'h100);
        update = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        #1;
        assert (!prediction.hit) else $fatal(1, "unexpected BTB hit after reset");

        update.valid = 1'b1;
        update.kind = BR_JAL;
        update.pc = lookup_pc;
        update.taken = 1'b1;
        update.target = xlen_t'(32'h180);
        @(posedge clk); #1;
        update.valid = 1'b0;
        assert (prediction.hit && prediction.taken && prediction.target == xlen_t'(32'h180))
            else $fatal(1, "JAL prediction");

        lookup_pc = xlen_t'(32'h104); #1;
        saved_idx = prediction.pht_idx;
        update.valid = 1'b1;
        update.kind = BR_EQ;
        update.pc = lookup_pc;
        update.target = xlen_t'(32'h120);
        update.taken = 1'b0;
        update.pred = prediction;
        @(posedge clk); #1;
        assert (dut.u_gshare.pht_q[saved_idx] == 2'b00) else $fatal(1, "not-taken training");
        update.taken = 1'b1;
        update.pred.pht_idx = saved_idx;
        @(posedge clk); #1;
        @(posedge clk); #1;
        update.valid = 1'b0;
        assert (dut.u_gshare.pht_q[saved_idx] == 2'b10) else $fatal(1, "saved-index training");
        $display("PASS tb_predictor");
        $finish;
    end
endmodule
