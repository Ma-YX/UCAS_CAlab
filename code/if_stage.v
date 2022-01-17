`include "mycpu.h"

module if_stage#(
    parameter TLBNUM = 16
)(
    input                            clk            ,
    input                            reset          ,
    //allwoin
    input                            ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD        - 1:0] br_bus         ,
    //to ds
    output                           fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD  - 1:0] fs_to_ds_bus   ,
    //from es
    input  [`ES_TO_FS_BUS_WD - 1 :0] es_to_fs_bus   ,
    //reflush
    input [`ES_REFLUSH_FS_WD  - 1:0] es_reflush_fs_bus,
    //inst_sram
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // search port 0 
    output [              18:0] s0_vppn,
    output                      s0_va_bit12,//
    output [               9:0] s0_asid,
    input                       s0_found,
    input  [$clog2(TLBNUM)-1:0] s0_index,
    input  [              19:0] s0_ppn,//
    input  [               5:0] s0_ps,//
    input  [               1:0] s0_plv,//
    input  [               1:0] s0_mat,//
    input                       s0_d,//
    input                       s0_v
);
//br 
wire         br_stall;
wire         br_taken;
wire         br_taken_cancel;
wire [ 31:0] br_target;
//tlb
wire [ 5:0] tlb_ex_bus;
// pre_if stage
reg inst_sram_addr_ok_r;
wire pfs_ready_go;
wire pfs_to_fs_valid;
wire [31:0] next_pc;
wire [31:0] seq_pc;
wire [31:0] fs_vaddr;
assign pfs_ready_go = (inst_sram_addr_ok && inst_sram_req) || inst_sram_addr_ok_r || (|tlb_ex_bus);
assign pfs_to_fs_valid = pfs_ready_go;
assign inst_sram_req =  fs_allowin &&~reset && ~|tlb_ex_bus;
assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_wdata = 32'b0;
//assign inst_sram_addr = next_pc;
reg         fs_valid;
wire        fs_ready_go;


assign {br_stall, br_taken, br_taken_cancel, br_target} = br_bus;


wire        es_reflush_fs;
wire [31:0] ex_entry;
assign {es_reflush_fs, ex_entry} = es_reflush_fs_bus;

wire [31:0] csr_asid_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
assign {csr_crmd_rvalue, csr_dmw0_rvalue, csr_dmw1_rvalue, csr_asid_rvalue} = es_to_fs_bus;

wire [31:0] fs_inst;
reg [31:0] fs_pc;
wire inst_adef;

assign fs_to_ds_bus = {
                       tlb_ex_bus,
                       inst_adef,
                       fs_inst ,
                       fs_pc   };

reg        fs_inst_valid;
reg [31:0] fs_inst_buff;

reg fs_inst_cancel;

// IF stage
assign fs_ready_go    =  fs_inst_valid || (fs_valid && inst_sram_data_ok) || (|tlb_ex_bus);
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~(br_taken&&~br_stall) && ~es_reflush_fs && ~fs_inst_cancel;
//error 6 br_taken
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= pfs_to_fs_valid;
    end
    /*
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end
    */
end

    always @(posedge clk) begin
        if(reset) begin
            inst_sram_addr_ok_r <= 1'b0;
        end
        else if(inst_sram_addr_ok && inst_sram_req && !fs_allowin) begin
            inst_sram_addr_ok_r <= 1'b1;
        end
        else if(fs_allowin) begin
            inst_sram_addr_ok_r <= 1'b0;
        end
    end

// ADEF
assign inst_adef = fs_valid & ((fs_pc[1:0] != 2'b0)||(next_pc[31] & (csr_crmd_rvalue[1:0]!=0)) & ~dmw_hit);

always @(posedge clk ) begin
    if(reset) begin
        fs_inst_valid <= 1'b0;
    end
    else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
        fs_inst_valid <= 1'b1;
    end
    else if (ds_allowin || es_reflush_fs ) begin
        fs_inst_valid <= 1'b0;
    end

    if(reset) begin
        fs_inst_buff <= 32'b0;
    end
    else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
        fs_inst_buff <= inst_sram_rdata;
    end
end


//inst_cancel
always @(posedge clk ) begin
    if(reset) begin
        fs_inst_cancel <= 1'b0;
    end
    else if(!fs_allowin && !fs_ready_go && ((es_reflush_fs) ||( br_taken && ~br_stall))) begin
        fs_inst_cancel <= 1'b1;
    end
    else if(inst_sram_data_ok) begin
        fs_inst_cancel <= 1'b0;
    end
end
    reg        br_taken_r;
    reg [31:0] br_target_r;
    //reflush
    reg        es_reflush_pfs_r;
    reg [31:0] ex_entry_r;
    always @(posedge clk) begin
        if(reset) begin
            br_taken_r <= 1'b0;
            br_target_r <= 32'b0;
        end
        else if(pfs_ready_go && fs_allowin)begin
            br_taken_r <= 1'b0;
            br_target_r <= 32'b0;
        end
        else if(br_taken && !br_stall) begin
            br_taken_r <= 1'b1;
            br_target_r <= br_target;
        end
    end
        //ex
    always @(posedge clk) begin
        if(reset) begin
            es_reflush_pfs_r <= 1'b0;
            ex_entry_r <= 32'b0;
        end
        else if(pfs_ready_go && fs_allowin)begin
            es_reflush_pfs_r <= 1'b0;
            ex_entry_r <= 32'b0;
        end
        else if(es_reflush_fs) begin
            es_reflush_pfs_r <= 1'b1;
            ex_entry_r <= ex_entry;
        end
    end

assign seq_pc=fs_pc+3'h4;
assign next_pc = es_reflush_pfs_r ? ex_entry_r : es_reflush_fs ? ex_entry : br_taken_r ? br_target_r : (br_taken && !br_stall) ? br_target : seq_pc;
always @(posedge clk ) begin
    if(reset) begin
        fs_pc <= 32'h1bfffffc;
    end
    else if(pfs_ready_go && fs_allowin) begin
        fs_pc <= next_pc;
    end
end
assign fs_inst = fs_inst_valid ? fs_inst_buff : inst_sram_rdata;
vaddr_transfer inst_transfer(
    .va        (next_pc),
    .inst_op   (3'b001),//{load.store,if}
    .pa        (inst_sram_addr),
    .tlb_ex_bus(tlb_ex_bus),//{PME,PPE,PIS,PIL,PIF,TLBR}
    //tlb
    .s_vppn    (s0_vppn),
    .s_va_bit12(s0_va_bit12),
    .s_asid    (s0_asid),
    .s_found   (s0_found),
    .s_index   (s0_index),
    .s_ppn     (s0_ppn),
    .s_ps      (s0_ps),
    .s_plv     (s0_plv),
    .s_mat     (s0_mat),
    .s_d       (s0_d),
    .s_v       (s0_v),
    //crmd
    .csr_asid  (csr_asid_rvalue),
    .csr_crmd  (csr_crmd_rvalue),
    //dmw
    .dmw_hit   (dmw_hit),
    .csr_dmw0  (csr_dmw0_rvalue),
    .csr_dmw1  (csr_dmw1_rvalue)
    
);
endmodule
