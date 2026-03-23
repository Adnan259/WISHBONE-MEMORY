class wb_scoreboard;
    wb_cfg                 cfg     = new();
    mailbox #(wb_rsp_item) rsp_mbx = new();
    logic [7:0][7:0]       ref_mem [logic [15:0]];
    int                    total_pass = 0;
    int                    total_fail = 0;

    function void connect_mailbox(mailbox #(wb_rsp_item) rsp_mbx);
        this.rsp_mbx = rsp_mbx;
    endfunction

    function void configure(wb_cfg cfg);
        this.cfg = cfg;
    endfunction

    task automatic run();
        forever begin
            wb_rsp_item      rsp;
            logic [7:0][7:0] expected;
            logic [7:0][7:0] actual;
            bit              match;

            rsp_mbx.get(rsp);

            if (rsp.is_write) begin
                if (!ref_mem.exists(rsp.addr))
                    ref_mem[rsp.addr] = '0;    // initialize to 0 first
                for (int i = 0; i < cfg.DATA_WIDTH/8; i++) begin
                    if (rsp.sel[i])
                        ref_mem[rsp.addr][i] = rsp.data[i];
                end

            end else begin
                if (ref_mem.exists(rsp.addr)) begin
                    expected = ref_mem[rsp.addr];
                    actual   = rsp.rdata;
                    match    = 1;

                    for (int i = 0; i < cfg.DATA_WIDTH/8; i++) begin
                        if (actual[i] !== expected[i]) begin
                            match = 0;
                            break;
                        end
                    end

                    if (match) begin
                        $display("[PASS] addr=0x%04h expected=0x%08h actual=0x%08h",
                                  rsp.addr, expected, actual);
                        total_pass++;
                    end else begin
                        $display("[FAIL] addr=0x%04h expected=0x%08h actual=0x%08h",
                                  rsp.addr, expected, actual);
                        total_fail++;
                    end

                end else begin
                    $display("[WARN] addr=0x%04h never written — skipping",
                              rsp.addr);
                end
            end
        end
    endtask

    function void report();
        $display("\n================================");
        $display("        TEST SUMMARY            ");
        $display("================================");
        $display("  Total  : %0d", total_pass + total_fail);
        $display("  PASSED : %0d", total_pass);
        $display("  FAILED : %0d", total_fail);
        $display("================================\n");
    endfunction

endclass