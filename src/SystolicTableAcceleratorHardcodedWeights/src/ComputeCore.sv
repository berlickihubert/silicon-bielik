module ComputeCore #(
    parameter int ROWS = 384,
    parameter int COLS = 384,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,
    input logic start_computation,

    input logic [ROWS*DATA_WIDTH-1:0] a_vector_data,

    output logic signed [ACC_WIDTH-1:0] result [COLS],
    output logic result_valid,
    output logic [2:0] status
);


    typedef enum logic [2:0] {
        IDLE,
        INFERENCE_READY,
        COMPUTE,
        INFERENCE_DONE
    } status_t;

    status_t state, next_state;
    assign status = state;

    localparam int RESULT_LATENCY = ROWS + COLS - 1;

    logic [RESULT_LATENCY-1:0] valid_pipe;
    logic feeding_req;
    logic feeding;

    assign result_valid = valid_pipe[RESULT_LATENCY-1];

    logic signed [DATA_WIDTH-1:0] a_raw            [ROWS];
    logic signed [DATA_WIDTH-1:0] a_delayed        [ROWS];
    logic signed [ACC_WIDTH-1:0]  partial_sum_zero [COLS];
    logic signed [ACC_WIDTH-1:0]  result_raw       [COLS];

    assign partial_sum_zero = '{default: '0};

    genvar gen_row;
    generate
        for(gen_row = 0; gen_row < ROWS; gen_row++) begin : unpack_a
            assign a_raw[gen_row] = $signed(a_vector_data[gen_row*DATA_WIDTH + DATA_WIDTH-1: gen_row*DATA_WIDTH]);
        end
    endgenerate

    genvar gen_row_2, gen_col_2;
    generate
        for (gen_row_2 = 0; gen_row_2 < ROWS; gen_row_2++) begin : a_delay_stage
            DataDelay #(
                .WIDTH(DATA_WIDTH),
                .DELAY_CYCLES(gen_row_2)
            ) a_delay (
                .clk(clk),
                .rst_n(rst_n),
                .data_in(a_raw[gen_row_2]),
                .data_out(a_delayed[gen_row_2])
            );
        end

        for (gen_col_2 = 0; gen_col_2 < COLS; gen_col_2++) begin : result_delay_stage
            DataDelay #(
                .WIDTH(ACC_WIDTH),
                .DELAY_CYCLES(COLS-1-gen_col_2)
            ) result_delay (
                .clk(clk),
                .rst_n(rst_n),
                .data_in(result_raw[gen_col_2]),
                .data_out(result[gen_col_2])
            );
        end
    endgenerate

    SystolicTableHardcoded #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) systolic_array (
        .clk(clk),
        .rst_n(rst_n),
        .a_in(a_delayed),
        .partial_sum_in(partial_sum_zero),
        .partial_sum_out(result_raw)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
            valid_pipe <= '0;
            feeding <= 1'b0;
        end
        else begin
            state <= next_state;
            valid_pipe <= {valid_pipe[RESULT_LATENCY-2:0], feeding};
            feeding <= feeding_req;
        end
    end


    always_comb begin
        next_state = state;
        feeding_req = 1'b0;

        case(state)
            IDLE: begin
                next_state = INFERENCE_READY;
            end
            INFERENCE_READY: begin
                if(start_computation) begin
                    feeding_req = 1'b1;
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if(result_valid) begin
                    next_state = INFERENCE_DONE;
                end
            end
            INFERENCE_DONE: begin
                next_state = INFERENCE_READY;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule
