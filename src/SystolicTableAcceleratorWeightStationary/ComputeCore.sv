module ComputeCore #(
    parameter int ROWS = 16,
    parameter int COLS = 16,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int ADDR_Width = 9
)(
    input logic clk,
    input logic rst_n,
    input logic start_loading_b,
    input logic start_computation,

    output logic [ADDR_Width-1:0] sram_b_vector_addr,
    input logic [COLS*DATA_WIDTH-1:0] sram_b_vector_data,

    output logic [ADDR_Width-1:0] sram_a_vector_addr,
    input logic [ROWS*DATA_WIDTH-1:0] sram_a_vector_data,

    output logic signed [ACC_WIDTH-1:0] result [COLS],
    output logic result_valid,
    output logic [2:0] status
);


    typedef enum logic [2:0] {
        IDLE,
        LOAD_B,
        INFERENCE_READY,
        COMPUTE,
        INFERENCE_DONE
    } status_t;

    status_t state, next_state;
    assign status = state;

    localparam int RESULT_LATENCY = ROWS + COLS - 1;
    localparam logic [ADDR_Width-1:0] ROWS_LAST_IDX = ADDR_Width'(ROWS-1);

    logic [ADDR_Width-1:0] b_vector_addr_cnt;
    logic [ADDR_Width-1:0] a_vector_addr_cnt;
    logic [ADDR_Width-1:0] results_seen_cnt;
    logic feeding_done;
    logic [RESULT_LATENCY-1:0] valid_pipe;
    logic load_b_req;
    logic load_b;
    logic feeding_req;
    logic feeding;

    assign result_valid = valid_pipe[RESULT_LATENCY-1];

    logic signed [DATA_WIDTH-1:0] a_raw            [ROWS];
    logic signed [DATA_WIDTH-1:0] a_delayed        [ROWS];
    logic signed [DATA_WIDTH-1:0] b_in             [COLS];
    logic signed [ACC_WIDTH-1:0]  partial_sum_zero [COLS];
    logic signed [ACC_WIDTH-1:0]  result_raw       [COLS];

    assign sram_b_vector_addr = b_vector_addr_cnt;
    assign sram_a_vector_addr = a_vector_addr_cnt;

    assign partial_sum_zero = '{default: '0};

    genvar gen_row, gen_col;
    generate
        for(gen_row = 0; gen_row < ROWS; gen_row++) begin : unpack_a
            assign a_raw[gen_row] = $signed(sram_a_vector_data[gen_row*DATA_WIDTH + DATA_WIDTH-1: gen_row*DATA_WIDTH]);
        end
        for(gen_col = 0; gen_col < COLS; gen_col++) begin : unpack_b
            assign b_in[gen_col] = $signed(sram_b_vector_data[gen_col*DATA_WIDTH + DATA_WIDTH-1: gen_col*DATA_WIDTH]);
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

    SystolicTableWeightStationary #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) systolic_array (
        .clk(clk),
        .rst_n(rst_n),
        .load_b(load_b),
        .a_in(a_delayed),
        .b_in(b_in),
        .partial_sum_in(partial_sum_zero),
        .partial_sum_out(result_raw)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
            b_vector_addr_cnt <= 0;
            a_vector_addr_cnt <= 0;
            results_seen_cnt <= 0;
            feeding_done <= 1'b0;
            valid_pipe <= '0;
            load_b <= 1'b0;
            feeding <= 1'b0;
        end
        else begin
            state <= next_state;
            valid_pipe <= {valid_pipe[RESULT_LATENCY-2:0], feeding};

            load_b <= load_b_req;
            feeding <= feeding_req;

            if((state == IDLE || state == INFERENCE_READY) && start_loading_b) begin
                b_vector_addr_cnt <= ROWS_LAST_IDX;
            end
            else if (state == LOAD_B) begin
                b_vector_addr_cnt <= b_vector_addr_cnt - 1;
            end

            if(state == INFERENCE_READY && start_computation) begin
                a_vector_addr_cnt <= 0;
                results_seen_cnt <= 0;
                feeding_done <= 1'b0;
            end
            else if(state == COMPUTE) begin
                if(!feeding_done) begin
                    a_vector_addr_cnt <= a_vector_addr_cnt + 1;
                    if(a_vector_addr_cnt == ROWS_LAST_IDX) begin
                        feeding_done <= 1'b1;
                    end
                end
                if(result_valid) begin
                    results_seen_cnt <= results_seen_cnt + 1;
                end
            end
        end
    end


    always_comb begin
        next_state = state;
        load_b_req = 1'b0;
        feeding_req = 1'b0;

        case(state)
            IDLE: begin
                if(start_loading_b) begin
                    next_state = LOAD_B;
                end
            end
            LOAD_B: begin
                load_b_req = 1'b1;
                if(b_vector_addr_cnt == 0) begin
                    next_state = INFERENCE_READY;
                end
            end
            INFERENCE_READY: begin
                if(start_loading_b) begin
                    next_state = LOAD_B;
                end
                else if(start_computation) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                feeding_req = !feeding_done;
                if(result_valid && results_seen_cnt == ROWS_LAST_IDX) begin
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
