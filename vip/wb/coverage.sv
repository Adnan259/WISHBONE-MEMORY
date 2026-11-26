class wb_coverage;
    mailbox #(wb_rsp_item) cov_mbx;

    bit          cov_is_write;
    logic [15:0] cov_addr;
    logic [3:0]  cov_sel;
    bit [1:0]    cov_sel_cat;
    bit [1:0]    cov_op_trans;
    bit          cov_same_addr;
    bit          has_prev;
    bit          prev_is_write;
    logic [15:0] prev_addr;
    int          sample_cnt;

    covergroup wb_cg;
        option.per_instance = 1;

        cp_op: coverpoint cov_is_write {
            bins write = {1'b1};
            bins read  = {1'b0};
        }

        cp_addr_region: coverpoint cov_addr {
            bins zero_boundary = {16'h0000};
            bins low_range     = {[16'h0004 : 16'h3FFC]};
            bins mid_range     = {[16'h4000 : 16'hBFFC]};
            bins high_range    = {[16'hC000 : 16'hFFF8]};
            bins max_boundary  = {16'hFFFC};
        }

        cp_sel: coverpoint cov_sel iff (cov_is_write) {
            bins noop            = {4'b0000};
            bins single_byte[]   = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins half_word[]     = {4'b0011, 4'b1100};
            bins full_word       = {4'b1111};
            bins partial_other[] = {4'b0101, 4'b0110, 4'b0111, 4'b1001,
                                    4'b1010, 4'b1011, 4'b1101, 4'b1110};
        }

        cp_sel_cat: coverpoint cov_sel_cat iff (cov_is_write) {
            bins noop        = {2'd0};
            bins single_byte = {2'd1};
            bins partial     = {2'd2};
            bins full_word   = {2'd3};
        }

        cp_op_trans: coverpoint cov_op_trans iff (has_prev) {
            bins rd_to_rd = {2'b00};
            bins rd_to_wr = {2'b01};
            bins wr_to_rd = {2'b10};
            bins wr_to_wr = {2'b11};
        }

        cp_same_addr: coverpoint cov_same_addr iff (has_prev) {
            bins diff_addr = {1'b0};
            bins same_addr = {1'b1};
        }

        cx_op_addr:   cross cp_op, cp_addr_region;
        cx_addr_sel:  cross cp_addr_region, cp_sel_cat;
        cx_trans_haz: cross cp_op_trans, cp_same_addr;
    endgroup

    function new();
        cov_mbx    = new();
        wb_cg      = new();
        has_prev   = 1'b0;
        sample_cnt = 0;
    endfunction

    function void connect_mailbox(mailbox #(wb_rsp_item) cov_mbx);
        this.cov_mbx = cov_mbx;
    endfunction

    function void sample_item(wb_rsp_item rsp);
        cov_is_write = rsp.is_write;
        cov_addr     = rsp.addr;
        cov_sel      = rsp.sel[3:0];

        case (cov_sel)
            4'b0000:                            cov_sel_cat = 2'd0;
            4'b0001, 4'b0010, 4'b0100, 4'b1000: cov_sel_cat = 2'd1;
            4'b1111:                            cov_sel_cat = 2'd3;
            default:                            cov_sel_cat = 2'd2;
        endcase

        if (has_prev) begin
            cov_op_trans  = {prev_is_write, cov_is_write};
            cov_same_addr = (cov_addr == prev_addr);
        end

        wb_cg.sample();
        sample_cnt++;

        prev_is_write = cov_is_write;
        prev_addr     = cov_addr;
        has_prev      = 1'b1;
    endfunction

    task automatic run();
        forever begin
            wb_rsp_item rsp;
            cov_mbx.get(rsp);
            sample_item(rsp);
        end
    endtask

    function void report();
        $display("\n==========================================");
        $display("       FUNCTIONAL COVERAGE SUMMARY        ");
        $display("==========================================");
        $display("  Samples Collected : %0d",      sample_cnt);
        $display("  cp_op             : %6.2f %%", wb_cg.cp_op.get_inst_coverage());
        $display("  cp_addr_region    : %6.2f %%", wb_cg.cp_addr_region.get_inst_coverage());
        $display("  cp_sel (16 bins)  : %6.2f %%", wb_cg.cp_sel.get_inst_coverage());
        $display("  cp_sel_cat        : %6.2f %%", wb_cg.cp_sel_cat.get_inst_coverage());
        $display("  cp_op_trans       : %6.2f %%", wb_cg.cp_op_trans.get_inst_coverage());
        $display("  cp_same_addr      : %6.2f %%", wb_cg.cp_same_addr.get_inst_coverage());
        $display("  cx_op_addr        : %6.2f %%", wb_cg.cx_op_addr.get_inst_coverage());
        $display("  cx_addr_sel       : %6.2f %%", wb_cg.cx_addr_sel.get_inst_coverage());
        $display("  cx_trans_haz      : %6.2f %%", wb_cg.cx_trans_haz.get_inst_coverage());
        $display("------------------------------------------");
        $display("  TOTAL COVERAGE    : %6.2f %%", wb_cg.get_inst_coverage());
        $display("==========================================\n");
    endfunction

endclass
