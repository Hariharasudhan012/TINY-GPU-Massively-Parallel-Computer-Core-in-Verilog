module mem_ctrl #(parameter N_CORES = 4) (

    input clk,
    input rst,

    // Requests from cores
    input [N_CORES-1:0] req,

    input [N_CORES-1:0] wr_en,

    // Packed address bus
    input [N_CORES*8-1:0] addr_bus,

    // Packed write-data bus
    input [N_CORES*8-1:0] wr_data_bus,

    // Shared memory
    input [7:0] mem [0:255],

    // Read data back to cores
    output reg [N_CORES*8-1:0] rd_data_bus,

    // Ready signal for each core
    output reg [N_CORES-1:0] ready,

    // Actual memory write interface
    output reg       mem_we,
    output reg [7:0] mem_addr,
    output reg [7:0] mem_wdata
);

    integer current;
    integer k;
    integer selected;

    reg granted;

    always @(posedge clk) begin

        if (rst) begin

            current     <= 0;
            ready       <= 0;
            rd_data_bus <= 0;

            mem_we      <= 0;
            mem_addr    <= 0;
            mem_wdata   <= 0;

        end

        else begin

            // Default values
            ready  <= 0;
            mem_we <= 0;

            granted  = 0;
            selected = 0;

            // Round-robin search
            for (k = 0; k < N_CORES; k = k + 1) begin

                if (!granted &&
                    req[(current + k) % N_CORES]) begin

                    selected = (current + k) % N_CORES;
                    granted = 1;

                end

            end

            // If a core requested memory
            if (granted) begin

                mem_addr <= addr_bus[selected*8 +: 8];

                // WRITE
                if (wr_en[selected]) begin

                    mem_we    <= 1;
                    mem_wdata <= wr_data_bus[selected*8 +: 8];

                end

                // READ
                else begin

                    rd_data_bus[selected*8 +: 8]
                        <= mem[addr_bus[selected*8 +: 8]];

                end

                // Tell selected core that its request completed
                ready[selected] <= 1;

                // Move round-robin pointer
                current <= (selected + 1) % N_CORES;

            end

        end

    end

endmodule
