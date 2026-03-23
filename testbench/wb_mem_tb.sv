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





/////////////////////////////////////////////////////////////////////////////////////////
// Module        : WISHBONE Memory Testbench (wb_mem_tb)
// Update at     : 19 Mar, 2026
// Description   : Testbench for wb_mem WISHBONE B.3 compliant memory slave.
//                 Covers reset, single write, single read, read-after-write,
//                 back-to-back writes, back-to-back reads, and partial writes.
// Author        : Adnan Sami Anirban
/////////////////////////////////////////////////////////////////////////////////////////

module wb_mem_tb;

  // -------------------------------------------------------
  // Parameters
  // -------------------------------------------------------
  parameter int ADDR_WIDTH = 16;
  parameter int DATA_WIDTH = 32;

  // -------------------------------------------------------
  // Clock and reset
  // -------------------------------------------------------
  logic clk;
  logic rst;

  // -------------------------------------------------------
  // WISHBONE signals
  // -------------------------------------------------------
  logic                           cyc;
  logic                           stb;
  logic                           we;
  logic [ADDR_WIDTH-1:0]          addr;
  logic [DATA_WIDTH/8-1:0][7:0]   data_in;
  logic [DATA_WIDTH/8-1:0]        sel;
  logic                           ack;
  logic [DATA_WIDTH/8-1:0][7:0]   data_out;

  // -------------------------------------------------------
  // Capture register for read data
  // -------------------------------------------------------
  logic [DATA_WIDTH/8-1:0][7:0]   read_data;

  // -------------------------------------------------------
  // Test counters
  // -------------------------------------------------------
  int pass_count;
  int fail_count;

  // -------------------------------------------------------
  // DUT instantiation
  // -------------------------------------------------------
  wb_mem #(
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)
  ) dut (
      .clk_i   (clk),
      .rst_i   (rst),
      .cyc_i   (cyc),
      .stb_i   (stb),
      .we_i    (we),
      .addr_i  (addr),
      .data_i  (data_in),
      .sel_i   (sel),
      .ack_o   (ack),
      .data_o  (data_out)
  );

  // -------------------------------------------------------
  // Clock generation - 100 MHz
  // -------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -------------------------------------------------------
  // Task: write_transaction
  // Performs a single WISHBONE write cycle
  // Waits for ACK per spec RULE 3.00
  // -------------------------------------------------------
  task automatic write_transaction(
      input logic [ADDR_WIDTH-1:0]        address,
      input logic [DATA_WIDTH/8-1:0][7:0] data,
      input logic [DATA_WIDTH/8-1:0]      strobe
  );
    @(posedge clk);
    cyc     <= 1;
    stb     <= 1;
    we      <= 1;
    addr    <= address;
    data_in <= data;
    sel     <= strobe;
    do @(posedge clk);                   // wait one cycle for signals to settle
    while (!ack);      // wait for ACK (registered, one cycle)
    //@(posedge clk);                   // deassert after ACK
    cyc <= 0;
    stb <= 0;
    we  <= 0;
  endtask

  // -------------------------------------------------------
  // Task: read_transaction
  // Performs a single WISHBONE read cycle
  // Captures data_out when ACK is asserted
  // -------------------------------------------------------
  task automatic read_transaction(
      input  logic [ADDR_WIDTH-1:0]        address,
      output logic [DATA_WIDTH/8-1:0][7:0] data
  );
    @(posedge clk);
    cyc  <= 1;
    stb  <= 1;
    we   <= 0;
    addr <= address;
    do @(posedge clk);                   // wait one cycle for signals to settle
    while (!ack);      // wait for ACK
    data = data_out;                  // sample data at ACK
    //@(posedge clk);                   // deassert after ACK
    cyc <= 0;
    stb <= 0;
  endtask

  // -------------------------------------------------------
  // Task: check_data
  // Compares actual vs expected and reports pass/fail
  // -------------------------------------------------------
  task automatic check_data(
      input logic [DATA_WIDTH/8-1:0][7:0] actual,
      input logic [DATA_WIDTH/8-1:0][7:0] expected,
      input string                         test_name
  );
    if (actual !== expected) begin
      $display("FAIL [%s]: got 0x%08h, expected 0x%08h", test_name, actual, expected);
      fail_count++;
    end else begin
      $display("PASS [%s]: data = 0x%08h", test_name, actual);
      pass_count++;
    end
  endtask

  // -------------------------------------------------------
  // Stimulus
  // -------------------------------------------------------
  initial begin
    // ----------------------------------------------------
    // Initialize all signals
    // ----------------------------------------------------
    pass_count = 0;
    fail_count = 0;
    rst     <= 1;
    cyc     <= 0;
    stb     <= 0;
    we      <= 0;
    addr    <= '0;
    data_in <= '0;
    sel     <= '0;

    // ----------------------------------------------------
    // TC1: Reset check
    // Verify ACK=0 and data_o=0 during reset
    // ----------------------------------------------------
    $display("\n--- TC1: Reset Check ---");
    @(posedge clk);
    @(posedge clk);
    if (ack === 1'b0)
      $display("PASS [TC1]: ACK=0 during reset");
    else
      $display("FAIL [TC1]: ACK should be 0 during reset");

    // Deassert reset cleanly at clock edge
    @(posedge clk);
    rst <= 0;
    @(posedge clk);

    // ----------------------------------------------------
    // TC2: Single write + single read (full word)
    // Write 0xAABBCCDD to address 0x0000, read back
    // ----------------------------------------------------
    $display("\n--- TC2: Single Write + Read (Full Word) ---");
    write_transaction(16'h0000, 32'hAABBCCDD, 4'b1111);
    read_transaction (16'h0000, read_data);
    check_data(read_data, 32'hAABBCCDD, "TC2");

    // ----------------------------------------------------
    // TC3: Read-after-write (different address)
    // Write to 0x0004, immediately read back
    // ----------------------------------------------------
    $display("\n--- TC3: Read After Write ---");
    write_transaction(16'h0004, 32'hDEADBEEF, 4'b1111);
    read_transaction (16'h0004, read_data);
    check_data(read_data, 32'hDEADBEEF, "TC3");

    // ----------------------------------------------------
    // TC4: Partial write - byte strobe 4'b0001
    // Write only byte 0 of address 0x0008
    // Pre-fill with 0xFFFFFFFF, then overwrite byte 0 only
    // Expected result: 0xFFFFFF11
    // ----------------------------------------------------
    $display("\n--- TC4: Partial Write (byte strobe 4'b0001) ---");
    write_transaction(16'h0008, 32'hFFFFFFFF, 4'b1111);  // pre-fill
    write_transaction(16'h0008, 32'h00000011, 4'b0001);  // overwrite byte 0
    read_transaction (16'h0008, read_data);
    check_data(read_data, 32'hFFFFFF11, "TC4");

    // ----------------------------------------------------
    // TC5: Back-to-back writes
    // Write to 3 consecutive word-aligned addresses
    // ----------------------------------------------------
    $display("\n--- TC5: Back-to-Back Writes ---");
    write_transaction(16'h0010, 32'h11111111, 4'b1111);
    write_transaction(16'h0014, 32'h22222222, 4'b1111);
    write_transaction(16'h0018, 32'h33333333, 4'b1111);

    // ----------------------------------------------------
    // TC6: Back-to-back reads
    // Read back the 3 addresses written in TC5
    // ----------------------------------------------------
    $display("\n--- TC6: Back-to-Back Reads ---");
    read_transaction(16'h0010, read_data);
    check_data(read_data, 32'h11111111, "TC6-word0");
    read_transaction(16'h0014, read_data);
    check_data(read_data, 32'h22222222, "TC6-word1");
    read_transaction(16'h0018, read_data);
    check_data(read_data, 32'h33333333, "TC6-word2");

    // ----------------------------------------------------
    // TC7: Reset during operation
    // Assert reset mid-simulation, check ACK goes low
    // ----------------------------------------------------
    $display("\n--- TC7: Reset During Operation ---");
    @(posedge clk);
    rst <= 1;
    @(posedge clk);
    @(posedge clk);
    if (ack === 1'b0)
      $display("PASS [TC7]: ACK=0 after reset reasserted");
    else
      $display("FAIL [TC7]: ACK should be 0 after reset");
    @(posedge clk);
    rst <= 0;
    @(posedge clk);

    // ----------------------------------------------------
    // Final report
    // ----------------------------------------------------
    $display("\n=============================");
    $display("RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("=============================\n");
    $finish;
  end

endmodule