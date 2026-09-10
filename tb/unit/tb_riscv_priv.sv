// Module: tb_riscv_priv
// Description: Checks privileged instruction, CSR, and trap encodings.
// 用于检查特权级指令编码
module tb_riscv_priv;
    import core_config_pkg::*;
    import riscv_priv_pkg::*;

    initial begin
        assert (INST_MRET == 32'h3020_0073)
            else $fatal(1, "invalid privileged instruction encoding");
        assert (CSR_MIE == 12'h304 && CSR_MIP == 12'h344)
            else $fatal(1, "invalid machine interrupt CSR address");
        assert (MSTATUS_MIE_BIT == 3 && MSTATUS_MPIE_BIT == 7)
            else $fatal(1, "invalid mstatus interrupt field");
        assert (MIE_MTIE_BIT == 7 && MIP_MTIP_BIT == 7)
            else $fatal(1, "invalid machine timer interrupt field");
        assert (MCAUSE_INTERRUPT_BIT == (XLEN - 1))
            else $fatal(1, "invalid mcause interrupt bit");
        assert (EXC_ILLEGAL_INST == 5'd2 && EXC_ECALL_M == 5'd11 &&
                IRQ_M_TIMER == 4'd7)
            else $fatal(1, "invalid trap cause encoding");
        $display("PASS tb_riscv_priv RV%0d", XLEN);
        $finish;
    end
endmodule
