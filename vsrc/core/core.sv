// Module: core
// Description: Portable single-issue IF-D1-D2-EX-MEM-WB in-order core.
module core (
    input  logic                              clk,
    input  logic                              rst,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0] imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output logic [core_config_pkg::XLEN-1:0] dmem_req_addr,
    output logic [core_config_pkg::XLEN-1:0] dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    input  logic                              dmem_rsp_valid,
    input  logic [core_config_pkg::XLEN-1:0] dmem_rsp_rdata,
    output logic                              commit_valid,
    output logic [core_config_pkg::XLEN-1:0] commit_pc,
    output logic [31:0]                       commit_inst,
    output logic [core_config_pkg::GPR_ADDR_W-1:0] commit_rd,
    output logic                              commit_rd_we,
    output logic [core_config_pkg::XLEN-1:0] commit_rd_data,
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
    pred_update_t d1_update_raw;
    pred_update_t ex_update_raw;
    pred_update_t d1_update;
    pred_update_t ex_update;
    pred_update_t predictor_update;

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
    logic d1_stage_advance;
    logic ex_stage_advance;
    logic predictor_overflow;
    logic d1_serialize;
    logic ex_serialize;
    logic serial_pending_q;
    logic fetch_enable;

    xlen_t csr_committed_data;
    xlen_t csr_old_data;
    xlen_t mtvec;
    xlen_t mepc;
    logic csr_implemented;
    logic csr_read_only;
    logic csr_access_illegal;
    logic csr_write_valid;
    logic trap_enter;
    logic mret_commit;
    xlen_t trap_pc;
    exc_cause_e trap_cause;
    xlen_t trap_tval;
    logic retire_valid;

    initial begin
        assert ((XLEN == 32) || (XLEN == 64))
            else $error("CORE_XLEN must be 32 or 64");
    end

    always_comb begin
        ex_serialize = d2_ex_q.valid && ex_packet.exc.valid;
        d1_stage_advance = if_d1_q.valid && !mem_stall && !data_stall &&
                           !ex_redirect.valid && !ex_serialize && !wb_redirect.valid;
        d1_serialize = d1_stage_advance &&
                       (d1_packet.exc.valid || d1_packet.uop.is_mret);
        d1_redirect = d1_redirect_raw;
        if (!d1_stage_advance)
            d1_redirect.valid = 1'b0;
        fetch_ready = !hold_front;
        fetch_enable = !serial_pending_q && !d1_serialize && !ex_serialize;
        ex_stage_advance = d2_ex_q.valid && !mem_stall && !wb_redirect.valid;
        d1_update = d1_update_raw;
        ex_update = ex_update_raw;
        d1_update.valid = d1_update_raw.valid && d1_stage_advance;
        ex_update.valid = ex_update_raw.valid && ex_stage_advance && !ex_packet.exc.valid;

        csr_old_data = csr_committed_data;
        if (mem_wb_q.valid && mem_wb_q.csr_we && !mem_wb_q.exc.valid &&
            (mem_wb_q.csr_addr == d2_ex_q.csr_addr))
            csr_old_data = mem_wb_q.csr_new;
        if (ex_mem_q.valid && ex_mem_q.csr_we && !ex_mem_q.exc.valid &&
            (ex_mem_q.csr_addr == d2_ex_q.csr_addr))
            csr_old_data = ex_mem_q.csr_new;

        csr_write_valid = mem_wb_q.valid && mem_wb_q.csr_we &&
                          !mem_wb_q.exc.valid;
    end

    predictor u_predictor (
        .clk,
        .rst,
        .lookup_pc(imem_req_addr),
        .prediction,
        .update(predictor_update)
    );

    predictor_update_arbiter u_predictor_update_arbiter (
        .clk,
        .rst,
        .d1_update,
        .ex_update,
        .update(predictor_update),
        .overflow(predictor_overflow)
    );

    if_stage u_if_stage (
        .clk,
        .rst,
        .fetch_enable,
        .out_ready(fetch_ready),
        .flush(d1_serialize || ex_serialize),
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
        .redirect(d1_redirect_raw),
        .pred_update(d1_update_raw)
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
        .csr_old_data,
        .csr_access_illegal,
        .out_packet(ex_packet),
        .redirect(ex_redirect),
        .pred_update(ex_update_raw),
        .forwarded_rs1,
        .forwarded_rs2
    );

    csr_access_check u_csr_access_check (
        .address(d2_ex_q.csr_addr),
        .write_intent(d2_ex_q.uop.csr_write),
        .implemented(csr_implemented),
        .read_only(csr_read_only),
        .illegal(csr_access_illegal)
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

    trap_controller u_trap_controller (
        .commit_packet(mem_wb_q),
        .mtvec,
        .mepc,
        .trap_enter,
        .mret_commit,
        .trap_pc,
        .trap_cause,
        .trap_tval,
        .retire_valid,
        .redirect(wb_redirect)
    );

    csr_file u_csr_file (
        .clk,
        .rst,
        .read_addr(d2_ex_q.csr_addr),
        .read_data(csr_committed_data),
        .write_valid(csr_write_valid),
        .write_addr(mem_wb_q.csr_addr),
        .write_data(mem_wb_q.csr_new),
        .retire_valid,
        .trap_enter,
        .trap_pc,
        .trap_cause,
        .trap_tval,
        .mret_commit,
        .mtvec,
        .mepc
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
        .ex_serialize,
        .d1_serialize,
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
            serial_pending_q <= 1'b0;
        end else begin
            assert (!predictor_overflow)
                else $error("predictor update pending buffer overflow");
            if (wb_redirect.valid) begin
                mem_wb_q.valid <= 1'b0;
                serial_pending_q <= 1'b0;
            end else begin
                mem_wb_q <= mem_packet;
                if (d1_serialize || ex_serialize)
                    serial_pending_q <= 1'b1;
            end

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

    logic unused_debug;
    assign unused_debug = ^{forwarded_rs1, forwarded_rs2, csr_implemented, csr_read_only};
endmodule
