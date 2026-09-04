// Module: core
// Description: Portable single-issue IF-D1-D2-EX-MEM-WB in-order core.
module core (
    // 端口无法导入包，用全称
    input  logic                              clk,
    input  logic                              rst,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0]  imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output logic [core_config_pkg::XLEN-1:0]  dmem_req_addr,
    output logic [core_config_pkg::XLEN-1:0]  dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    input  logic                              dmem_rsp_valid,
    input  logic [core_config_pkg::XLEN-1:0]  dmem_rsp_rdata,
    // commit:一方面便于调试，可以只管看到运行情况与指令，另一方面，用于规定retired指令，便于指令统计与性能测试。
    output logic                              commit_valid,
    output logic [core_config_pkg::XLEN-1:0]  commit_pc,
    output logic [31:0]                       commit_inst,
    output logic [core_config_pkg::GPR_ADDR_W-1:0] commit_rd,
    output logic                              commit_rd_we,
    output logic [core_config_pkg::XLEN-1:0]  commit_rd_data,
    output logic                              commit_exception
);
    import core_config_pkg::*;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    if_d1_t if_d1_q;
    d1_d2_t d1_d2_q;
    d2_ex_t d2_ex_q;
    ex_mem_t ex_mem_q;
    mem_wb_t mem_wb_q;

    if_d1_t fetch_packet;
    d1_d2_t d1_packet;
    d2_ex_t d2_packet;
    ex_mem_t ex_packet;
    mem_wb_t mem_packet;
    pred_info_t prediction;
    redirect_t d1_redirect_raw;
    redirect_t d1_redirect;
    redirect_t ex_redirect;
    redirect_t wb_redirect;
    redirect_t selected_redirect;

    xlen_t rs1_data;
    xlen_t rs2_data;
    logic gpr_write_enable;
    gpr_addr_t gpr_write_addr;
    xlen_t gpr_write_data;
    logic mem_stall;
    logic data_stall;
    logic mem_forward_valid;
    gpr_addr_t mem_forward_addr;
    xlen_t mem_forward_data;
    xlen_t forwarded_rs1;
    xlen_t forwarded_rs2;

    logic hold_front;
    logic hold_d1_d2;
    logic hold_d2_ex;
    logic hold_ex_mem;
    logic bubble_d2_ex;
    logic flush_if_d1;
    logic flush_d1_d2;
    logic flush_d2_ex;
    logic flush_ex_mem;
    logic fetch_ready;

    // 参数断言仅用于仿真与 lint
`ifndef SYNTHESIS
    initial begin
        assert ((XLEN == 32) || (XLEN == 64))
            else $error("CORE_XLEN must be 32 or 64");
    end
`endif

    always_comb begin
        prediction = '0;
        wb_redirect = '0;
        d1_redirect = d1_redirect_raw;
        if (mem_stall || data_stall)
            d1_redirect.valid = 1'b0;
        fetch_ready = !hold_front;
    end

    if_stage u_if_stage (
        .clk,
        .rst,
        .fetch_enable(1'b1),
        .out_ready(fetch_ready),
        .redirect(selected_redirect),
        .prediction,
        .out_packet(fetch_packet),
        .imem_req_valid,
        .imem_req_addr,
        .imem_req_ready,
        .imem_rsp_valid,
        .imem_rsp_data
    );

    d1_stage u_d1_stage (
        .in_packet(if_d1_q),
        .out_packet(d1_packet),
        .redirect(d1_redirect_raw)
    );

    regfile u_regfile (
        .clk,
        .rs1_addr(d1_d2_q.rs1),
        .rs2_addr(d1_d2_q.rs2),
        .rs1_data,
        .rs2_data,
        .write_enable(gpr_write_enable),
        .write_addr(gpr_write_addr),
        .write_data(gpr_write_data)
    );

    d2_stage u_d2_stage (
        .in_packet(d1_d2_q),
        .rs1_data,
        .rs2_data,
        .out_packet(d2_packet)
    );

    ex_stage u_ex_stage (
        .in_packet(d2_ex_q),
        .mem_forward_valid,
        .mem_forward_addr,
        .mem_forward_data,
        .wb_forward_valid(gpr_write_enable),
        .wb_forward_addr(gpr_write_addr),
        .wb_forward_data(gpr_write_data),
        .out_packet(ex_packet),
        .redirect(ex_redirect),
        .forwarded_rs1,
        .forwarded_rs2
    );

    mem_stage u_mem_stage (
        .clk,
        .rst,
        .in_packet(ex_mem_q),
        .dmem_req_valid,
        .dmem_req_write,
        .dmem_req_addr,
        .dmem_req_wdata,
        .dmem_req_wstrb,
        .dmem_req_ready,
        .dmem_rsp_valid,
        .dmem_rsp_rdata,
        .out_packet(mem_packet),
        .stall(mem_stall),
        .forward_valid(mem_forward_valid),
        .forward_addr(mem_forward_addr),
        .forward_data(mem_forward_data)
    );

    wb_stage u_wb_stage (
        .in_packet(mem_wb_q),
        .gpr_write_enable,
        .gpr_write_addr,
        .gpr_write_data,
        .commit_valid,
        .commit_pc,
        .commit_inst,
        .commit_rd,
        .commit_rd_we,
        .commit_rd_data,
        .commit_exception
    );

    hazard_unit u_hazard_unit (
        .producer(d2_ex_q),
        .consumer(d1_d2_q),
        .stall_request(data_stall)
    );

    pipeline_ctrl u_pipeline_ctrl (
        .wb_redirect,
        .ex_redirect,
        .d1_redirect,
        .mem_stall,
        .data_stall,
        .redirect(selected_redirect),
        .hold_front,
        .hold_d1_d2,
        .hold_d2_ex,
        .hold_ex_mem,
        .bubble_d2_ex,
        .flush_if_d1,
        .flush_d1_d2,
        .flush_d2_ex,
        .flush_ex_mem
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            if_d1_q <= '0;
            d1_d2_q <= '0;
            d2_ex_q <= '0;
            ex_mem_q <= '0;
            mem_wb_q <= '0;
        end else begin
            mem_wb_q <= mem_packet;

            if (flush_ex_mem)
                ex_mem_q.valid <= 1'b0;
            else if (!hold_ex_mem)
                ex_mem_q <= ex_packet;

            if (hold_d2_ex) begin
                d2_ex_q <= d2_ex_q;
            end else if (flush_d2_ex || bubble_d2_ex) begin
                d2_ex_q.valid <= 1'b0;
            end else begin
                d2_ex_q <= d2_packet;
            end

            if (flush_d1_d2)
                d1_d2_q.valid <= 1'b0;
            else if (!hold_d1_d2)
                d1_d2_q <= d1_packet;

            if (flush_if_d1)
                if_d1_q.valid <= 1'b0;
            else if (!hold_front)
                if_d1_q <= fetch_packet;
        end
    end

    logic unused_forwarded;
    assign unused_forwarded = ^{forwarded_rs1, forwarded_rs2};
endmodule
