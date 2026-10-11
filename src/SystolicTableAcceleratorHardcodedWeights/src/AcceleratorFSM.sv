module AcceleratorFSM(
    input  logic cmd_valid,
    input  logic [1:0] cmd,
    input  logic master_busy,

    output logic start_computation
);

    localparam logic [1:0] CMD_COMPUTE = 2'd2;

    assign start_computation = cmd_valid && (cmd == CMD_COMPUTE) && !master_busy;

endmodule
