/*
Predict_method-
1.It works predominantly on abstraction register.
2.Predict method  update both desire as well as mirror value.
3.It returns true(bcz it "bit type") if prediction was successful for each field in the register.

Mirror_method-
1.It perform read operation.
2.After reading it will perform comparison between existing mirror value with current mirror value if both of them are equal.
then it will update the mirror value with current value,other wise it will throw and error.
*/
//Design
module top(
input clk, rst,
input wr,addr,
  input [7:0] din,
  output [7:0] dout
);
  
  reg [7:0] tempin;
  reg [7:0] tempout;
  
  always@(posedge clk)
    begin
      if(rst)
        begin
        tempin <= 8'h00;
        tempout <= 8'h00;  
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
  logic [7:0] din;
  logic [7:0] dout;
  
endinterface

//Testbench
import uvm_pkg::*;
`include "uvm_macros.svh"

//////////////////transaction class

class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)

       bit [7:0] din;
       bit       wr;
       bit       addr;
       bit       rst;
       bit [7:0] dout;   
  
  function new(string name = "transaction");
    super.new(name);
  endfunction
  
endclass

//driver 
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
    tif.wr   <= 1'b0;
    tif.din  <= 8'h00;
    tif.addr <= 1'b0;
    repeat(5)@(posedge tif.clk);
    `uvm_info("DRV", "System Reset", UVM_NONE);
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
          repeat(2) @(posedge tif.clk);
           tr.dout = tif.dout;
          `uvm_info("DRV", $sformatf("Data Read -> Rdata : %0d",tif.dout), UVM_NONE);
       end    
  endtask
  
///////////////main task of driver
  
   virtual task run_phase(uvm_phase phase);
      tr = transaction::type_id::create("tr");
     forever begin
        seq_item_port.get_next_item(tr);
        drive_dut();
        seq_item_port.item_done();  
      end
   endtask

endclass

//agent class

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

//building reg model

class temp_reg extends uvm_reg;
  `uvm_object_utils(temp_reg)
   
  rand uvm_reg_field temp;

  
  function new (string name = "temp_reg");
    super.new(name,8,UVM_NO_COVERAGE); 
  endfunction

 function void build; 
    
 
    temp = uvm_reg_field::type_id::create("temp");   
    // Configure
    temp.configure(  .parent(this), 
                     .size(8), 
                     .lsb_pos(0), 
                     .access("RW"),  
                     .volatile(0), 
                     .reset(0), 
                     .has_reset(1), 
                     .is_rand(1), 
                     .individually_accessible(1)); 
  endfunction
  
endclass

