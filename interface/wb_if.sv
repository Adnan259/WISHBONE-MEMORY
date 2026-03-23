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

    // -------------------------------------------------------
    // Reset task
    // -------------------------------------------------------
    task automatic req_reset();
        cyc_i  <= '0;
        stb_i  <= '0;
        we_i   <= '0;
        addr_i <= '0;
        data_i <= '0;
        sel_i  <= '0;
    endtask

    // -------------------------------------------------------
    // Send write
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // Send read
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // Look write
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // Look read
    // -------------------------------------------------------
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

endinterface