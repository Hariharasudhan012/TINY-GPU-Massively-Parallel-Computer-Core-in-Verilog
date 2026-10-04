module dispatch_unit #(parameter N_CORES = 4) (

    input clk,
    input rst,

    input start,

    input [7:0] thread_count,

    input [N_CORES-1:0] core_done,

    output reg [N_CORES-1:0] core_enable,

    output reg [N_CORES-1:0] thread_start,

    output reg [7:0] thread_id [0:N_CORES-1],

    output reg done
);

    integer next_thread;
    integer i;
    integer assigned;
    integer candidate;

    always @(posedge clk) begin

        if (rst) begin

            core_enable  <= 0;
            thread_start <= 0;

            done <= 0;

            next_thread <= 0;

            for (i = 0; i < N_CORES; i = i + 1)
                thread_id[i] <= 0;

        end

        else begin

            // Default
            thread_start <= 0;
            done <= 0;

            // No kernel running
            if (!start) begin

                core_enable <= 0;
                next_thread <= 0;

            end

            else begin

                assigned = 0;

                // Check every core
                for (i = 0; i < N_CORES; i = i + 1) begin

                    // Core is free or finished
                    if ((core_done[i] || !core_enable[i])) begin

                        candidate = next_thread + assigned;

                        // More threads available
                        if (candidate < thread_count) begin

                            thread_id[i] <= candidate;

                            core_enable[i] <= 1'b1;

                            thread_start[i] <= 1'b1;

                            assigned = assigned + 1;

                        end

                        // No more threads
                        else if (core_done[i]) begin

                            core_enable[i] <= 1'b0;

                        end

                    end

                end

                next_thread <= next_thread + assigned;

                // All threads completed
                if ((assigned == 0) &&
                    (next_thread >= thread_count) &&
                    ((core_enable & ~core_done) == 0)) begin

                    done <= 1'b1;

                end

            end

        end

    end

endmodule
