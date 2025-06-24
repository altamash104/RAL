//Design
module top (
input clk, wr,
input [3:0] addr,
input [7:0] din,
output reg [7:0] dout  
);
 
  reg [7:0] mem [16];
 
  ///first 4 locations store commands
  /// rest 12 locations store data
 
 
 
  always@(posedge clk)
    begin
      if(wr)
        mem[addr] <= din;
      else
        dout      <= mem[addr];
    end
 
 
endmodule

//////////////////////////////interface
interface top_if;
  logic clk, wr;
  logic [3:0] addr;
  logic [7:0] din;
  logic [7:0] dout ;
endinterface

/////////////////////////////////////////

//Testbench

`include "uvm_macros.svh"
import uvm_pkg::*;

/////////////////////////////////////////////////
///////////////////transaction 

class transaction extends uvm_sequence_item;
`uvm_object_utils(transaction)
  
  rand bit wr;
  rand bit [3:0] addr;
  rand bit [7:0] din;
       bit [7:0] dout;
        
   function new(input string path = "transaction");
    super.new(path);
   endfunction


endclass

///////////////////////////////////////////////////////////
/////////////////driver code

class drv extends uvm_driver#(transaction);
  `uvm_component_utils(drv)

  transaction tr;
  virtual top_if vif;

  function new(input string path = "drv", uvm_component parent = null);
    super.new(path,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    if(!uvm_config_db#(virtual top_if)::get(this,"","vif",vif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface");
  endfunction
  
   virtual task run_phase(uvm_phase phase);
      tr = transaction::type_id::create("tr");
     forever begin
        seq_item_port.get_next_item(tr);
               if(tr.wr == 1'b1)
                    begin
                    @(posedge vif.clk);
                    vif.wr   <= tr.wr;
                    vif.addr <= tr.addr;
                    vif.din  <= tr.din;
      `uvm_info("DRV", $sformatf("wr : %0b  addr : %0d  din : %0d dout : %0d", tr.wr, tr.addr, tr.din, tr.dout), UVM_NONE);
        
                   repeat(2) @(posedge vif.clk);  
                    end
                else
                  begin
                    @(posedge vif.clk);
                    vif.wr   <= tr.wr;
                    vif.addr <= tr.addr;
                    @(posedge vif.clk);
      `uvm_info("DRV", $sformatf("wr : %0b  addr : %0d  din : %0d dout : %0d", tr.wr, tr.addr, tr.din, vif.dout), UVM_NONE);
                    tr.dout   = vif.dout;
                     @(posedge vif.clk);
                   end
      seq_item_port.item_done();
      
      end
   endtask


endclass

///////////////////////////////////////////////////////////////////////////////
      
class monitor extends uvm_monitor;
    `uvm_component_utils( monitor )

    uvm_analysis_port   #(transaction)  mon_ap;
    virtual top_if vif;
    transaction tr;
    

  
  
    virtual function void build_phase(uvm_phase phase);
        super.build_phase (phase);
        mon_ap = new("mon_ap", this);
      
    if(!uvm_config_db#(virtual top_if)::get(this,"","vif",vif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface");
      
    endfunction : build_phase
  
  
    
  
    function new(string name="my_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new
  
  
  
  
  
    virtual task run_phase(uvm_phase phase);
     tr = transaction::type_id::create("tr");
            forever begin
              repeat(3) @(posedge vif.clk);
                  tr.wr    = vif.wr;
                  tr.addr  = vif.addr;
                  tr.din   = vif.din;
                  tr.dout  = vif.dout;
                  
                         
                  `uvm_info("MON", $sformatf("Wr :%0b  Addr : %0d Din:%0d  Dout:%0d", tr.wr, tr.addr, tr.din, tr.dout), UVM_NONE)
                  mon_ap.write(tr);
                end 
    endtask 

      
endclass

//////////////////////////////////////////////////////////////////////////////////////////////


 class sco extends uvm_scoreboard;
`uvm_component_utils(sco)

  uvm_analysis_imp#(transaction,sco) recv;
   bit [7:0] arr [16]; 

    function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
    endfunction
    
    
  virtual function void write(transaction tr);
    `uvm_info("SCO", $sformatf("Wr :%0b  Addr : %0d Din:%0d  Dout:%0d", tr.wr, tr.addr, tr.din, tr.dout), UVM_NONE)                   if(tr.wr == 1'b1)
        begin
          arr[tr.addr] = tr.din;
          `uvm_info("SCO", $sformatf("Data Stored -> addr : %0d data : %0d", tr.addr, tr.din), UVM_NONE);             
        end
    else
       begin
         if(arr[tr.addr] == tr.dout)
           `uvm_info("SCO","Test Passed", UVM_NONE)
         else
           `uvm_info("SCO","Test Failed", UVM_NONE)
       end
           
   $display("---------------------------------------------");          
  endfunction

endclass      
         
//////////////////////////////////////////////////////////////////////////////////////

class agent extends uvm_agent;
`uvm_component_utils(agent)

function new(input string inst = "agent", uvm_component parent = null);
super.new(inst,parent);
endfunction

 drv d;
 uvm_sequencer#(transaction) seqr;
 monitor m;


virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);

 d = drv::type_id::create("d",this); 
 seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this); 
 m = monitor::type_id::create("m",this);
  
endfunction

virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
d.seq_item_port.connect(seqr.seq_item_export);
endfunction

endclass


///////////////adding memory in verif env


class dut_mem extends uvm_mem;
`uvm_object_utils(dut_mem)
      
function new(string name = "dut_mem");
  super.new(name, 16, 8, "RW", UVM_NO_COVERAGE);
endfunction
 
endclass

/////////////////////////////////////////////////
class top_mem_block extends uvm_reg_block;
  `uvm_object_utils(top_mem_block)
  

  dut_mem	mem; 
  
  function new (string name = "top_mem_block");
    super.new(name, build_coverage(UVM_NO_COVERAGE));
  endfunction


  function void build;
    
      add_hdl_path("dut", "RTL");
    
      mem = new("mem");
      mem.add_hdl_path_slice("mem", 0, 8);
      mem.configure( .parent(this) );
      mem.set_coverage(UVM_NO_COVERAGE);


    default_map = create_map("reg_map", 0, 1, UVM_LITTLE_ENDIAN, 1); // name, base, nBytes
    default_map.add_mem(mem	, 'h0);  // reg, offset, access
    
    lock_model();
  endfunction
endclass

//////////////////////////////////////////////////////////////////
class top_reg_seq extends uvm_sequence;
  `uvm_object_utils(top_reg_seq)
  
   top_mem_block regmodel;
  
  
   
  function new (string name = "top_reg_seq"); 
    super.new(name);    
  endfunction
  
  
  task body;
     uvm_status_e   status;
    
    uvm_reg_data_t burst_data[];
    
     burst_data = new[4];
    
    
    
    
    for (int i = 0; i < 4; i++) begin
      burst_data[i] = $urandom_range(50, 255);
    end
    
    
  ////////burst write to memory  
    regmodel.mem.burst_write(status, .offset(regmodel.mem.get_offset),  .value(burst_data), .path(UVM_FRONTDOOR), .parent(this));
    
   ////// burst read from memory  
    regmodel.mem.burst_read(status,  .offset(regmodel.mem.get_offset),  .value(burst_data), .path(UVM_FRONTDOOR), .parent(this));
 
    
  endtask

  
  /*
  task body;  
    uvm_status_e   status;
    bit [7:0] rdata,data;
    bit [7:0] arr_wr[10] = '{default : 0};
    bit [7:0] arr_rd[10] = '{default : 0};
    
    
    for(int i = 0; i < 10; i++) 
      begin
        data = $urandom_range(5, 255);
        regmodel.mem.write(status, i , data);
        arr_wr[i] = data;
        $display("-----------------------------------------");
      end
    
    for(int i = 0; i < 10; i++) 
      begin
        regmodel.mem.read(status, i , rdata);
        arr_rd[i] = rdata;
        $display("-----------------------------------------");
      end
    
   // regmodel.mem.write(status,'h0,  8'h4);
   // regmodel.mem.read(status,'h0,  rdata);
   // `uvm_info("SEQ", $sformatf("Data read : %0d", rdata), UVM_NONE);
    
   // regmodel.mem.poke(status,'h1,  8'h12);
   // regmodel.mem.peek(status,'h1,  rdata);
   // `uvm_info("SEQ", $sformatf("Data read : %0d", rdata), UVM_NONE);
    
 


  
  
  endtask
  
    */
  
  
  
  
endclass
         
        
         
         
         
         
  
  //////////////////////////////////////////////////////////////////////
  
  
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
    
    if(rw.kind == (UVM_WRITE | UVM_BURST_WRITE))
      tr.wr = 1'b1;
    else if (rw.kind == UVM_READ | UVM_BURST_READ)
      tr.wr = 1'b0;
    
    //tr.wr    = (rw.kind == UVM_WRITE )? 1'b1 : 1'b0;
    
    
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

  
  /////////////////////////////////////////////////////
  
  
  class env extends uvm_env;
  
  agent          agent_inst;
  top_mem_block  regmodel;   
  top_adapter    adapter_inst;
  sco s;
    
      
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
    
    s = sco::type_id::create("s", this);
  

    agent_inst = agent::type_id::create("agent_inst", this);
    regmodel   = top_mem_block::type_id::create("regmodel", this);
    regmodel.build();
     
    
    adapter_inst = top_adapter::type_id::create("adapter_inst",, get_full_name());
  endfunction 
  

  function void connect_phase(uvm_phase phase);
    agent_inst.m.mon_ap.connect(s.recv);
  
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
  phase.phase_done.set_drain_time(this, 50);
endtask
  
  
  
endclass

//////////////////////////////////////////////////////////////


module tb;
  
    
    
  top_if vif();
    
  top dut (vif.clk, vif.wr, vif.addr, vif.din, vif.dout);

  
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
