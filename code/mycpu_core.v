`include "mycpu.h"
module mycpu_core
#(
    parameter TLBNUM = 16
)
(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn; 

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`RAW_BUS_WD      -1:0] raw_es_bus;
wire [`RAW_BUS_WD      -1:0] raw_ms_bus;
wire [`RAW_BUS_WD      -1:0] raw_ws_bus;
wire                         blk_es_load;
wire                         es_reflush_ds;
wire [`ES_REFLUSH_FS_WD -1:0]es_reflush_fs_bus;
wire                         ms_to_es_valid;
wire                         ws_to_es_valid;
wire                         has_int;
wire [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus;
wire                         pfs_to_fs_valid;
wire                         fs_allow_in;
wire                         fs_inst_unable;
wire                         blk_ms_load;
//tlb
wire [              18:0]    s0_vppn;
wire                         s0_va_bit12;
wire [               9:0]    s0_asid;
wire                         s0_found;
wire [$clog2(TLBNUM)-1:0]    s0_index;
wire [              19:0]    s0_ppn;
wire [               5:0]    s0_ps;
wire [               1:0]    s0_plv;
wire [               1:0]    s0_mat;
wire                         s0_d;
wire                         s0_v;
    // search port 1 (for load/store)
wire  [              18:0]   s1_vppn;
wire                         s1_va_bit12;
wire  [               9:0]   s1_asid;
wire                         s1_found;
wire [$clog2(TLBNUM)-1:0]    s1_index;
wire [              19:0]    s1_ppn;
wire [               5:0]    s1_ps;
wire [               1:0]    s1_plv;
wire [               1:0]    s1_mat;
wire                         s1_d;
wire                         s1_v;
    // invtlb opcode
wire                         invtlb_valid;
wire  [               4:0]   invtlb_op;
    // write port
wire                         we; //w(rite) e(nable)
wire  [$clog2(TLBNUM)-1:0]   w_index;
wire                         w_e;
wire  [               5:0]   w_ps;
wire  [              18:0]   w_vppn;
wire  [               9:0]   w_asid;
wire                         w_g;
wire  [              19:0]   w_ppn0;
wire  [               1:0]   w_plv0;
wire  [               1:0]   w_mat0;
wire                         w_d0;
wire                         w_v0;
wire  [              19:0]   w_ppn1;
wire  [               1:0]   w_plv1;
wire  [               1:0]   w_mat1;
wire                         w_d1;
wire                         w_v1;
    // read port
wire  [$clog2(TLBNUM)-1:0]   r_index;
wire                         r_e;
wire [              18:0]    r_vppn;
wire [               5:0]    r_ps;
wire [               9:0]    r_asid;
wire                         r_g;
wire [              19:0]    r_ppn0;
wire [               1:0]    r_plv0;
wire [               1:0]    r_mat0;
wire                         r_d0;
wire                         r_v0;
wire [              19:0]    r_ppn1;     
wire [               1:0]    r_plv1;
wire [               1:0]    r_mat1;
wire                         r_d1;
wire                         r_v1;
wire [`ES_TO_FS_BUS_WD - 1 :0] es_to_fs_bus;
//PRE_IF stage
/*
pre_if_stage pre_if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .fs_allowin     (fs_allowin     ),    
    .fs_inst_unable (fs_inst_unable ),
    //outputs
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    .pfs_to_fs_valid(pfs_to_fs_valid),    
    //brbus
    .br_bus         (br_bus         ),    
    .es_reflush_pfs_bus(es_reflush_fs_bus),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata)    
);
*/
// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    

    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    .es_to_fs_bus   (es_to_fs_bus   ),
    //reflush
    .es_reflush_fs_bus(es_reflush_fs_bus),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
     // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_fount       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //raw signals: from es, ms, ws
    .raw_es_bus     (raw_es_bus     ),
    .raw_ms_bus     (raw_ms_bus     ),
    .raw_ws_bus     (raw_ws_bus     ),
    //reflush
    .es_reflush_ds  (es_reflush_ds  ),
    //has int
    .has_int        (has_int        ),
    //block signals
    .blk_es_load    (blk_es_load    ),
    .blk_ms_load    (blk_ms_load    )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //from ms
    .ms_to_es_valid (ms_to_es_valid ),
    //from ws
    .ws_to_es_valid (ws_to_es_valid ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_req  (data_sram_req  ),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_size (data_sram_size ),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    //raw signals: to ds
    .raw_es_bus     (raw_es_bus     ),
    //reflush
    .es_reflush_fs_bus(es_reflush_fs_bus),
    .es_reflush_ds  (es_reflush_ds  ),
    //int
    .has_int        (has_int        ),
    //block signals
    .blk_es_load    (blk_es_load    ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_fount       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    // write port
    .we            (we             ), //w(rite) e(nable)
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           ),
    .es_to_fs_bus  (es_to_fs_bus   )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to es
    .ms_to_es_valid (ms_to_es_valid ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata),
    //raw signals: to ds
    .raw_ms_bus     (raw_ms_bus     ),
    .blk_ms_load    (blk_ms_load    )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to es
    .ws_to_es_valid (ws_to_es_valid ),
    //raw signals: to ds
    .raw_ws_bus     (raw_ws_bus     ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

//tlb
tlb tlb(
    .clk           (clk            ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_fount       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    // write port
    .we            (we             ), //w(rite) e(nable)
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);
endmodule
module vaddr_transfer(
    input  [31:0] va,
    input  [ 2:0] inst_op,//{load.store,if}
    output [31:0] pa,
    output [ 5:0] tlb_ex_bus,//{PME,PPE,PIS,PIL,PIF,TLBR}
    //tlb
    output [18:0] s_vppn,
    output        s_va_bit12,
    output [ 9:0] s_asid,
    input         s_found,
    input  [ 3:0] s_index,
    input  [19:0] s_ppn,
    input  [ 5:0] s_ps,
    input  [ 1:0] s_plv,
    input  [ 1:0] s_mat,
    input         s_d,
    input         s_v,
    //crmd
    input  [31:0] csr_asid,
    input  [31:0] csr_crmd,
    //dmw
    output dmw_hit,
    input  [31:0] csr_dmw0,
    input  [31:0] csr_dmw1
    
);
    parameter ps4k = 12;
    wire direct;
    wire mapping;
    //direct
    wire dmw_hit0;
    wire dmw_hit1;
    wire [31:0] dmw_pa0;
    wire [31:0] dmw_pa1;
    wire [31:0] tlb_pa;
    wire [31:0] tlb_pa4k;
    wire [31:0] tlb_pa4m;
    assign direct = csr_crmd[3] & ~csr_crmd[4];
    //direct
    assign dmw_hit0 = csr_dmw0[csr_crmd[1:0]] && (csr_dmw0[31:29]==va[31:29]);
    assign dmw_hit1 = csr_dmw1[csr_crmd[1:0]] && (csr_dmw1[31:29]==va[31:29]);
    assign dmw_pa0  = {csr_dmw0[27:25],va[28:0]};
    assign dmw_pa1  = {csr_dmw1[27:25],va[28:0]};
     //mapping
     assign s_vppn =  va[31:13];
     assign s_va_bit12 = va[12];
     assign s_asid =  csr_asid[9:0];
     assign tlb_ex_bus = {direct?1'b0:~dmw_hit & inst_op[1]&~s_d,
                          direct?1'b0:~dmw_hit &csr_crmd[1:0]>s_plv,
                          direct?1'b0:~dmw_hit &inst_op[1]&~s_v,
                          direct?1'b0:~dmw_hit &inst_op[2]&~s_v,
                          direct?1'b0:~dmw_hit &inst_op[0]&~s_v,
                          direct?1'b0:~dmw_hit &~s_found
                          };
     assign tlb_pa4k = {s_ppn[19:0],va[11:0]};
     assign tlb_pa4m = {s_ppn[19:10],va[21:0]};
     assign tlb_pa = (s_ps==ps4k)? tlb_pa4k:tlb_pa4m;
     assign dmw_hit = dmw_hit0 | dmw_hit1;
     assign pa = direct ? va:(dmw_hit0 ? dmw_pa0 : (dmw_hit1 ? dmw_pa1 : tlb_pa));
endmodule