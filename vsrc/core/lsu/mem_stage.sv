// Module: mem_stage
// Description: Issues one cache-facing memory request and carries metadata toward WB.
// rsp一类的读取在wb阶段进行响应，mem阶段只负责发出请求
module mem_stage (
    input  logic                              issue_enable,  // 表示当前是否允许访存
    output logic                              request_stall, // 表示当前是否需要等待访存响应
    input  pipeline_pkg::ex_mem_t             in_packet,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output core_types_pkg::xlen_t             dmem_req_addr,
    output core_types_pkg::xlen_t             dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    output pipeline_pkg::mem_wb_t             out_packet,
    output logic                              forward_valid,  // 前递数据
    output core_types_pkg::gpr_addr_t         forward_addr,
    output core_types_pkg::xlen_t             forward_data
);
    import core_types_pkg::*;

    logic memory_request;
    logic request_fire;
    logic packet_can_advance;
    xlen_t store_wdata;
    logic [core_config_pkg::DBUS_BYTES-1:0] store_wstrb;

    // store 数据在 MEM 根据地址低位移到对应字节通道。
    store_unit u_store_unit (
        .store_data(in_packet.store_data),
        .address(in_packet.result),
        .size(in_packet.uop.mem_size),
        .bus_wdata(store_wdata),
        .bus_wstrb(store_wstrb)
    );

    // dmem相关请求：只有合法且无异常的 load/store 才能浸润dmem。
    always_comb begin
        // 多重判定
        memory_request = in_packet.valid &&
                         (in_packet.uop.mem_read || in_packet.uop.mem_write) &&
                         !in_packet.exc.valid && !in_packet.uop.illegal;
        dmem_req_valid = issue_enable && memory_request;
        dmem_req_write = in_packet.uop.mem_write;
        dmem_req_addr = in_packet.result;
        dmem_req_wdata = store_wdata;
        dmem_req_wstrb = store_wstrb;
        request_fire = dmem_req_valid && dmem_req_ready;

        // 非访存指令+握手完成前进，有请求但是握手没成功
        packet_can_advance = !memory_request || request_fire;
        request_stall = dmem_req_valid && !dmem_req_ready;
    end

    // load在wb阶段接收数据
    always_comb begin
        out_packet = '0;
        out_packet.valid = issue_enable && in_packet.valid && packet_can_advance;
        out_packet.pc = in_packet.pc;
        out_packet.seq_pc = in_packet.seq_pc;
        out_packet.inst = in_packet.inst;
        out_packet.rd = in_packet.rd;
        out_packet.result = in_packet.result;
        out_packet.csr_addr = in_packet.csr_addr;
        out_packet.csr_old = in_packet.csr_old;
        out_packet.csr_new = in_packet.csr_new;
        out_packet.csr_we = in_packet.csr_we;
        out_packet.uop = in_packet.uop;
        out_packet.exc = in_packet.exc;
    end

    // MEM 前递没有load ，load必须等待 WB 的存储器响应。
    always_comb begin
        unique case (in_packet.uop.wb_sel)
            WB_SEQ_PC: forward_data = in_packet.seq_pc;
            WB_CSR:    forward_data = in_packet.csr_old;
            default:   forward_data = in_packet.result;
        endcase
        // 规避store（不写入）与load
        forward_valid = out_packet.valid && in_packet.uop.gpr_write &&
                        (in_packet.uop.wb_sel != WB_LOAD) &&
                        !in_packet.exc.valid && !in_packet.uop.illegal;
        forward_addr = in_packet.rd;
    end

endmodule
