// Module: csr_warl
// Description: Legalizes writable CSR values before forwarding and architectural commit.
module csr_warl (
    input  core_types_pkg::csr_addr_t address,
    input  core_types_pkg::xlen_t    proposed_value,
    output core_types_pkg::xlen_t    legal_value
);
    import core_types_pkg::*;
    import riscv_isa_pkg::*;

    always_comb begin
        legal_value = proposed_value;
        unique case (address)
            CSR_MSTATUS: begin
                legal_value = '0;
                legal_value[3] = proposed_value[3];
                legal_value[7] = proposed_value[7];
                legal_value[12:11] = 2'b11;
            end
            CSR_MTVEC, CSR_MEPC: legal_value = proposed_value & ~xlen_t'(3);
            default: ;
        endcase
    end
endmodule
