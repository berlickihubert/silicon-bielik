module Asap7SramMacro (
    input logic clk,

    input logic we,
    input logic [7:0] addr,
    input logic [63:0] write_data,

    output logic [63:0] read_data
);

    srambank_64x4x64_6t122 mem_instance (
        .clk(clk),
        .ADDRESS(addr),
        .wd(write_data),
        .banksel(1'b1),
        .write(we),
        .read(~we),
        .dataout(read_data)
    );

endmodule
