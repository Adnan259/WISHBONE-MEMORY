class wb_seq_item;

    rand logic          is_write;
    rand logic [15:0]   addr;
    logic [7:0][7:0]    data;
    logic [7:0]         sel;
    wb_cfg              cfg;

    function void configure(wb_cfg cfg);
        this.cfg = cfg;
    endfunction

    constraint addr_c {
        addr < (2 ** cfg.ADDR_WIDTH);
        addr[1:0]   == 0; // Ensure address is aligned to data width
    }

    function new();
        cfg = new();
    endfunction

    function void post_randomize();
        if (is_write) begin
            foreach (data[i]) begin
                if (i < cfg.DATA_WIDTH / 8) begin
                    data[i] = $urandom;
                    sel[i]  = $urandom;
                end else begin
                    data[i] = '0;    // ← clear unused bytes
                    sel[i]  = '0;
                end
            end
        end
    endfunction

endclass