module Sky130SramMacro (
    input logic clk,

    input logic we,
    input logic [7:0] addr,
    input logic [31:0] write_data,

    output logic [31:0] read_data
);

    // https://github.com/VLSIDA/sky130_sram_macros/blob/main/sky130_sram_1kbyte_1rw1r_32x256_8/sky130_sram_1kbyte_1rw1r_32x256_8.v
    sky130_sram_1kbyte_1rw1r_32x256_8 mem_instance (
        .clk0(clk),
        .csb0(1'b0),
        .web0(~we),
        .wmask0(4'b1111),
        .addr0(addr),
        .din0(write_data),
        .dout0(read_data),

        .clk1(clk),
        .csb1(1'b1),
        .addr1(8'b0),
        .dout1()
    );

endmodule
