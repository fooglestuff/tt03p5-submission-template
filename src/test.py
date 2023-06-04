# SPDX-FileCopyrightText: 2023 Anton Maurovic <anton@maurovic.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0


#NOTE: These tests are borrowed from same the solo_squash repo's caravel target
# https://github.com/algofoogle/solo_squash/blob/main/caravel_stuff/test_solo_squash_caravel.py
# and then adapted for tt03p5, with modifications also to handle the registered RGB outputs.


import cocotb
import os
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer, with_timeout
from cocotb.types import Logic


SIM_CLOCK_HZ = 25_000_000
SIM_CLOCK_PERIOD = 1_000_000_000 / SIM_CLOCK_HZ  # =40 (Clock period in nanoseconds)
# Horizontal front porch, hsync, and back porch clock counts:
HF = 16
HS = 96
HB = 48
# Same for vertical:
VF = 10
VS = 2
VB = 33

def init_design_clock(dut):
    clock = Clock(dut.clk, SIM_CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    return clock

async def settle_step(dut):
    # Wait an arbitrarily small amount of time for logic to settle:
    await Timer(10, units="ns")
    # await Timer(1, units="step")

# Assert our external reset for 10 clock cycles,
# so we will then make it to a known state:
async def external_reset_cycle(dut):
    dut.ext_reset_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.ext_reset_n.value = 1
    await settle_step(dut)

# Returns true if the given signal is driven as 0 or 1.
# Otherwise returns false (e.g. for logic X, Z, etc).
def known_driven(signal):
    return signal.value.binstr in {'0', '1'}

# Returns true if the given signal is hi-Z:
def z(signal):
    return signal.value.binstr == 'z'


##############################################################################
### INITIAL TEST: test_start:
### Gets the design to an initial known reset state.
### NOTE: I'm assuming that if this test is run first, then at the end the
### whole system is in a ready state for IO and further tests.
##############################################################################
@cocotb.test()
async def test_start(dut):
    # Init and start the main Caravel clock at 25MHz:
    clock = init_design_clock(dut)
    print("--- TEST DEBUG: Clock started")

    # Set the initial unpressed button states:
    dut.up_key.value        = 0
    dut.down_key.value      = 0
    dut.new_game.value      = 0
    dut.pause.value         = 0

    # Assert our external reset for 10 clock cycles (400ns),
    # so we will then make it to a known state for remaining tests:
    print("--- TEST DEBUG: Resetting main design...")
    await external_reset_cycle(dut)
    print("--- TEST DEBUG: ...main reset done")

    # At this point, the design is at its initial post-reset state,
    # so other tests are good to go.

    # Typical outputs should all be asserted 0 or 1:
    assert known_driven(dut.hsync)
    assert known_driven(dut.vsync)
    assert known_driven(dut.red)
    assert known_driven(dut.green)
    assert known_driven(dut.blue)
    assert known_driven(dut.speaker)

    # Await 1 full clock, to balance out settle_step from external_reset_cycle:
    await ClockCycles(dut.clk, 1)
    print("--- TEST DEBUG: Ready for other tests")



##############################################################################
### test_frame0:
### Generate the first full frame after issuing a reset.
### At the moment this doesn't assert any tests, but rather just ensures
### we capture a good continuation of the VCD to examine.
##############################################################################
@cocotb.test()
async def test_frame0(dut):
    clock = init_design_clock(dut)
    print("--- TEST DEBUG: Clock started in test_frame0")

    await external_reset_cycle(dut)
    print("--- TEST DEBUG: Reset completed. Rendering first frame...")

    # Stabilise after coming out of reset:
    await RisingEdge(dut.clk)

    # Coming out of reset, we should be immediately starting to render the first VGA line, but
    # note that the RGB outputs are expected to be delayed by 1 clock because they're registered.
    # Meanwhile note that HSYNC and VSYNC are NOT registered (because I expect some skew in their
    # timing is fine).

    # Check that the first 2 lines are fully yellow (other than proper HBLANK and HSYNC):
    for v in range(2):
        print(f"--- TEST DEBUG: Testing line {v}...")
        # Visible part of line:
        for h in range(640):
            if h>0:    # Don't check at h==0, because RGB lags by 1 clock.
                # Expect yellow:
                assert dut.red.value    == 1
                assert dut.green.value  == 1
                assert dut.blue.value   == 0
            # Expect HSYNC and VSYNC are NOT asserted:
            assert dut.hsync.value  == 1
            assert dut.vsync.value  == 1
            # Advance to the next clock:
            await ClockCycles(dut.clk, 1)
        # HFRONT porch:
        for h in range(HF):
            if h==0:    # At h==0, RGB are still lagging because they're registered while HSYNC is not.
                # Expect yellow for 1 more pixel:
                assert dut.red.value    == 1
                assert dut.green.value  == 1
                assert dut.blue.value   == 0
            else:
                # Expect black:
                assert dut.red.value    == 0
                assert dut.green.value  == 0
                assert dut.blue.value   == 0
            # Expect HSYNC and VSYNC are NOT asserted:
            assert dut.hsync.value  == 1
            assert dut.vsync.value  == 1
            # Advance to the next clock:
            await ClockCycles(dut.clk, 1)
        # HSYNC pulse:
        for h in range(HS):
            # Expect black:
            assert dut.red.value    == 0
            assert dut.green.value  == 0
            assert dut.blue.value   == 0
            # Expect HSYNC is now asserted, but VSYNC is not:
            assert dut.hsync.value  == 0
            assert dut.vsync.value  == 1
            # Advance to the next clock:
            await ClockCycles(dut.clk, 1)
        # HBACK porch:
        for h in range(HB):
            # Expect black:
            assert dut.red.value    == 0
            assert dut.green.value  == 0
            assert dut.blue.value   == 0
            # Expect HSYNC and VSYNC are NOT asserted:
            assert dut.hsync.value  == 1
            assert dut.vsync.value  == 1
            # Advance to the next clock:
            await ClockCycles(dut.clk, 1)
    # Now we get a little lazy... the NEXT two lines should have some green and yellow pixels (only)
    # so count how many of each:
    yellow_count = 0
    green_count = 0
    for v in range(2):
        print(f"--- TEST DEBUG: Testing line {2+v}...")
        for h in range(640):
            if h>0:
                assert dut.blue.value == 0
                assert dut.green.value == 1
                if dut.red.value:
                    yellow_count += 1
                else:
                    green_count += 1
            await ClockCycles(dut.clk, 1)
        for h in range(HF+HS+HB):
            await ClockCycles(dut.clk, 1)
    # Horizontal "bricks" in the upper wall are each 32 pixels wide, so there are 640/32 = 20 of them.
    # The yellow "mortar" between any pair of them is 4 pixels wide, while the outer-most mortar on
    # each side is 2 pixels wide. Thus, 80 yellow pixels per line in total, but to keep things simple
    # we only end up counting 79 per line, above, or 158 total per 2 lines.
    assert yellow_count == 158
    # Green pixels should be the difference of 1280-160, i.e. 1120:
    assert green_count == 1120

    # Now render the remaining lines for this frame, just to get a full VCD:
    for v in range(480+VF+VS+VB-4):
        print(f"--- TEST DEBUG: Skimming line {4+v}...")
        for h in range(800):
            await ClockCycles(dut.clk, 1)

    print("--- TEST DEBUG: First frame completed")
    # Verify we're in a black region...
    assert dut.red.value    == 0
    assert dut.green.value  == 0
    assert dut.blue.value   == 0
    # Wait 1 more clock...
    await ClockCycles(dut.clk, 1)
    # ...and then we should be able to verify we've got a yellow pixel again:
    assert dut.red.value    == 1
    assert dut.green.value  == 1
    assert dut.blue.value   == 0
