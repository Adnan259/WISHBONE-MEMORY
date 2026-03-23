`timescale 1ns/1ps
`include "vip/wb/wb.svh"

module wb_vip_tb;

    initial $display("=== TEST STARTED ===");
    final   $display("=== TEST ENDED ===");

    import wb_vip_pkg::*;

    // -------------------------------------------------------
    // Parameters
    // -------------------------------------------------------
    localparam int ADDR_WIDTH = 16;
    localparam int DATA_WIDTH = 32;

    // Boundary addresses (addr[1:0] must always be 0 — word aligned)
    localparam logic [15:0] ADDR_ZERO = 16'h0000;
    localparam logic [15:0] ADDR_MAX  = 16'hFFFC;
    localparam logic [15:0] ADDR_MID  = 16'h8000;

    // -------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------
    logic clk_i;
    logic rst_i;

    // -------------------------------------------------------
    // Interface
    // -------------------------------------------------------
    wb_if #(ADDR_WIDTH, DATA_WIDTH) intf (
        .clk_i(clk_i),
        .rst_i(rst_i)
    );

    // -------------------------------------------------------
    // DUT
    // -------------------------------------------------------
    wb_mem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .cyc_i  (intf.cyc_i),
        .stb_i  (intf.stb_i),
        .we_i   (intf.we_i),
        .addr_i (intf.addr_i),
        .data_i (intf.data_i),
        .sel_i  (intf.sel_i),
        .ack_o  (intf.ack_o),
        .data_o (intf.data_o)
    );

    // -------------------------------------------------------
    // VIP components
    // -------------------------------------------------------
    wb_driver  #(ADDR_WIDTH, DATA_WIDTH) dvr;
    wb_monitor #(ADDR_WIDTH, DATA_WIDTH) mon;
    wb_scoreboard                        scb;
    mailbox #(wb_rsp_item)               rsp_mbx;

    // -------------------------------------------------------
    // Tasks
    // -------------------------------------------------------
    task automatic start_clock();
        fork
            forever begin
                clk_i <= 1; #5ns;
                clk_i <= 0; #5ns;
            end
        join_none
        @(posedge clk_i);
    endtask

    task automatic apply_reset();
        rst_i <= 1;
        dvr.reset();
        repeat(3) @(posedge clk_i);
        rst_i <= 0;
        @(posedge clk_i);
    endtask

    // Normal write or read — data is fully randomized
    task automatic do_tx(
        input bit           is_write,
        input logic [15:0]  addr
    );
        automatic wb_seq_item item = new();
        item.cfg.ADDR_WIDTH = ADDR_WIDTH;
        item.cfg.DATA_WIDTH = DATA_WIDTH;
        void'(item.randomize() with {
            is_write == local::is_write;
            addr     == local::addr;
        });
        dvr.seq_mbx.put(item);
        repeat(20) @(posedge clk_i);
    endtask

    // Write with a SPECIFIC sel (byte enable) value
    task automatic do_tx_sel(
        input logic [15:0]  addr,
        input logic [3:0]   sel
    );
        automatic wb_seq_item item = new();
        item.cfg.ADDR_WIDTH = ADDR_WIDTH;
        item.cfg.DATA_WIDTH = DATA_WIDTH;
        void'(item.randomize() with {
            is_write == 1;
            addr     == local::addr;
        });
        item.sel[3:0] = sel;  // override sel with the exact value we want
        dvr.seq_mbx.put(item);
        repeat(20) @(posedge clk_i);
    endtask

    // -------------------------------------------------------
    // Main
    // -------------------------------------------------------
    initial begin

        dvr     = new();
        mon     = new();
        scb     = new();
        rsp_mbx = new();

        dvr.connect_interface(intf);
        mon.connect_interface(intf);
        mon.connect_mailbox(rsp_mbx);
        scb.connect_mailbox(rsp_mbx);

        clk_i = 0;
        rst_i = 0;

        start_clock();
        apply_reset();

        fork
            dvr.run();
            mon.run();
            scb.run();
        join_none

        repeat(5) @(posedge clk_i);

        // ====================================================
        // TC1 — Basic write then read
        // What it tests : most fundamental operation.
        //                 Write random data, read it back.
        //                 Scoreboard checks they match.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC1: Basic write then read back ---");
        do_tx(1, 16'h0000);
        do_tx(0, 16'h0000);

        // ====================================================
        // TC2 — Different address write + read
        // What it tests : address decoding is correct.
        //                 Data written to 0x0004 should
        //                 only come back from 0x0004.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC2: Different address 0x0004 ---");
        do_tx(1, 16'h0004);
        do_tx(0, 16'h0004);

        // ====================================================
        // TC3 — Back-to-back writes, then reads
        // What it tests : writing 3 consecutive addresses,
        //                 then reading all 3 back. Checks that
        //                 no write corrupts its neighbours.
        // Expected      : 3x PASS
        // ====================================================
        $display("\n--- TC3: Back-to-back writes then reads ---");
        do_tx(1, 16'h0008);
        do_tx(1, 16'h000C);
        do_tx(1, 16'h0010);
        do_tx(0, 16'h0008);
        do_tx(0, 16'h000C);
        do_tx(0, 16'h0010);

        // ====================================================
        // TC4 — Overwrite same address twice
        // What it tests : writing twice to same address.
        //                 Only the SECOND write's data
        //                 should be seen on read.
        // Expected      : PASS (second written value)
        // ====================================================
        $display("\n--- TC4: Overwrite same address ---");
        do_tx(1, 16'h0014);   // first write
        do_tx(1, 16'h0014);   // second write — this one wins
        do_tx(0, 16'h0014);   // must match second write

        // ====================================================
        // TC5 — Boundary: lowest address 0x0000
        // What it tests : bottom of address space.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC5: Lowest address 0x0000 ---");
        do_tx(1, ADDR_ZERO);
        do_tx(0, ADDR_ZERO);

        // ====================================================
        // TC6 — Boundary: highest address 0xFFFC
        // What it tests : top of address space.
        //                 addr[1:0] must be 0 for alignment,
        //                 so 0xFFFC is the highest valid word.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC6: Highest address 0xFFFC ---");
        do_tx(1, ADDR_MAX);
        do_tx(0, ADDR_MAX);

        // ====================================================
        // TC7 — Boundary: middle address 0x8000
        // What it tests : mid-range address decode.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC7: Middle address 0x8000 ---");
        do_tx(1, ADDR_MID);
        do_tx(0, ADDR_MID);

        // ====================================================
        // TC8 — Byte enable: byte 0 only (sel = 4'b0001)
        // What it tests : only the lowest byte (data[7:0])
        //                 is written. Other 3 bytes keep
        //                 their old values from first write.
        // Expected      : PASS (scoreboard tracks sel)
        // ====================================================
        $display("\n--- TC8: Byte enable sel=0001 (byte 0 only) ---");
        do_tx(1,         16'h0020);      // write all 4 bytes first
        do_tx_sel(       16'h0020, 4'b0001); // update only byte 0
        do_tx(0,         16'h0020);      // read back full word

        // ====================================================
        // TC9 — Byte enable: byte 3 only (sel = 4'b1000)
        // What it tests : only the highest byte (data[31:24])
        //                 is written. Other 3 bytes unchanged.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC9: Byte enable sel=1000 (byte 3 only) ---");
        do_tx(1,         16'h0024);
        do_tx_sel(       16'h0024, 4'b1000);
        do_tx(0,         16'h0024);

        // ====================================================
        // TC10 — Byte enable: upper half (sel = 4'b1100)
        // What it tests : write bytes 2 and 3 only.
        //                 Bytes 0 and 1 unchanged.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC10: Byte enable sel=1100 (upper 2 bytes) ---");
        do_tx(1,         16'h0028);
        do_tx_sel(       16'h0028, 4'b1100);
        do_tx(0,         16'h0028);

        // ====================================================
        // TC11 — Read from never-written address
        // What it tests : memory initializes to 0x00000000.
        //                 Reading a fresh address should give 0.
        //                 Scoreboard prints WARN (correct behavior
        //                 — it was never written in THIS test run).
        // Expected      : WARN (not a failure)
        // ====================================================
        $display("\n--- TC11: Read never-written address 0x0100 ---");
        do_tx(0, 16'h0100);

        // ====================================================
        // TC12 — Stress: 10 spread-out addresses
        // What it tests : write to 10 different addresses
        //                 spread across the full memory range,
        //                 then read all back. Catches aliasing
        //                 bugs (two addresses mapping to same
        //                 physical location).
        // Expected      : 10x PASS
        // ====================================================
        $display("\n--- TC12: Stress — 10 spread addresses ---");
        begin
            automatic logic [15:0] addrs[10];
            addrs[0] = 16'h0040; addrs[1] = 16'h0080;
            addrs[2] = 16'h0100; addrs[3] = 16'h0200;
            addrs[4] = 16'h0400; addrs[5] = 16'h0800;
            addrs[6] = 16'h1000; addrs[7] = 16'h2000;
            addrs[8] = 16'h4000; addrs[9] = 16'h7FFC;
            foreach (addrs[i]) do_tx(1, addrs[i]);  // write all
            foreach (addrs[i]) do_tx(0, addrs[i]);  // read all
        end

        // ====================================================
        // TC13 — Reset during operation
        // What it tests : apply reset, then verify the DUT
        //                 works correctly after coming out
        //                 of reset. ack_o and data_o must
        //                 clear during reset.
        // Expected      : PASS after reset
        // ====================================================
        $display("\n--- TC13: Reset during operation ---");
        do_tx(1, 16'h0030);    // write before reset
        apply_reset();          // reset the DUT
        repeat(5) @(posedge clk_i);
        do_tx(1, 16'h0034);    // fresh write after reset
        do_tx(0, 16'h0034);    // read back — must match

        // ====================================================
        // TC14 — Repeated write-read to same address
        // What it tests : 2 full write-read cycles to the
        //                 same address. Data updates correctly
        //                 each time.
        // Expected      : 2x PASS
        // ====================================================
        $display("\n--- TC14: Repeated write-read same address ---");
        do_tx(1, 16'h0038);
        do_tx(0, 16'h0038);
        do_tx(1, 16'h0038);
        do_tx(0, 16'h0038);

        // ====================================================
        // TC15 — Full word write (sel = 4'b1111) explicit
        // What it tests : all byte enables active at once —
        //                 full 32-bit word written and read.
        // Expected      : PASS
        // ====================================================
        $display("\n--- TC15: Full word write sel=1111 ---");
        do_tx_sel(16'h003C, 4'b1111);
        do_tx(0,  16'h003C);

        // wait for all outstanding transactions to complete
        mon.wait_for_idle();

        scb.report();
        $finish;
    end

endmodule