module AxiStreamMaster #(
    parameter int ACC_WIDTH = 32,
    parameter int ROWS = 16,
    parameter int COLS = 16
)(
    input  logic clk,
    input  logic rst_n,

    input  logic signed [ACC_WIDTH-1:0] result [COLS],
    input  logic result_valid,

    output logic [ACC_WIDTH-1:0] cpu_data_out,
    output logic cpu_data_valid,
    input  logic cpu_data_ready,
    output logic cpu_data_last,

    output logic busy
);

    localparam int VEC_WIDTH = $clog2(ROWS);
    localparam int COL_WIDTH = $clog2(COLS);

    typedef enum logic {
        COLLECT,
        SEND
    } state_t;

    state_t state;
    logic signed [ACC_WIDTH-1:0] c_buf [ROWS][COLS];
    logic [VEC_WIDTH-1:0] collect_idx;
    logic [VEC_WIDTH-1:0] vec_idx;
    logic [COL_WIDTH-1:0] col_idx;

    logic handshake;
    assign handshake = cpu_data_valid && cpu_data_ready;

    assign busy = (state == SEND);

    assign cpu_data_out = c_buf[vec_idx][col_idx];
    assign cpu_data_valid = (state == SEND);
    assign cpu_data_last = (state == SEND)
                         && (vec_idx == VEC_WIDTH'(ROWS-1))
                         && (col_idx == COL_WIDTH'(COLS-1));

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= COLLECT;
            collect_idx <= '0;
            vec_idx <= '0;
            col_idx <= '0;
        end
        else begin
            case(state)
                COLLECT: begin
                    if(result_valid) begin
                        for(int j = 0; j < COLS; j++) begin
                            c_buf[collect_idx][j] <= result[j];
                        end
                        if(collect_idx == VEC_WIDTH'(ROWS-1)) begin
                            collect_idx <= '0;
                            vec_idx <= '0;
                            col_idx <= '0;
                            state <= SEND;
                        end
                        else begin
                            collect_idx <= collect_idx + 1'b1;
                        end
                    end
                end
                SEND: begin
                    if(handshake) begin
                        if(col_idx == COL_WIDTH'(COLS-1)) begin
                            col_idx <= '0;
                            if(vec_idx == VEC_WIDTH'(ROWS-1)) begin
                                vec_idx <= '0;
                                state <= COLLECT;
                            end
                            else begin
                                vec_idx <= vec_idx + 1'b1;
                            end
                        end
                        else begin
                            col_idx <= col_idx + 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
