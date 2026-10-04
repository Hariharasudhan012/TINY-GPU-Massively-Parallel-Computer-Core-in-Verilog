`timescale 1ns/1ps

module tb_gpu;

    // ============================================================
    // SIGNALS
    // ============================================================

    reg clk;
    reg rst;
    reg start;

    reg [7:0] thread_count;

    reg [15:0] prog_mem [0:255];

    wire done;

    // ============================================================
    // GPU
    // ============================================================

    gpu_top #(.N_CORES(4)) uut (

        .clk          (clk),
        .rst          (rst),

        .start        (start),

        .thread_count (thread_count),

        .prog_mem     (prog_mem),

        .done         (done)

    );

    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;

    integer i;
    integer errors;

    // ============================================================
    // CLEAR PROGRAM MEMORY
    // ============================================================

    task clear_program;

        begin

            for (i = 0; i < 256; i = i + 1)
                prog_mem[i] = 16'h0000;

        end

    endtask

    // ============================================================
    // RESET GPU
    // ============================================================

    task reset_gpu;

        begin

            rst = 1'b1;
            start = 1'b0;

            #20;

            rst = 1'b0;

            #10;

        end

    endtask

    // ============================================================
    // RUN KERNEL
    // ============================================================

    task run_kernel;

        begin

            start = 1'b1;

            // Wait until dispatcher says complete
            wait(done == 1'b1);

            #20;

            start = 1'b0;

            #10;

        end

    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin
       $monitor("TIME=%0t DONE=%b | DONE=%b ENABLE=%b | STATES=%d,%d,%d,%d",
         $time,
         done,
         uut.core_done,
         uut.core_enable,
         uut.core_gen[0].core_inst.state,
         uut.core_gen[1].core_inst.state,
         uut.core_gen[2].core_inst.state,
         uut.core_gen[3].core_inst.state);

        // GTKWave waveform
        $dumpfile("gpu_sim.vcd");
        $dumpvars(0, tb_gpu);

        // Initial values
        clk = 1'b0;

        rst = 1'b1;

        start = 1'b0;

        thread_count = 0;

        errors = 0;

        clear_program();


        // ========================================================
        // KERNEL 1
        // VECTOR ADDITION
        //
        // C[i] = A[i] + B[i]
        // ========================================================

        reset_gpu();

        $display("");
        $display("========================================");
        $display("KERNEL 1: VECTOR ADDITION");
        $display("========================================");

        thread_count = 8;


        // --------------------------------------------------------
        // PROGRAM
        // --------------------------------------------------------

        // MUL R0, R13, R14
        prog_mem[0] =
            16'b0010_0000_1101_1110;

        // ADD R0, R0, R15
        prog_mem[1] =
            16'b0000_0000_0000_1111;

        // CONST R1, #0
        prog_mem[2] =
            16'b1000_0001_0000_0000;

        // CONST R2, #8
        prog_mem[3] =
            16'b1000_0010_0000_1000;

        // CONST R3, #16
        prog_mem[4] =
            16'b1000_0011_0001_0000;

        // ADD R4, R1, R0
        prog_mem[5] =
            16'b0000_0100_0001_0000;

        // LD R4, [R4]
        prog_mem[6] =
            16'b0110_0100_0100_0000;

        // ADD R5, R2, R0
        prog_mem[7] =
            16'b0000_0101_0010_0000;

        // LD R5, [R5]
        prog_mem[8] =
            16'b0110_0101_0101_0000;

        // ADD R6, R4, R5
        prog_mem[9] =
            16'b0000_0110_0100_0101;

        // ADD R7, R3, R0
        prog_mem[10] =
            16'b0000_0111_0011_0000;

        // ST [R7], R6
        prog_mem[11] =
            16'b0111_0000_0111_0110;

        // RET
        prog_mem[12] =
            16'b1111_0000_0000_0000;


        // --------------------------------------------------------
        // DATA
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            // A = 0,1,2,3,4,5,6,7
            uut.data_mem[i] = i;

            // B = 0,1,2,3,4,5,6,7
            uut.data_mem[8+i] = i;

            // C initially zero
            uut.data_mem[16+i] = 0;

        end


        // --------------------------------------------------------
        // RUN
        // --------------------------------------------------------

        run_kernel();


        // --------------------------------------------------------
        // RESULTS
        // --------------------------------------------------------

        $display("");
        $display("Vector Addition Results:");

        for (i = 0; i < 8; i = i + 1) begin

            $display(
                "C[%0d] = %0d (expected %0d)",
                i,
                uut.data_mem[16+i],
                i+i
            );

            if (uut.data_mem[16+i] !== i+i)
                errors = errors + 1;

        end


        // ========================================================
        // KERNEL 2
        // ELEMENT MULTIPLICATION
        //
        // C[i] = A[i] * B[i]
        // ========================================================

        reset_gpu();

        $display("");
        $display("========================================");
        $display("KERNEL 2: ELEMENT MULTIPLICATION");
        $display("========================================");

        thread_count = 8;


        // --------------------------------------------------------
        // PROGRAM
        // --------------------------------------------------------

        // MUL R0, R13, R14
        prog_mem[0] =
            16'b0010_0000_1101_1110;

        // ADD R0, R0, R15
        prog_mem[1] =
            16'b0000_0000_0000_1111;

        // CONST R1, #0
        prog_mem[2] =
            16'b1000_0001_0000_0000;

        // CONST R2, #8
        prog_mem[3] =
            16'b1000_0010_0000_1000;

        // CONST R3, #16
        prog_mem[4] =
            16'b1000_0011_0001_0000;

        // ADD R4, R1, R0
        prog_mem[5] =
            16'b0000_0100_0001_0000;

        // LD R4, [R4]
        prog_mem[6] =
            16'b0110_0100_0100_0000;

        // ADD R5, R2, R0
        prog_mem[7] =
            16'b0000_0101_0010_0000;

        // LD R5, [R5]
        prog_mem[8] =
            16'b0110_0101_0101_0000;

        // MUL R6, R4, R5
        prog_mem[9] =
            16'b0010_0110_0100_0101;

        // ADD R7, R3, R0
        prog_mem[10] =
            16'b0000_0111_0011_0000;

        // ST [R7], R6
        prog_mem[11] =
            16'b0111_0000_0111_0110;

        // RET
        prog_mem[12] =
            16'b1111_0000_0000_0000;


        // --------------------------------------------------------
        // DATA
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            // A = 1,2,3,4,5,6,7,8
            uut.data_mem[i] = i + 1;

            // B = 1,2,3,4,5,6,7,8
            uut.data_mem[8+i] = i + 1;

            // C initially zero
            uut.data_mem[16+i] = 0;

        end


        // --------------------------------------------------------
        // RUN
        // --------------------------------------------------------

        run_kernel();


        // --------------------------------------------------------
        // RESULTS
        // --------------------------------------------------------

        $display("");
        $display("Element Multiplication Results:");

        for (i = 0; i < 8; i = i + 1) begin

            $display(
                "C[%0d] = %0d (expected %0d)",
                i,
                uut.data_mem[16+i],
                (i+1)*(i+1)
            );

            if (uut.data_mem[16+i] !==
                (i+1)*(i+1))
                errors = errors + 1;

        end


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");

        if (errors == 0) begin

            $display("**************************************");
            $display("*** ALL TESTS PASSED ***");
            $display("**************************************");

        end

        else begin

            $display("**************************************");
            $display("*** TEST FAILED: %0d errors ***",
                     errors);
            $display("**************************************");

        end

        $display("");
        $display("=== Simulation Complete ===");

        #20;

        $finish;

    end

endmodule
