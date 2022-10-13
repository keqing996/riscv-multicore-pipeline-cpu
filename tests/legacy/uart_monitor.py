import cocotb
from cocotb.triggers import RisingEdge

async def monitor_uart(dut):
    """Monitor UART output and return the captured string."""
    log = ""
    while True:
        await RisingEdge(dut.clk)
        # Check if UART Write Enable is high
        # Hierarchy: system_top -> u_core -> uart_write_enable
        if dut.u_core.uart_write_enable.value == 1:
            # Read data from rs2_data (which is write_data for UART)
            # Hierarchy: system_top -> u_core -> u_uart_simulator -> write_data
            # Or directly from core's internal signal if exposed.
            # In system_top, we don't expose uart signals directly, but we can access internal signals via dot notation in Cocotb.
            
            # Note: Accessing internal signals might depend on simulator capabilities (Icarus usually allows it).
            try:
                char_code = int(dut.u_core.u_uart_simulator.write_data.value)
                char = chr(char_code & 0xFF)
                log += char
                # print(char, end="", flush=True) # Optional: print to console in real-time
            except Exception:
                pass
                
        # Check for end of test or timeout is handled by the main test coroutine
        # But we need a way to break this loop or just let it run as a background task.
        # We'll return the log when queried? No, this is a coroutine.
        # We can use a global list or a mutable object passed in.
    return log

class UARTMonitor:
    def __init__(self, dut):
        self.dut = dut
        self.log = ""
        self._coro = None

    def start(self):
        self._coro = cocotb.start_soon(self._monitor())

    async def _monitor(self):
        while True:
            await RisingEdge(self.dut.clk)
            try:
                # Check if UART Write Enable is high
                # We need to access the signal that enables UART write.
                # In core.v: uart_write_enable
                if self.dut.u_core.uart_write_enable.value == 1:
                    # The data to write is in ex_mem_rs2_data or similar, passed to u_uart_simulator
                    # Let's look at u_uart_simulator.write_data
                    val = self.dut.u_core.u_uart_simulator.write_data.value
                    self.log += chr(int(val) & 0xFF)
            except Exception:
                pass
