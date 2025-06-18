// To implement memory in uvm environment we have a base class name "uvm_mem" in uvm .

//size of memory is 16x8
class dut_mem1 extends uvm_mem;
 
  `uvm_object_utils(dut_mem1)
 
  function new(string name = "dut_mem1");
  super.new(name, 16, 8, "RW", UVM_NO_COVERAGE);
endfunction
 
endclass

//size of 1024x16
class dut_mem2 extends uvm_mem;
 
`uvm_object_utils(dut_mem2)
 
  function new(string name = "dut_mem2");
    super.new(name, 1024, 16, "RW", UVM_NO_COVERAGE);
  endfunction
 
endclass

//size of memory is 2048x32
class dut_mem3 extends uvm_mem;
 
`uvm_object_utils(dut_mem3)
 
	function new(string name = "dut_mem3");
  	  super.new(name, 2048, 32, "RW", UVM_NO_COVERAGE);
	endfunction
 
endclass


