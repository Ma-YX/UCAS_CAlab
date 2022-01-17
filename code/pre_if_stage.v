`include "mycpu.h"

module pre_if_stage (
    input                            clk              ,
    input                            reset            ,
    //from fs
    input                            fs_allowin       ,
    input                            fs_inst_unable   ,
    //to fs
    output [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus    ,
    output                           pfs_to_fs_valid  ,
    //br
    input [`BR_BUS_WD - 1        :0] br_bus           ,
    //reflush
    input [`ES_REFLUSH_FS_WD -1  :0] es_reflush_pfs_bus,
    //inst_sram
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata
);

    //control signals
    reg  pfs_valid;
    wire pfs_ready_go;
    
    //inst_sram
    reg        inst_sram_addr_ok_r;
    reg        inst_sram_data_ok_r;
    reg [31:0] inst_buff;

    //br
    wire br_stall;
    wire br_taken;
    wire br_taken_cancel;
    wire [31:0] br_target;
    assign {br_stall, br_taken, br_taken_cancel, br_target} = br_bus;
    reg        br_taken_r;
    reg [31:0] br_target_r;
    
    //pc
    reg  [31:0] pfs_pc;
    wire [31:0] next_pc;
    wire [31:0] seq_pc;

    //reflush
    wire        es_reflush_pfs;
    wire [31:0] ex_entry;
    assign {es_reflush_pfs, ex_entry} = es_reflush_pfs_bus;
    reg        es_reflush_pfs_r;
    reg [31:0] ex_entry_r;

    reg inst_cancel;

    //control signals
    assign pfs_ready_go = (inst_sram_addr_ok && inst_sram_req) || inst_sram_addr_ok_r && ~es_reflush_pfs;
    assign pfs_to_fs_valid = pfs_valid && pfs_ready_go;
    always @(posedge clk) begin
        if(reset  ) begin
            pfs_valid <= 1'b0;
        end
        else begin
            pfs_valid <= 1'b1;
        end
    end

    //to fs
    assign pfs_to_fs_bus = {inst_sram_data_ok && fs_inst_unable ? 1'b1 : inst_sram_data_ok_r,//64:64
                            inst_sram_data_ok && fs_inst_unable? inst_sram_rdata : inst_buff,          //63:32
                            next_pc              //31:0
                           };

    //inst_sram
    always @(posedge clk) begin
        if(reset) begin
            inst_sram_addr_ok_r <= 1'b0;
        end
        else if(inst_sram_addr_ok && inst_sram_req && !fs_allowin) begin
            inst_sram_addr_ok_r <= 1'b1;
        end
        else if(fs_allowin || es_reflush_pfs) begin
            inst_sram_addr_ok_r <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if(reset || fs_allowin || es_reflush_pfs) begin
            inst_sram_data_ok_r <= 1'b0;
        end
        else if(inst_sram_data_ok && fs_inst_unable && !inst_cancel) begin
            inst_sram_data_ok_r <= 1'b1;
        end

        if(reset || fs_allowin || es_reflush_pfs) begin
            inst_buff <= 32'b0;
        end
        else if(inst_sram_data_ok && fs_inst_unable && !inst_cancel) begin
            inst_buff <= inst_sram_rdata;
        end
    end

    assign inst_sram_req = pfs_valid && !inst_sram_addr_ok_r && !br_stall && fs_allowin;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr = next_pc;

    //inst_cancel
    always @(posedge clk ) begin
        if(reset) begin
            inst_cancel <= 1'b0;
        end
        else if(pfs_ready_go && (es_reflush_pfs || es_reflush_pfs_r || br_taken || br_taken_r)) begin
            inst_cancel <= 1'b1;
        end
        else if(inst_sram_data_ok) begin
            inst_cancel <= 1'b0;
        end
    end
    
    //br
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
        else if(es_reflush_pfs) begin
            es_reflush_pfs_r <= 1'b1;
            ex_entry_r <= ex_entry;
        end
    end
    
    //pc
    assign seq_pc = pfs_pc + 3'h4;
    assign next_pc = es_reflush_pfs_r ? ex_entry_r : es_reflush_pfs ? ex_entry : br_taken_r ? br_target_r : (br_taken && !br_stall) ? br_target : seq_pc;
    always @(posedge clk ) begin
        if(reset) begin
            pfs_pc <= 32'h1bfffffc;
        end
        else if(pfs_ready_go && fs_allowin) begin
            pfs_pc <= next_pc;
        end
    end

endmodule