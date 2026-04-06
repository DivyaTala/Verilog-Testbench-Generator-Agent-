module tb_counter;
  localparam int MIN_VALUE = 0;
  localparam int MAX_VALUE = 10;
  localparam int MODULUS   = MAX_VALUE - MIN_VALUE + 1;

  logic       clk;
  logic       rst;
  logic       reinit;
  logic       incr_valid;
  logic       decr_valid;
  logic [3:0] initial_value;
  logic [1:0] incr;
  logic [1:0] decr;
  logic [3:0] value;
  logic [3:0] value_next;

  int expected_value;

  counter dut (
    .clk(clk),
    .rst(rst),
    .reinit(reinit),
    .incr_valid(incr_valid),
    .decr_valid(decr_valid),
    .initial_value(initial_value),
    .incr(incr),
    .decr(decr),
    .value(value),
    .value_next(value_next)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  function automatic int wrap_value(int raw_value);
    int wrapped;
    begin
      wrapped = raw_value % MODULUS;
      if (wrapped < 0) begin
        wrapped += MODULUS;
      end
      return wrapped;
    end
  endfunction

  function automatic int calc_next_value(
    int current_value,
    bit rst_i,
    bit reinit_i,
    int initial_value_i,
    bit incr_valid_i,
    bit decr_valid_i,
    int incr_i,
    int decr_i
  );
    int delta;
    begin
      if (rst_i || reinit_i) begin
        return initial_value_i;
      end

      delta = 0;
      if (incr_valid_i) begin
        delta += incr_i;
      end
      if (decr_valid_i) begin
        delta -= decr_i;
      end

      return wrap_value(current_value + delta);
    end
  endfunction

  task automatic check_outputs(string label, int expected_next);
    begin
      #1;
      if (value !== expected_value[3:0]) begin
        $fatal(1, "%s: value mismatch. expected=%0d actual=%0d", label, expected_value, value);
      end
      if (value_next !== expected_next[3:0]) begin
        $fatal(1, "%s: value_next mismatch. expected=%0d actual=%0d", label, expected_next, value_next);
      end
    end
  endtask

  task automatic apply_and_step(
    string label,
    bit rst_i,
    bit reinit_i,
    bit incr_valid_i,
    bit decr_valid_i,
    int initial_value_i,
    int incr_i,
    int decr_i
  );
    int expected_next;
    int post_edge_expected_next;
    begin
      rst           = rst_i;
      reinit        = reinit_i;
      incr_valid    = incr_valid_i;
      decr_valid    = decr_valid_i;
      initial_value = initial_value_i[3:0];
      incr          = incr_i[1:0];
      decr          = decr_i[1:0];

      expected_next = calc_next_value(
        expected_value,
        rst_i,
        reinit_i,
        initial_value_i,
        incr_valid_i,
        decr_valid_i,
        incr_i,
        decr_i
      );

      check_outputs({label, " pre-edge"}, expected_next);

      @(posedge clk);
      #1;
      expected_value = expected_next;
      post_edge_expected_next = calc_next_value(
        expected_value,
        rst,
        reinit,
        initial_value,
        incr_valid,
        decr_valid,
        incr,
        decr
      );

      if (value !== expected_value[3:0]) begin
        $fatal(1, "%s: registered value mismatch after clock. expected=%0d actual=%0d", label, expected_value, value);
      end
      if (value_next !== post_edge_expected_next[3:0]) begin
        $fatal(1, "%s: value_next mismatch after clock. expected=%0d actual=%0d",
               label,
               post_edge_expected_next,
               value_next);
      end
    end
  endtask

  initial begin
    rst           = 1'b0;
    reinit        = 1'b0;
    incr_valid    = 1'b0;
    decr_valid    = 1'b0;
    initial_value = 4'd0;
    incr          = 2'd0;
    decr          = 2'd0;
    expected_value = 0;

    apply_and_step("synchronous reset loads initial value", 1'b1, 1'b0, 1'b0, 1'b0, 4, 0, 0);
    apply_and_step("hold with no valids",                 1'b0, 1'b0, 1'b0, 1'b0, 4, 0, 0);
    apply_and_step("increment by 2",                      1'b0, 1'b0, 1'b1, 1'b0, 4, 2, 0);
    apply_and_step("decrement by 1",                      1'b0, 1'b0, 1'b0, 1'b1, 4, 0, 1);
    apply_and_step("simultaneous incr and decr",          1'b0, 1'b0, 1'b1, 1'b1, 4, 3, 1);
    apply_and_step("overflow wraps around",               1'b0, 1'b0, 1'b1, 1'b0, 4, 3, 0);
    apply_and_step("reinitialize dominates updates",      1'b0, 1'b1, 1'b1, 1'b1, 7, 3, 3);
    apply_and_step("underflow wraps around",              1'b0, 1'b0, 1'b0, 1'b1, 7, 0, 3);
    apply_and_step("reset dominates updates",             1'b1, 1'b0, 1'b1, 1'b1, 9, 3, 3);
    apply_and_step("post-reset hold",                     1'b0, 1'b0, 1'b0, 1'b0, 9, 0, 0);

    $display("TB_PASS");
    $finish;
  end

endmodule
