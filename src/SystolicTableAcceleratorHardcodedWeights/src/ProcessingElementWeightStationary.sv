module ProcessingElementWeightStationary #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32

    parameter logic signed [DATA_WIDTH-1:0] WEIGHT = '0
)(
    input  logic clk,
    input  logic rst_n,

    input  logic signed [DATA_WIDTH-1:0] a_in,
    input  logic signed [ACC_WIDTH-1:0]  partial_sum_in,

    output logic signed [DATA_WIDTH-1:0] a_out,
    output logic signed [ACC_WIDTH-1:0]  partial_sum_out
);

    assign b_out = b_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out           <= '0;
            partial_sum_out <= '0;
        end
        else begin
            a_out           <= a_in;
            partial_sum_out <= partial_sum_in + (a_in * WEIGHT);
        end
    end

endmodule
