`include "uvm_macros.svh"
  import uvm_pkg::*;

class reg3 extends uvm_reg;
  `uvm_object_utils(reg3)
   

  rand uvm_reg_field en;//LSB-0
  rand uvm_reg_field mode;//LSB-1
  rand uvm_reg_field addr;//LSB-4
  rand uvm_reg_field data;//LSB-12
  
  function new (string name = "reg3");
    super.new(name,32,UVM_NO_COVERAGE); 
  endfunction

function void build; 
    en = uvm_reg_field::type_id::create("en");   
  en.configure(this, 1,       0,   "RW",   0,        0,        1,        1,      1); //this by name method
    
    mode = uvm_reg_field::type_id::create("mode");   
    mode.configure(this, 3,       1,   "RW",   0,        0,        1,        1,      1); 
    
    addr = uvm_reg_field::type_id::create("addr");   
    addr.configure(this, 8,       4,   "RW",   0,        0,        1,        1,      1); 
    
    data = uvm_reg_field::type_id::create("slv_cntrl");   
    data.configure(this, 16,       12,   "RW",   0,        0,        1,        1,     1); 
    
      endfunction
endclass
//Note- for reserved field we do not need to do any thing
///////////////////////////////////////////
module tb;
  
  reg3 r3;
  initial begin
    r3 = new("r3");
    r3.build();
  end
endmodule
