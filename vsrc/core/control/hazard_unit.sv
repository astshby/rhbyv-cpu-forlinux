// Module: hazard_unit
// Description: Detects a D2 consumer whose EX producer is an unresolved load.
module hazard_unit (
    input  pipeline_pkg::d2_ex_t producer,
    input  pipeline_pkg::d1_d2_t consumer,
    output logic                  stall_request
);
    logic rs1_hazard;
    logic rs2_hazard;

    always_comb begin
        rs1_hazard = consumer.uop.rs1_used && (consumer.rs1 == producer.rd);
        rs2_hazard = consumer.uop.rs2_used && (consumer.rs2 == producer.rd);
        stall_request = producer.valid && producer.uop.mem_read &&
                        producer.uop.gpr_write && (producer.rd != '0) &&
                        consumer.valid && (rs1_hazard || rs2_hazard);
    end
endmodule
