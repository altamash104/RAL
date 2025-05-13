///////////////////////////////////////////////////////////////////////////////////
`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)
  
  rand bit [7:0] csr_addr;
  rand bit [31:0] csr_wr_data;
       bit [31:0] csr_rd_data;
  rand bit csr_wr_en;
  rand bit csr_rd_en;
  
  function new(string name = "transaction");
    super.new(name);
  endfunction
  
  constraint csr_addr_c {
    csr_addr inside {0, 4, 8, 12, 16};
  }
  
endclass

/////////////////////////////////////////////////////////////////

class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)

  virtual top_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual top_if)::get(this, "", "vif", vif))
      `uvm_error("DRV", "Virtual interface not set for driver")
  endfunction

  virtual task run_phase(uvm_phase phase);
    transaction tr;
    drive_reset_transaction(tr);
    forever begin
      seq_item_port.get_next_item(tr);

      // Apply transaction to DUT
      drive_transaction(tr);

      seq_item_port.item_done();
    end
  endtask
  
  task drive_reset_transaction(transaction tr);
    vif.csr_wr_en   <= 0;
    vif.csr_rd_en   <= 0;
    vif.csr_addr    <= 0;
    vif.csr_wr_data <= 0;
    vif.rst_n <= 1;
    @(posedge vif.clk);
    vif.rst_n <= 0;
    @(posedge vif.clk);
    vif.rst_n <= 1;
  endtask
    
  task drive_transaction(transaction tr);
  // Default values before driving
  vif.csr_wr_en   <= 0;
  vif.csr_rd_en   <= 0;
  vif.csr_addr    <= 0;
  vif.csr_wr_data <= 0;
  vif.rst_n <= 1;
  @(posedge vif.clk);

  vif.csr_addr    <= tr.csr_addr;
  vif.csr_wr_data <= tr.csr_wr_data;

  if (tr.csr_wr_en) begin
    `uvm_info("DRV", $sformatf("Mode : WRITE | WDATA : %0h | ADDR : %0h", tr.csr_wr_data, tr.csr_addr), UVM_MEDIUM)
    vif.csr_wr_en <= 1;
    @(posedge vif.clk);
    vif.csr_wr_en <= 0;
  end
  else if (tr.csr_rd_en) begin
    `uvm_info("DRV", $sformatf("Mode : READ  | ADDR : %0h", tr.csr_addr), UVM_MEDIUM)
    vif.csr_rd_en <= 1;
    @(posedge vif.clk);
    vif.csr_rd_en <= 0;
  end
endtask

endclass
    
////////////////////////////////////////////////////////////////////////
    
class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)

  virtual top_if vif;
  uvm_analysis_port#(transaction) mon_ap;
  transaction tr;
  
  bit [31:0] observed_addr;
  
  covergroup addr_cov;
    option.per_instance = 1;
    coverpoint observed_addr{
      bins addr_0 = {0};
      bins addr_4 = {4};
      bins addr_8 = {8};
      bins addr_12 = {12};
      bins addr_16 = {16};
                     }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    addr_cov = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_ap = new("mon_ap", this);
    if (!uvm_config_db#(virtual top_if)::get(this, "", "vif", vif))
      `uvm_error("MON", "Virtual interface not set for monitor")
  endfunction

  virtual task run_phase(uvm_phase phase);
    transaction tr;

    forever begin
      @(posedge vif.clk);

      if (vif.csr_wr_en) begin
        tr = transaction::type_id::create("tr", this);
        tr.csr_addr    = vif.csr_addr;
        tr.csr_wr_data = vif.csr_wr_data;
        tr.csr_wr_en   = 1;
        tr.csr_rd_en   = 0;
        observed_addr = tr.csr_addr;
        addr_cov.sample();
        `uvm_info("MON", $sformatf("Observed WRITE | ADDR : %0h | WDATA : %0h", tr.csr_addr, tr.csr_wr_data), UVM_MEDIUM)

        mon_ap.write(tr);
      end
      else if (vif.csr_rd_en) begin
        tr = transaction::type_id::create("tr", this);
        tr.csr_addr    = vif.csr_addr;
        tr.csr_rd_data = vif.csr_rd_data;
        tr.csr_wr_en   = 0;
        tr.csr_rd_en   = 1;
        observed_addr = tr.csr_addr;
        addr_cov.sample();
        `uvm_info("MON", $sformatf("Observed READ  | ADDR : %0h | RDATA : %0h", tr.csr_addr, tr.csr_rd_data), UVM_MEDIUM)

        mon_ap.write(tr);
      end
    end
  endtask
endclass
    
//////////////////////////////////////////////////////////////////////////
    
 class agent extends uvm_agent;    
`uvm_component_utils(agent)
  
 
function new(input string inst = "agent", uvm_component parent = null);
super.new(inst,parent);
endfunction
 
 driver drv;
 uvm_sequencer#(transaction) seqr;
 monitor mon;
 
 
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
   drv = driver::type_id::create("d",this);
   mon = monitor::type_id::create("m",this);
   seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this); 
