# Testbench Notes

Assumptions required by the spec:

- `value`, `value_next`, and `initial_value` are modeled as 4-bit signals because the counter range is 0 through 10.
- `incr` and `decr` are modeled as 2-bit signals because the spec states their maximum value is 3.
- `rst` is treated as a synchronous active-high reset exactly like `reinit`, and both force `value_next` to equal `initial_value` in the same cycle.
- The testbench expects `value` to update on each rising edge of `clk` and checks `value_next` combinationally before and after each active clock edge.

Coverage included by the testbench:

- Synchronous reset load
- Hold behavior with no valid requests
- Increment-only and decrement-only updates
- Simultaneous increment and decrement using net change
- Overflow wrap-around and underflow wrap-around
- `reinit` priority over concurrent increment/decrement requests
- `rst` priority over concurrent increment/decrement requests
