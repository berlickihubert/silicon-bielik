import numpy as np

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CMD_NOP     = 0
CMD_LOAD_B  = 1
CMD_COMPUTE = 2

STATUS_IDLE            = 0
STATUS_LOAD_B          = 1
STATUS_INFERENCE_READY = 2
STATUS_COMPUTE         = 3
STATUS_INFERENCE_DONE  = 4


def to_signed(value, width):
    value &= (1 << width) - 1
    if value & (1 << (width - 1)):
        value -= 1 << width
    return value

# Pakuje tablice w bitowo jeden wektor
def pack_vector(values, width):
    mask = (1 << width) - 1
    word = 0
    for i, v in enumerate(values):
        word |= (int(v) & mask) << (i * width)
    return word


class AcceleratorDriver:

    def __init__(self, dut):
        self.dut = dut
        self.rows = int(dut.ROWS.value)
        self.cols = int(dut.COLS.value)
        self.data_width = int(dut.DATA_WIDTH.value)
        self.acc_width = int(dut.ACC_WIDTH.value)

    async def _sample(self):
        await RisingEdge(self.dut.clk)
        await Timer(1, units="ns")

    async def reset(self):
        d = self.dut
        d.cmd_valid.value = 0
        d.cmd.value = 0
        d.s_axis_b_tdata.value = 0
        d.s_axis_b_tvalid.value = 0
        d.s_axis_b_tlast.value = 0
        d.s_axis_a_tdata.value = 0
        d.s_axis_a_tvalid.value = 0
        d.s_axis_a_tlast.value = 0
        d.m_axis_tready.value = 0
        d.rst_n.value = 0
        await ClockCycles(d.clk, 4)
        d.rst_n.value = 1
        await self._sample()

    async def send_cmd(self, cmd):
        d = self.dut
        d.cmd.value = cmd
        d.cmd_valid.value = 1
        await self._sample()
        d.cmd_valid.value = 0
        d.cmd.value = CMD_NOP

    def read_status(self):
        return int(self.dut.status.value) & 0x7

    async def wait_status(self, target, timeout=2000):
        for _ in range(timeout):
            if self.read_status() == target:
                return
            await self._sample()
        raise TimeoutError(f"STATUS nie osiagnal {target}")

    async def _send_stream(self, tdata, tvalid, tready, tlast, words):
        for i, w in enumerate(words):
            tdata.value = w
            tvalid.value = 1
            tlast.value = 1 if i == len(words) - 1 else 0
            while True:
                await self._sample()
                if tready.value == 1:
                    break
        tvalid.value = 0
        tlast.value = 0

    async def load_b(self, b_matrix):
        words = [pack_vector(row, self.data_width) for row in b_matrix]
        d = self.dut
        await self._send_stream(d.s_axis_b_tdata, d.s_axis_b_tvalid,
                                d.s_axis_b_tready, d.s_axis_b_tlast, words)

    async def load_a(self, a_vectors):
        words = [pack_vector(vec, self.data_width) for vec in a_vectors]
        d = self.dut
        await self._send_stream(d.s_axis_a_tdata, d.s_axis_a_tvalid,
                                d.s_axis_a_tready, d.s_axis_a_tlast, words)

    async def read_result(self, timeout=4000):
        d = self.dut
        d.m_axis_tready.value = 1
        flat = []
        got_last = False
        for _ in range(timeout):
            await self._sample()
            if d.m_axis_tvalid.value == 1:
                flat.append(to_signed(int(d.m_axis_tdata.value), self.acc_width))
                if d.m_axis_tlast.value == 1:
                    got_last = True
                    break
        d.m_axis_tready.value = 0
        if not got_last:
            raise TimeoutError("nie odebrano pelnego wyniku (brak tlast)")
        return [flat[i * self.cols:(i + 1) * self.cols] for i in range(self.rows)]

    async def run_matmul(self, b_matrix, a_vectors):
        await self.load_b(b_matrix)
        await self.load_a(a_vectors)
        await self.send_cmd(CMD_LOAD_B)
        await self.wait_status(STATUS_INFERENCE_READY)
        await self.send_cmd(CMD_COMPUTE)
        return await self.read_result()


@cocotb.test()
async def test_accelerator_matmul(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    ROWS, COLS = 3, 4
    A = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    B = [[2, 1, 3, 7], [7, 7, 7, 7], [2, 1, 3, 7]]
    expected_C = (np.array(A) @ np.array(B)).tolist()

    drv = AcceleratorDriver(dut)
    await drv.reset()

    result = await drv.run_matmul(B, A)

    dut._log.info(f"Expected C: {expected_C}")
    dut._log.info(f"Actual C: {result}")

    assert result == expected_C, f"expected {expected_C}, got {result}"
