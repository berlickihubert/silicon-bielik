import numpy as np

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

# Definicje w ComputeCore.sv
STATUS_IDLE            = 0
STATUS_LOAD_B          = 1
STATUS_INFERENCE_READY = 2
STATUS_COMPUTE         = 3
STATUS_INFERENCE_DONE  = 4

STATUS_NAME = {
    STATUS_IDLE: "IDLE",
    STATUS_LOAD_B: "LOAD_B",
    STATUS_INFERENCE_READY: "INFERENCE_READY",
    STATUS_COMPUTE: "COMPUTE",
    STATUS_INFERENCE_DONE: "INFERENCE_DONE",
}


def to_signed(value, width):
    value &= (1 << width) - 1
    if value & (1 << (width - 1)):
        value -= 1 << width
    return value


def array_to_vector(array, width):
    mask = (1 << width) - 1
    vector = 0
    for i, v in enumerate(array):
        vector |= (int(v) & mask) << (i * width)
    return vector



async def tick_clk(dut):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")


async def reset_dut(dut):
    dut.start_loading_b.value = 0
    dut.start_computation.value = 0
    dut.sram_b_vector_data.value = 0
    dut.sram_a_vector_data.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await tick_clk(dut)


async def pulse(dut, signal):
    getattr(dut, signal).value = 1
    await RisingEdge(dut.clk)
    getattr(dut, signal).value = 0
    await Timer(1, units="ns")

async def wait_for_signal_value(dut, signal, target_value, timeout=2000):
    for cycles in range(timeout):
        await tick_clk(dut)
        if int(getattr(dut, signal).value) == target_value:
            return cycles
    raise TimeoutError


async def fill_srams(dut, b_mem, a_mem, data_width):
    while True:
        await RisingEdge(dut.clk)

        try:
            b_addr = int(dut.sram_b_vector_addr.value)
        except ValueError:
            b_addr = None

        try:
            a_addr = int(dut.sram_a_vector_addr.value)
        except ValueError:
            a_addr = None

        await Timer(1, units="ns")

        if b_addr is not None and b_addr < len(b_mem):
            dut.sram_b_vector_data.value = array_to_vector(b_mem[b_addr], data_width)

        if a_addr is not None and a_addr < len(a_mem):
            dut.sram_a_vector_data.value = array_to_vector(a_mem[a_addr], data_width)


@cocotb.test()
async def test_compute_core(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    ROWS, COLS = 3, 4
    A = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    B = [[2, 1, 3, 7], [7, 7, 7, 7], [2, 1, 3, 7]]
    expected_C = (np.array(A) @ np.array(B)).tolist()

    ACC_WIDTH = int(dut.ACC_WIDTH.value) 
    DATA_WIDTH = int(dut.DATA_WIDTH.value)

    await reset_dut(dut)
    cocotb.start_soon(fill_srams(dut, B, A, DATA_WIDTH))
    await pulse(dut, "start_loading_b")
    await wait_for_signal_value(dut, "status", STATUS_INFERENCE_READY)

    await pulse(dut, "start_computation")

    res_vectors = []
    for i in range(ROWS):
        await wait_for_signal_value(dut, "result_valid", 1)
        vec = [to_signed(int(dut.result[c].value), ACC_WIDTH) for c in range(COLS)]
        res_vectors.append(vec)

    dut._log.info(f"Expected C: {expected_C}")
    dut._log.info(f"Actual C: {res_vectors}")

    assert res_vectors == expected_C, f"expected {expected_C}, actual {res_vectors}"

    