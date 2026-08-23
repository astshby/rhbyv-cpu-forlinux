// Package: core_config_pkg
// Description: Build-time widths and portable core constants.
`ifndef CORE_XLEN
`define CORE_XLEN 32
`endif

package core_config_pkg;
    localparam int unsigned XLEN = `CORE_XLEN;
    localparam int unsigned GPR_NUM = 32;
    localparam int unsigned GPR_ADDR_W = 5;
    localparam int unsigned CSR_ADDR_W = 12;
    localparam int unsigned DBUS_BYTES = XLEN / 8;
    localparam int unsigned BTB_ENTRIES = 16;
    localparam int unsigned BTB_IDX_W = $clog2(BTB_ENTRIES);
    localparam int unsigned PHT_ENTRIES = 16;
    localparam int unsigned PHT_IDX_W = $clog2(PHT_ENTRIES);
    localparam int unsigned GHR_W = PHT_IDX_W;
    localparam logic [XLEN-1:0] RESET_VECTOR = '0;
endpackage
