# SPDX-FileCopyrightText: 2026 ChipFoundry
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
#
# SPDX-License-Identifier: Apache-2.0

"""Functional test for the example timer (verilog/rtl/timer.v).

The wrapper maps the timer as follows:
  GPIO 0     user clock
  GPIO 1     user reset (active high)
  GPIO 5:2   digit enable
  GPIO 12:6  seven-segment (common cathode, CC=1)
"""

from cocotb.triggers import Timer
import cocotb
from caravel_cocotb.caravel_interfaces import report_test, test_configure

# Common-cathode encodings produced by timer.v with CC=1.
SEG = {
    0: 0b1111110,
    1: 0b0110000,
}
DIGIT_ONES = 0b1110  # dig_cnt == 0, seconds ones
DIGIT_TENS = 0b1101  # dig_cnt == 1, seconds tens

CLK_GPIO = 0
RST_GPIO = 1
# FREQ=2000, so the ones digit increments on user cycle 2001 and is scanned
# out a few cycles later. 2500 clocks covers that without reaching 10 seconds.
USER_CLOCKS = 2500


async def user_clocks(env, count):
    for _ in range(count):
        env.drive_gpio(CLK_GPIO, 0)
        await Timer(10, units="ns")
        env.drive_gpio(CLK_GPIO, 1)
        await Timer(10, units="ns")


def read_display(env):
    digit_en = env.monitor_gpio_range((5, 2))
    seven_seg = env.monitor_gpio_range((12, 6))
    return digit_en, seven_seg


@cocotb.test()
@report_test
async def timer(dut):
    env = await test_configure(dut, timeout_cycles=20000)

    env.drive_gpio(RST_GPIO, 1)
    await user_clocks(env, 4)
    digit_en, seven_seg = read_display(env)
    assert (digit_en, seven_seg) == (DIGIT_ONES, SEG[0]), (
        f"reset display was digit_en={digit_en:04b} seven_seg={seven_seg:07b}, "
        f"expected {DIGIT_ONES:04b} {SEG[0]:07b}"
    )

    env.drive_gpio(RST_GPIO, 0)
    saw_zero = False
    saw_one = False
    for _ in range(USER_CLOCKS):
        await user_clocks(env, 1)
        digit_en, seven_seg = read_display(env)
        if digit_en == DIGIT_ONES:
            if seven_seg == SEG[0]:
                saw_zero = True
            elif seven_seg == SEG[1]:
                if not saw_zero:
                    raise AssertionError("seconds ones showed 1 before 0")
                saw_one = True
            else:
                raise AssertionError(
                    f"unexpected seconds-ones pattern {seven_seg:07b}"
                )
        elif digit_en == DIGIT_TENS and seven_seg != SEG[0]:
            raise AssertionError(
                f"seconds tens changed during the first second: {seven_seg:07b}"
            )

    assert saw_zero and saw_one, (
        "seconds ones digit did not count from 0 to 1 "
        f"(saw 0={saw_zero}, saw 1={saw_one})"
    )
    cocotb.log.info("[timer] seconds digit counted from 0 to 1")
