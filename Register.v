module register_file (
    input        clk,
    input        rst,
    input        thread_start,

    input  [7:0] thread_id,

    input  [3:0] rd_addr1,
    input  [3:0] rd_addr2,

    input  [3:0] wr_addr,
    input        wr_en,
    input [15:0] wr_data,

    output [15:0] rd_data1,
    output [15:0] rd_data2
);

    // 16 registers, each 16 bits
    reg [15:0] registers [0:15];

    integer i;

    // Asynchronous read
    assign rd_data1 = registers[rd_addr1];
    assign rd_data2 = registers[rd_addr2];

    always @(posedge clk) begin

        // Reset or start of a new thread
        if (rst || thread_start) begin

            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 16'h0000;

            // Special registers
            // R13 = blockIdx
            // R14 = blockDim
            // R15 = threadIdx

            registers[13] <= 16'h0000;
            registers[14] <= 16'h0001;
            registers[15] <= {8'h00, thread_id};

        end

        // Normal register write
        else if (wr_en && (wr_addr < 4'd13)) begin

            registers[wr_addr] <= wr_data;

        end

    end

endmodule
