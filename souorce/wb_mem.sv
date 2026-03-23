module wb_mem #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
) (
    input  logic                            clk_i,
    input  logic                            rst_i,
    input  logic                            cyc_i,    
    input  logic                            stb_i,
    input  logic                            we_i,     
    input  logic [ADDR_WIDTH-1:0]           addr_i,                           
    input  logic [DATA_WIDTH/8-1:0][7:0]    data_i,                    
    input  logic [DATA_WIDTH/8-1:0]         sel_i,                           
    output logic                            ack_o,
    output logic [DATA_WIDTH/8-1:0][7:0]    data_o
);

  // Internal signals for memory interface
  logic [ADDR_WIDTH-1:0]                    mem_addr_i;
  logic                                     mem_we_i;
  logic [DATA_WIDTH/8-1:0][7:0]             mem_wdata_i;
  logic [DATA_WIDTH/8-1:0]                  mem_wstrb_i;
  logic [DATA_WIDTH/8-1:0][7:0]             mem_rdata_o;

  // Instantiate the Wishbone memory controller
  wishbone_mem_ctrlr #(
      .ADDR_WIDTH                           (ADDR_WIDTH),
      .DATA_WIDTH                           (DATA_WIDTH)
  ) ctrlr_inst (  
      .clk_i                                (clk_i),
      .rst_i                                (rst_i),  
      .cyc_i                                (cyc_i),
      .stb_i                                (stb_i),
      .we_i                                 (we_i),
      .addr_i                               (addr_i),
      .data_i                               (data_i),
      .sel_i                                (sel_i),
      .ack_o                                (ack_o),
      .data_o                               (data_o),
      .mem_addr_i                           (mem_addr_i),
      .mem_we_i                             (mem_we_i),
      .mem_wdata_i                          (mem_wdata_i),
      .mem_wstrb_i                          (mem_wstrb_i),
      .mem_rdata_o                          (mem_rdata_o)
  );

  // Instantiate the memory module
  mem #(
      .ADDR_WIDTH                           (ADDR_WIDTH),
      .DATA_WIDTH                           (DATA_WIDTH)
  ) mem_inst (    
      .clk_i                                (clk_i),
      .addr_i                               (mem_addr_i),
      .we_i                                 (mem_we_i),
      .wdata_i                              (mem_wdata_i),
      .wstrb_i                              (mem_wstrb_i),
      .rdata_o                              (mem_rdata_o)
  );


endmodule
