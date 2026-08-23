// Module: csr_file
// Description: Implements the minimal machine CSR state, counters, trap entry, and MRET state.
module csr_file (
    input  logic                        clk,
    input  logic                        rst,
    input  core_types_pkg::csr_addr_t  read_addr,
    output core_types_pkg::xlen_t      read_data,
    input  logic                        write_valid,
    input  core_types_pkg::csr_addr_t  write_addr,
    input  core_types_pkg::xlen_t      write_data,
    input  logic                        retire_valid,
    input  logic                        trap_enter,
    input  core_types_pkg::xlen_t      trap_pc,
    input  pipeline_pkg::exc_cause_e   trap_cause,
    input  core_types_pkg::xlen_t      trap_tval,
    input  logic                        mret_commit,
    output core_types_pkg::xlen_t      mtvec,
    output core_types_pkg::xlen_t      mepc
);
    import core_config_pkg::*;
    import core_types_pkg::*;
    import riscv_isa_pkg::*;

    xlen_t mstatus_q;
    xlen_t mtvec_q;
    xlen_t mscratch_q;
    xlen_t mepc_q;
    xlen_t mcause_q;
    xlen_t mtval_q;
    xlen_t mcycle_q;
    xlen_t minstret_q;

    function automatic xlen_t misa_value();
        xlen_t value;
        value = '0;
        value[XLEN-1 -: 2] = (XLEN == 32) ? 2'b01 : 2'b10;
        value[8] = 1'b1;
        return value;
    endfunction

    function automatic xlen_t make_mstatus(input logic mie, input logic mpie);
        xlen_t sanitized;
        sanitized = '0;
        sanitized[3] = mie;
        sanitized[7] = mpie;
        sanitized[12:11] = 2'b11;
        return sanitized;
    endfunction

    assign mtvec = mtvec_q;
    assign mepc = mepc_q;

    always_comb begin
        unique case (read_addr)
            CSR_MSTATUS:  read_data = mstatus_q;
            CSR_MISA:     read_data = misa_value();
            CSR_MTVEC:    read_data = mtvec_q;
            CSR_MSCRATCH: read_data = mscratch_q;
            CSR_MEPC:     read_data = mepc_q;
            CSR_MCAUSE:   read_data = mcause_q;
            CSR_MTVAL:    read_data = mtval_q;
            CSR_MCYCLE:   read_data = mcycle_q;
            CSR_MINSTRET: read_data = minstret_q;
            CSR_MHARTID:  read_data = '0;
            default:      read_data = '0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mstatus_q <= make_mstatus(1'b0, 1'b0);
            mtvec_q <= '0;
            mscratch_q <= '0;
            mepc_q <= '0;
            mcause_q <= '0;
            mtval_q <= '0;
            mcycle_q <= '0;
            minstret_q <= '0;
        end else begin
            mcycle_q <= mcycle_q + xlen_t'(1);
            if (retire_valid)
                minstret_q <= minstret_q + xlen_t'(1);

            if (write_valid) begin
                unique case (write_addr)
                    CSR_MSTATUS:  mstatus_q <= make_mstatus(write_data[3], write_data[7]);
                    CSR_MTVEC:    mtvec_q <= write_data & ~xlen_t'(3);
                    CSR_MSCRATCH: mscratch_q <= write_data;
                    CSR_MEPC:     mepc_q <= write_data & ~xlen_t'(3);
                    CSR_MCAUSE:   mcause_q <= write_data;
                    CSR_MTVAL:    mtval_q <= write_data;
                    CSR_MCYCLE:   mcycle_q <= write_data;
                    CSR_MINSTRET: minstret_q <= write_data;
                    default: ;
                endcase
            end

            if (mret_commit) begin
                mstatus_q[3] <= mstatus_q[7];
                mstatus_q[7] <= 1'b1;
                mstatus_q[12:11] <= 2'b11;
            end

            if (trap_enter) begin
                mepc_q <= trap_pc & ~xlen_t'(3);
                mcause_q <= xlen_t'(trap_cause);
                mtval_q <= trap_tval;
                mstatus_q[7] <= mstatus_q[3];
                mstatus_q[3] <= 1'b0;
                mstatus_q[12:11] <= 2'b11;
            end
        end
    end
endmodule
