# Feedback for Codex

- Testbench: `C:/Users/Divya/AutomationProj/codex_verilog_tb_full/generated/tb_counter.sv`
- Spec: `C:/Users/Divya/AutomationProj/codex_verilog_tb_full/specs/my_spec.md`

## Results

### mutant_0.v
- Status: **sim_fail**
- Return code: `1`

STDOUT:
```
TB_FAIL case=2 check=value_next expected=5 actual=0 time=30
FATAL: C:\Users\Divya\AutomationProj\codex_verilog_tb_full\generated\tb_counter.sv:85: 
       Time: 30  Scope: tb_counter.fail_check
```

### mutant_1.v
- Status: **sim_fail**
- Return code: `1`

STDOUT:
```
TB_FAIL case=2 check=value_next expected=5 actual=0 time=30
FATAL: C:\Users\Divya\AutomationProj\codex_verilog_tb_full\generated\tb_counter.sv:85: 
       Time: 30  Scope: tb_counter.fail_check
```

### mutant_3.v
- Status: **sim_fail**
- Return code: `1`

STDOUT:
```
TB_FAIL case=1 check=value_next expected=0 actual=8 time=16
FATAL: C:\Users\Divya\AutomationProj\codex_verilog_tb_full\generated\tb_counter.sv:85: 
       Time: 16  Scope: tb_counter.fail_check
```
