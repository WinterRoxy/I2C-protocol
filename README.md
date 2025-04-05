# I2C_controller Module Documentation

## Overview

The `I2C_controller` module implements a combined I²C master that supports both write and read transactions. It generates the I²C protocol signals—including the start and stop conditions, the clock signal (SCL), and the bidirectional data line (SDA)—and implements a finite state machine (FSM) to control the transaction sequence.

## Features

- **Combined Write/Read Operation:**  
  - **Write Mode (r_w = 0):**  
    The module sends a start condition, transmits a 7-bit address with the write bit appended, waits for a slave ACK, and then transmits one or more data bytes. After each data byte, the module waits for a slave ACK. The number of data bytes to transmit is specified by the `NUM_BYTES` input.
  - **Read Mode (r_w = 1):**  
    The module sends a start condition, transmits a 7-bit address with the read bit appended, waits for a slave ACK, and then releases SDA to sample 8 data bits from the slave. After reading the byte, the module drives a NACK to indicate that no further data will be read.

- **Open-Drain SDA Operation:**  
  SDA is implemented as a bidirectional open-drain bus controlled by an output enable (`sda_oe`) and an output value (`sda_out`). When `sda_oe` is low, the line is high impedance.

- **SCL Generation and Phase Toggling:**  
  SCL is generated based on the input clock, and an internal `phase` signal toggles on every clock edge to create two phases per bit (one for SCL low and one for SCL high). This ensures proper timing for data setup and hold.

- **STOP Condition Generation:**  
  The STOP condition is produced in three phases:
  1. **Phase 0:** SCL is pulled low and SDA is driven low.
  2. **Phase 1:** SCL is driven high while SDA remains low.
  3. **Phase 2:** With SCL high, SDA is driven high to complete the STOP condition.

## Architecture

### Finite State Machine (FSM)

The module uses a 4-bit encoded FSM with the following states:

