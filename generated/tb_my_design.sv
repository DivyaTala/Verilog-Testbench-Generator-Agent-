module tb_my_design;

  localparam int MAX_VALUE = 10;

  logic       clk;
  logic       rst;
  logic       reinit;
  logic       incr_valid;
  logic       decr_valid;
  logic [1:0] incr;
  logic [1:0] decr;
  logic [3:0] initial_value;
  logic [3:0] value;
  logic [3:0] value_next;

  my_dut dut (
    .clk(clk),
    .rst(rst),
    .reinit(reinit),
    .incr_valid(incr_valid),
    .decr_valid(decr_valid),
    .incr(incr),
    .decr(decr),
    .initial_value(initial_value),
    .value(value),
    .value_next(value_next)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  function automatic int wrap_value(input int raw_value);
    int wrapped;
    wrapped = raw_value % (MAX_VALUE + 1);
    if (wrapped < 0) begin
      wrapped += (MAX_VALUE + 1);
    end
    return wrapped;
  endfunction

  function automatic int compute_next_value(
    input int current_value,
    input bit rst_i,
    input bit reinit_i,
    input bit incr_valid_i,
    input bit decr_valid_i,
    input int incr_i,
    input int decr_i,
    input int initial_value_i
  );
    int next_value;
    if (rst_i || reinit_i) begin
      next_value = initial_value_i;
    end else begin
      next_value = current_value;
      if (incr_valid_i) begin
        next_value += incr_i;
      end
      if (decr_valid_i) begin
        next_value -= decr_i;
      end
      next_value = wrap_value(next_value);
    end
    return next_value;
  endfunction

  task automatic check_value_next(
    input int expected,
    input string context
  );
    #1;
    if (value_next !== expected[3:0]) begin
      $fatal(1, "%s: value_next mismatch. expected=%0d actual=%0d", context, expected, value_next);
    end
  endtask

  task automatic drive_and_check(
    input bit rst_i,
    input bit reinit_i,
    input bit incr_valid_i,
    input bit decr_valid_i,
    input int incr_i,
    input int decr_i,
    input int initial_value_i,
    inout int expected_value,
    input string context
  );
    int expected_next;
    rst = rst_i;
    reinit = reinit_i;
    incr_valid = incr_valid_i;
    decr_valid = decr_valid_i;
    incr = incr_i[1:0];
    decr = decr_i[1:0];
    initial_value = initial_value_i[3:0];

    expected_next = compute_next_value(
      expected_value,
      rst_i,
      reinit_i,
      incr_valid_i,
      decr_valid_i,
      incr_i,
      decr_i,
      initial_value_i
    );

    check_value_next(expected_next, {context, " before clock"});

    @(posedge clk);
    #1;
    if (value !== expected_next[3:0]) begin
      $fatal(1, "%s: value mismatch after clock. expected=%0d actual=%0d", context, expected_next, value);
    end

    expected_value = expected_next;
    check_value_next(expected_value, {context, " after clock"});
  endtask

  initial begin
    int expected_value;

    rst = 1'b0;
    reinit = 1'b0;
    incr_valid = 1'b0;
    decr_valid = 1'b0;
    incr = '0;
    decr = '0;
    initial_value = '0;
    expected_value = 0;

    drive_and_check(1'b1, 1'b0, 1'b0, 1'b0, 0, 0, 4, expected_value, "synchronous reset loads initial value");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b0, 2, 0, 4, expected_value, "increment by two");
    drive_and_check(1'b0, 1'b0, 1'b0, 1'b1, 0, 1, 4, expected_value, "decrement by one");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b1, 3, 1, 4, expected_value, "simultaneous increment and decrement");
    drive_and_check(1'b0, 1'b0, 1'b0, 1'b0, 0, 0, 4, expected_value, "hold when no valid inputs");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b0, 3, 0, 4, expected_value, "increment to boundary");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b0, 1, 0, 4, expected_value, "overflow wraps from ten to zero");
    drive_and_check(1'b0, 1'b0, 1'b0, 1'b1, 0, 2, 4, expected_value, "underflow wraps from zero to nine");
    drive_and_check(1'b0, 1'b1, 1'b1, 1'b1, 3, 3, 7, expected_value, "reinit overrides increment and decrement");
    drive_and_check(1'b0, 1'b0, 1'b0, 1'b1, 0, 3, 7, expected_value, "decrement by three");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b1, 0, 3, 7, expected_value, "simultaneous zero increment and decrement");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b0, 3, 0, 7, expected_value, "increment back to boundary");
    drive_and_check(1'b0, 1'b0, 1'b1, 1'b0, 3, 0, 7, expected_value, "overflow wraps with increment of three");

    $display("TB_PASS");
    $finish;
  end

endmodule
