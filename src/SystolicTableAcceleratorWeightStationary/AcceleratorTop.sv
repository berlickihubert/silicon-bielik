module AcceleratorTop #(
    parameter int ROWS = 16,
    parameter int COLS = 16,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int ADDR_WIDTH = 9,
    parameter int MEM_BACKEND = 0 // 0 = GENERIC, 1 = SKY130_SRAM
)(
    input  logic clk,
    input  logic rst_n,

    input  logic cmd_valid,
    input  logic [1:0] cmd,
    output logic [2:0] status,

    input  logic [COLS*DATA_WIDTH-1:0] s_axis_b_tdata,
    input  logic s_axis_b_tvalid,
    output logic s_axis_b_tready,
    input  logic s_axis_b_tlast,

    input  logic [ROWS*DATA_WIDTH-1:0] s_axis_a_tdata,
    input  logic s_axis_a_tvalid,
    output logic s_axis_a_tready,
    input  logic s_axis_a_tlast,

    output logic [ACC_WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);

    localparam int B_WORD = COLS*DATA_WIDTH;
    localparam int A_WORD = ROWS*DATA_WIDTH;

    logic core_start_loading_b;
    logic core_start_computation;
    logic [2:0] core_status;

    logic master_busy;

    logic signed [ACC_WIDTH-1:0] core_result [COLS];
    logic core_result_valid;

    logic [ADDR_WIDTH-1:0] b_write_addr;
    logic b_we;
    logic [B_WORD-1:0] b_write_data;
    logic [ADDR_WIDTH-1:0] b_read_addr;
    logic [B_WORD-1:0] b_read_data;

    logic [ADDR_WIDTH-1:0] a_write_addr;
    logic a_we;
    logic [A_WORD-1:0] a_write_data;
    logic [ADDR_WIDTH-1:0] a_read_addr;
    logic [A_WORD-1:0] a_read_data;

    assign status = core_status;

    AcceleratorFSM fsm (
        .cmd_valid(cmd_valid),
        .cmd(cmd),
        .master_busy(master_busy),
        .start_loading_b(core_start_loading_b),
        .start_computation(core_start_computation)
    );

    AxiStreamSlave #(
        .DATA_WIDTH(B_WORD),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) stream_b (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_data_in(s_axis_b_tdata),
        .cpu_data_valid(s_axis_b_tvalid),
        .cpu_data_ready(s_axis_b_tready),
        .cpu_data_last(s_axis_b_tlast),
        .mem_ready_to_receive(1'b1),
        .mem_data_out(b_write_data),
        .mem_data_valid(),
        .mem_data_last(),
        .mem_write_addr_out(b_write_addr),
        .mem_we(b_we)
    );

    MemoryBuffer #(
        .DATA_WIDTH(B_WORD),
        .DEPTH(1<<ADDR_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BACKEND(MEM_BACKEND)
    ) buffer_b (
        .clk(clk),
        .we(b_we),
        .write_addr(b_write_addr),
        .write_data(b_write_data),
        .read_addr(b_read_addr),
        .read_data(b_read_data)
    );

    AxiStreamSlave #(
        .DATA_WIDTH(A_WORD),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) stream_a (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_data_in(s_axis_a_tdata),
        .cpu_data_valid(s_axis_a_tvalid),
        .cpu_data_ready(s_axis_a_tready),
        .cpu_data_last(s_axis_a_tlast),
        .mem_ready_to_receive(1'b1),
        .mem_data_out(a_write_data),
        .mem_data_valid(),
        .mem_data_last(),
        .mem_write_addr_out(a_write_addr),
        .mem_we(a_we)
    );

    MemoryBuffer #(
        .DATA_WIDTH(A_WORD),
        .DEPTH(1<<ADDR_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BACKEND(MEM_BACKEND)
    ) buffer_a (
        .clk(clk),
        .we(a_we),
        .write_addr(a_write_addr),
        .write_data(a_write_data),
        .read_addr(a_read_addr),
        .read_data(a_read_data)
    );

    ComputeCore #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ADDR_Width(ADDR_WIDTH)
    ) compute_core (
        .clk(clk),
        .rst_n(rst_n),
        .start_loading_b(core_start_loading_b),
        .start_computation(core_start_computation),
        .sram_b_vector_addr(b_read_addr),
        .sram_b_vector_data(b_read_data),
        .sram_a_vector_addr(a_read_addr),
        .sram_a_vector_data(a_read_data),
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
