module tb_counter;

  localparam integer MAX_VALUE = 10;
  localparam integer MODULUS = MAX_VALUE + 1;

  reg        clk;
  reg        rst;
  reg        reinit;
  reg        incr_valid;
  reg        decr_valid;
  reg [3:0]  initial_value;
  reg [1:0]  incr;
  reg [1:0]  decr;
  wire [3:0] value;
  wire [3:0] value_next;

  integer expected_value;
  integer case_id;

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

  function automatic integer wrap_value;
    input integer raw_value;
    begin
      wrap_value = raw_value % MODULUS;
      if (wrap_value < 0) begin
        wrap_value = wrap_value + MODULUS;
      end
    end
  endfunction

  function automatic integer model_next;
    input integer current_value;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    integer raw_next;
    begin
      if (rst_i || reinit_i) begin
        model_next = initial_value_i;
      end else begin
        raw_next = current_value;
        if (incr_valid_i) begin
          raw_next = raw_next + incr_i;
        end
        if (decr_valid_i) begin
          raw_next = raw_next - decr_i;
        end
        model_next = wrap_value(raw_next);
      end
    end
  endfunction

  task automatic fail_check;
    input [255:0] check_name;
    input integer expected_int;
    input integer actual_int;
    begin
      $display(
        "TB_FAIL case=%0d check=%0s expected=%0d actual=%0d time=%0t",
        case_id,
        check_name,
        expected_int,
        actual_int,
        $time
      );
      $fatal(1);
    end
  endtask

  task automatic drive_inputs;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    begin
      rst = rst_i[0];
      reinit = reinit_i[0];
      incr_valid = incr_valid_i[0];
      decr_valid = decr_valid_i[0];
      initial_value = initial_value_i[3:0];
      incr = incr_i[1:0];
      decr = decr_i[1:0];
      #0;
      #0;
    end
  endtask

  task automatic expect_now;
    input integer expected_value_i;
    input integer expected_next_i;
    begin
      if (^value === 1'bx) begin
        fail_check("value_unknown", expected_value_i, value);
      end
      if (^value_next === 1'bx) begin
        fail_check("value_next_unknown", expected_next_i, value_next);
      end
      if (value !== expected_value_i[3:0]) begin
        fail_check("value", expected_value_i, value);
      end
      if (value_next !== expected_next_i[3:0]) begin
        fail_check("value_next", expected_next_i, value_next);
      end
    end
  endtask

  task automatic set_state;
    input integer target_state;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 0, 0, target_state, 0, 0);
      expect_now(expected_value, target_state);

      @(posedge clk);
      expected_value = target_state;
      #1;
      expect_now(expected_value, target_state);

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, target_state, 0, 0);
      expect_now(expected_value, expected_value);

      @(posedge clk);
      #1;
      expect_now(expected_value, expected_value);
    end
  endtask

  task automatic initialize_state;
    input integer target_state;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 0, 0, target_state, 0, 0);

      @(posedge clk);
      expected_value = target_state;
      #1;
      expect_now(expected_value, target_state);

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, target_state, 0, 0);
      expect_now(expected_value, expected_value);

      @(posedge clk);
      #1;
      expect_now(expected_value, expected_value);
    end
  endtask

  task automatic check_cycle;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    integer expected_next_before_edge;
    integer expected_next_after_edge;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(rst_i, reinit_i, incr_valid_i, decr_valid_i, initial_value_i, incr_i, decr_i);

      expected_next_before_edge = model_next(
        expected_value,
        rst_i,
        reinit_i,
        incr_valid_i,
        decr_valid_i,
        initial_value_i,
        incr_i,
        decr_i
      );
      expect_now(expected_value, expected_next_before_edge);

      @(posedge clk);
      expected_value = expected_next_before_edge;
      #1;

      expected_next_after_edge = model_next(
        expected_value,
        rst_i,
        reinit_i,
        incr_valid_i,
        decr_valid_i,
        initial_value_i,
        incr_i,
        decr_i
      );
      expect_now(expected_value, expected_next_after_edge);
    end
  endtask

  task automatic check_midcycle;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    integer expected_next_i;
    begin
      case_id = case_id + 1;
      drive_inputs(rst_i, reinit_i, incr_valid_i, decr_valid_i, initial_value_i, incr_i, decr_i);
      expected_next_i = model_next(
        expected_value,
        rst_i,
        reinit_i,
        incr_valid_i,
        decr_valid_i,
        initial_value_i,
        incr_i,
        decr_i
      );
      expect_now(expected_value, expected_next_i);
    end
  endtask

  task automatic check_priority_behavior;
    integer init_sel;
    begin
      set_state(7);
      for (init_sel = 0; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
        check_cycle(1, 0, 1, 1, init_sel, 3, 3);
        check_cycle(0, 1, 1, 1, init_sel, 3, 3);
      end
    end
  endtask

  task automatic check_arithmetic_state_space;
    integer start_value;
    integer incr_sel;
    integer decr_sel;
    begin
      for (start_value = 0; start_value <= MAX_VALUE; start_value = start_value + 1) begin
        set_state(start_value);
        check_cycle(0, 0, 0, 0, 0, 0, 0);

        for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
          set_state(start_value);
          check_cycle(0, 0, 1, 0, 0, incr_sel, 0);
        end

        for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
          set_state(start_value);
          check_cycle(0, 0, 0, 1, 0, 0, decr_sel);
        end

        for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
          for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
            set_state(start_value);
            check_cycle(0, 0, 1, 1, 0, incr_sel, decr_sel);
          end
        end
      end
    end
  endtask

  task automatic check_midcycle_reactivity;
    begin
      set_state(4);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, expected_value);

      check_midcycle(0, 0, 1, 0, 0, 1, 0);
      check_midcycle(0, 0, 1, 0, 0, 3, 0);
      check_midcycle(0, 0, 0, 1, 0, 0, 2);
      check_midcycle(0, 0, 1, 1, 0, 3, 1);
      check_midcycle(0, 1, 1, 1, 8, 3, 3);
      check_midcycle(1, 0, 1, 1, 2, 3, 3);
      check_midcycle(0, 1, 0, 0, 10, 0, 0);
      check_midcycle(1, 0, 0, 0, 6, 0, 0);
      check_midcycle(0, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, expected_value);
    end
  endtask

  task automatic check_midcycle_state_space;
    integer start_value;
    integer incr_sel;
    integer decr_sel;
    integer init_sel;
    begin
      for (start_value = 0; start_value <= MAX_VALUE; start_value = start_value + 1) begin
        set_state(start_value);

        case_id = case_id + 1;
        @(negedge clk);
        drive_inputs(0, 0, 0, 0, 0, 0, 0);
        expect_now(expected_value, expected_value);

        for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
          check_midcycle(0, 0, 1, 0, 0, incr_sel, 0);
        end

        for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
          check_midcycle(0, 0, 0, 1, 0, 0, decr_sel);
        end

        for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
          for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
            check_midcycle(0, 0, 1, 1, 0, incr_sel, decr_sel);
          end
        end

        for (init_sel = 0; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
          check_midcycle(0, 1, 1, 1, init_sel, 3, 2);
          check_midcycle(1, 0, 1, 1, init_sel, 2, 3);
        end

        check_midcycle(0, 0, 0, 0, 0, 0, 0);
        expect_now(expected_value, expected_value);
      end
    end
  endtask

  task automatic check_targeted_boundaries;
    begin
      set_state(5);
      check_cycle(0, 0, 1, 0, 0, 2, 0);

      set_state(9);
      check_cycle(0, 0, 1, 0, 0, 3, 0);

      set_state(1);
      check_cycle(0, 0, 0, 1, 0, 0, 3);

      set_state(1);
      check_cycle(0, 0, 1, 1, 0, 1, 3);

      set_state(6);
      check_cycle(0, 0, 1, 1, 0, 3, 1);

      set_state(7);
      check_cycle(0, 1, 1, 1, 2, 3, 3);

      set_state(3);
      check_cycle(1, 0, 1, 0, 9, 3, 0);
    end
  endtask

  task automatic check_reset_reinit_initial_value_tracking;
    integer init_sel;
    begin
      set_state(4);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, 0);
      for (init_sel = 1; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
        check_midcycle(1, 0, 0, 0, init_sel, 0, 0);
      end

      @(posedge clk);
      expected_value = MAX_VALUE;
      #1;
      expect_now(expected_value, MAX_VALUE);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 1, 1, 1, 10, 3, 3);
      expect_now(expected_value, 10);
      for (init_sel = MAX_VALUE - 1; init_sel >= 0; init_sel = init_sel - 1) begin
        check_midcycle(0, 1, 1, 1, init_sel, 3, 3);
      end

      @(posedge clk);
      expected_value = 0;
      #1;
      expect_now(expected_value, 0);

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, expected_value);
    end
  endtask

  task automatic check_initial_value_ignored_without_reset_or_reinit;
    integer init_sel;
    integer baseline_next;
    begin
      set_state(6);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 1, 1, 0, 3, 1);
      baseline_next = model_next(expected_value, 0, 0, 1, 1, 0, 3, 1);
      expect_now(expected_value, baseline_next);
      for (init_sel = 1; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
        check_midcycle(0, 0, 1, 1, init_sel, 3, 1);
      end

      @(posedge clk);
      expected_value = baseline_next;
      #1;
      expect_now(expected_value, model_next(expected_value, 0, 0, 1, 1, 0, 3, 1));

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, expected_value);
      for (init_sel = 1; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
        check_midcycle(0, 0, 0, 0, init_sel, 0, 0);
      end
    end
  endtask

  task automatic check_held_input_multi_cycle_sequences;
    integer cycle_idx;
    integer expected_next_i;
    begin
      set_state(8);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 1, 0, 10, 3, 0);
      for (cycle_idx = 0; cycle_idx < 4; cycle_idx = cycle_idx + 1) begin
        expected_next_i = model_next(expected_value, 0, 0, 1, 0, 10, 3, 0);
        expect_now(expected_value, expected_next_i);
        @(posedge clk);
        expected_value = expected_next_i;
        #1;
      end
      expect_now(expected_value, model_next(expected_value, 0, 0, 1, 0, 10, 3, 0));

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 1, 1, 4, 1, 3);
      for (cycle_idx = 0; cycle_idx < 4; cycle_idx = cycle_idx + 1) begin
        expected_next_i = model_next(expected_value, 0, 0, 1, 1, 4, 1, 3);
        expect_now(expected_value, expected_next_i);
        @(posedge clk);
        expected_value = expected_next_i;
        #1;
      end
      expect_now(expected_value, model_next(expected_value, 0, 0, 1, 1, 4, 1, 3));

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 0, 0, 0);
      expect_now(expected_value, expected_value);
    end
  endtask

  task automatic check_consecutive_sequences;
    begin
      set_state(8);
      check_cycle(0, 0, 1, 0, 0, 3, 0);
      check_cycle(0, 0, 1, 0, 0, 3, 0);
      check_cycle(0, 0, 0, 1, 0, 0, 2);
      check_cycle(0, 0, 1, 1, 0, 1, 3);

      set_state(10);
      check_cycle(0, 0, 1, 1, 0, 3, 1);
      check_cycle(0, 0, 1, 1, 0, 0, 2);
      check_cycle(0, 0, 0, 0, 0, 0, 0);
      check_cycle(0, 0, 0, 1, 0, 0, 3);

      set_state(6);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 1, 1, 1, 4, 3, 3);
      expect_now(expected_value, 4);
      check_midcycle(0, 1, 0, 0, 9, 0, 0);

      @(posedge clk);
      expected_value = 9;
      #1;
      expect_now(expected_value, 9);

      @(negedge clk);
      drive_inputs(0, 1, 1, 0, 2, 1, 0);
      expect_now(expected_value, 2);

      @(posedge clk);
      expected_value = 2;
      #1;
      expect_now(expected_value, 2);

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 2, 0, 0);
      expect_now(expected_value, expected_value);

      set_state(5);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 1, 1, 8, 3, 3);
      expect_now(expected_value, 8);
      check_midcycle(1, 0, 0, 0, 1, 0, 0);

      @(posedge clk);
      expected_value = 1;
      #1;
      expect_now(expected_value, 1);

      @(negedge clk);
      drive_inputs(1, 0, 0, 1, 10, 0, 3);
      expect_now(expected_value, 10);

      @(posedge clk);
      expected_value = 10;
      #1;
      expect_now(expected_value, 10);

      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 10, 0, 0);
      expect_now(expected_value, expected_value);
    end
  endtask

  initial begin
    rst = 1'b1;
    reinit = 1'b0;
    incr_valid = 1'b0;
    decr_valid = 1'b0;
    initial_value = 4'd0;
    incr = 2'd0;
    decr = 2'd0;
    expected_value = 0;
    case_id = 0;

    initialize_state(0);
    check_targeted_boundaries();
    check_reset_reinit_initial_value_tracking();
    check_initial_value_ignored_without_reset_or_reinit();
    check_midcycle_reactivity();
    check_midcycle_state_space();
    check_held_input_multi_cycle_sequences();
    check_consecutive_sequences();
    check_priority_behavior();
    check_arithmetic_state_space();

    $display("TB_PASS");
    $finish;
  end

endmodule
