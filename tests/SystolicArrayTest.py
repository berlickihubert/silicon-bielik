import numpy as np

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer


def to_signed(value, width):
    value &= (1 << width) - 1
    if value & (1 << (width - 1)):
        value -= 1 << width
    return value


async def tick_clk(dut):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")


async def reset_dut(dut, rows, cols):
    dut.load_b.value = 0
    for r in range(rows):
        dut.a_in[r].value = 0
    for c in range(cols):
        dut.b_in[c].value = 0
        dut.partial_sum_in[c].value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await tick_clk(dut)


async def load_b_matrix(dut, b_matrix, rows, cols, mask):
    dut.load_b.value = 1
    for k in range(rows):
        row = b_matrix[rows - 1 - k]
        for c in range(cols):
            dut.b_in[c].value = row[c] & mask
        await RisingEdge(dut.clk)
    dut.load_b.value = 0


async def apply_a_and_read(dut, a_vec, rows, cols, mask, acc_width, settle):
    for r in range(rows):
        dut.a_in[r].value = a_vec[r] & mask
    for c in range(cols):
        dut.partial_sum_in[c].value = 0
    await ClockCycles(dut.clk, settle)
    return [to_signed(int(dut.partial_sum_out[c].value), acc_width) for c in range(cols)]


@cocotb.test()
async def test_systolic_array(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    ROWS, COLS = 3, 4
    A = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    B = [[2, 1, 3, 7], [7, 7, 7, 7], [2, 1, 3, 7]]
    expected_C = (np.array(A) @ np.array(B)).tolist()

    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    ACC_WIDTH = int(dut.ACC_WIDTH.value)
    mask = (1 << DATA_WIDTH) - 1
    cycles_to_output = ROWS + COLS + 2

    await reset_dut(dut, ROWS, COLS)
    await load_b_matrix(dut, B, ROWS, COLS, mask)

    res_vectors = []
    for a_vec in A:
        res_vectors.append(
            await apply_a_and_read(dut, a_vec, ROWS, COLS, mask, ACC_WIDTH, cycles_to_output)
        )

    dut._log.info(f"Expected C: {expected_C}")
    dut._log.info(f"Actual C: {res_vectors}")

    assert res_vectors == expected_C, f"expected {expected_C}, actual {res_vectors}"
