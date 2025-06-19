/*
Predictor is used to update the mirror and desired value,there are three type of predictor.
1.Auto prediction/impcit prediction-Here we use response of driver from bidirectional tlm port to update the mirror and desried  value of reg model.
2.Explicit prediction-here we use an independent component predictor which will call the predict method to update the desired and mirror value.
3.Passive Predictor-Here we donot use any reg sequence instead we use bus sequence and predictor wil capture response and uodate the mirror and desire value.
*/
//This code is simple implementation of implicit predictor,using by bi-dirctional property of driver sequencer.
class generator extends uvm_sequence #(transaction);
  `uvm_object_utils(generator)
  
    transaction tr;
  	//int addr, data;
  
  function new (string name = "generator");
    super.new(name);
  endfunction

  task body();
    tr = transaction::type_id::create("tr");
    //wait_for_grant();
    start_item(tr);    
    tr.randomize() with {tr.addr==addr;tr.data==data;};
    `uvm_info("SEQ", $sformatf("Sending TX to SEQR: addr = %0d  data = %0d", tr.addr, tr.data),UVM_LOW); 
   // send_request(tr);
    //wait_for_item_done();
    //get_response(tr);
    finish_item(tr);
    `uvm_info("SEQ", $sformatf("After get_response: addr = %0d  data = %0d", tr.addr, tr.data), UVM_LOW);
  endtask
endclass

//driver

class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)
  
  transaction tr;
  
  
  function new(string name = "driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  

  
  task run_phase (uvm_phase phase);
    forever 
      begin
        seq_item_port.get_next_item(tr);
        `uvm_info("DRV", $sformatf("Recv. TX from SEQR addr = %0d data = %0d",tr.addr, tr.data), UVM_LOW);
         #100; 
        `uvm_info("DRV", $sformatf("Applied Stimuli to DUT -> Sending REQ response to SEQR"), UVM_LOW);
        seq_item_port.item_done(tr);
      end
  endtask
  
  
endclass


///////////////////////////////////////////////////// sequencer


class sequencer extends uvm_sequencer #(transaction);
  `uvm_component_utils(sequencer)
  
  function new(string name = "sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
endclass

////////////////////////////////////////////agent

class agent extends uvm_agent;
   `uvm_component_utils(agent)
  
  driver drv;
  sequencer seqr;
  

  
  function new(string name = "agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = driver::type_id::create("drv", this);
    seqr = sequencer::type_id::create("seqr", this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
  
  
endclass


//////////////////////////////////////////////////// env

class env extends uvm_agent;
  `uvm_component_utils(env)

  
  agent agt;
  
  function new(string name = "env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = agent::type_id::create("agt", this);
  endfunction
  
endclass

////////////////////////////////////////test

class test extends uvm_test;
  `uvm_component_utils(test)
  
  
  env e;
  generator gen;


  
  function new(string name = "test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e = env::type_id::create("e", this);
    gen = generator::type_id::create("gen");    
 
  endfunction
 
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    gen.start(e.agt.seqr);
    phase.drop_objection(this);
  endtask
endclass


/////////////////////////////////////////////

module tb;
  initial begin
    run_test("test");
  end
endmodule
