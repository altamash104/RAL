/*
Q.Why RAL?
->when we do not use RAL and directly access the hardware register then we have to take care of address, bit ,fields manually

 Example: without RAL

  dut.reg_if.addr <= 32'h00000010;  // address
  dut.reg_if.wdata <= 8'hAA;        // write data
  dut.reg_if.write <= 1'b1;         // write enable
this can look easy when number of register in dut are less but as the number of register increases complexity increases.
 
Example: with RAL

    my_reg_model.ctrl_reg.write(status, 8'hAA);

Here, ctrl_reg is a register and write() is a method. You don’t need to find the address or manually toggle the signals(it will be automatically retrive from address map through reg model). 
Everything is happening through abstraction.Means RAL hide all the details and left you with minimal work.

->In RAL  if we wish we don't have to do all the transaction we can have backdoor access of the hardware register if we are not using frontdoor access it give us flexibility.
    
    reg_ints.write(status,data,UVM_FRONTDOOR/UVM_BACKDOOR)
  Note-Backdoor access is used for debugging and loading the elf in to the memor
      -Frontdoor access is used in post silicon verification 

-> Minimum requirements for including RAL in testbench.
  
  1) atlest single register/ memory exist in DUT
  2) register have atleast single field
  3) registers should have address

*/
/////////////////////////////////
module top (
  input clk, write,
  input [31:0] data_in,
  output reg [31:0] data_out,
  output done
);
  
  reg [31:0] temp;/// [31:16] --> addr  [15:0] --> data
  
  always@(posedge clk)
  begin
    if(write)
       temp <= data_in;
    else
       data_out <= temp;
  end
endmodule
//Note- here register don't have address and field

//////////////////////////////////////////////////////////////

module top (
  input clk, write,addr,
  input [31:0] data_in,
  output reg [31:0] data_out,
  output done
);
  
  reg [31:0] temp;
  
always@(posedge clk)
  begin
    if(write) 
      begin
        if(addr == 0) 
          begin
           temp <= data_in;
          end
      end 
    else
       begin
        if(addr == 0) 
          begin
           data_out <= temp;
          end
      end
endmodule
//Note-Here we have addr of the register
