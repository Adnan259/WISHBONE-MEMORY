class wb_monitor #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
);
    virtual wb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(wb_rsp_item) rsp_mbx;

    function new();
        rsp_mbx = new();
    endfunction

    function void connect_interface(
        virtual wb_if #(ADDR_WIDTH, DATA_WIDTH) vif
    );
        this.vif = vif;
    endfunction

    function void connect_mailbox(mailbox #(wb_rsp_item) rsp_mbx);
        this.rsp_mbx = rsp_mbx;
    endfunction

    task automatic run();
        fork
            forever begin
                automatic wb_rsp_item                   item;
                automatic logic [ADDR_WIDTH-1:0]        addr;
                automatic logic [DATA_WIDTH/8-1:0][7:0] data;
                automatic logic [DATA_WIDTH/8-1:0]      sel;
                automatic logic                         ack;

                vif.look_write(addr, data, sel, ack);
                item          = new();
                item.is_write = 1;
                item.addr     = {'0, addr};
                item.data     = '0;
                item.data[DATA_WIDTH/8-1:0] = data;
                item.sel      = {'0, sel};
                item.ack      = ack;
                $display("[WRITE] addr=0x%04h data=0x%08h sel=%04b",
                          addr, data, sel);
                rsp_mbx.put(item);
            end

            forever begin
                automatic wb_rsp_item                   item;
                automatic logic [ADDR_WIDTH-1:0]        addr;
                automatic logic [DATA_WIDTH/8-1:0][7:0] rdata;
                automatic logic                         ack;

                vif.look_read(addr, rdata, ack);
                item          = new();
                item.is_write = 0;
                item.addr     = {'0, addr};
                item.rdata    = '0;
                item.rdata[DATA_WIDTH/8-1:0] = rdata;
                item.ack      = ack;
                $display("[READ ] addr=0x%04h rdata=0x%08h",
                          addr, rdata);
                rsp_mbx.put(item);
            end
        join_none
    endtask

    task automatic wait_for_idle(int num_cycles = 10);
        int count = 0;
        while (count < num_cycles) begin
            if (rsp_mbx.num() == 0) count++;
            else                    count = 0;
            @(posedge vif.clk_i);
        end
    endtask

endclass