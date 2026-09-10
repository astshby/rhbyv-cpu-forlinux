// Module: tb_sim_test_device
// Description: Checks byte strobes and the 32-bit MMIO termination protocol.
module tb_sim_test_device;
    timeunit 1ns;
    timeprecision 1ps;
    import core_config_pkg::*;

    logic clk = 0;
    logic rst = 1;
    logic req_valid = 0;
    logic req_write = 0;
    logic [XLEN-1:0] req_wdata = '0;
    logic [DBUS_BYTES-1:0] req_wstrb = '0;
    logic req_ready, rsp_valid, rsp_ready, test_done, test_pass;
    logic [XLEN-1:0] rsp_rdata;
    logic [31:0] test_code;

    always #5 clk = ~clk;
    sim_test_device dut (.*);

    task automatic write_code(input logic [DBUS_BYTES-1:0] mask,
                              input logic [XLEN-1:0] data);
        @(negedge clk);
        req_valid = 1;
        req_write = 1;
        req_wstrb = mask;
        req_wdata = data;
        @(negedge clk);
        req_valid = 0;
    endtask

    initial begin
        rsp_ready = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        write_code(DBUS_BYTES'(0), XLEN'(1));
        assert (!test_done) else $fatal(1, "zero strobe terminated test");
        write_code(DBUS_BYTES'(1), XLEN'(1));
        assert (!test_done) else $fatal(1, "byte write terminated test");
        write_code(DBUS_BYTES'(3), XLEN'(1));
        assert (!test_done) else $fatal(1, "halfword write terminated test");
        write_code(DBUS_BYTES'(15), XLEN'(64'hffff_ffff_0000_0001));
        assert (test_done && test_pass && test_code == 1)
            else $fatal(1, "32-bit success code rejected");
        write_code('1, XLEN'(2));
        assert (test_done && !test_pass && test_code == 2)
            else $fatal(1, "failure code not captured");
        $display("PASS tb_sim_test_device RV%0d", XLEN);
        $finish;
    end
endmodule
