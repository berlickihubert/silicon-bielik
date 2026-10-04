module ProcessingElementWeightStationary #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic load_b,

    input  logic signed [DATA_WIDTH-1:0] a_in,
    input  logic signed [DATA_WIDTH-1:0] b_in,
    input  logic signed [ACC_WIDTH-1:0]  partial_sum_in,

    output logic signed [DATA_WIDTH-1:0] a_out,
    output logic signed [DATA_WIDTH-1:0] b_out,
    output logic signed [ACC_WIDTH-1:0]  partial_sum_out
);

    // B (stacjonarne) siedzi w tym rejestrze, A przeplywa przez komorke.
    logic signed [DATA_WIDTH-1:0] b_reg;

    assign b_out = b_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_reg           <= '0;
            a_out           <= '0;
            partial_sum_out <= '0;
        end
        else if (load_b) begin
            b_reg           <= b_in;
            a_out           <= '0;
            partial_sum_out <= '0;
        end
        else begin
            a_out           <= a_in;
            partial_sum_out <= partial_sum_in + (a_in * b_reg);
        end
    end

endmodule
