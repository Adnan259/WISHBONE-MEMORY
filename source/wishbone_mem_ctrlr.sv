module wishbone_mem_ctrlr #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
) (
///////////////////////////////////////////////////////////////
// Global signals
///////////////////////////////////////////////////////////////
    input  logic                            clk_i,
    input  logic                            rst_i,
    
///////////////////////////////////////////////////////////////
// Wishbone signals
///////////////////////////////////////////////////////////////
    input  logic                            cyc_i,    
    input  logic                            stb_i,
    input  logic                            we_i,     
    input  logic [ADDR_WIDTH-1:0]           addr_i,                           
    input  logic [DATA_WIDTH/8-1:0][7:0]    data_i,                    
    input  logic [DATA_WIDTH/8-1:0]         sel_i,                           
    output logic                            ack_o,
    output logic [DATA_WIDTH/8-1:0][7:0]    data_o,

/////////////////////////////////////////////////////////////////
//Memory signals
/////////////////////////////////////////////////////////////////

    output  logic [  ADDR_WIDTH-1:0]        mem_addr_i,
    output  logic                           mem_we_i,
    output  logic [DATA_WIDTH/8-1:0][7:0]   mem_wdata_i,
    output  logic [DATA_WIDTH/8-1:0]        mem_wstrb_i,
    input   logic [DATA_WIDTH/8-1:0][7:0]   mem_rdata_o
);

// -------------------------------------------------------
// Combinational — memory control signals + read data
// -------------------------------------------------------
always_comb begin
    mem_addr_i  = addr_i;
    mem_we_i    = cyc_i & stb_i & we_i & ~ rst_i; // Ensure no writes during reset
    mem_wdata_i = data_i;
    mem_wstrb_i = sel_i;
end

// -------------------------------------------------------
// Registered — ACK + data_o with reset
// Per WISHBONE spec RULE 3.00
// -------------------------------------------------------
always_ff @(posedge clk_i) begin
    if (rst_i) begin
        ack_o  <= 1'b0;
        data_o <= '0;
    end else begin
        ack_o  <= cyc_i & stb_i;
        data_o <= mem_rdata_o;
    end
end
endmodule
        