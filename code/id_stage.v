`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //raw signals: from es, ms, ws
    input  [`RAW_BUS_WD      -1:0] raw_es_bus    ,
    input  [`RAW_BUS_WD      -1:0] raw_ms_bus    ,
    input  [`RAW_BUS_WD      -1:0] raw_ws_bus    ,
    //reflush
    input                          es_reflush_ds ,
    //int 
    input                          has_int       ,
    //block signals
    input                          blk_es_load   ,
    input                          blk_ms_load
);

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        inst_adef;
wire [ 5:0] fs_tlb_ex_bus;
assign {fs_tlb_ex_bus,
        inst_adef,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire        br_taken_cancel;
wire [31:0] br_target;

wire [11:0] alu_op;
//
wire [2:0]  mul_op;
wire [2:0]  div_op;
wire [1:0]  store_op;
wire [2:0]  load_op;
wire [2:0]  clk_op;

wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;



wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

//kernel mode
wire csr_we;
wire csr_re;
wire [31:0]csr_wmask;
// tlb
wire [ 4:0]tlb_bus;


wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
wire [ 4:0] op;
//kernel_mode
wire [13:0] csr_num;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
  
wire        inst_add_w; 
wire        inst_sub_w;  
wire        inst_slt;    
wire        inst_sltu;   
wire        inst_nor;    
wire        inst_and;    
wire        inst_or;     
wire        inst_xor;    
wire        inst_slli_w;  
wire        inst_srli_w;  
wire        inst_srai_w;  
wire        inst_addi_w; 
wire        inst_ld_w;  
wire        inst_st_w;   
wire        inst_jirl;   
wire        inst_b;      
wire        inst_bl;     
wire        inst_beq;    
wire        inst_bne;    
wire        inst_lu12i_w;
// user mode
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;

wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;

//kernel mode
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
wire        inst_ine;
wire [16:0] ex_cause_bus;
// clock
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;
//TLB
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
wire        inv_ex;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;  
wire        src2_is_4;
// user mode
wire        need_ui12;
wire        need_si16u;


wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_ltu_rd;
wire        rj_ge_rd;
wire        rj_geu_rd;
/*
wire        rd_valid;
wire        rk_valid;
wire        rj_valid;
wire        rf_raddr1_valid;
wire        rf_raddr2_valid;
*/
wire        raw_es_valid;
wire        raw_ms_valid;
wire        raw_ws_valid;
wire [ 4:0] raw_es_addr;
wire [ 4:0] raw_ms_addr;
wire [ 4:0] raw_ws_addr;
wire [31:0] raw_es_data;
wire [31:0] raw_ms_data;
wire [31:0] raw_ws_data;
/*
wire        raw_es_blk;
wire        raw_ms_blk;
wire        raw_ws_blk;
*/

assign {raw_es_valid, raw_es_addr, raw_es_data} = raw_es_bus;
assign {raw_ms_valid, raw_ms_addr, raw_ms_data} = raw_ms_bus;
assign {raw_ws_valid, raw_ws_addr, raw_ws_data} = raw_ws_bus;
/*
assign rj_valid = inst_add_w | inst_addi_w | inst_sub_w | inst_ld_w | inst_st_w | inst_bne | inst_beq | inst_jirl |
                  inst_slt | inst_sltu | inst_slli_w | inst_srli_w | inst_srai_w | inst_and | inst_or | inst_nor | inst_xor;
assign rk_valid = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | inst_xor;
assign rd_valid = inst_bne | inst_beq;

assign rf_raddr1_valid = rj_valid;
assign rf_raddr2_valid = rd_valid | rj_valid;

assign raw_es_blk = raw_es_valid && 
                    ((rf_raddr1_valid && rf_raddr1 == raw_es_addr) || (rf_raddr2_valid && (rf_raddr2 == raw_es_addr)));
assign raw_ms_blk = raw_ms_valid && 
                    ((rf_raddr1_valid && rf_raddr1 == raw_ms_addr) || (rf_raddr2_valid && (rf_raddr2 == raw_ms_addr)));
assign raw_ws_blk = raw_ws_valid && 
                    ((rf_raddr1_valid && rf_raddr1 == raw_ws_addr) || (rf_raddr2_valid && (rf_raddr2 == raw_ws_addr)));
*/
assign br_bus       = {br_stall,br_taken, br_taken_cancel, br_target};
assign tlb_bus      = {inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill,inst_invtlb};

assign ds_to_es_bus = {tlb_bus     ,  //239:235
                       op          ,  //234:230
                       clk_op      ,  //229:227
                       inst_ertn   ,  //226:226
                       ex_cause_bus,  //225:209
                       csr_num     ,  //208:195
                       csr_we      ,  //194:194
                       csr_re      ,  //193:193
                       csr_wmask   ,  //192:161
                       store_op    ,  //160:159
                       load_op     ,  //158:156
                       mul_op      ,  //155:153
                       div_op      ,  //152:150
                       alu_op      ,  //149:138
                       res_from_mem,  //137:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };

/*assign ds_ready_go    = ~(raw_es_blk | raw_ms_blk | raw_ws_blk);*/
assign ds_ready_go    = !(((blk_ms_load &&raw_ms_valid)  && (raw_ms_addr == rf_raddr1 || raw_ms_addr == rf_raddr2))
                        || (( blk_es_load && raw_es_valid) && (rf_raddr1 == raw_es_addr || rf_raddr2 == raw_es_addr)));
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go && ~es_reflush_ds;
always @(posedge clk) begin
    if(reset) begin
        ds_valid <= 1'b0;
    end
    else if(br_taken_cancel|| es_reflush_ds) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

always @(posedge clk) begin 
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];
assign op   = ds_inst[ 4: 0];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

//kernel mode
assign csr_num = inst_ertn ? 14'h6:ds_inst[23:10];//ertn : csr_era
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
//usr model
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i
                   = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b]; 
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0]; 
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];   
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
//kernel mode
assign inst_csrrd  = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & ~|rj;//rj =0
assign inst_csrwr  = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (rj == 5'h01);//rj =0
assign inst_csrxchg= op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (rj != 5'h01) & |rj;
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01110) & ~|rj & ~|rd;
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16] ;
assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14] ;
assign inst_ine = ~(inst_add_w   | inst_sub_w   | inst_slt     | inst_sltu   | inst_nor       | inst_and    
                  | inst_or      | inst_xor     | inst_slli_w  | inst_srli_w | inst_srai_w    | inst_addi_w 
                  | inst_ld_w    | inst_st_w    | inst_jirl    | inst_b      | inst_bl        | inst_beq
                  | inst_bne     | inst_lu12i_w | inst_slti    | inst_sltui  | inst_andi      | inst_ori
                  | inst_xori    | inst_sll_w   | inst_srl_w   | inst_sra_w  | inst_pcaddu12i | inst_mul_w
                  | inst_mulh_w  | inst_mulh_wu | inst_div_w   | inst_mod_w  | inst_div_wu    | inst_mod_wu
                  | inst_blt     | inst_bge     | inst_bltu    | inst_bgeu   | inst_ld_b      | inst_ld_h
                  | inst_ld_bu   | inst_ld_hu   | inst_st_b    | inst_st_h   | inst_csrrd     | inst_csrwr
                  | inst_csrxchg | inst_ertn    | inst_syscall | inst_break  | inst_rdcntvl_w | inst_rdcntvh_w 
                  | inst_rdcntid | inst_tlbsrch | inst_tlbrd   | inst_tlbwr  | inst_tlbfill   | inst_invtlb
                  ); 
 
 //clock
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'b11000) & ~|rj;
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'b11001) & ~|rj;
assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'b11000) & ~|rd; 