- **IDLE (4'd0):**  
  Waits for the `start` signal.

- **START_ST (4'd1):**  
  Generates the START condition by transitioning SDA from high to low while SCL is high.

- **SEND_ADDR (4'd2):**  
  Transmits the 8-bit address. The address is formed by concatenating the 7-bit address input with the R/W bit (0 for write, 1 for read).

- **WAIT_ACK_ADDR (4'd3):**  
  Releases SDA (sets it to high impedance) to sample the slave's ACK for the address byte.  
  - If ACK (SDA = 0) is received:
    - In write mode: proceeds to transmit data.
    - In read mode: proceeds to read data.
  - If NACK (SDA ≠ 0) is detected, the transaction is aborted by moving to the STOP condition.

- **SEND_DATA (4'd4):** *(Write mode only)*  
  Transmits an 8-bit data byte.

- **WAIT_ACK_DATA (4'd5):** *(Write mode only)*  
  Releases SDA to sample the slave’s ACK after a data byte.  
  - If ACK is received and there are more bytes to transmit, the FSM loops back to `SEND_DATA`.
  - Otherwise, the FSM proceeds to the STOP condition.

- **READ_DATA (4'd6):** *(Read mode only)*  
  Releases SDA so that the slave can drive data bits. The master samples 8 bits from SDA (typically on the rising edge of SCL).

- **SEND_NACK (4'd7):** *(Read mode only)*  
  After receiving the data byte, the master drives a NACK (SDA = 1) to signal the end of reading.

- **STOP_ST (4'd8):**  
  Generates the STOP condition in three sub-phases (using an internal counter) before returning to IDLE.

### Internal Signals

- **`phase`:**  
  Toggles every clock cycle to create two phases per bit (data setup and data sampling).

- **`bit_cnt`:**  
  A 4-bit counter used to index bits in the current byte (from bit 7 down to 0).

- **`shift_reg`:**  
  An 8-bit register used to hold the byte being transmitted (in write mode) or received (in read mode).

- **`stop_cnt`:**  
  A 2-bit counter that sequences the three phases required to generate the STOP condition.

- **`byte_count`:**  
  Counts the number of data bytes transmitted during a write transaction.

## Port Descriptions

- **Inputs:**
  - `clk`: System clock.
  - `reset`: Asynchronous reset signal.
  - `start`: Initiates a new I²C transaction.
  - `r_w`: Operation mode; `0` for WRITE, `1` for READ.
  - `addr`: 7-bit slave address.
  - `data_in`: 8-bit data input used in WRITE mode (for each data byte).
  - `NUM_BYTES`: Number of data bytes to transmit in WRITE mode.

- **Bidirectional:**
  - `SDA`: I²C data line (open-drain). Driven by the master when `sda_oe` is high, otherwise remains high impedance.

- **Outputs:**
  - `SCL`: I²C clock output.
  - `done`: Indicates the completion of the transaction.
  - `state_reg`: The current state of the FSM (useful for debugging).
  - `data_out`: The 8-bit data received from the slave in READ mode.

## Operation

1. **START Condition:**  
   When `start` is asserted, the FSM enters the `START_ST` state and generates a START condition by driving SDA from high to low while SCL remains high.

2. **Address Transmission:**  
   In the `SEND_ADDR` state, the module transmits the 8-bit address (7-bit address concatenated with the R/W bit).  
   The FSM then enters `WAIT_ACK_ADDR`, where SDA is released so the slave can drive an ACK (logic 0).  
   - If ACK is detected:
     - **Write Mode:** The FSM loads the first data byte and transitions to `SEND_DATA`.
     - **Read Mode:** The FSM transitions to `READ_DATA` to begin sampling data.

3. **Data Transmission (Write Mode):**  
   - In the `SEND_DATA` state, the module sends the 8-bit data byte.
   - In `WAIT_ACK_DATA`, SDA is released so that the slave can ACK the data byte.  
     If ACK is received and more bytes remain (based on `NUM_BYTES`), the FSM loops back to `SEND_DATA` for the next byte. Otherwise, it proceeds to the STOP condition.

4. **Data Reception (Read Mode):**  
   - In `READ_DATA`, the master releases SDA (sets `sda_oe` low) to allow the slave to drive the data.
   - The FSM samples each bit (using the `phase` signal to ensure proper timing) and assembles the received byte in `shift_reg`.
   - Once all 8 bits are received, the FSM transfers the value to `data_out` and moves to `SEND_NACK`.

5. **NACK and STOP Condition:**  
   - In READ mode, the FSM enters `SEND_NACK` to drive a NACK (SDA = 1) indicating that no more data is requested.
   - Finally, in `STOP_ST`, the STOP condition is generated in three phases:
     1. SCL is pulled low while SDA is held low.
     2. SCL is then driven high while SDA remains low.
     3. Finally, SDA is driven high while SCL is high to signal the STOP condition.
   - The FSM then returns to the `IDLE` state, and the `done` signal is asserted.

## Usage Notes

- **Transaction Mode Selection:**  
  Set `r_w = 0` for write transactions and `r_w = 1` for read transactions. In read mode, the `data_in` input is ignored.

- **Multi-Byte Write:**  
  The number of bytes to be transmitted in write mode is specified by `NUM_BYTES`. For each new data byte, it is expected that external logic updates `data_in` before the transaction begins.

- **Timing Considerations:**  
  The I²C clock (SCL) frequency is derived from the input `clk` and the internal phase toggling. Ensure that the `clk` frequency is set appropriately for your I²C speed requirements. Note that the design uses a simple phase delay (two phases per bit) and does not include advanced timing control such as clock stretching.

- **Debugging:**  
  The `state_reg` output provides the current state of the FSM (in 4-bit encoding) which can be monitored during simulation for debugging purposes.

## Summary

The `I2C_controller` module provides a simple and combined I²C master solution supporting both write and read operations. It implements all necessary I²C conditions (START, address transmission with R/W, data transmission/reception, ACK/NACK, and STOP) using a finite state machine with a two-phase clocking scheme. This module is suitable for basic I²C communication scenarios and can be easily integrated into larger designs that require I²C master functionality.
