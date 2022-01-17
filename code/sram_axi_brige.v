`include "mycpu.h"
module sram_axi_bridge (
    input         aclk,
    input         aresetn,
    
    //AR read request
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,

    //R read response
    input  [ 3:0] rid,
    input  [31:0] rdata,
    input  [ 1:0] rresp,
    input         rlast,
    input         rvalid,
    output        rready,

    //AW write request
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,

    //W write data
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,

    //B write response
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready,

    //sram
    // inst sram interface
    input         inst_sram_req,
    input         inst_sram_wr,
    input  [ 1:0] inst_sram_size,
    input  [ 3:0] inst_sram_wstrb,
    input  [31:0] inst_sram_addr,
    input  [31:0] inst_sram_wdata,
    output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    output [31:0] inst_sram_rdata,
    // data sram interface
    input         data_sram_req,
    input         data_sram_wr,
    input  [ 1:0] data_sram_size,
    input  [ 3:0] data_sram_wstrb,
    input  [31:0] data_sram_addr,
    input  [31:0] data_sram_wdata,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    output [31:0] data_sram_rdata
);

/***********set parameters*************/
//parameters
    //id for read/write
parameter INST_ID = 4'h0;
parameter DATA_ID = 4'h1;

/***********define variables***********/
//AXI
    //AR read request
reg         axi_ar_busy;
reg [ 3:0]  axi_ar_id;
reg [31:0]  axi_ar_addr;
reg [ 2:0]  axi_ar_size;

    //R read response
wire        axi_r_data_ok;
wire        axi_r_inst_ok;
wire [31:0] axi_r_data;

    //AW write request
reg         axi_aw_busy;
reg [31:0]  axi_aw_addr;
reg [ 2:0]  axi_aw_size;
    //W write data
reg         axi_w_busy;
reg [31:0]  axi_w_data;
reg [ 3:0]  axi_w_strb;

    //B write response
wire        axi_b_ok;

//intermediate signals
    //read request
wire        read_req_data_valid;
wire        read_req_inst_valid;
wire        read_req_valid;
wire [ 3:0] read_req_id;
wire [31:0] read_req_addr;
wire [ 2:0] read_req_size;
wire        read_req_data_ok;
wire        read_req_inst_ok;

    //write request
wire        write_req_valid;
wire [31:0] write_req_addr;
wire [ 2:0] write_req_size;
wire [31:0] write_req_data;
wire [ 3:0] write_req_strb;
wire        write_req_ok;

//SRAM
    //inst request
wire        inst_read_valid;
    //inst response
wire        inst_read_ready;

    //data request
wire        data_read_valid;
wire        data_write_valid;
wire        data_related;
    //data response
wire        data_read_ready;
wire        data_write_ready;

/* 
In this version of sram_axi_bridge,
SRAM sends data to AXI through buffer;
AXI sends data to SRAM through buffer
*/
//BUFFER(FIFO) 
    //read response
        //inst
wire        read_resp_inst_wen;
wire        read_resp_inst_ren;
wire        read_resp_inst_empty;
wire        read_resp_inst_full;
wire [31:0] read_resp_inst_input;
wire [31:0] read_resp_inst_output;

        //data
wire        read_resp_data_wen;
wire        read_resp_data_ren;
wire        read_resp_data_empty;
wire        read_resp_data_full;
wire [31:0] read_resp_data_input;
wire [31:0] read_resp_data_output;


    //write response
wire        write_resp_data_wen;
wire        write_resp_data_ren;
wire        write_resp_data_empty;
wire        write_resp_data_full;

    //data request
wire        data_req_wen;
wire        data_req_ren;
wire        data_req_empty;
wire        data_req_full;
wire        data_req_related;
wire [32:0] data_req_input;
wire [32:0] data_req_output;
wire [31:0] data_req_check;

/*************assign vslues to variables************/
//AXI
    //AR read request
always @(posedge aclk ) begin
    if(!aresetn) begin
        axi_ar_busy <= 1'b0;
        axi_ar_id   <= 4'b0;
        axi_ar_addr <= 32'b0;
        axi_ar_size <= 3'b0;
    end
    else if(!axi_ar_busy && read_req_valid) begin
        axi_ar_busy <= 1'b1;
        axi_ar_id   <= read_req_id;
        axi_ar_addr <= read_req_addr;
        axi_ar_size <= read_req_size;
    end
    else if(axi_ar_busy && arvalid && arready) begin
        axi_ar_busy <= 1'b0;
        axi_ar_id   <= 4'b0;
        axi_ar_addr <= 32'b0;
        axi_ar_size <= 3'b0;
    end
end
assign arvalid = axi_ar_busy;
assign arid    = axi_ar_id;
assign araddr  = axi_ar_addr;
assign arsize  = axi_ar_size;
assign arlen   = 8'b0;
assign arburst = 2'b01;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

    //R read response
assign rready        = !read_resp_inst_full && !read_resp_data_full;
assign axi_r_data_ok = rvalid && rready && (rid == DATA_ID);
assign axi_r_inst_ok = rvalid && rready && (rid == INST_ID);
assign axi_r_data    = rdata;

    //AW write request && W write_data
always @(posedge aclk ) begin
    if(!aresetn) begin
        axi_aw_busy <= 1'b0;
        axi_aw_addr <= 32'b0;
        axi_aw_size <= 3'b0;
    end
    else if(!axi_aw_busy && !axi_w_busy && write_req_valid) begin
        axi_aw_busy <= 1'b1;
        axi_aw_addr <= write_req_addr;
        axi_aw_size <= write_req_size;
    end
    else if(axi_aw_busy && awvalid && awready) begin
        axi_aw_busy <= 1'b0;
        axi_aw_addr <= 32'b0;
        axi_aw_size <= 3'b0;
    end

    if(!aresetn) begin
        axi_w_busy <= 1'b0;
        axi_w_data <= 32'b0;
        axi_w_strb <= 4'b0;
    end
    else if(!axi_w_busy && !axi_aw_busy && write_req_valid) begin
        axi_w_busy <= 1'b1;
        axi_w_data <= write_req_data;
        axi_w_strb <= write_req_strb;
    end
    else if(axi_w_busy && wvalid && wready) begin
        axi_w_busy <= 1'b0;
        axi_w_data <= 32'b0;
        axi_w_strb <= 4'b0;
    end
end
assign awvalid = axi_aw_busy;
assign awaddr  = axi_aw_addr;
assign awsize  = axi_aw_size;
assign awid    = 4'b0001;
assign awlen   = 8'b0;
assign awbrust = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign wvalid  = axi_w_busy;
assign wdata   = axi_w_data;
assign wstrb   = axi_w_strb;
assign wid     = 4'b0001;
assign wlast   = 1'b1;


    //B write response
assign bready   = !write_resp_data_full;
assign axi_b_ok = bvalid && bready;

//intermediate signals
    //read request
assign read_req_data_valid = data_read_valid;
assign read_req_inst_valid = !data_read_valid && inst_read_valid;
        //sram to axi
assign read_req_valid      = data_read_valid || inst_read_valid;
assign read_req_id         = read_req_data_valid ? DATA_ID        : INST_ID;
assign read_req_addr       = read_req_data_valid ? data_sram_addr : inst_sram_addr;
assign read_req_size       = read_req_data_valid ? data_sram_size : inst_sram_size;
        //axi to sram
assign read_req_data_ok    = read_req_data_valid && !axi_ar_busy;
assign read_req_inst_ok    = read_req_inst_valid && !axi_ar_busy;

    //read response
        //inst
assign read_resp_inst_ren   = inst_read_ready;
assign read_resp_inst_wen   = axi_r_inst_ok;
assign read_resp_inst_input = axi_r_data;
        //data
assign read_resp_data_ren   = data_read_ready;
assign read_resp_data_wen   = axi_r_data_ok;
assign read_resp_data_input = axi_r_data;

    //write request && write data
        //sram to axi
assign write_req_valid = data_write_valid;
assign write_req_addr  = data_sram_addr;
assign write_req_size  = data_sram_size;
assign write_req_data  = data_sram_wdata;
assign write_req_strb  = data_sram_wstrb;
        //axi to sram
assign write_req_ok    = data_write_valid && !axi_aw_busy && !axi_w_busy;

    //write response
assign write_resp_data_ren = data_write_ready;
assign write_resp_data_wen = axi_b_ok;

//SRAM
    //inst request
assign inst_read_valid   = inst_sram_req && !inst_sram_wr;
assign inst_sram_addr_ok = read_req_inst_ok;

    //inst response
assign inst_read_ready   = 1'b1;
assign inst_sram_data_ok = !read_resp_inst_empty;
assign inst_sram_rdata   = read_resp_inst_output;

    //data request
assign data_related      = data_req_related;
assign data_read_valid   = data_sram_req && !data_sram_wr && !data_related;
assign data_write_valid  = data_sram_req && data_sram_wr && !data_related;
assign data_sram_addr_ok = read_req_data_ok || write_req_ok;

    //data response
assign data_sram_rdata   = read_resp_data_output;
assign data_read_ready   = !data_req_empty && !data_req_output[32];
assign data_write_ready  = !data_req_empty && data_req_output[32];
assign data_sram_data_ok = (data_read_ready  && !read_resp_data_empty) ||
                           (data_write_ready && !write_resp_data_empty);

    //data sram request address record
assign data_req_ren   = data_sram_data_ok;
assign data_req_wen   = data_sram_req && data_sram_addr_ok;
assign data_req_input = {data_sram_wr, data_sram_addr};

//buffer
    //read request
        //inst
fifo_buffer_r #(
    .DATA_WIDTH (32),
    .BUFF_DEPTH (5),
    .ADDR_WIDTH (3)
)read_inst_resp_buff(
    .clk         (aclk),
    .resetn      (aresetn),
    .wen         (read_resp_inst_wen),
    .ren         (read_resp_inst_ren),
    .empty       (read_resp_inst_empty),
    .full        (read_resp_inst_full),
    .input_data  (read_resp_inst_input),
    .output_data (read_resp_inst_output)
);
    //data
fifo_buffer_r #(
    .DATA_WIDTH (32),
    .BUFF_DEPTH (5),
    .ADDR_WIDTH (3)
)read_data_resp_buff(
    .clk         (aclk),
    .resetn      (aresetn),
    .wen         (read_resp_data_wen),
    .ren         (read_resp_data_ren),
    .empty       (read_resp_data_empty),
    .full        (read_resp_data_full),
    .input_data  (read_resp_data_input),
    .output_data (read_resp_data_output)
);

    //write request
fifo_buffer_w #(
    .BUFF_DEPTH (5),
    .ADDR_WIDTH (3)
)write_data_resp_buff(
    .clk    (aclk),
    .resetn (aresetn),
    .wen    (write_resp_data_wen),
    .ren    (write_resp_data_ren),
    .empty  (write_resp_data_empty),
    .full   (write_resp_data_full)
);

    //data sram request(address)
fifo_buffer_data #(
    .DATA_WIDTH (33),
    .BUFF_DEPTH (5),
    .ADDR_WIDTH (3),
    .RELA_WIDTH (32)
)data_req_buff(
    .clk         (aclk),
    .resetn      (aresetn),
    .wen         (data_req_wen),
    .ren         (data_req_ren),
    .empty       (data_req_empty),
    .full        (data_req_full),
    .input_data  (data_req_input), 
    .output_data (data_req_output),
    .related     (data_related), 
    .check_addr  (data_req_check)
);
endmodule