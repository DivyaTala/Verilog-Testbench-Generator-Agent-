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

  function integer wrap_value;
    input integer raw_value;
    begin
      wrap_value = raw_value % MODULUS;
      if (wrap_value < 0) begin
        wrap_value = wrap_value + MODULUS;
      end
    end
  endfunction

  function integer model_next;
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

  task fail_check;
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

  task drive_inputs;
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

  task expect_value_only;
    input integer expected_value_i;
    begin
      if (value !== expected_value_i[3:0]) begin
        fail_check("value", expected_value_i, value);
      end
    end
  endtask

  task expect_next_only;
    input integer expected_next_i;
    begin
      if (value_next !== expected_next_i[3:0]) begin
        fail_check("value_next", expected_next_i, value_next);
      end
    end
  endtask

  task expect_outputs;
    input integer expected_value_i;
    input integer expected_next_i;
    begin
      expect_value_only(expected_value_i);
      expect_next_only(expected_next_i);
    end
  endtask

  task load_state;
    input integer next_state;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 1, 1, next_state, 3, 3);
      expect_outputs(expected_value, next_state);

      @(posedge clk);
      expected_value = next_state;
      #1;
      expect_outputs(expected_value, next_state);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 0, 0, next_state, 0, 0);
      expect_outputs(expected_value, expected_value);
    end
  endtask

  task initialize_known_state;
    input integer next_state;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(1, 0, 0, 0, next_state, 0, 0);

      @(posedge clk);
      expected_value = next_state;
      #1;
      expect_outputs(expected_value, expected_value);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 0, 0, next_state, 0, 0);
      expect_outputs(expected_value, expected_value);
    end
  endtask

  task poke_and_check_next;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    integer expected_next;
    begin
      case_id = case_id + 1;
      drive_inputs(rst_i, reinit_i, incr_valid_i, decr_valid_i, initial_value_i, incr_i, decr_i);
      expected_next = model_next(
        expected_value,
        rst_i,
        reinit_i,
        incr_valid_i,
        decr_valid_i,
        initial_value_i,
        incr_i,
        decr_i
      );
      expect_outputs(expected_value, expected_next);
    end
  endtask

  task step_and_check;
    input integer rst_i;
    input integer reinit_i;
    input integer incr_valid_i;
    input integer decr_valid_i;
    input integer initial_value_i;
    input integer incr_i;
    input integer decr_i;
    integer expected_next;
    begin
      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(rst_i, reinit_i, incr_valid_i, decr_valid_i, initial_value_i, incr_i, decr_i);
      expected_next = model_next(
        expected_value,
        rst_i,
        reinit_i,
        incr_valid_i,
        decr_valid_i,
        initial_value_i,
        incr_i,
        decr_i
      );
      expect_outputs(expected_value, expected_next);

      @(posedge clk);
      expected_value = expected_next;
      #1;
      expect_outputs(expected_value, expected_next);
    end
  endtask

  task check_same_cycle_value_next;
    begin
      load_state(4);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 0, 0, 0, 0, 0);
      expect_outputs(4, 4);

      poke_and_check_next(0, 0, 1, 0, 0, 1, 0);
      poke_and_check_next(0, 0, 1, 0, 0, 2, 0);
      poke_and_check_next(0, 0, 1, 0, 0, 3, 0);
      poke_and_check_next(0, 0, 0, 1, 0, 0, 1);
      poke_and_check_next(0, 0, 0, 1, 0, 0, 2);
      poke_and_check_next(0, 0, 0, 1, 0, 0, 3);
      poke_and_check_next(0, 0, 1, 1, 0, 3, 2);
      poke_and_check_next(0, 0, 1, 1, 0, 0, 3);
      poke_and_check_next(0, 1, 1, 1, 8, 3, 3);
      poke_and_check_next(0, 1, 0, 0, 2, 0, 0);
      poke_and_check_next(1, 0, 1, 1, 9, 3, 3);
      poke_and_check_next(1, 0, 0, 0, 1, 0, 0);
      poke_and_check_next(0, 0, 0, 0, 0, 0, 0);
    end
  endtask

  task check_priority_and_register_update;
    begin
      load_state(5);
      step_and_check(1, 0, 1, 1, 3, 3, 2);
      step_and_check(0, 0, 1, 1, 0, 3, 1);

      step_and_check(0, 1, 1, 1, 6, 3, 3);
      step_and_check(0, 0, 0, 1, 0, 0, 3);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 1, 1, 1, 1, 3, 3);
      expect_outputs(expected_value, 1);
      poke_and_check_next(0, 1, 1, 1, 10, 3, 3);
      poke_and_check_next(0, 1, 0, 0, 7, 0, 0);

      @(posedge clk);
      expected_value = 7;
      #1;
      expect_outputs(expected_value, 7);
    end
  endtask

  task check_wrap_corners;
    begin
      load_state(9);
      step_and_check(0, 0, 1, 0, 0, 3, 0);

      load_state(1);
      step_and_check(0, 0, 0, 1, 0, 0, 3);

      load_state(10);
      step_and_check(0, 0, 1, 1, 0, 3, 1);

      load_state(0);
      step_and_check(0, 0, 1, 1, 0, 0, 3);
    end
  endtask

  task check_control_precedence_matrix;
    integer init_sel;
    begin
      load_state(6);
      for (init_sel = 0; init_sel <= MAX_VALUE; init_sel = init_sel + 1) begin
        poke_and_check_next(1, 0, 0, 0, init_sel, 0, 0);
        poke_and_check_next(1, 0, 1, 0, init_sel, 3, 0);
        poke_and_check_next(1, 0, 0, 1, init_sel, 0, 3);
        poke_and_check_next(1, 0, 1, 1, init_sel, 3, 3);
        poke_and_check_next(0, 1, 0, 0, init_sel, 0, 0);
        poke_and_check_next(0, 1, 1, 0, init_sel, 3, 0);
        poke_and_check_next(0, 1, 0, 1, init_sel, 0, 3);
        poke_and_check_next(0, 1, 1, 1, init_sel, 3, 3);
      end
    end
  endtask

  task check_comb_next_full_state_space;
    integer start_value;
    integer rst_sel;
    integer reinit_sel;
    integer incr_valid_sel;
    integer decr_valid_sel;
    integer initial_sel;
    integer incr_sel;
    integer decr_sel;
    begin
      for (start_value = 0; start_value <= MAX_VALUE; start_value = start_value + 1) begin
        load_state(start_value);
        case_id = case_id + 1;
        @(negedge clk);
        drive_inputs(0, 0, 0, 0, start_value, 0, 0);
        expect_outputs(start_value, start_value);

        for (rst_sel = 0; rst_sel <= 1; rst_sel = rst_sel + 1) begin
          for (reinit_sel = 0; reinit_sel <= 1; reinit_sel = reinit_sel + 1) begin
            for (incr_valid_sel = 0; incr_valid_sel <= 1; incr_valid_sel = incr_valid_sel + 1) begin
              for (decr_valid_sel = 0; decr_valid_sel <= 1; decr_valid_sel = decr_valid_sel + 1) begin
                for (initial_sel = 0; initial_sel <= MAX_VALUE; initial_sel = initial_sel + 1) begin
                  for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
                    for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
                      poke_and_check_next(
                        rst_sel,
                        reinit_sel,
                        incr_valid_sel,
                        decr_valid_sel,
                        initial_sel,
                        incr_sel,
                        decr_sel
                      );
                    end
                  end
                end
              end
            end
          end
        end

        expect_value_only(start_value);
      end
    end
  endtask

  task check_midcycle_transitions;
    begin
      load_state(8);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 0, 1, 0, 2, 3, 0);
      expect_outputs(8, 0);

      poke_and_check_next(0, 0, 0, 1, 2, 3, 2);
      poke_and_check_next(0, 0, 1, 1, 2, 1, 3);
      poke_and_check_next(0, 1, 1, 1, 10, 3, 3);
      poke_and_check_next(1, 0, 1, 1, 4, 3, 3);
      poke_and_check_next(0, 0, 0, 0, 4, 0, 0);
      expect_value_only(8);

      @(posedge clk);
      expected_value = 8;
      #1;
      expect_outputs(8, 8);

      case_id = case_id + 1;
      @(negedge clk);
      drive_inputs(0, 1, 1, 0, 9, 2, 0);
      expect_outputs(8, 9);
      poke_and_check_next(0, 1, 1, 0, 3, 2, 0);
      poke_and_check_next(0, 0, 1, 0, 3, 2, 0);
      poke_and_check_next(0, 0, 0, 1, 3, 0, 3);
      expect_value_only(8);

      @(posedge clk);
      expected_value = 5;
      #1;
      expect_outputs(5, 2);
    end
  endtask

  task check_full_state_space;
    integer start_value;
    integer incr_valid_sel;
    integer decr_valid_sel;
    integer incr_sel;
    integer decr_sel;
    begin
      for (start_value = 0; start_value <= MAX_VALUE; start_value = start_value + 1) begin
        load_state(start_value);
        for (incr_valid_sel = 0; incr_valid_sel <= 1; incr_valid_sel = incr_valid_sel + 1) begin
          for (decr_valid_sel = 0; decr_valid_sel <= 1; decr_valid_sel = decr_valid_sel + 1) begin
            for (incr_sel = 0; incr_sel <= 3; incr_sel = incr_sel + 1) begin
              for (decr_sel = 0; decr_sel <= 3; decr_sel = decr_sel + 1) begin
                step_and_check(0, 0, incr_valid_sel, decr_valid_sel, 0, incr_sel, decr_sel);
                load_state(start_value);
              end
            end
          end
        end
      end
    end
  endtask

  initial begin
    rst = 1'b0;
    reinit = 1'b0;
    incr_valid = 1'b0;
    decr_valid = 1'b0;
    initial_value = 4'd0;
    incr = 2'd0;
    decr = 2'd0;
    expected_value = 0;
    case_id = 0;

    initialize_known_state(0);
    check_same_cycle_value_next();
    check_wrap_corners();
    check_priority_and_register_update();
    check_control_precedence_matrix();
    check_midcycle_transitions();
    check_comb_next_full_state_space();
    check_full_state_space();

    $display("TB_PASS");
    $finish;
  end

endmodule
