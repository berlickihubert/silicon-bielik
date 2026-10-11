# All weights are in:
#     models/Bielik-1.5B-v3/model.safetensors   (3.19 GB)


# Names of tensors in each layer(N = layer numer 0..31):
#     model.layers.N.self_attn.q_proj.weight   [1536, 1536]
#     model.layers.N.self_attn.k_proj.weight   [256, 1536]
#     model.layers.N.self_attn.v_proj.weight   [256, 1536]
#     model.layers.N.self_attn.o_proj.weight   [1536, 1536]
#     model.layers.N.mlp.gate_proj.weight      [8960, 1536]
#     model.layers.N.mlp.up_proj.weight        [8960, 1536]
#     model.layers.N.mlp.down_proj.weight      [1536, 8960]

# Rest:
#     model.embed_tokens.weight   [32000, 1536]
#     model.norm.weight           [1536]
#     lm_head.weight               [32000, 1536]


ROWS = 384
COLS = 384

import torch
from safetensors import safe_open
MODEL_PATH = "models/Bielik-1.5B-v3/model.safetensors"

def quantize_int8(w): # temporary quantisation
    scale = w.abs().max().item() / 127.0
    w_q = (w / scale).round().clamp(-127, 127).to(torch.int8)
    return w_q, scale


def generate_pe_instances(weights_int8, data_width=8, acc_width=32):
    rows, cols = weights_int8.shape
    lines = []
    for r in range(rows):
        for c in range(cols):
            w = int(weights_int8[r, c])
            w_in_sv = f"{data_width}'(signed'({w}))" # https://medium.com/@aiclab.official/signed-arithmetic-in-systemverilog-c1185ba6c63e
            lines.append(
                f"    ProcessingElementWeightStationary #(\n"
                f"        .DATA_WIDTH({data_width}),\n"
                f"        .ACC_WIDTH({acc_width}),\n"
                f"        .WEIGHT({w_in_sv})\n"
                f"    ) pe_{r}_{c} (\n"
                f"        .clk(clk),\n"
                f"        .rst_n(rst_n),\n"
                f"        .a_in(a_wire[{r}][{c}]),\n"
                f"        .partial_sum_in(psum_wire[{r}][{c}]),\n"
                f"        .a_out(a_wire[{r}][{c + 1}]),\n"
                f"        .partial_sum_out(psum_wire[{r + 1}][{c}])\n"
                f"    );\n"
            )
    return "\n".join(lines)


def build_systolic_array_module(module_name, weights_int8, data_width=8, acc_width=32):
    rows, cols = weights_int8.shape
    pe_instances = generate_pe_instances(weights_int8, data_width, acc_width)

    return f"""\
module {module_name} #(
    parameter int ROWS = {rows},
    parameter int COLS = {cols},
    parameter int DATA_WIDTH = {data_width},
    parameter int ACC_WIDTH = {acc_width}
)(
    input  logic clk,
    input  logic rst_n,

    input  logic signed [DATA_WIDTH-1:0] a_in            [ROWS],
    input  logic signed [ACC_WIDTH-1:0]  partial_sum_in  [COLS],

    output logic signed [ACC_WIDTH-1:0]  partial_sum_out [COLS]
);

    logic signed [DATA_WIDTH-1:0] a_wire [ROWS][COLS+1];
    logic signed [ACC_WIDTH-1:0] psum_wire [ROWS+1][COLS];

    genvar gen_i;
    generate
        for(gen_i = 0; gen_i < ROWS; gen_i++) begin : assign_a_in
            assign a_wire[gen_i][0] = a_in[gen_i];
        end

        for(gen_i = 0; gen_i < COLS; gen_i++) begin : assign_top_bottom
            assign psum_wire[0][gen_i] = partial_sum_in[gen_i];
            assign partial_sum_out[gen_i] = psum_wire[ROWS][gen_i];
        end
    endgenerate

{pe_instances}
endmodule
"""


if __name__ == "__main__":
    model = safe_open(MODEL_PATH, framework="pt", device="cpu")
    weights = model.get_tensor("model.layers.0.self_attn.q_proj.weight").float()
    print("original shape:", weights.shape)

    weights = weights[:ROWS, :COLS]
    print("subarray shape:", weights.shape)

    weights_int8, scale = quantize_int8(weights)

    module_src = build_systolic_array_module("SystolicTableHardcoded", weights_int8)

    out_path = "src/SystolicTableAcceleratorHardcodedWeights/src/SystolicTableHardcoded.sv"
    with open(out_path, "w") as f:
        f.write(module_src)
    print("written to", out_path)


