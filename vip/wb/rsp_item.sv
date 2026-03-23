class wb_rsp_item extends wb_seq_item;
    logic            ack;
    logic [7:0][7:0] rdata;

    function new();
        super.new();
    endfunction
endclass