// Module: mem_stage
// Description: Executes one outstanding data-memory transaction and forms WB data.
module mem_stage (
    input  logic                              clk,
    input  logic                              rst,
    input  pipeline_pkg::ex_mem_t            in_packet,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output core_types_pkg::xlen_t            dmem_req_addr,
    output core_types_pkg::xlen_t            dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    input  logic                              dmem_rsp_valid,
    input  core_types_pkg::xlen_t            dmem_rsp_rdata,
    output pipeline_pkg::mem_wb_t            out_packet,
    output logic                              stall,
    output logic                              forward_valid,
    output core_types_pkg::gpr_addr_t        forward_addr,
    output core_types_pkg::xlen_t            forward_data
);
    import core_types_pkg::*;

    logic load_pending_q;
    logic transaction_complete;
    xlen_t load_data;
    xlen_t store_wdata;
    logic [core_config_pkg::DBUS_BYTES-1:0] store_wstrb;

    load_unit u_load_unit (
        .bus_data(dmem_rsp_rdata),
        .address(in_packet.result),
        .size(in_packet.uop.mem_size),
        .unsigned_load(in_packet.uop.load_unsigned),
        .load_data
    );

    store_unit u_store_unit (
        .store_data(in_packet.store_data),
        .address(in_packet.result),
        .size(in_packet.uop.mem_size),
        .bus_wdata(store_wdata),
        .bus_wstrb(store_wstrb)
    );

    always_comb begin
        dmem_req_valid = in_packet.valid &&
                         (in_packet.uop.mem_read || in_packet.uop.mem_write) &&
                         !in_packet.exc.valid && !load_pending_q;
        dmem_req_write = in_packet.uop.mem_write;
        dmem_req_addr = in_packet.result;
        dmem_req_wdata = store_wdata;
        dmem_req_wstrb = store_wstrb;

        transaction_complete = 1'b1;
        if (in_packet.valid && !in_packet.exc.valid && in_packet.uop.mem_write)
            transaction_complete = dmem_req_valid && dmem_req_ready;
        else if (in_packet.valid && !in_packet.exc.valid && in_packet.uop.mem_read)
            transaction_complete = load_pending_q && dmem_rsp_valid;

        stall = in_packet.valid && !transaction_complete;
        out_packet = '0;
        out_packet.valid = in_packet.valid && transaction_complete;
        out_packet.pc = in_packet.pc;
        out_packet.seq_pc = in_packet.seq_pc;
        out_packet.inst = in_packet.inst;
        out_packet.rd = in_packet.rd;
        out_packet.csr_addr = in_packet.csr_addr;
        out_packet.csr_old = in_packet.csr_old;
        out_packet.csr_new = in_packet.csr_new;
        out_packet.csr_we = in_packet.csr_we;
        out_packet.uop = in_packet.uop;
        out_packet.exc = in_packet.exc;
        unique case (in_packet.uop.wb_sel)
            WB_LOAD:   out_packet.wb_data = load_data;
            WB_SEQ_PC: out_packet.wb_data = in_packet.seq_pc;
            WB_CSR:    out_packet.wb_data = in_packet.csr_old;
            default:   out_packet.wb_data = in_packet.result;
        endcase

        forward_valid = out_packet.valid && out_packet.uop.gpr_write &&
                        !out_packet.exc.valid;
        forward_addr = out_packet.rd;
        forward_data = out_packet.wb_data;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            load_pending_q <= 1'b0;
        end else begin
            if (in_packet.valid && !in_packet.exc.valid && in_packet.uop.mem_read &&
                !load_pending_q && dmem_req_valid && dmem_req_ready)
                load_pending_q <= 1'b1;
            if (load_pending_q && dmem_rsp_valid)
                load_pending_q <= 1'b0;
            if (!in_packet.valid || in_packet.exc.valid || !in_packet.uop.mem_read)
                load_pending_q <= 1'b0;
        end
    end
endmodule
