module MemoryBuffer #(
    parameter int DATA_WIDTH = 64,
    parameter int DEPTH = 512,
    parameter int ADDR_WIDTH = 9,

    parameter int BACKEND_GENERIC = 0,
    parameter int BACKEND_SKY130_SRAM = 1,
    parameter int BACKEND_ASAP7_SRAM = 2,
    parameter int BACKEND = BACKEND_GENERIC
)(
    input logic clk,

    input logic we,
    input logic [ADDR_WIDTH-1:0] write_addr,
    input logic [DATA_WIDTH-1:0] write_data,

    input logic [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] read_data
);

    generate
        if (BACKEND == BACKEND_GENERIC) begin : gen_generic
            logic [DATA_WIDTH-1:0] sram_array [0:DEPTH-1];

            always_ff @(posedge clk) begin
                if (we) begin
                    sram_array[write_addr] <= write_data;
                end
                read_data <= sram_array[read_addr];
            end
        end
        else if (BACKEND == BACKEND_SKY130_SRAM) begin : gen_sky130

            localparam int MEM_CELL_WIDTH = 32;
            localparam int MEM_CEL_DEPTH = 256;
            localparam int MEM_CELL_ADDR_WIDTH = 8;
            
            // uwaga musza byc podzielne
            localparam int M = DATA_WIDTH / MEM_CELL_WIDTH;
            localparam int N = DEPTH / MEM_CEL_DEPTH;

            localparam int BANK_SEL_WIDTH = (N > 1) ? $clog2(N) : 1;

            logic [BANK_SEL_WIDTH-1:0] selected_cell_row;
            assign selected_cell_row = BANK_SEL_WIDTH'(32'(read_addr) / MEM_CEL_DEPTH);
            logic [MEM_CELL_ADDR_WIDTH-1:0] selected_cell_addr;
            assign selected_cell_addr = MEM_CELL_ADDR_WIDTH'(32'(read_addr) % MEM_CEL_DEPTH);


            // synchroniczne czytanie
            logic [BANK_SEL_WIDTH-1:0] selected_cell_row_reg;
            always_ff @(posedge clk) begin
                selected_cell_row_reg <= selected_cell_row;
            end

            logic [DATA_WIDTH-1:0] memory_cells_outputs [N];

            genvar gen_i, gen_j;
            for (gen_i = 0; gen_i < N; gen_i++) begin : gen_memory_rows
                for (gen_j = 0; gen_j < M; gen_j++) begin : gen_memory_row
                    Sky130SramMacro mem_instance (
                        .clk(clk),
                        .we(we & (gen_i == selected_cell_row)),
                        .addr(selected_cell_addr),
                        .write_data(write_data[gen_j*MEM_CELL_WIDTH + MEM_CELL_WIDTH - 1 : gen_j*MEM_CELL_WIDTH]),
                        .read_data(memory_cells_outputs[gen_i][gen_j*MEM_CELL_WIDTH + MEM_CELL_WIDTH - 1 : gen_j*MEM_CELL_WIDTH])
                    );
                end
            end

            assign read_data = memory_cells_outputs[selected_cell_row_reg];
        end
        else if (BACKEND == BACKEND_ASAP7_SRAM) begin : gen_asap7

            localparam int MEM_CELL_WIDTH = 64;
            localparam int MEM_CEL_DEPTH = 256;
            localparam int MEM_CELL_ADDR_WIDTH = 8;

            // uwaga musza byc podzielne
            localparam int M = DATA_WIDTH / MEM_CELL_WIDTH;
            localparam int N = DEPTH / MEM_CEL_DEPTH;

            localparam int BANK_SEL_WIDTH = (N > 1) ? $clog2(N) : 1;

            logic [BANK_SEL_WIDTH-1:0] selected_cell_row;
            assign selected_cell_row = BANK_SEL_WIDTH'(32'(read_addr) / MEM_CEL_DEPTH);
            logic [MEM_CELL_ADDR_WIDTH-1:0] selected_cell_addr;
            assign selected_cell_addr = MEM_CELL_ADDR_WIDTH'(32'(read_addr) % MEM_CEL_DEPTH);

            // synchroniczne czytanie
            logic [BANK_SEL_WIDTH-1:0] selected_cell_row_reg;
            always_ff @(posedge clk) begin
                selected_cell_row_reg <= selected_cell_row;
            end

            logic [DATA_WIDTH-1:0] memory_cells_outputs [N];

            genvar gen_i, gen_j;
            for (gen_i = 0; gen_i < N; gen_i++) begin : gen_memory_rows
                for (gen_j = 0; gen_j < M; gen_j++) begin : gen_memory_row
                    Asap7SramMacro mem_instance (
                        .clk(clk),
                        .we(we & (gen_i == selected_cell_row)),
                        .addr(selected_cell_addr),
                        .write_data(write_data[gen_j*MEM_CELL_WIDTH + MEM_CELL_WIDTH - 1 : gen_j*MEM_CELL_WIDTH]),
                        .read_data(memory_cells_outputs[gen_i][gen_j*MEM_CELL_WIDTH + MEM_CELL_WIDTH - 1 : gen_j*MEM_CELL_WIDTH])
                    );
                end
            end

            assign read_data = memory_cells_outputs[selected_cell_row_reg];
        end
        else begin : gen_unsupported
            $error("nieobslugiwany %0d", BACKEND);
        end
    endgenerate

endmodule
