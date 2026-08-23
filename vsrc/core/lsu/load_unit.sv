// Module: load_unit
// Description: Selects a byte lane and applies RV load sign or zero extension.
module load_unit (
    input  core_types_pkg::xlen_t     bus_data,
    input  core_types_pkg::xlen_t     address,
    input  core_types_pkg::mem_size_e size,
    input  logic                       unsigned_load,
    output core_types_pkg::xlen_t     load_data
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    localparam int unsigned OFFSET_W = $clog2(DBUS_BYTES);
    xlen_t shifted_data;

    always_comb begin
        shifted_data = bus_data >> (8 * address[OFFSET_W-1:0]);
        unique case (size)
            MEM_BYTE: begin
                if (unsigned_load)
                    load_data = xlen_t'(shifted_data[7:0]);
                else
                    load_data = {{(XLEN-8){shifted_data[7]}}, shifted_data[7:0]};
            end
            MEM_HALF: begin
                if (unsigned_load)
                    load_data = xlen_t'(shifted_data[15:0]);
                else
                    load_data = {{(XLEN-16){shifted_data[15]}}, shifted_data[15:0]};
            end
            MEM_WORD: begin
                if (unsigned_load)
                    load_data = xlen_t'(shifted_data[31:0]);
                else
                    load_data = {{(XLEN-32){shifted_data[31]}}, shifted_data[31:0]};
            end
            default:
                load_data = shifted_data;
        endcase
    end
endmodule