//tlb
assign inst_tlbsrch   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01010) & ~|rj & ~|rd;
assign inst_tlbrd     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01011) & ~|rj & ~|rd;
assign inst_tlbwr     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01100) & ~|rj & ~|rd;
assign inst_tlbfill   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01101) & ~|rj & ~|rd;
assign inst_invtlb    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13] ;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h
                    | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

//user model 
assign mul_op[ 0] = inst_mulh_w | inst_mulh_wu;
assign mul_op[ 1] = inst_mul_w  | inst_mulh_w;
assign mul_op[ 2] = inst_mul_w  | inst_mulh_w | inst_mulh_wu;

assign div_op[ 0] = inst_div_w  | inst_div_wu;
assign div_op[ 1] = inst_div_w  | inst_mod_w;
assign div_op[ 2] = inst_div_w  | inst_div_wu | inst_mod_w | inst_mod_wu;


assign load_op    =  {inst_ld_w , inst_ld_bu | inst_ld_hu , ~(inst_ld_b|inst_ld_bu) & (inst_ld_h|inst_ld_hu)};//000 b 010 bu 001 h 011 hu 100 w
assign store_op   =  {inst_st_w | inst_st_b , inst_st_h | inst_st_b};//11 b 01 h 10 w
assign clk_op     =  {inst_rdcntid , inst_rdcntvh_w | inst_rdcntvl_w , inst_rdcntvl_w};// 100 read tid 010 read counter high 011 read counter low

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h | inst_slti | inst_sltui;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge|inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;

assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


assign ds_imm = src2_is_4 ? 32'h4                      :
		need_si20 ? {i20,12'b0} :  //i20[16:5]==i12[11:0]
        need_ui5 || need_si12 ? {{20{i12[11]}}, i12[11:0]} :
                                {20'b0, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : //si26
                //si16u
                             {{14{i16[15]}}, i16[15:0], 2'b0} ; //si16

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h | inst_blt | inst_bltu | inst_bgeu | inst_bge | inst_csrwr | inst_csrxchg; //kernel mode

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w | 
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_b   |
                       inst_st_h   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i;


assign res_from_mem  = inst_ld_w| inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu ;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_st_b & ~inst_st_h & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu
                      &~inst_ine & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill &~inst_invtlb;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : inst_rdcntid? rj : rd;


//kernel_mode
//csr
assign csr_we       = inst_csrwr | inst_csrxchg;
assign csr_re       = inst_csrrd | inst_csrxchg;
assign csr_wmask    = inst_csrxchg ? rj_value : {32{1'b1}};

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );


assign rj_value  = (raw_es_valid && (raw_es_addr == rf_raddr1) && (|raw_es_addr)) ? raw_es_data :
                   (raw_ms_valid && (raw_ms_addr == rf_raddr1) && (|raw_ms_addr)) ? raw_ms_data :
                   (raw_ws_valid && (raw_ws_addr == rf_raddr1) && (|raw_ws_addr)) ? raw_ws_data :
                   rf_rdata1;
assign rkd_value = (raw_es_valid && (raw_es_addr == rf_raddr2) && (|raw_es_addr)) ? raw_es_data :
                   (raw_ms_valid && (raw_ms_addr == rf_raddr2) && (|raw_ms_addr)) ? raw_ms_data :
                   (raw_ws_valid && (raw_ws_addr == rf_raddr2) && (|raw_ws_addr)) ? raw_ws_data :
                   rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
//user mode
assign rj_lt_rd = ($signed(rj_value) <  $signed(rkd_value));
assign rj_ltu_rd = (rj_value <  rkd_value);
assign rj_ge_rd = ($signed(rj_value) >=  $signed(rkd_value));
assign rj_geu_rd = (rj_value >= rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                   || inst_blt && rj_lt_rd
                   || inst_bltu && rj_ltu_rd
                   || inst_bge && rj_ge_rd
                   || inst_bgeu && rj_geu_rd
                  ) && ds_valid; 
//assign br_taken_cancel = br_taken & ~(raw_es_blk | raw_ms_blk | raw_ws_blk);
assign br_stall = (inst_beq||inst_bne||inst_jirl||inst_bl||inst_b||inst_blt||inst_bltu||inst_bge||inst_bgeu) & !ds_ready_go;
assign br_taken_cancel = br_taken && ds_ready_go;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bltu || inst_bge || inst_bgeu) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign inv_ex = inst_invtlb & (op>=7);// inv_op>=7
assign ex_cause_bus[`ECODE_ADE] = ds_valid & inst_adef;
assign ex_cause_bus[`ECODE_SYS] = ds_valid & inst_syscall;
assign ex_cause_bus[`ECODE_BRK] = ds_valid & inst_break;
assign ex_cause_bus[`ECODE_INE] = ds_valid & (inst_ine||inv_ex);
assign ex_cause_bus[`ECODE_INT] = ds_valid & has_int;
assign ex_cause_bus[`ECODE_PME] = ds_valid & fs_tlb_ex_bus[5];
assign ex_cause_bus[`ECODE_PPI] = ds_valid & fs_tlb_ex_bus[4];
assign ex_cause_bus[`ECODE_PIS] = ds_valid & fs_tlb_ex_bus[3];
assign ex_cause_bus[`ECODE_PIL] = ds_valid & fs_tlb_ex_bus[2];
assign ex_cause_bus[`ECODE_PIF] = ds_valid & fs_tlb_ex_bus[1];
assign ex_cause_bus[        16] = ds_valid & fs_tlb_ex_bus[0];
assign ex_cause_bus[15:14]      = 3'b0;
assign ex_cause_bus[10: 9]      = 2'b0;
assign ex_cause_bus[ 6: 5]      = 8'b0;
endmodule
