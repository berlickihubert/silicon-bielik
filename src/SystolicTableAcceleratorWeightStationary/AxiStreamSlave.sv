module AxiStreamSlave #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 9
)(
    input logic clk,
    input logic rst_n,

    input logic [DATA_WIDTH-1:0] cpu_data_in,
    input logic cpu_data_valid,
    input logic cpu_data_last,
    output logic cpu_data_ready,

    input logic mem_ready_to_receive,
    output logic [DATA_WIDTH-1:0] mem_data_out,
    output logic mem_data_valid,
    output logic mem_data_last,
    output logic [ADDR_WIDTH-1:0] mem_write_addr_out,
    output logic mem_we
);

    logic handshake;
    assign handshake = cpu_data_valid && cpu_data_ready;

    assign cpu_data_ready = mem_ready_to_receive;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mem_data_out <= '0;
            mem_data_valid <= 1'b0;
            mem_data_last <= 1'b0;
            mem_we <= 1'b0;
            mem_write_addr_out <= '0;
        end
        else begin
            mem_data_valid <= 1'b0;
            mem_data_last <= 1'b0;
            mem_we <= 1'b0;

            if(handshake) begin
                mem_data_out <= cpu_data_in;
                mem_data_valid <= 1'b1;
                mem_data_last <= cpu_data_last;
                mem_we <= 1'b1;
            end

            if(mem_we) begin
                if(mem_data_last) begin
                    mem_write_addr_out <= '0;
                end
                else begin
                    mem_write_addr_out <= mem_write_addr_out + 1;
                end
            end
        end
    end
endmodule
