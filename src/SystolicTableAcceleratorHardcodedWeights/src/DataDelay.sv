module DataDelay #(
    parameter int WIDTH = 8,
    parameter int DELAY_CYCLES = 1
)(
    input logic clk,
    input logic rst_n,
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] stages [DELAY_CYCLES+1];

    assign stages[0] = data_in;
    assign data_out = stages[DELAY_CYCLES];

    genvar gen_i;
    generate
        for(gen_i = 1; gen_i <= DELAY_CYCLES; gen_i++) begin : delay_logic
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                stages[gen_i] <= '0;
            end
            else begin
                stages[gen_i] <= stages[gen_i-1];
            end

        end
        end
    endgenerate
endmodule