`timescale 1ns/1ps

module tb_my_spec;
  localparam int DEPTH = 13;

  logic clk;
  logic rst;
  logic push_valid;
  logic pop_ready;
  logic [7:0] push_data;

  wire push_ready_o;
  wire pop_valid;
  wire full;
  wire full_next;
  wire empty;
  wire empty_next;
  wire [7:0] pop_data;
  wire [3:0] slots;
  wire [3:0] slots_next;
  wire [3:0] items;
  wire [3:0] items_next;

  logic [7:0] model_mem [0:DEPTH-1];
  int model_head;
  int model_tail;
  int model_count;

  fifo_flops dut (
    .clk(clk),
    .rst(rst),
    .push_ready(push_ready_o),
    .push_valid(push_valid),
    .pop_ready(pop_ready),
    .pop_valid(pop_valid),
    .full(full),
    .full_next(full_next),
    .empty(empty),
    .empty_next(empty_next),
    .push_data(push_data),
    .pop_data(pop_data),
    .slots(slots),
    .slots_next(slots_next),
    .items(items),
    .items_next(items_next)
  );

  always #5 clk = ~clk;

  task automatic fail(input string msg);
    begin
      $display("TB_FAIL %s at time %0t", msg, $time);
      $fatal(1);
    end
  endtask

  task automatic check_bit(input string name, input logic actual, input logic expected);
    begin
      if (actual !== expected) begin
        fail($sformatf("%s expected %0b got %0b", name, expected, actual));
      end
    end
  endtask

  task automatic check_u4(input string name, input logic [3:0] actual, input int expected);
    begin
      if (actual !== expected[3:0]) begin
        fail($sformatf("%s expected %0d got %0d", name, expected, actual));
      end
    end
  endtask

  task automatic check_u8(input string name, input logic [7:0] actual, input logic [7:0] expected);
    begin
      if (actual !== expected) begin
        fail($sformatf("%s expected 0x%02h got 0x%02h", name, expected, actual));
      end
    end
  endtask

  function automatic logic [7:0] model_front();
    begin
      model_front = model_mem[model_head];
    end
  endfunction

  function automatic int expected_count_after_cycle(
    input int cur_count,
    input logic cur_push_valid,
    input logic cur_pop_ready
  );
    bit exp_push_ready;
    bit exp_pop_valid;
    bit push_fire;
    bit pop_fire;
    begin
      exp_push_ready = (cur_count < DEPTH);
      exp_pop_valid = (cur_count != 0) || cur_push_valid;
      push_fire = cur_push_valid && exp_push_ready;
      pop_fire = cur_pop_ready && exp_pop_valid;
      expected_count_after_cycle = cur_count + (push_fire ? 1 : 0) - (pop_fire ? 1 : 0);
    end
  endfunction

  task automatic check_outputs(input string name);
    int exp_count_next;
    logic exp_push_ready;
    logic exp_pop_valid;
    logic exp_empty;
    logic exp_full;
    logic exp_empty_next;
    logic exp_full_next;
    begin
      exp_empty = (model_count == 0);
      exp_full = (model_count == DEPTH);
      exp_push_ready = !exp_full;
      exp_pop_valid = (model_count != 0) || push_valid;
      exp_count_next = expected_count_after_cycle(model_count, push_valid, pop_ready);
      exp_empty_next = (exp_count_next == 0);
      exp_full_next = (exp_count_next == DEPTH);

      check_bit({name, "_push_ready"}, push_ready_o, exp_push_ready);
      check_bit({name, "_full"}, full, exp_full);
      check_bit({name, "_empty"}, empty, exp_empty);
      check_bit({name, "_pop_valid"}, pop_valid, exp_pop_valid);
      check_u4({name, "_items"}, items, model_count);
      check_u4({name, "_slots"}, slots, DEPTH - model_count);
      check_bit({name, "_full_next"}, full_next, exp_full_next);
      check_bit({name, "_empty_next"}, empty_next, exp_empty_next);
      check_u4({name, "_items_next"}, items_next, exp_count_next);
      check_u4({name, "_slots_next"}, slots_next, DEPTH - exp_count_next);

      if (exp_pop_valid) begin
        if (model_count == 0) begin
          check_u8({name, "_pop_data_bypass"}, pop_data, push_data);
        end else begin
          check_u8({name, "_pop_data_buffered"}, pop_data, model_front());
        end
      end
    end
  endtask

  task automatic model_reset();
    int idx;
    begin
      model_head = 0;
      model_tail = 0;
      model_count = 0;
      for (idx = 0; idx < DEPTH; idx = idx + 1) begin
        model_mem[idx] = '0;
      end
    end
  endtask

  task automatic apply_model_cycle(
    input logic cur_push_valid,
    input logic [7:0] cur_push_data,
    input logic cur_pop_ready
  );
    bit push_fire;
    bit pop_fire;
    int old_count;
    begin
      old_count = model_count;
      push_fire = cur_push_valid && (old_count < DEPTH);
      pop_fire = cur_pop_ready && ((old_count != 0) || cur_push_valid);

      if (push_fire && !(old_count == 0 && pop_fire)) begin
        model_mem[model_tail] = cur_push_data;
        model_tail = (model_tail + 1) % DEPTH;
      end

      if (pop_fire && old_count != 0) begin
        model_head = (model_head + 1) % DEPTH;
      end

      model_count = old_count + (push_fire ? 1 : 0) - (pop_fire ? 1 : 0);
    end
  endtask

  task automatic drive_idle_and_check(input string name);
    begin
      push_valid = 1'b0;
      pop_ready = 1'b0;
      push_data = 8'h00;
      #1;
      check_outputs(name);
    end
  endtask

  task automatic cycle_with_inputs(
    input string name,
    input logic cur_push_valid,
    input logic [7:0] cur_push_data,
    input logic cur_pop_ready
  );
    begin
      push_valid = cur_push_valid;
      push_data = cur_push_data;
      pop_ready = cur_pop_ready;
      #1;
      check_outputs({name, "_pre"});
      @(posedge clk);
      apply_model_cycle(cur_push_valid, cur_push_data, cur_pop_ready);
      #1;
      drive_idle_and_check({name, "_post"});
    end
  endtask

  task automatic hold_without_clock(
    input string name,
    input logic cur_push_valid,
    input logic [7:0] cur_push_data,
    input logic cur_pop_ready
  );
    begin
      push_valid = cur_push_valid;
      push_data = cur_push_data;
      pop_ready = cur_pop_ready;
      #1;
      check_outputs({name, "_a"});
      #2;
      check_outputs({name, "_b"});
    end
  endtask

  task automatic do_reset(input string name);
    begin
      rst = 1'b1;
      push_valid = 1'b0;
      pop_ready = 1'b0;
      push_data = 8'h00;
      model_reset();
      @(posedge clk);
      #1;
      check_outputs({name, "_after_edge"});
      rst = 1'b0;
      #1;
      check_outputs({name, "_released"});
    end
  endtask

  initial begin
    clk = 1'b0;
    rst = 1'b0;
    push_valid = 1'b0;
    pop_ready = 1'b0;
    push_data = 8'h00;
    model_reset();

    do_reset("reset");
    drive_idle_and_check("idle_empty");

    hold_without_clock("empty_bypass_visible", 1'b1, 8'hA1, 1'b1);
    cycle_with_inputs("empty_bypass_transfer", 1'b1, 8'hA1, 1'b1);

    cycle_with_inputs("store_first_word", 1'b1, 8'h11, 1'b0);
    hold_without_clock("stored_word_held", 1'b0, 8'h00, 1'b0);
    cycle_with_inputs("store_second_word", 1'b1, 8'h22, 1'b0);
    cycle_with_inputs("store_third_word", 1'b1, 8'h33, 1'b0);
    cycle_with_inputs("pop_first_word", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("pop_second_word", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("pop_third_word", 1'b0, 8'h00, 1'b1);

    cycle_with_inputs("refill_a0", 1'b1, 8'hA0, 1'b0);
    cycle_with_inputs("refill_a1", 1'b1, 8'hA1, 1'b0);
    cycle_with_inputs("simul_push_pop_nonempty", 1'b1, 8'hB0, 1'b1);
    cycle_with_inputs("drain_after_simul_0", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_after_simul_1", 1'b0, 8'h00, 1'b1);

    cycle_with_inputs("fill_00", 1'b1, 8'h40, 1'b0);
    cycle_with_inputs("fill_01", 1'b1, 8'h41, 1'b0);
    cycle_with_inputs("fill_02", 1'b1, 8'h42, 1'b0);
    cycle_with_inputs("fill_03", 1'b1, 8'h43, 1'b0);
    cycle_with_inputs("fill_04", 1'b1, 8'h44, 1'b0);
    cycle_with_inputs("fill_05", 1'b1, 8'h45, 1'b0);
    cycle_with_inputs("fill_06", 1'b1, 8'h46, 1'b0);
    cycle_with_inputs("fill_07", 1'b1, 8'h47, 1'b0);
    cycle_with_inputs("fill_08", 1'b1, 8'h48, 1'b0);
    cycle_with_inputs("fill_09", 1'b1, 8'h49, 1'b0);
    cycle_with_inputs("fill_10", 1'b1, 8'h4A, 1'b0);
    cycle_with_inputs("fill_11", 1'b1, 8'h4B, 1'b0);
    cycle_with_inputs("fill_12", 1'b1, 8'h4C, 1'b0);
    hold_without_clock("full_holds_back_push", 1'b1, 8'hEE, 1'b0);
    cycle_with_inputs("full_blocks_push", 1'b1, 8'hEE, 1'b0);
    cycle_with_inputs("full_allows_pop", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("push_after_space_freed", 1'b1, 8'h55, 1'b0);

    cycle_with_inputs("drain_00", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_01", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_02", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_03", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_04", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_05", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_06", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_07", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_08", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_09", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_10", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_11", 1'b0, 8'h00, 1'b1);
    cycle_with_inputs("drain_12", 1'b0, 8'h00, 1'b1);

    do_reset("midrun_reset");
    cycle_with_inputs("post_reset_bypass", 1'b1, 8'hC3, 1'b1);
    drive_idle_and_check("final_idle");

    $display("TB_PASS");
    $finish;
  end
endmodule
