import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

async def test_uart_rec(dut, value):
    await FallingEdge(dut.uart_tx)
    await ClockCycles(dut.clk, 2)
    assert dut.uart_tx.value == 0
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == value & 1
    value >>= 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == 1
    await ClockCycles(dut.clk, 9)
    assert dut.uart_tx.value == 1

@cocotb.test()
async def test_cpu(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut.DI.value = 0
    dut.uart_rx.value = 1
    dut.intr.value = 0
    dut._log.info("reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    await ClockCycles(dut.clk, 25)
    await test_uart_rec(dut, 0x57)
    
    for i in range(0, 16):
        await RisingEdge(dut.Q)
        await FallingEdge(dut.Q)

    await test_uart_rec(dut, 0x16)
    await test_uart_rec(dut, 0x34)
    
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 0
    dut.DI.value = 1
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 1
    dut.DI.value = 0
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 1
    dut.DI.value = 1
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 1
    dut.DI.value = 1
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 0
    dut.DI.value = 0
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 0
    dut.DI.value = 0
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 0
    dut.DI.value = 1
    await FallingEdge(dut.SCLK)
    await RisingEdge(dut.SCLK)
    assert dut.DO.value == 1
    
    await test_uart_rec(dut, 0b01011001)
    
    await RisingEdge(dut.Q)
    await ClockCycles(dut.clk, 32)
