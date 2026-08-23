// Module: store_unit
// Description: Aligns store data and generates byte write strobes.
module store_unit (
    input  core_types_pkg::xlen_t     store_data,
    input  core_types_pkg::xlen_t     address,
    input  core_types_pkg::mem_size_e size,
    output core_types_pkg::xlen_t     bus_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] bus_wstrb
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    localparam int unsigned OFFSET_W = $clog2(DBUS_BYTES);
    logic [DBUS_BYTES-1:0] base_strobe;

    always_comb begin
        unique case (size)
            MEM_BYTE:  base_strobe = DBUS_BYTES'(1);
            MEM_HALF:  base_strobe = DBUS_BYTES'(3);
            MEM_WORD:  base_strobe = DBUS_BYTES'(15);
            default:   base_strobe = '1;
        endcase
        bus_wstrb = base_strobe << address[OFFSET_W-1:0];
        bus_wdata = store_data << (8 * address[OFFSET_W-1:0]);
    end
endmodule
