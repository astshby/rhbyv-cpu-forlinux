// Module: operand_bypass
// Description: Selects the newest available GPR value for an EX operand.
// 输入mem，wb（使用，地址，数据）与自身的使用，地址，数据，输出前递后的数据
module operand_bypass (
    input  core_types_pkg::gpr_addr_t source_addr,
    input  logic                      source_used,
    input  core_types_pkg::xlen_t     original_data,
    input  logic                      mem_valid,
    input  core_types_pkg::gpr_addr_t mem_addr,
    input  core_types_pkg::xlen_t     mem_data,
    input  logic                      wb_valid,
    input  core_types_pkg::gpr_addr_t wb_addr,
    input  core_types_pkg::xlen_t     wb_data,
    output core_types_pkg::xlen_t     forwarded_data
);
    always_comb begin
        forwarded_data = original_data;
        if (source_used && wb_valid && (wb_addr != '0) && (wb_addr == source_addr))
            forwarded_data = wb_data;
        if (source_used && mem_valid && (mem_addr != '0) && (mem_addr == source_addr))
            forwarded_data = mem_data;
    end
endmodule
