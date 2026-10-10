import numpy as np
from safetensors import safe_open

import torch

MODEL_PATH = "models/Bielik-1.5B-v3/model.safetensors"
TENSOR_NAME = "model.layers.0.self_attn.q_proj.weight"
OUT_PATH = "models/q_proj_int8.npz"


def main():
    pass


if __name__ == "__main__":
    main()
