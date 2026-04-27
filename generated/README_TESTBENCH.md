# Testbench Notes

- The testbench targets module `cdc_fifo_flops_push_credit` from `specs/my_spec.md`.
- It is self-checking and maintains a simple FIFO/credit scoreboard for:
  `pop_data`, `pop_valid`, `pop_empty`, `pop_items`, `push_slots`,
  `push_full`, `credit_count_push`, and `credit_available_push`.
- It exercises:
  reset behavior, empty-to-nonempty cut-through, backpressure hold,
  FIFO ordering, withheld-credit accounting, stalled credit return,
  full-depth operation, pointer wraparound, and the sender-reset handshake.

## Assumptions

- Cross-domain visibility is allowed to take multiple destination-clock cycles.
  The testbench uses bounded waits of up to 48 push or pop clocks to allow for
  the specified synchronizer and delayed-reset behavior.
- `push_slots` reflects physical FIFO storage space, while
  `credit_available_push` reflects sender-visible credits after withholding.
- `credit_count_push` is expected to increase only when the returned credit is
  observed on `push_credit`.
