module AcceleratorTop #(
    parameter int ROWS = 384,
    parameter int COLS = 384,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic cmd_valid,
    input  logic [1:0] cmd,
    output logic [2:0] status,

    input  logic [ROWS*DATA_WIDTH-1:0] s_axis_a_tdata,
    input  logic s_axis_a_tvalid,
    output logic s_axis_a_tready,
    input  logic s_axis_a_tlast,

    output logic [ACC_WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);

    localparam int A_WORD = ROWS*DATA_WIDTH;

    logic core_start_computation;
    logic [2:0] core_status;

    logic master_busy;

    logic signed [ACC_WIDTH-1:0] core_result [COLS];
    logic core_result_valid;

    logic [A_WORD-1:0] a_vector_data;

    assign status = core_status;

    AcceleratorFSM fsm (
        .cmd_valid(cmd_valid),
        .cmd(cmd),
        .master_busy(master_busy),
        .start_computation(core_start_computation)
    );

    AxiStreamSlave #(
        .DATA_WIDTH(A_WORD)
    ) stream_a (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_data_in(s_axis_a_tdata),
        .cpu_data_valid(s_axis_a_tvalid),
        .cpu_data_ready(s_axis_a_tready),
        .cpu_data_last(s_axis_a_tlast),
        .mem_ready_to_receive(1'b1),
        .mem_data_out(a_vector_data),
        .mem_data_valid(),
        .mem_data_last()
    );

    ComputeCore #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) compute_core (
        .clk(clk),
        .rst_n(rst_n),
        .start_computation(core_start_computation),
        .a_vector_data(a_vector_data),
        .result(core_result),
        .result_valid(core_result_valid),
        .status(core_status)
    );

    AxiStreamMaster #(
        .ACC_WIDTH(ACC_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) stream_master (
        .clk(clk),
        .rst_n(rst_n),
        .result(core_result),
        .result_valid(core_result_valid),
        .cpu_data_out(m_axis_tdata),
        .cpu_data_valid(m_axis_tvalid),
        .cpu_data_ready(m_axis_tready),
        .cpu_data_last(m_axis_tlast),
        .busy(master_busy)
    );

endmodule
