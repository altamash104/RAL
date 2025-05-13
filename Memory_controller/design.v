// Code your design here
module memory_controller(
    input logic clk,
    input logic rst_n,

    // Control and Status Register Interface
    input logic          csr_wr_en,
    input logic          csr_rd_en,
    input logic [7:0]    csr_addr,
    input logic [31:0]   csr_wr_data,
    output logic [31:0]  csr_rd_data,

    // Memory Interface
    output logic         mem_start,
    output logic [3:0]   mem_mode,
    output logic [7:0]   mem_burst_length,
    output logic [3:0]   mem_latency,
    output logic         error_flag
);

    // Internal registers
    logic [31:0] mem_ctrl_reg;
    logic [31:0] mem_status_reg;
    logic [31:0] mem_cfg_reg;
    logic [31:0] mem_error_reg;
    logic [31:0] mem_id_reg;

    // Parameters for register addresses
    localparam MEM_CTRL_ADDR   = 8'h00;
    localparam MEM_STATUS_ADDR = 8'h04;
    localparam MEM_CFG_ADDR    = 8'h08;
    localparam MEM_ERROR_ADDR  = 8'h0C;
    localparam MEM_ID_ADDR     = 8'h10;

    // Read operation
    always_comb begin
        csr_rd_data = 32'd0;
        if (csr_rd_en) begin
            unique case (csr_addr)
                MEM_CTRL_ADDR   : csr_rd_data = mem_ctrl_reg;
                MEM_STATUS_ADDR : csr_rd_data = mem_status_reg;
                MEM_CFG_ADDR    : csr_rd_data = mem_cfg_reg;
                MEM_ERROR_ADDR  : csr_rd_data = mem_error_reg;
                MEM_ID_ADDR     : csr_rd_data = mem_id_reg;
                default         : csr_rd_data = 32'h00000000;
            endcase
        end
    end

    // Write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ctrl_reg   <= 32'd0;
            mem_status_reg <= 32'd0;
            mem_cfg_reg    <= 32'd0;
            mem_error_reg  <= 32'd0;
            mem_id_reg     <= 32'h1234_ABCD; // Hardcoded ID
        end else begin
            if (csr_wr_en) begin
                unique case (csr_addr)
                    MEM_CTRL_ADDR : mem_ctrl_reg <= csr_wr_data;
                    MEM_CFG_ADDR  : mem_cfg_reg  <= csr_wr_data;
                    default: /* Do nothing - read-only registers */;
                endcase
            end

            // Simulate status updates (for now, dummy logic)
            if (mem_ctrl_reg[0]) begin
                mem_status_reg[0] <= 1'b1; // busy flag
            end else begin
                mem_status_reg[0] <= 1'b0;
            end
          
           // Flag error on performing both read and write operation at the same instant
           if(csr_wr_en && csr_rd_en)
               mem_error_reg[0] <= 1;
        end
    end

    // Exposed signals to memory interface
    assign mem_start        = mem_ctrl_reg[0];
    assign mem_mode         = mem_ctrl_reg[4:1];
    assign mem_burst_length = mem_cfg_reg[7:0];
    assign mem_latency      = mem_cfg_reg[11:8];
    assign error_flag       = mem_error_reg[0];

endmodule

////////////////////////////////////////////////////////

interface top_if();
  
  logic clk;
  logic rst_n;
  logic csr_wr_en;
  logic csr_rd_en;
  logic [7:0] csr_addr;
  logic [31:0] csr_wr_data;
  logic [31:0] csr_rd_data;
  logic mem_start;
  logic [3:0] mem_mode;
  logic [7:0] mem_burst_length;
  logic [3:0] mem_latency;
  logic error_flag;
  
endinterface