endfunction
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
   drv.seq_item_port.connect(seqr.seq_item_export);
endfunction
 
endclass
 
////////////////////////////////////////////////////////////////////////////
    
class sco extends uvm_scoreboard;
  `uvm_component_utils(sco)
  
  uvm_analysis_imp #(transaction,sco) recv;
  bit [31:0] golden_mem[byte];
  
  function new(string name = "sco", uvm_component parent = null);
    super.new(name,parent);
    recv = new("recv",this);
  endfunction
  
  function void write(transaction tr);
  if (tr.csr_wr_en && !tr.csr_rd_en) begin
    // Only write
    golden_mem[tr.csr_addr] = tr.csr_wr_data;
    `uvm_info("SCOREBOARD", $sformatf("Wrote 0x%0h to addr 0x%0h", tr.csr_wr_data, tr.csr_addr), UVM_MEDIUM)
  end
  else if (tr.csr_rd_en && !tr.csr_wr_en) begin
    // Only read
    bit [31:0] expected = golden_mem.exists(tr.csr_addr) ? golden_mem[tr.csr_addr] : '0;
    if (tr.csr_rd_data !== expected) begin
      if(tr.csr_addr == 8'h10)
        `uvm_info("SCOREBOARD", $sformatf("Hardcoded Memory ID Read at addr 0x%0h: 0x%0h",
                                        tr.csr_addr, tr.csr_rd_data), UVM_MEDIUM) 
        else
      `uvm_error("SCOREBOARD", $sformatf("Read mismatch at addr 0x%0h: Expected 0x%0h, Got 0x%0h",
                                         tr.csr_addr, expected, tr.csr_rd_data))
    end else begin
      `uvm_info("SCOREBOARD", $sformatf("Read match at addr 0x%0h: 0x%0h",
                                        tr.csr_addr, tr.csr_rd_data), UVM_MEDIUM)
    end
  end
  else begin
    `uvm_warning("SCOREBOARD", "Transaction has both or neither of rd/wr enables set.")
  end

  $display("----------------------------------------------------------------");
endfunction
endclass
      
////////////////////////////////////////////////////////////////////////////////
      
class cntrl_reg extends uvm_reg;
  `uvm_object_utils(cntrl_reg)
  
  rand uvm_reg_field start;
  rand uvm_reg_field mode;  
  
  // Local variables to hold sampled values
  bit start_val;
  bit [3:0] mode_val;
  
  covergroup cntrl_cov;
    option.per_instance = 1;
    coverpoint start_val{
      bins zero = {0};
      bins one = {1};
    }
    coverpoint mode_val{
      bins lower = {[0:7]};
      bins higher = {[8:15]};
    }
  endgroup
  
  function new(string name = "cntrl_reg");
    super.new(name,32,build_coverage(UVM_CVR_FIELD_VALS));
    if(has_coverage(UVM_CVR_FIELD_VALS))
      cntrl_cov = new();
  endfunction
  
  virtual function void sample(uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
    cntrl_cov.sample();
  endfunction
   
  virtual function void sample_values();
    start_val = start.get_mirrored_value();
    mode_val = mode.get_mirrored_value();
    super.sample_values();
    cntrl_cov.sample();
  endfunction    
   
  
  virtual function void build();
    start = uvm_reg_field::type_id::create("start");
    start.configure(this,1,0,"RW",0,1'h0,1,1,1);
    
    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this,4,1,"RW",0,4'h0,1,1,1);    
  endfunction
  
endclass
      
//////////////////////////////////////////////////////////////////////////
      
class cfg_reg extends uvm_reg;
  `uvm_object_utils(cfg_reg)
  
  rand uvm_reg_field burst_length;
  rand uvm_reg_field latency;
  
  // Local variables to hold sampled values
  bit [7:0] burst_length_val;
  bit [3:0] latency_val;
  
  covergroup cfg_cov;
    option.per_instance = 1;
    coverpoint burst_length_val{
      bins lower = {[0:63]};
      bins mid = {[64:127]};
      bins higher = {[128:255]};
    }
    coverpoint latency_val{
      bins lower = {[0:7]};
      bins high = {[8:15]};
    }
  endgroup
  
  function new(string name = "cfg_reg");
    super.new(name,32,build_coverage(UVM_CVR_FIELD_VALS));
    if(has_coverage(UVM_CVR_FIELD_VALS))
      cfg_cov = new();
  endfunction  
    
  virtual function void sample(uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
    cfg_cov.sample();
  endfunction
   
  virtual function void sample_values();
    burst_length_val = burst_length.get_mirrored_value();
    latency_val = latency.get_mirrored_value();
    super.sample_values();
    cfg_cov.sample();
  endfunction  
  
  virtual function void build();
    burst_length = uvm_reg_field::type_id::create("burst_length");
    burst_length.configure(this,8,0,"RW",0,1'h0,1,1,1);
    
    latency = uvm_reg_field::type_id::create("latecy");
    latency.configure(this,4,8,"RW",0,4'h0,1,1,1);    
  endfunction
  
endclass
      
/////////////////////////////////////////////////////////////////////////
class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)
  
  rand uvm_reg_field busy;
  bit busy_val;  
  
  covergroup status_cov;
    option.per_instance = 1;
    coverpoint busy_val {    
      bins zero = {0};
      bins one  = {1};
    }
  endgroup
  
  function new(string name = "status_reg");
    super.new(name,32,build_coverage(UVM_CVR_FIELD_VALS));
    if(has_coverage(UVM_CVR_FIELD_VALS))
      status_cov = new();
  endfunction  
    
  virtual function void sample(uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
    status_cov.sample();
  endfunction
   
  virtual function void sample_values();
    busy_val = busy.get_mirrored_value();  
    super.sample_values();
    status_cov.sample();
  endfunction  
  
  virtual function void build();
    busy = uvm_reg_field::type_id::create("busy");
    busy.configure(this,1,0,"RO",0,1'h0,1,1,1);   
  endfunction

endclass


////////////////////////////////////////////////////////////////////////////
      
class error_reg extends uvm_reg;
  `uvm_object_utils(error_reg)
  
  rand uvm_reg_field error;
  bit error_val;
  
  covergroup error_cov;
    option.per_instance = 1;
    coverpoint error_val{
      bins zero = {0};
      bins one = {1};
    }
  endgroup
  
  function new(string name = "error_reg");
    super.new(name,32,build_coverage(UVM_CVR_FIELD_VALS));
    if(has_coverage(UVM_CVR_FIELD_VALS))
      error_cov = new();
  endfunction  
    
  virtual function void sample(uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
    error_cov.sample();
  endfunction
   
  virtual function void sample_values();
    error_val = error.get_mirrored_value();
    super.sample_values();
    error_cov.sample();
  endfunction  
  
  virtual function void build();
    error = uvm_reg_field::type_id::create("error");
    error.configure(this,1,0,"RO",0,1'h0,1,1,1);    
  endfunction
  
endclass
      
/////////////////////////////////////////////////////////////////////////////
    
class id_reg extends uvm_reg;
  `uvm_object_utils(id_reg)
  
  rand uvm_reg_field id;
    
  function new(string name = "id_reg");
    super.new(name,32,build_coverage(UVM_NO_COVERAGE));
  endfunction  
  
  virtual function void build();
    id = uvm_reg_field::type_id::create("id");
    id.configure(this,32,0,"RO",0,1'h0,1,1,1);    
  endfunction
  
endclass
    
///////////////////////////////////////////////////////////////////////////////////////
      
class top_reg_block extends uvm_reg_block;
  `uvm_object_utils(top_reg_block)
  
  rand cntrl_reg cntrl_reg_inst;
  rand cfg_reg cfg_reg_inst;
  rand status_reg status_reg_inst;
  rand error_reg error_reg_inst;
  rand id_reg id_reg_inst;
  
  function new(string name = "top_reg_block");
    super.new(name,build_coverage(UVM_NO_COVERAGE));
  endfunction
  
  virtual function void build();
    uvm_reg::include_coverage("*",UVM_CVR_ALL);
    cntrl_reg_inst = cntrl_reg::type_id::create("cntrl_reg_inst");
    cntrl_reg_inst.build();
    cntrl_reg_inst.set_coverage(UVM_CVR_FIELD_VALS);
    cntrl_reg_inst.configure(this,null);
    
    cfg_reg_inst = cfg_reg::type_id::create("cfg_reg_inst");
    cfg_reg_inst.build();
    cfg_reg_inst.set_coverage(UVM_CVR_FIELD_VALS);
    cfg_reg_inst.configure(this,null);    
    
    status_reg_inst = status_reg::type_id::create("status_reg_inst");
    status_reg_inst.build();
    status_reg_inst.set_coverage(UVM_CVR_FIELD_VALS);
    status_reg_inst.configure(this,null);    
    
    error_reg_inst = error_reg::type_id::create("error_reg_inst");
    error_reg_inst.build();
    error_reg_inst.set_coverage(UVM_CVR_FIELD_VALS);
    error_reg_inst.configure(this,null);
    
    id_reg_inst = id_reg::type_id::create("id_reg_inst");
    id_reg_inst.build();
    id_reg_inst.configure(this,null);
    
    default_map = create_map("default_map",0,4,UVM_LITTLE_ENDIAN,0);
    default_map.add_reg(cntrl_reg_inst,'h0,"RW");
    default_map.add_reg(status_reg_inst,'h4,"RO");
    default_map.add_reg(cfg_reg_inst,'h8,"RW");
    default_map.add_reg(error_reg_inst,'hc,"RO");
    default_map.add_reg(id_reg_inst,'h10,"RO");
    lock_model();
  endfunction
  
endclass
      
///////////////////////////////////////////////////////////////////////////
      
class top_adapter extends uvm_reg_adapter;
  `uvm_object_utils (top_adapter)
 
 
  function new (string name = "top_adapter");
      super.new (name);
   endfunction
  
 
  function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    transaction tr;    
    tr = transaction::type_id::create("tr");
    
    tr.csr_wr_en    = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;
    tr.csr_rd_en    = (rw.kind == UVM_READ) ? 1'b1 : 1'b0;
    tr.csr_addr     = rw.addr;
    tr.csr_wr_data    = rw.data;
 
 
    return tr;
  endfunction
 
 
   
  function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    transaction tr;
    
    assert($cast(tr, bus_item));
 
    rw.kind = (tr.csr_wr_en == 1'b1) ? UVM_WRITE : UVM_READ;
    rw.data = (tr.csr_wr_en == 1'b1) ? tr.csr_wr_data : tr.csr_rd_data;
    rw.addr = tr.csr_addr;
    rw.status = UVM_IS_OK;
  endfunction
endclass
      
/////////////////////////////////////////////////////////////////////////////
      
class env extends uvm_env;
  `uvm_component_utils(env)
  
  top_adapter adapter_inst;
  agent agent_inst;
  top_reg_block regmodel;
  sco sco_inst;
  uvm_reg_predictor#(transaction) predictor_inst;
  
  function new(string name = "env",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    adapter_inst = top_adapter::type_id::create("adapter_inst",,get_full_name());
    predictor_inst = uvm_reg_predictor#(transaction)::type_id::create("predictor_inst",this);
    agent_inst = agent::type_id::create("agent_inst",this);
    sco_inst = sco::type_id::create("sco_inst",this);
    regmodel = top_reg_block::type_id::create("regmodel",this);
    regmodel.build();
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent_inst.mon.mon_ap.connect(sco_inst.recv);
    agent_inst.mon.mon_ap.connect(predictor_inst.bus_in);
    regmodel.default_map.set_base_addr(0);
    regmodel.default_map.set_sequencer(.sequencer(agent_inst.seqr), .adapter(adapter_inst));   
    predictor_inst.map       = regmodel.default_map;
    predictor_inst.adapter   = adapter_inst;
  endfunction 
 
endclass    
      
/////////////////////////////////////////////////////////////////////////////////

class cntrl_wr_rd extends uvm_sequence;
  `uvm_object_utils(cntrl_wr_rd)
  
   top_reg_block regmodel;
 
   
  function new (string name = "ctrl_wr_rd"); 
    super.new(name);    
  endfunction
  
 
  task body;  
    uvm_status_e   status;
    bit [31:0] wdata;
    bit [31:0] rdata;
         
         repeat(5) begin
    //////working with control 
      wdata = $urandom_range(0,31);
      regmodel.cntrl_reg_inst.write(status, wdata);
      regmodel.cntrl_reg_inst.read(status, rdata); 
      regmodel.cntrl_reg_inst.sample_values(); 
      regmodel.status_reg_inst.sample_values(); 
         end

  endtask
  
  
endclass
        

/////////////////////////////////////////////////////////////////////////////////

class cfg_wr_rd extends uvm_sequence;
  `uvm_object_utils(cfg_wr_rd)
  
   top_reg_block regmodel;
 
   
  function new (string name = "cfg_wr_rd"); 
    super.new(name);    
  endfunction
  
 
  task body;  
    uvm_status_e   status;
    bit [31:0] wdata, rdata; 
    
    repeat (5) begin
    //////working with cfg
      wdata = $urandom_range(0,4095);
      regmodel.cfg_reg_inst.write(status, wdata);
      regmodel.cfg_reg_inst.read(status, rdata);
      regmodel.cfg_reg_inst.sample_values(); 
    end
    
  endtask
  
  
endclass     
  
/////////////////////////////////////////////////////////////////////////        
       
 class status_rd extends uvm_sequence;
 
   `uvm_object_utils(status_rd)
  
   top_reg_block regmodel;
  
   
   function new (string name = "status_rd"); 
    super.new(name);    
  endfunction
  
 
  task body;  
    uvm_status_e   status;
    bit [31:0] rdata;
    
    //////working with status   
     regmodel.status_reg_inst.read(status, rdata); 
     regmodel.status_reg_inst.sample_values(); 
    
  endtask
 
endclass            

/////////////////////////////////////////////////////////////////////////        
       
 class error_rd extends uvm_sequence;
 
   `uvm_object_utils(error_rd)
  
   top_reg_block regmodel;
  
   
   function new (string name = "error_rd"); 
    super.new(name);    
  endfunction
  
 
  task body;  
    uvm_status_e   status;
    bit [31:0] rdata;
    
    //////working with error 
     regmodel.error_reg_inst.read(status, rdata); 
    regmodel.error_reg_inst.sample_values(); 
    
  endtask
 
endclass 
    
/////////////////////////////////////////////////////////////////////////        
       
 class id_rd extends uvm_sequence;
 
   `uvm_object_utils(id_rd)
  
   top_reg_block regmodel;
  
   
   function new (string name = "id_rd"); 
    super.new(name);    
  endfunction
  
 
  task body;  
    uvm_status_e   status;
    bit [31:0] rdata;
    
    //////working with id 
     regmodel.id_reg_inst.read(status, rdata); 

  endtask
 
endclass
     
/////////////////////////////////////////////////////////////////////////////
      
class test extends uvm_test;   
  `uvm_component_utils(test)
  
  env e;
  cntrl_wr_rd cwr;
  cfg_wr_rd cfgwr;
  status_rd srd;
  error_rd erd;
  id_rd ird;
  
  function new(string name = "test",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e = env::type_id::create("e",this);
    cwr = cntrl_wr_rd::type_id::create("cwr");
    cfgwr = cfg_wr_rd::type_id::create("cfgwr");
    srd = status_rd::type_id::create("srd");
    erd = error_rd::type_id::create("erd");
    ird = id_rd::type_id::create("ird");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    assert(cwr.randomize());
    cwr.regmodel = e.regmodel;
    cwr.start(e.agent_inst.seqr);
    
    assert(erd.randomize());    
    erd.regmodel = e.regmodel;
    erd.start(e.agent_inst.seqr);
    
    assert(cfgwr.randomize());
    cfgwr.regmodel = e.regmodel;
    cfgwr.start(e.agent_inst.seqr);
    
    assert(srd.randomize());    
    srd.regmodel = e.regmodel;
    srd.start(e.agent_inst.seqr);

    assert(ird.randomize());    
    ird.regmodel = e.regmodel;
    ird.start(e.agent_inst.seqr);
    
    phase.drop_objection(this);
    phase.phase_done.set_drain_time(this, 1000);
  endtask
  
endclass

/////////////////////////////////////////////////////////////////////////////////
    
      
module tb;
  
  top_if vif();
    
  memory_controller dut (vif.clk, vif.rst_n, vif.csr_wr_en, vif.csr_rd_en, vif.csr_addr, vif.csr_wr_data, vif.csr_rd_data, vif.mem_start, vif.mem_mode, vif.mem_burst_length, vif.mem_latency, vif.error_flag);
 
  
  initial begin
   vif.clk <= 0;
  end
 
  always #10 vif.clk = ~vif.clk;
  
  initial begin
    uvm_config_db#(virtual top_if)::set(null, "*", "vif", vif);
    run_test("test");
   end
  
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
 
  
endmodule 
