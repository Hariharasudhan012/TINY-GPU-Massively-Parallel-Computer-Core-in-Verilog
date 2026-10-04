module shader_core #(parameter CORE_ID = 0) (
    input clk,
    input rst,
    input enable,
    input thread_start,
    input [7:0] thread_id,
    input [15:0] instruction,
    output reg [7:0] instr_addr,
    input [7:0] mem_data_in,
    input mem_ready,
    output reg mem_read_en,
    output reg mem_write_en,
    output reg [7:0] mem_addr,
    output reg [7:0] mem_data_out,
    output reg done
);

    // =========================================================
    // STATE DEFINITIONS
    // =========================================================

    localparam S_IDLE    = 3'd0;
    localparam S_FETCH   = 3'd1;
    localparam S_DECODE  = 3'd2;
    localparam S_REQUEST = 3'd3;
    localparam S_WAIT    = 3'd4;
    localparam S_EXECUTE = 3'd5;
    localparam S_UPDATE  = 3'd6;

    // =========================================================
    // OPCODE DEFINITIONS
    // =========================================================

    localparam OP_ADD   = 4'b0000;
    localparam OP_SUB   = 4'b0001;
    localparam OP_MUL   = 4'b0010;
    localparam OP_AND   = 4'b0011;
    localparam OP_OR    = 4'b0100;
    localparam OP_CMP   = 4'b0101;
    localparam OP_LD    = 4'b0110;
    localparam OP_ST    = 4'b0111;
    localparam OP_CONST = 4'b1000;
    localparam OP_JMP   = 4'b1001;
    localparam OP_RET   = 4'b1111;

    // =========================================================
    // INTERNAL REGISTERS
    // =========================================================

    reg [2:0] state;

    reg [3:0] opcode;
    reg [3:0] rd;
    reg [3:0] rs1;
    reg [3:0] rs2;

    reg [7:0] imm;
    reg [2:0] nzp;

    // =========================================================
    // REGISTER FILE CONNECTIONS
    // =========================================================

    wire [15:0] rs1_data;
    wire [15:0] rs2_data;

    reg rf_wr_en;
    reg [3:0] rf_wr_addr;
    reg [15:0] rf_wr_data;

    // =========================================================
    // ALU CONNECTION
    // =========================================================

    wire [15:0] alu_result;

    alu alu_inst (
        .op     (opcode),
        .a      (rs1_data),
        .b      (rs2_data),
        .result (alu_result)
    );

    // =========================================================
    // REGISTER FILE
    // =========================================================

    register_file rf_inst (
        .clk          (clk),
        .rst          (rst),
        .thread_start (thread_start),
        .thread_id    (thread_id),

        .rd_addr1     (rs1),
        .rd_addr2     (rs2),

        .wr_addr      (rf_wr_addr),
        .wr_en        (rf_wr_en),
        .wr_data      (rf_wr_data),

        .rd_data1     (rs1_data),
        .rd_data2     (rs2_data)
    );

    // =========================================================
    // MAIN SHADER CORE FSM
    // =========================================================

    always @(posedge clk) begin

        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        if (rst) begin

            state <= S_IDLE;

            instr_addr <= 8'h00;

            opcode <= 4'h0;
            rd     <= 4'h0;
            rs1    <= 4'h0;
            rs2    <= 4'h0;

            imm <= 8'h00;
            nzp <= 3'b000;

            done <= 1'b0;

            mem_read_en  <= 1'b0;
            mem_write_en <= 1'b0;

            mem_addr     <= 8'h00;
            mem_data_out <= 8'h00;

            rf_wr_en   <= 1'b0;
            rf_wr_addr <= 4'h0;
            rf_wr_data <= 16'h0000;
        end

        // -----------------------------------------------------
        // NORMAL OPERATION
        // -----------------------------------------------------

        else begin

            // Default: write enable and memory request
            // are cleared every clock.
            rf_wr_en      <= 1'b0;
            mem_read_en   <= 1'b0;
            mem_write_en  <= 1'b0;
            done          <= 1'b0;

            // -------------------------------------------------
            // NEW THREAD START
            // -------------------------------------------------

            if (thread_start) begin

                state <= S_FETCH;

                // Start execution from instruction 0
                instr_addr <= 8'h00;
            end

            // -------------------------------------------------
            // CORE ENABLED
            // -------------------------------------------------

            else if (enable) begin

                case (state)

                    // =========================================
                    // IDLE
                    // =========================================

                    S_IDLE: begin
                        // Wait for a new thread
                    end

                    // =========================================
                    // FETCH
                    // =========================================

                    S_FETCH: begin

                        // Instruction is supplied by gpu_top
                        // using instr_addr.

                        state <= S_DECODE;
                    end

                    // =========================================
                    // DECODE
                    // =========================================

                    S_DECODE: begin

                        opcode <= instruction[15:12];

                        rd  <= instruction[11:8];
                        rs1 <= instruction[7:4];
                        rs2 <= instruction[3:0];

                        imm <= instruction[7:0];

                        // Load/store instructions require
                        // memory access.
                        if ((instruction[15:12] == OP_LD) ||
                            (instruction[15:12] == OP_ST)) begin

                            state <= S_REQUEST;
                        end

                        else begin

                            state <= S_EXECUTE;
                        end
                    end

                    // =========================================
                    // MEMORY REQUEST
                    // =========================================

                    S_REQUEST: begin

                        // Address comes from source register
                        mem_addr <= rs1_data[7:0];

                        // LOAD
                        if (opcode == OP_LD) begin

                            mem_read_en <= 1'b1;
                        end

                        // STORE
                        else begin

                            mem_write_en <= 1'b1;

                            mem_data_out <= rs2_data[7:0];
                        end

                        state <= S_WAIT;
                    end

                    // =========================================
                    // WAIT FOR MEMORY CONTROLLER
                    // =========================================
                    //
                    // IMPORTANT FIX:
                    //
                    // Keep the memory request asserted while
                    // waiting for the round-robin controller.
                    //
                    // Previously the request disappeared after
                    // one clock, causing cores 1, 2 and 3 to
                    // remain permanently in S_WAIT.
                    // =========================================

                    S_WAIT: begin

                        // Keep address stable
                        mem_addr <= rs1_data[7:0];

                        // Keep LOAD request active
                        if (opcode == OP_LD) begin

                            mem_read_en <= 1'b1;
                        end

                        // Keep STORE request active
                        else if (opcode == OP_ST) begin

                            mem_write_en <= 1'b1;

                            mem_data_out <= rs2_data[7:0];
                        end

                        // Memory controller granted this core
                        if (mem_ready) begin

                            state <= S_EXECUTE;
                        end
                    end

                    // =========================================
                    // EXECUTE
                    // =========================================

                    S_EXECUTE: begin

                        case (opcode)

                            // ---------------------------------
                            // COMPARE
                            // ---------------------------------

                            OP_CMP: begin

                                if (rs1_data < rs2_data)
                                    nzp <= 3'b100;

                                else if (rs1_data == rs2_data)
                                    nzp <= 3'b010;

                                else
                                    nzp <= 3'b001;

                                state <= S_UPDATE;
                            end

                            // ---------------------------------
                            // RETURN / THREAD COMPLETE
                            // ---------------------------------

                            OP_RET: begin

                                done  <= 1'b1;

                                state <= S_IDLE;
                            end

                            // ---------------------------------
                            // OTHER ALU INSTRUCTIONS
                            // ---------------------------------

                            default: begin

                                state <= S_UPDATE;
                            end
                        endcase
                    end

                    // =========================================
                    // UPDATE
                    // =========================================

                    S_UPDATE: begin

                        case (opcode)

                            // ---------------------------------
                            // ADD / SUB / MUL / AND / OR
                            // ---------------------------------

                            OP_ADD,
                            OP_SUB,
                            OP_MUL,
                            OP_AND,
                            OP_OR: begin

                                if (rd < 13) begin

                                    rf_wr_en   <= 1'b1;
                                    rf_wr_addr <= rd;
                                    rf_wr_data <= alu_result;
                                end

                                instr_addr <= instr_addr + 1'b1;
                            end

                            // ---------------------------------
                            // LOAD
                            // ---------------------------------

                            OP_LD: begin

                                if (rd < 13) begin

                                    rf_wr_en   <= 1'b1;
                                    rf_wr_addr <= rd;

                                    rf_wr_data <= {
                                        8'h00,
                                        mem_data_in
                                    };
                                end

                                instr_addr <= instr_addr + 1'b1;
                            end

                            // ---------------------------------
                            // STORE
                            // ---------------------------------

                            OP_ST: begin

                                instr_addr <= instr_addr + 1'b1;
                            end

                            // ---------------------------------
                            // CONSTANT
                            // ---------------------------------

                            OP_CONST: begin

                                if (rd < 13) begin

                                    rf_wr_en   <= 1'b1;
                                    rf_wr_addr <= rd;

                                    rf_wr_data <= {
                                        8'h00,
                                        imm
                                    };
                                end

                                instr_addr <= instr_addr + 1'b1;
                            end

                            // ---------------------------------
                            // JUMP
                            // ---------------------------------

                            OP_JMP: begin

                                instr_addr <= imm;
                            end

                            // ---------------------------------
                            // COMPARE
                            // ---------------------------------

                            OP_CMP: begin

                                instr_addr <= instr_addr + 1'b1;
                            end

                            // ---------------------------------
                            // DEFAULT
                            // ---------------------------------

                            default: begin

                                instr_addr <= instr_addr + 1'b1;
                            end

                        endcase

                        state <= S_FETCH;
                    end

                    // =========================================
                    // DEFAULT
                    // =========================================

                    default: begin

                        state <= S_IDLE;
                    end

                endcase
            end
        end
    end

endmodule
