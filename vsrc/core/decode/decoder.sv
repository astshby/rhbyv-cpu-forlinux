// Module: decoder
// Description: Converts a canonical 32-bit instruction into a typed uOp.
module decoder (
    input  logic [31:0]              inst,
    output core_types_pkg::uop_t     uop,
    output core_types_pkg::gpr_addr_t rs1,
    output core_types_pkg::gpr_addr_t rs2,
    output core_types_pkg::gpr_addr_t rd,
    output core_types_pkg::csr_addr_t csr_addr
);
    import core_types_pkg::*;
    import core_config_pkg::*;
    import riscv_isa_pkg::*;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = inst[6:0];
        funct3 = inst[14:12];
        funct7 = inst[31:25];
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        rd = inst[11:7];
        csr_addr = inst[31:20];
        uop = '0;
        uop.illegal = 1'b1;

        unique case (opcode)
            OPCODE_LUI: begin
                uop.illegal = 1'b0;
                uop.fu = FU_ALU;
                uop.alu_op = ALU_ADD;
                uop.op_a_sel = OP_A_ZERO;
                uop.op_b_sel = OP_B_IMM;
                uop.gpr_write = 1'b1;
                uop.wb_sel = WB_ALU;
            end
            OPCODE_AUIPC: begin
                uop.illegal = 1'b0;
                uop.fu = FU_ALU;
                uop.alu_op = ALU_ADD;
                uop.op_a_sel = OP_A_PC;
                uop.op_b_sel = OP_B_IMM;
                uop.gpr_write = 1'b1;
                uop.wb_sel = WB_ALU;
            end
            OPCODE_JAL: begin
                uop.illegal = 1'b0;
                uop.fu = FU_BRANCH;
                uop.branch_op = BR_JAL;
                uop.gpr_write = 1'b1;
                uop.wb_sel = WB_SEQ_PC;
            end
            OPCODE_JALR: begin
                if (funct3 == 3'b000) begin
                    uop.illegal = 1'b0;
                    uop.fu = FU_BRANCH;
                    uop.branch_op = BR_JALR;
                    uop.rs1_used = 1'b1;
                    uop.gpr_write = 1'b1;
                    uop.wb_sel = WB_SEQ_PC;
                end
            end
            OPCODE_BRANCH: begin
                uop.fu = FU_BRANCH;
                uop.rs1_used = 1'b1;
                uop.rs2_used = 1'b1;
                unique case (funct3)
                    3'b000: begin uop.branch_op = BR_EQ;  uop.illegal = 1'b0; end
                    3'b001: begin uop.branch_op = BR_NE;  uop.illegal = 1'b0; end
                    3'b100: begin uop.branch_op = BR_LT;  uop.illegal = 1'b0; end
                    3'b101: begin uop.branch_op = BR_GE;  uop.illegal = 1'b0; end
                    3'b110: begin uop.branch_op = BR_LTU; uop.illegal = 1'b0; end
                    3'b111: begin uop.branch_op = BR_GEU; uop.illegal = 1'b0; end
                    default: ;
                endcase
            end
            OPCODE_LOAD: begin
                uop.fu = FU_LSU;
                uop.alu_op = ALU_ADD;
                uop.op_a_sel = OP_A_RS1;
                uop.op_b_sel = OP_B_IMM;
                uop.rs1_used = 1'b1;
                uop.gpr_write = 1'b1;
                uop.mem_read = 1'b1;
                uop.wb_sel = WB_LOAD;
                unique case (funct3)
                    3'b000: begin uop.mem_size = MEM_BYTE; uop.illegal = 1'b0; end
                    3'b001: begin uop.mem_size = MEM_HALF; uop.illegal = 1'b0; end
                    3'b010: begin uop.mem_size = MEM_WORD; uop.illegal = 1'b0; end
                    3'b011: if (XLEN == 64) begin uop.mem_size = MEM_DWORD; uop.illegal = 1'b0; end
                    3'b100: begin uop.mem_size = MEM_BYTE; uop.load_unsigned = 1'b1; uop.illegal = 1'b0; end
                    3'b101: begin uop.mem_size = MEM_HALF; uop.load_unsigned = 1'b1; uop.illegal = 1'b0; end
                    3'b110: if (XLEN == 64) begin
                        uop.mem_size = MEM_WORD;
                        uop.load_unsigned = 1'b1;
                        uop.illegal = 1'b0;
                    end
                    default: ;
                endcase
            end
            OPCODE_STORE: begin
                uop.fu = FU_LSU;
                uop.alu_op = ALU_ADD;
                uop.op_a_sel = OP_A_RS1;
                uop.op_b_sel = OP_B_IMM;
                uop.rs1_used = 1'b1;
                uop.rs2_used = 1'b1;
                uop.mem_write = 1'b1;
                unique case (funct3)
                    3'b000: begin uop.mem_size = MEM_BYTE; uop.illegal = 1'b0; end
                    3'b001: begin uop.mem_size = MEM_HALF; uop.illegal = 1'b0; end
                    3'b010: begin uop.mem_size = MEM_WORD; uop.illegal = 1'b0; end
                    3'b011: if (XLEN == 64) begin uop.mem_size = MEM_DWORD; uop.illegal = 1'b0; end
                    default: ;
                endcase
            end
            OPCODE_OP_IMM: begin
                uop.fu = FU_ALU;
                uop.op_a_sel = OP_A_RS1;
                uop.op_b_sel = OP_B_IMM;
                uop.rs1_used = 1'b1;
                uop.gpr_write = 1'b1;
                uop.wb_sel = WB_ALU;
                unique case (funct3)
                    3'b000: begin uop.alu_op = ALU_ADD;  uop.illegal = 1'b0; end
                    3'b010: begin uop.alu_op = ALU_SLT;  uop.illegal = 1'b0; end
                    3'b011: begin uop.alu_op = ALU_SLTU; uop.illegal = 1'b0; end
                    3'b100: begin uop.alu_op = ALU_XOR;  uop.illegal = 1'b0; end
                    3'b110: begin uop.alu_op = ALU_OR;   uop.illegal = 1'b0; end
                    3'b111: begin uop.alu_op = ALU_AND;  uop.illegal = 1'b0; end
                    3'b001: begin
                        if (((XLEN == 32) && (funct7 == 7'b0000000)) ||
                            ((XLEN == 64) && (inst[31:26] == 6'b000000))) begin
                            uop.alu_op = ALU_SLL;
                            uop.illegal = 1'b0;
                        end
                    end
                    3'b101: begin
                        if (((XLEN == 32) && (funct7 == 7'b0000000)) ||
                            ((XLEN == 64) && (inst[31:26] == 6'b000000))) begin
                            uop.alu_op = ALU_SRL;
                            uop.illegal = 1'b0;
                        end else if (((XLEN == 32) && (funct7 == 7'b0100000)) ||
                                     ((XLEN == 64) && (inst[31:26] == 6'b010000))) begin
                            uop.alu_op = ALU_SRA;
                            uop.illegal = 1'b0;
                        end
                    end
                    default: ;
                endcase
            end
            OPCODE_OP_IMM_32: begin
                if (XLEN == 64) begin
                    uop.fu = FU_ALU;
                    uop.op_a_sel = OP_A_RS1;
                    uop.op_b_sel = OP_B_IMM;
                    uop.op_width = OP_WIDTH_WORD;
                    uop.rs1_used = 1'b1;
                    uop.gpr_write = 1'b1;
                    uop.wb_sel = WB_ALU;
                    unique case (funct3)
                        3'b000: begin uop.alu_op = ALU_ADD; uop.illegal = 1'b0; end
                        3'b001: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SLL; uop.illegal = 1'b0; end
                        3'b101: begin
                            if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SRL; uop.illegal = 1'b0; end
                            else if (funct7 == 7'b0100000) begin uop.alu_op = ALU_SRA; uop.illegal = 1'b0; end
                        end
                        default: ;
                    endcase
                end
            end
            OPCODE_OP: begin
                uop.fu = FU_ALU;
                uop.op_a_sel = OP_A_RS1;
                uop.op_b_sel = OP_B_RS2;
                uop.rs1_used = 1'b1;
                uop.rs2_used = 1'b1;
                uop.gpr_write = 1'b1;
                uop.wb_sel = WB_ALU;
                unique case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            uop.alu_op = ALU_ADD;
                            uop.illegal = 1'b0;
                        end else if (funct7 == 7'b0100000) begin
                            uop.alu_op = ALU_SUB;
                            uop.illegal = 1'b0;
                        end
                    end
                    3'b001: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SLL;  uop.illegal = 1'b0; end
                    3'b010: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SLT;  uop.illegal = 1'b0; end
                    3'b011: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SLTU; uop.illegal = 1'b0; end
                    3'b100: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_XOR;  uop.illegal = 1'b0; end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SRL; uop.illegal = 1'b0; end
                        else if (funct7 == 7'b0100000) begin uop.alu_op = ALU_SRA; uop.illegal = 1'b0; end
                    end
                    3'b110: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_OR;   uop.illegal = 1'b0; end
                    3'b111: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_AND;  uop.illegal = 1'b0; end
                    default: ;
                endcase
            end
            OPCODE_OP_32: begin
                if (XLEN == 64) begin
                    uop.fu = FU_ALU;
                    uop.op_a_sel = OP_A_RS1;
                    uop.op_b_sel = OP_B_RS2;
                    uop.op_width = OP_WIDTH_WORD;
                    uop.rs1_used = 1'b1;
                    uop.rs2_used = 1'b1;
                    uop.gpr_write = 1'b1;
                    uop.wb_sel = WB_ALU;
                    unique case (funct3)
                        3'b000: begin
                            if (funct7 == 7'b0000000) begin uop.alu_op = ALU_ADD; uop.illegal = 1'b0; end
                            else if (funct7 == 7'b0100000) begin uop.alu_op = ALU_SUB; uop.illegal = 1'b0; end
                        end
                        3'b001: if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SLL; uop.illegal = 1'b0; end
                        3'b101: begin
                            if (funct7 == 7'b0000000) begin uop.alu_op = ALU_SRL; uop.illegal = 1'b0; end
                            else if (funct7 == 7'b0100000) begin uop.alu_op = ALU_SRA; uop.illegal = 1'b0; end
                        end
                        default: ;
                    endcase
                end
            end
            OPCODE_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    unique case (inst)
                        32'h0000_0073: begin uop.is_ecall = 1'b1; uop.illegal = 1'b0; end
                        32'h0010_0073: begin uop.is_ebreak = 1'b1; uop.illegal = 1'b0; end
                        32'h3020_0073: begin uop.is_mret = 1'b1; uop.illegal = 1'b0; end
                        default: ;
                    endcase
                end else begin
                    uop.fu = FU_CSR;
                    uop.csr_valid = 1'b1;
                    uop.csr_imm = funct3[2];
                    uop.rs1_used = !funct3[2] && (rs1 != '0);
                    uop.gpr_write = 1'b1;
                    uop.wb_sel = WB_CSR;
                    unique case (funct3)
                        3'b001, 3'b101: begin
                            uop.csr_cmd = CSR_RW;
                            uop.csr_write = 1'b1;
                            uop.illegal = 1'b0;
                        end
                        3'b010, 3'b110: begin
                            uop.csr_cmd = CSR_RS;
                            uop.csr_write = (rs1 != '0);
                            uop.illegal = 1'b0;
                        end
                        3'b011, 3'b111: begin
                            uop.csr_cmd = CSR_RC;
                            uop.csr_write = (rs1 != '0);
                            uop.illegal = 1'b0;
                        end
                        default: ;
                    endcase
                end
            end
            OPCODE_MISC_MEM: begin
                if ((funct3 == 3'b000) || (funct3 == 3'b001))
                    uop.illegal = 1'b0;
            end
            default: ;
        endcase
    end
endmodule
