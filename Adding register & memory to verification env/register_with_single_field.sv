`include "uvm_macros.svh"
  import uvm_pkg::*;

class reg0 extends uvm_reg;
  `uvm_object_utils(reg0)
   
  rand uvm_reg_field slv_reg0;

  
  function new (string name = "reg0");
    super.new(name,32,UVM_NO_COVERAGE); 
  endfunction

  function void build; 
     slv_reg0 = uvm_reg_field::type_id::create("slv_reg0");   
    
    //first method order base
    slv_reg0.configure(  .parent(this), 
                         .size(32), 
                         .lsb_pos(0), 
                         .access("RW"),  
                         .volatile(0), 
                         .reset('h0), 
                         .has_reset(1), 
                         .is_rand(1), 
                         .individually_accessible(1)); 
    
  /*
  parent- it tells us who own this field
  size- what is the size of this field
  lsb_pos=lsb position what is the starting point of lsb in this field 
  access= whehter it is right only aur read only(most of the time it is read only)
  volatil- if this bit is "1" in that case value of the field changes between the transaction
  	if this bit is "0" in this case value  changes only when we do transaction.(in most of the case it will be 0)
    
  reset-this value will be defined in code itself
  has_reset-(1) most of the case it has reset.
  is_rand= it indicates whether user is allowed to rand or rand ,this is possible in case of access state whether it is write or read if 	it is write only then we can add rand keyword
  individualy_accessible-this bit allow us to invidually access the field ,if it is low means it means we have access all reg block ,register address and then reg field (it is always kept high)
  */
    
    //second method 
   // slv_reg0.configure(this, 32,       0,   "RW",   0,        0,        1,        1,      1); 
    //                  reg, bitwidth, lsb, access, volatile, reselVal, hasReset, isRand, fieldAccess
    
      endfunction
endclass

////////////////////////////////

module tb;
  
 reg0 r1;
  
  initial begin 
    r1 = new("r1");
    r1.build();
  end

endmodule
