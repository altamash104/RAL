/*
1.A register is said to be accessed as a back door if it uses a simulator database to directly access the DUT register using design signals.
2.Using specified path of register with dot operator we can access the dut of the register.
3.It is faster compare to frontdoor.
    syntax:
      add_hdl_path(instance,"RTL"); // instance is nothing bit top dut(.(),.()), this is called instance.
      add_hdl_path_slice(Register name,Starting position,no of bits);
      eg-
      add_hdl_path_slice("dut","RTL");
      add_hdl_path_slice("reg1",0,32);
*/
//design
module top(
input clk, rst,
input wr,addr,
input [3:0] din,
output [3:0] dout
);
  
  reg [3:0] tempin;
  reg [3:0] tempout;
  
  always@(posedge clk)
    begin
      if(rst)
        begin
        tempin <= 4'h4;
        tempout <= 4'b0000;  
        end  
      else if (wr == 1'b1)
        begin
          if(addr == 1'b0)
           tempin <= din;
          end  
      else if(wr == 1'b0)
           if(addr == 1'b0)
           tempout <= tempin;
          end  
        
  
  assign dout = tempout;
  
endmodule


//////////////////////////////////////

interface top_if ;
  
logic clk, rst;
logic wr;
logic addr;
logic [3:0] din;
logic [3:0] dout;
  
  
endinterface
////////////////////////////////////////
//testbench
import uvm_pkg::*;
`include "uvm_macros.svh"

//////////////////transaction class

class transaction extends uvm_sequence_item;

       bit [3:0] din;
       bit       wr;
       bit       addr;
       bit       rst;
       bit [3:0] dout;   
  
  function new(string name = "transaction");
    super.new(name);
  endfunction
  
  

  `uvm_object_utils_begin(transaction)
    `uvm_field_int(din,UVM_ALL_ON)
    `uvm_field_int(wr,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_int(dout,UVM_ALL_ON)
  `uvm_object_utils_end
  


endclass

///////////////////////////////////////////////////////
////////////////////////driver 

class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)

  transaction tr;
  virtual top_if tif;

  function new(input string path = "driver", uvm_component parent = null);
    super.new(path,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    if(!uvm_config_db#(virtual top_if)::get(this,"","tif",tif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface");
  endfunction
  
  ///////////////reset DUT at the start
  task reset_dut();
    @(posedge tif.clk);
    tif.rst  <= 1'b1;
    tif.wr   <= 1'b1;
  //  tif.din  <= 4'b0000;
    tif.addr <= 1'b0;
    repeat(5)@(posedge tif.clk);
    `uvm_info("DRV", $sformatf("SYSTEM RESET Wdata : %0d", tif.din), UVM_NONE);
    tif.rst  <= 1'b0;
  endtask
  
  //////////////drive DUT
  
  task drive_dut();
    @(posedge tif.clk);
    tif.rst  <= 1'b0;
    tif.wr   <= tr.wr;
    tif.addr <= tr.addr;
    if(tr.wr == 1'b1)
       begin
           tif.din <= tr.din;
         repeat(2) @(posedge tif.clk);
          `uvm_info("DRV", $sformatf("Data Write -> Wdata : %0d",tif.din), UVM_NONE);
       end
      else
       begin  
         repeat(2)  @(posedge tif.clk);
         tr.dout = tif.dout;
          `uvm_info("DRV", $sformatf("Data Read -> Rdata : %0d",tif.dout), UVM_NONE);
       end    
  endtask
  
  
  //
  ///////////////main task of driver
  
   virtual task run_phase(uvm_phase phase);
 //    reset_dut();   ///////reset at start of simulation
      tr = transaction::type_id::create("tr");
     forever begin
        seq_item_port.get_next_item(tr);
        drive_dut();
        seq_item_port.item_done();  
      end
   endtask

endclass

////////////////////////////////////////////////////////////////////////////////
///////////////////////agent class


class agent extends uvm_agent;
`uvm_component_utils(agent)
  

function new(input string inst = "agent", uvm_component parent = null);
super.new(inst,parent);
endfunction

 driver d;
 uvm_sequencer#(transaction) seqr;



virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
   d = driver::type_id::create("d",this);
   seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this); 
endfunction

virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
   d.seq_item_port.connect(seqr.seq_item_export);
endfunction

endclass

////////////////////////////////////////////////////////////////////////////////////////



//////////////////////building reg model

////////////////////////


class temp_reg extends uvm_reg;
  `uvm_object_utils(temp_reg)
   

  rand uvm_reg_field temp;

  
  function new (string name = "temp_reg");
    super.new(name,4,UVM_NO_COVERAGE); 
  endfunction


  
  function void build; 
    
 
    temp = uvm_reg_field::type_id::create("temp");   
    // Configure
    temp.configure(  .parent(this), 
                     .size(4), 
                     .lsb_pos(0), 
                     .access("RW"),  
                   .volatile(0), 
                     .reset(2), 
                     .has_reset(1), 
                     .is_rand(1), 
                   .individually_accessible(0)); 
    // Below line is equivalen to above one   
    // temp.configure(this, 32,       0,   "RW",   0,        0,        1,        1,      0); 
    //                  reg, bitwidth, lsb, access, volatile, reselVal, hasReset, isRand, fieldAccess
    
      endfunction
endclass


//////////////////////////////////////creating reg block


class top_reg_block extends uvm_reg_block;
  `uvm_object_utils(top_reg_block)
  

  rand temp_reg 	temp_reg_inst; 
  

  function new (string name = "top_reg_block");
    super.new(name, build_coverage(UVM_NO_COVERAGE));
  endfunction


  function void build;
    
    add_hdl_path ("dut", "RTL");

    temp_reg_inst = temp_reg::type_id::create("temp_reg_inst");
    temp_reg_inst.build();
    temp_reg_inst.configure(this,null);
    temp_reg_inst.add_hdl_path_slice("tempin",0, 4); //reg name in rtl,starting position,no.of bits wide
    
    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN,0); // name, base, nBytes
    default_map.add_reg(temp_reg_inst	, 'h0, "RW");  // reg, offset, access
    default_map.set_auto_predict(1);
    
    
    lock_model();
  endfunction
endclass


/////////////////////////////////////////////////////////////////////////////////////

class top_reg_seq extends uvm_sequence;

  `uvm_object_utils(top_reg_seq)
  
   top_reg_block regmodel;
   uvm_reg_data_t ref_data;
  
   
  function new (string name = "top_reg_seq"); 
    super.new(name);    
  endfunction
  

  task body;  
    uvm_status_e   status;
    bit [3:0] rdata;
    
    
    ///////frontdoor write
    regmodel.temp_reg_inst.write(status, 4'hf, UVM_FRONTDOOR);
     ref_data = regmodel.temp_reg_inst.get(); ///get the desired value
    `uvm_info("REG_SEQ", $sformatf("Desired Value backdoor: %0d", ref_data), UVM_NONE);
    ref_data = regmodel.temp_reg_inst.get_mirrored_value();
    `uvm_info("REG_SEQ", $sformatf("Mirror Value backdoor: %0d", ref_data), UVM_NONE);
    
  
    
    ////////////////backdoor read
    regmodel.temp_reg_inst.read(status, rdata, UVM_BACKDOOR);
    `uvm_info("REG_SEQ",$sformatf("Backdoor read",rdata),UVM_LOW);
    
    
    ///////////////////backdoor write
    
    regmodel.temp_reg_inst.write(status, 4'he, UVM_BACKDOOR);
     ref_data = regmodel.temp_reg_inst.get(); ///get the desired value
    `uvm_info("REG_SEQ", $sformatf("Desired Value backdoor: %0d", ref_data), UVM_NONE);
    ref_data = regmodel.temp_reg_inst.get_mirrored_value();
    `uvm_info("REG_SEQ", $sformatf("Mirror Value backdoor: %0d", ref_data), UVM_NONE);

    
  endtask
  
  
  
endclass

////////////////////////////////////////////////////////////////////////
///////////////////////reg adapter

class top_adapter extends uvm_reg_adapter;
  `uvm_object_utils (top_adapter)

  //---------------------------------------
  // Constructor 
  //--------------------------------------- 
  function new (string name = "top_adapter");
      super.new (name);
   endfunction
  
  //---------------------------------------
  // reg2bus method 
  //--------------------------------------- 
  function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    transaction tr;    
    tr = transaction::type_id::create("tr");
    
    tr.wr    = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;
    tr.addr  = rw.addr;
    if(tr.wr == 1'b1) tr.din  = rw.data;
    if(tr.wr == 1'b0) tr.dout = rw.data;
    
    return tr;
  endfunction

  //---------------------------------------
  // bus2reg method 
  //--------------------------------------- 
  function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    transaction tr;
    
    assert($cast(tr, bus_item));

    rw.kind = (tr.wr == 1'b1) ? UVM_WRITE : UVM_READ;
    rw.data = tr.dout;
    rw.addr = tr.addr;
    rw.status = UVM_IS_OK;
  endfunction
endclass




////////////////////////////////////////////////////////////////////////

class env extends uvm_env;
  
  agent          agent_inst;
  top_reg_block  regmodel;   
  top_adapter    adapter_inst;
  
  `uvm_component_utils(env)
  
  //--------------------------------------- 
  // constructor
  //---------------------------------------
  function new(string name = "env", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //---------------------------------------
  // build_phase - create the components
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_inst = agent::type_id::create("agent_inst", this);
    regmodel   = top_reg_block::type_id::create("regmodel", this);
    regmodel.build();
    
    
    adapter_inst = top_adapter::type_id::create("adapter_inst",, get_full_name());
  endfunction 
  

  function void connect_phase(uvm_phase phase);
     
    regmodel.default_map.set_sequencer( .sequencer(agent_inst.seqr), .adapter(adapter_inst) );
    regmodel.default_map.set_base_addr(0);        
  endfunction 

endclass

//////////////////////////////////////////////////////////////////////////////////////////////////


class test extends uvm_test;
`uvm_component_utils(test)

function new(input string inst = "test", uvm_component c);
super.new(inst,c);
endfunction

env e;
top_reg_seq trseq;


  
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
   e      = env::type_id::create("env",this);
   trseq  = top_reg_seq::type_id::create("trseq");
endfunction

virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  assert(trseq.randomize());
  trseq.regmodel = e.regmodel;
  trseq.start(e.agent_inst.seqr);
  phase.drop_objection(this);
  phase.phase_done.set_drain_time(this, 200);
endtask
endclass

//////////////////////////////////////////////////////////////


module tb;
  
    
    
  top_if tif();
    
  top dut (tif.clk, tif.rst, tif.wr, tif.addr, tif.din, tif.dout);

  
  initial begin
   tif.clk <= 0;
  end

  always #10 tif.clk = ~tif.clk;

  
  
  initial begin
    uvm_config_db#(virtual top_if)::set(null, "*", "tif", tif);
    run_test("test");
   end
  
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

  
endmodule
/*
# KERNEL: UVM_INFO @ 0: reporter [RNTST] Running test test...
# KERNEL: UVM_INFO /home/runner/testbench.sv(65) @ 50: uvm_test_top.env.agent_inst.d [DRV] Data Write -> Wdata : 5
# KERNEL: UVM_INFO /home/runner/testbench.sv(222) @ 50: uvm_test_top.env.agent_inst.seqr@@trseq [SEQ] Write Tx to DUT -> Des : 5 and Mir : 5 
# KERNEL: UVM_INFO /home/runner/testbench.sv(71) @ 110: uvm_test_top.env.agent_inst.d [DRV] Data Read -> Rdata : 5
# KERNEL: UVM_INFO /home/runner/testbench.sv(227) @ 110: uvm_test_top.env.agent_inst.seqr@@trseq [SEQ] Read Tx from DUT -> Des : 5 and Mir : 5 Data read : 5
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_objection.svh(1271) @ 310: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_report_server.svh(869) @ 310: reporter [UVM/REPORT/SERVER]
*/
