`include "uvm_macros.svh"
  import uvm_pkg::*;

class reg2 extends uvm_reg;
  `uvm_object_utils(reg2)
   

  rand uvm_reg_field slv_cntrl;
  rand uvm_reg_field slv_data;

  
  function new (string name = "reg2");
    super.new(name,32,UVM_NO_COVERAGE); 
  endfunction

  function void build; 
    slv_cntrl = uvm_reg_field::type_id::create("slv_cntrl");   
    
    slv_cntrl.configure(  .parent(this), 
                     .size(16), 
                     .lsb_pos(0), 
                     .access("RW"),  
                     .volatile(0), 
                     .reset(16'h0), 
                     .has_reset(1), 
                     .is_rand(1), 
                     .individually_accessible(1)); 
    
 /////////////////////////////////////////////////////////   
    
    slv_data = uvm_reg_field::type_id::create("slv_data");   
    
    slv_data.configure(  .parent(this), 
                     .size(16), 
                     .lsb_pos(16), 
                     .access("RW"),  
                     .volatile(0), 
                     .reset(16'h0), 
                     .has_reset(1), 
                     .is_rand(1), 
                     .individually_accessible(1));   
  endfunction
endclass


module tb;
  
  reg2 r2;
  initial begin
    r2 = new("r2");
    r2.build();
  end
endmodule