//creating reg block
class top_reg_block extends uvm_reg_block;
  `uvm_object_utils(top_reg_block)
  
  rand temp_reg 	temp_reg_inst; 
  
  function new (string name = "top_reg_block");
    super.new(name, build_coverage(UVM_NO_COVERAGE));
  endfunction


  function void build;
    temp_reg_inst = temp_reg::type_id::create("temp_reg_inst");
    temp_reg_inst.build();
    temp_reg_inst.configure(this);

    default_map = create_map("default_map", 'h0, 1, UVM_LITTLE_ENDIAN); // name, base, nBytes
    default_map.add_reg(temp_reg_inst	, 'h0, "RW");  // reg, offset, access
    
    default_map.set_auto_predict(1);
    
    lock_model();
  endfunction
endclass


/////////////////////////////////////////////////////////////////////////////////////

class top_reg_seq extends uvm_sequence;

  `uvm_object_utils(top_reg_seq)
  
   top_reg_block regmodel;
  
   
  function new (string name = "top_reg_seq"); 
    super.new(name);    
  endfunction
  

  task body;  
    uvm_status_e   status;
    bit [7:0] rdata,rdata_m;
    
    
    
     regmodel.temp_reg_inst.write(status,5'h10);
     rdata = regmodel.temp_reg_inst.get();//desire value =10
     rdata_m = regmodel.temp_reg_inst.get_mirrored_value();//mirror value=10
    `uvm_info("SEQ", $sformatf("Mir : %0d Des : %0d ", rdata_m, rdata), UVM_NONE);
   
     
     regmodel.temp_reg_inst.predict(5'h05);
     rdata = regmodel.temp_reg_inst.get();//desire value=05
     rdata_m = regmodel.temp_reg_inst.get_mirrored_value();//mirror value=05
    `uvm_info("SEQ", $sformatf("Mir : %0d Des : %0d ", rdata_m, rdata), UVM_NONE);
   
     regmodel.temp_reg_inst.mirror(status,UVM_CHECK);// UVM_NO_CHECK uses will not throw error
    rdata = regmodel.temp_reg_inst.get();
     rdata_m = regmodel.temp_reg_inst.get_mirrored_value();
    `uvm_info("SEQ", $sformatf("Mir : %0d Des : %0d ", rdata_m, rdata), UVM_NONE);
  
  endtask
endclass

///////////////////////reg adapter

class top_adapter extends uvm_reg_adapter;
  `uvm_object_utils (top_adapter)

   function new (string name = "top_adapter");
      super.new (name);
   endfunction
  
  //---------------------------------------
  // reg2bus method 
  //--------------------------------------- 
  function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    transaction tr;    
    tr = transaction::type_id::create("tr");
    
    tr.wr    = (rw.kind == UVM_WRITE);
    tr.addr  = rw.addr;
    
    if(tr.wr == 1'b1) tr.din = rw.data;
    
    return tr;
  endfunction

  //---------------------------------------
  // bus2reg method 
  //--------------------------------------- 
  function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    transaction tr;
    
    assert($cast(tr, bus_item));

    rw.kind = tr.wr ? UVM_WRITE : UVM_READ;
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
    super.connect_phase(phase);
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
  
  // e.set_config_int( "*", "include_coverage", 0 );
endfunction

virtual task run_phase(uvm_phase phase);
  
  phase.raise_objection(this);
  
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
    
    uvm_config_db#(int)::set(null,"*","include_coverage", 0); //to remove include coverage message

    run_test("test");
   end
  
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
//////////////////////////////////////////////////////////
/*
UVM_INFO @ 0: reporter [RNTST] Running test test...
UVM_INFO testbench.sv(65) @ 50: uvm_test_top.env.agent_inst.d [DRV] Data Write -> Wdata : 16
UVM_INFO testbench.sv(220) @ 50: uvm_test_top.env.agent_inst.seqr@@trseq [SEQ] Mir : 16 Des : 16 
UVM_INFO testbench.sv(226) @ 50: uvm_test_top.env.agent_inst.seqr@@trseq [SEQ] Mir : 5 Des : 5 
UVM_INFO testbench.sv(71) @ 110: uvm_test_top.env.agent_inst.d [DRV] Data Read -> Rdata : 16
UVM_ERROR /apps/vcsmx/vcs/U-2023.03-SP2//etc/uvm-1.2/src/reg/uvm_reg.svh(2950) @ 110: reporter [RegModel] Register "regmodel.temp_reg_inst" value read from DUT (0x0000000000000010) does not match mirrored value (0x0000000000000005)
UVM_INFO /apps/vcsmx/vcs/U-2023.03-SP2//etc/uvm-1.2/src/reg/uvm_reg.svh(2963) @ 110: reporter [RegModel] Field temp (regmodel.temp_reg_inst[7:0]) mismatch read=8'h10 mirrored=8'h5 
UVM_INFO testbench.sv(231) @ 110: uvm_test_top.env.agent_inst.seqr@@trseq [SEQ] Mir : 16 Des : 16 
UVM_INFO /apps/vcsmx/vcs/U-2023.03-SP2//etc/uvm-1.2/src/base/uvm_objection.svh(1276) @ 310: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
UVM_INFO /apps/vcsmx/vcs/U-2023.03-SP2//etc/uvm-1.2/src/base/uvm_report_server.svh(904) @ 310: reporter [UVM/REPORT/SERVER]
*/
