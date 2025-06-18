//considering dut with register in it only

class reg1 extends uvm_reg;
  `uvm_object_utils(reg1)
   
  rand uvm_reg_field ctrl;

  function new (string name = "reg1");
    super.new(name,32,UVM_NO_COVERAGE); 
  endfunction

  function void build; 
    ctrl = uvm_reg_field::type_id::create("ctrl");   
    // Configure
    ctrl.configure(  .parent(this), 
                     .size(32), 
                     .lsb_pos(0), 
                     .access("RW"),  
                     .volatile(0), 
                     .reset('h0), 
                     .has_reset(1), 
                     .is_rand(1), 
                   .individually_accessible(1)); 
    endfunction
endclass

///////////////////////////////////////////////////////
class reg2 extends uvm_reg;
  `uvm_object_utils(reg2)
   
  rand uvm_reg_field data;

  function new (string name = "reg2");
    super.new(name,32,UVM_NO_COVERAGE); 
  endfunction

  function void build; 
    data = uvm_reg_field::type_id::create("data");   
    // Configure
    data.configure(  .parent(this), 
                     .size(32), 
                     .lsb_pos(0), 
                     .access("RW"),  
                     .volatile(0), 
                     .reset('h0), 
                     .has_reset(1), 
                     .is_rand(1), 
                   .individually_accessible(1)); 
    endfunction
endclass
////////////////////////////////////////////////////////////
class top_reg_block extends uvm_reg_block;
  `uvm_object_utils(top_reg_block)
  

  rand reg1  	reg1_inst; 
  rand reg2  	reg2_inst; 

  function new (string name = "top_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction


  function void build;
    reg1_inst = reg1::type_id::create("reg1_inst");
    reg1_inst.build();  //manually calling build of reg1
    reg1_inst.configure(this); //configure instance of reg1

    
    reg2_inst = reg2::type_id::create("reg2_inst");
    reg2_inst.build();//manually calling build of reg2
    reg2_inst.configure(this);//configure instance of reg2
    

    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN); ////instance, base_addr, size in byte, endian
    default_map.add_reg(reg1_inst	, 'h0, "RW"); //instance, offset_addr , access
    default_map.add_reg(reg2_inst	, 'h4, "RW"); 
    
    lock_model();
    /*
    lock_model build the addr map ,once locked no further changes,such as adding registers or memories,can be made.
    It is not possible to unlock a model.
    */
    endfunction
endclass





