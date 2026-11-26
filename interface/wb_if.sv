`timescale 1ns/1ps

interface wb_if #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_i
);

    logic                           cyc_i;
    logic                           stb_i;
    logic                           we_i;
    logic [ADDR_WIDTH-1:0]          addr_i;
    logic [DATA_WIDTH/8-1:0][7:0]   data_i;
    logic [DATA_WIDTH/8-1:0]        sel_i;
    logic                           ack_o;
    logic [DATA_WIDTH/8-1:0][7:0]   data_o;

    task automatic req_reset();
        cyc_i  <= '0;
        stb_i  <= '0;
        we_i   <= '0;
        addr_i <= '0;
        data_i <= '0;
        sel_i  <= '0;
    endtask

    task automatic send_write(
        input logic [ADDR_WIDTH-1:0]        addr,
        input logic [DATA_WIDTH/8-1:0][7:0] data,
        input logic [DATA_WIDTH/8-1:0]      sel
    );
        cyc_i  <= 1'b1;
        stb_i  <= 1'b1;
        we_i   <= 1'b1;
        addr_i <= addr;
        data_i <= data;
        sel_i  <= sel;
        do @(posedge clk_i);
        while (!ack_o);
        cyc_i  <= 1'b0;
        stb_i  <= 1'b0;
        we_i   <= 1'b0;
    endtask

    task automatic send_read(
        input logic [ADDR_WIDTH-1:0] addr
    );
        cyc_i  <= 1'b1;
        stb_i  <= 1'b1;
        we_i   <= 1'b0;
        addr_i <= addr;
        do @(posedge clk_i);
        while (!ack_o);
        cyc_i  <= 1'b0;
        stb_i  <= 1'b0;
    endtask

    task automatic look_write(
        output logic [ADDR_WIDTH-1:0]        addr,
        output logic [DATA_WIDTH/8-1:0][7:0] data,
        output logic [DATA_WIDTH/8-1:0]      sel,
        output logic                         ack
    );
        do @(posedge clk_i);
        while (!(cyc_i && stb_i && we_i && ack_o));
        addr = addr_i;
        data = data_i;
        sel  = sel_i;
        ack  = ack_o;
    endtask

    task automatic look_read(
        output logic [ADDR_WIDTH-1:0]        addr,
        output logic [DATA_WIDTH/8-1:0][7:0] rdata,
        output logic                         ack
    );
        do @(posedge clk_i);
        while (!(cyc_i && stb_i && !we_i && ack_o));
        @(posedge clk_i);
        addr  = addr_i;
        rdata = data_o;
        ack   = ack_o;
    endtask

    // -------------------------------------------------------
    // WISHBONE B.3 Protocol Assertions (SVA)
    // -------------------------------------------------------
    bit rst_seen = 1'b0;
    always_ff @(posedge clk_i) begin
        if (rst_i) rst_seen <= 1'b1;
    end

    property p_reset_clears_outputs;
        @(posedge clk_i) rst_i |=> (!ack_o && (data_o == '0));
    endproperty
    a_reset_clears_outputs: assert property (p_reset_clears_outputs)
        else $error("[SVA] ack_o or data_o not cleared after reset");

    property p_stb_within_cyc;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        stb_i |-> cyc_i;
    endproperty
    a_stb_within_cyc: assert property (p_stb_within_cyc)
        else $error("[SVA] WISHBONE Rule 3.25 violated: stb_i asserted without cyc_i");

    property p_req_implies_ack;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        (cyc_i && stb_i) |=> ack_o;
    endproperty
    a_req_implies_ack: assert property (p_req_implies_ack)
        else $error("[SVA] Missing ack_o on cycle following cyc_i && stb_i");

    property p_no_spurious_ack;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        (!cyc_i || !stb_i) |=> !ack_o;
    endproperty
    a_no_spurious_ack: assert property (p_no_spurious_ack)
        else $error("[SVA] Spurious ack_o without prior cyc_i && stb_i");

    property p_ctrl_stable_until_ack;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        (cyc_i && stb_i && !ack_o) |=> (cyc_i && stb_i && $stable(we_i) && $stable(addr_i));
    endproperty
    a_ctrl_stable_until_ack: assert property (p_ctrl_stable_until_ack)
        else $error("[SVA] Control or address changed before ack_o");

    property p_addr_word_aligned;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        (cyc_i && stb_i) |-> (addr_i[$clog2(DATA_WIDTH/8)-1:0] == '0);
    endproperty
    a_addr_word_aligned: assert property (p_addr_word_aligned)
        else $error("[SVA] Unaligned address 0x%0h during active transfer", addr_i);

    property p_no_x_on_active_req;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        (cyc_i && stb_i) |-> !$isunknown({we_i, addr_i, sel_i});
    endproperty
    a_no_x_on_active_req: assert property (p_no_x_on_active_req)
        else $error("[SVA] X/Z detected on active request signals");

    property p_no_x_on_rdata;
        @(posedge clk_i) disable iff (rst_i || !rst_seen)
        ack_o |-> !$isunknown(data_o);
    endproperty
    a_no_x_on_rdata: assert property (p_no_x_on_rdata)
        else $error("[SVA] X/Z detected on data_o when ack_o asserted");

endinterface
