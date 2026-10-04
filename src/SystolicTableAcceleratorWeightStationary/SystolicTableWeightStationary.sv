module SystolicTableWeightStationary #(
    parameter int ROWS = 16,
    parameter int COLS = 16,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic load_b,

    input  logic signed [DATA_WIDTH-1:0] a_in            [ROWS],
    input  logic signed [DATA_WIDTH-1:0] b_in            [COLS],
    input  logic signed [ACC_WIDTH-1:0]  partial_sum_in  [COLS],

    output logic signed [ACC_WIDTH-1:0]  partial_sum_out [COLS]
);

    logic signed [DATA_WIDTH-1:0] a_wire [ROWS][COLS+1];
    logic signed [DATA_WIDTH-1:0] b_wire [ROWS+1][COLS];
    logic signed [ACC_WIDTH-1:0] psum_wire [ROWS+1][COLS];

    genvar gen_i;
    generate
        for(gen_i = 0; gen_i < ROWS; gen_i++) begin : assign_a_in
            assign a_wire[gen_i][0] = a_in[gen_i];
        end

        for(gen_i = 0; gen_i < COLS; gen_i++) begin : assign_top_bottom
            assign b_wire[0][gen_i] = b_in[gen_i];
            assign psum_wire[0][gen_i] = partial_sum_in[gen_i];
            assign partial_sum_out[gen_i] = psum_wire[ROWS][gen_i];
        end
    endgenerate

    genvar gen_r, gen_c;
    generate
        for(gen_r = 0; gen_r < ROWS; gen_r++) begin : row_gen
            for(gen_c = 0; gen_c < COLS; gen_c++) begin : col_gen

            ProcessingElementWeightStationary #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) processing_element (
                .clk(clk),
                .rst_n(rst_n),
                .load_b(load_b),
                .a_in(a_wire[gen_r][gen_c]),
                .b_in(b_wire[gen_r][gen_c]),
                .partial_sum_in(psum_wire[gen_r][gen_c]),
                .a_out(a_wire[gen_r][gen_c+1]),
                .b_out(b_wire[gen_r+1][gen_c]),
                .partial_sum_out(psum_wire[gen_r+1][gen_c])
            );

            end
        end
    endgenerate

endmodule
