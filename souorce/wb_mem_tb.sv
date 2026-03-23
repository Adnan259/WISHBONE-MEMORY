module wb_mem_tb;

  // Parameters
  parameter int ADDR_WIDTH = 16;
  parameter int DATA_WIDTH = 32;

  // Clock and reset
  logic clk;
  logic rst;

  // Wishbone signals
  logic cyc;
  logic stb;
  logic we;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH/8-1:0][7:0] data_in;
  logic [DATA_WIDTH/8-1:0] sel;
  logic ack;
  logic [DATA_WIDTH/8-1:0][7:0] data_out;

  // Instantiate the DUT
  wb_mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk_i(clk),
      .rst_i(rst),
      .cyc_i(cyc),
      .stb_i(stb),
      .we_i(we),
      .addr_i(addr),
      .data_i(data_in),
      .sel_i(sel),
      .ack_o(ack),
      .data_o(data_out)
  );

  logic [DATA_WIDTH/8-1:0][7:0] read_data;

  task automatic write_transaction(input logic [ADDR_WIDTH-1:0] address,
                                   input logic [DATA_WIDTH/8-1:0][7:0] data, 
                                   input logic [DATA_WIDTH/8-1:0] strobe);
    begin
      @(posedge clk);
      cyc <= 1;
      stb <= 1;
      we <= 1;
      addr <= address;
      data_in <= data;
      sel <= strobe;
      do @(posedge clk);
      while (!ack); // Wait for ACK
      cyc <= 0;
      stb <= 0;
      we <= 0;
    end
  endtask

  task automatic read_transaction(input logic [ADDR_WIDTH-1:0] address
                                  output logic [DATA_WIDTH/8-1:0][7:0] data);

    begin
      @(posedge clk);
        cyc <= 1;
        stb <= 1;
        we <= 0;                
        addr <= address;
        do @(posedge clk);
        while (!ack); // Wait for ACK
        data = data_out;
        cyc <= 0;
        stb <= 0;
    end
  endtask

  task check_read_data(input logic [DATA_WIDTH/8-1:0][7:0] expected_data,
                       input logic [DATA_WIDTH/8-1:0][7:0] actual_data);
    begin
      if (actual_data !== expected_data) begin
        $display("Test failed: Read data does not match expected data");
      end else begin
        $display("Test passed: Read data matches expected data");
      end
    end

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
  end

  initial begin 
    rst = 1;
    cyc = 0;
    stb = 0;
    we = 0;
    addr = 0;
    data_in = '0;
    sel = '0;
    #20 rst = 0; // Release reset after 20 ns
    // Test sequence
    
    // Write to address 0x0000
    write_transaction(16'h0000, 32'hAABBCCDD, 4'b1111);
    write_transaction(16'h0001, 32'h00112233, 4'b1111);
    write_transaction(16'h0001, 32'hAA_11_22_CC, 4'b1001);


    // Read back from address 0x0000
    read_transaction(16'h0000, read_data);
    check_read_data(32'hAABBCCDD, read_data);
    read_transaction(16'h0001, read_data);
    check_read_data(32'hAA_11_22_CC, read_data);
    // Check read data
  end
endmodule