class wb_driver #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
);
    virtual wb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(wb_seq_item) seq_mbx;

    function new();
        seq_mbx = new(1);
    endfunction

    function void connect_interface(
        virtual wb_if #(ADDR_WIDTH, DATA_WIDTH) vif
    );
        this.vif = vif;
    endfunction

    function void connect_mailbox(mailbox #(wb_seq_item) seq_mbx);
        this.seq_mbx = seq_mbx;
    endfunction

    task automatic run();
        forever begin
            wb_seq_item item;
            seq_mbx.get(item);
            if (item.is_write)
                vif.send_write(
                    item.addr[ADDR_WIDTH-1:0],
                    item.data[DATA_WIDTH/8-1:0],
                    item.sel[DATA_WIDTH/8-1:0]
                );
            else
                vif.send_read(item.addr[ADDR_WIDTH-1:0]);
        end
    endtask

    task automatic reset();
        vif.req_reset();
    endtask

endclass