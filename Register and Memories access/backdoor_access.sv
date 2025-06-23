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
