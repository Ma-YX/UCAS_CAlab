`include "mycpu.h"

module exe_stage
#(
    parameter TLBNUM = 16
)
(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //from ms
    input                          ms_to_es_valid,
    //from ws
    input                          ws_to_es_valid,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    //raw signals: to ds
    output  [`RAW_BUS_WD      -1:0] raw_es_bus    ,
    // reflush
    output [`ES_REFLUSH_FS_WD -1:0] es_reflush_fs_bus,
    output                          es_reflush_ds,
    //int
    output                          has_int,
      
    //block signals to fs
    output                         blk_es_load,
    //tb
    output [              18:0] s0_vppn,
    output                      s0_va_bit12,
    output [               9:0] s0_asid,
    input                       s0_found,
    input  [$clog2(TLBNUM)-1:0] s0_index,
    input  [              19:0] s0_ppn,
    input  [               5:0] s0_ps,
    input  [               1:0] s0_plv,
    input  [               1:0] s0_mat,
    input                       s0_d,
    input                       s0_v,
    // search port 1 (for load/store)
    output [              18:0] s1_vppn,
    output                      s1_va_bit12,//
    output [               9:0] s1_asid,
    input                       s1_found,
    input  [$clog2(TLBNUM)-1:0] s1_index,
    input  [              19:0] s1_ppn,//
    input  [               5:0] s1_ps,//
    input  [               1:0] s1_plv,//
    input  [               1:0] s1_mat,//
    input                       s1_d,//
    input                       s1_v,//
    // invtlb opcode
    output                      invtlb_valid,
    output [               4:0] invtlb_op,
    // write port
    output                      we, //w(rite) e(nable)
    output [$clog2(TLBNUM)-1:0] w_index,
    output                      w_e,
    output [               5:0] w_ps,
    output [              18:0] w_vppn,
    output [               9:0] w_asid,
    output                      w_g,
    output [              19:0] w_ppn0,
    output [               1:0] w_plv0,
    output [               1:0] w_mat0,
    output                      w_d0,
    output                      w_v0,
    output [              19:0] w_ppn1,
    output [               1:0] w_plv1,
    output [               1:0] w_mat1,
    output                      w_d1,
    output                      w_v1,
    // read port
    output [$clog2(TLBNUM)-1:0] r_index,
    input                       r_e,
    input  [              18:0] r_vppn,
    input  [               5:0] r_ps,
    input  [               9:0] r_asid,
    input                       r_g,
    input  [              19:0] r_ppn0,
    input  [               1:0] r_plv0,
    input  [               1:0] r_mat0,
    input                       r_d0,
    input                       r_v0,
    input  [              19:0] r_ppn1,     
    input  [               1:0] r_plv1,
    input  [               1:0] r_mat1,
    input                       r_d1,
    input                       r_v1,
    output [`ES_TO_FS_BUS_WD - 1:0] es_to_fs_bus
    
);

reg         es_ex_r;
reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
reg         data_sram_addr_ok_r;
wire [11:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;
wire [2:0]  es_mul_op     ;
wire [2:0]  es_div_op     ; 
wire [2:0]  es_load_op       ;      
wire [1:0]  es_store_op      ;

//kernel_mode
//csr
wire [16:0] ex_cause_bus;
wire [16:0] ex_cause_bus_es;
wire inst_ertn;
wire csr_we;
wire csr_re;
wire [31:0] csr_wmask;
wire [13:0] csr_num;
wire ertn_flush;
wire es_ex;
wire [31:0]es_status;
wire [5:0] es_ecode;
wire [8:0] es_esubcode;
wire [31:0] ex_entry;
wire [31:0] era_entry;
wire [7:0]   hw_int_in;
wire         ipi_int_in;
wire [31: 0] es_vaddr;
wire [31: 0] coreid_in;
wire         ex_ld;
//clk
wire [2:  0] clk_op;  
wire [63: 0] rdcnt;
wire [31: 0] tid_value;
wire [31: 0] clk_rvalue;



wire        es_res_from_mem;

wire [65:0] mul_add1;
wire [65:0] mul_add2;
wire mul_cin;
//user model div
reg         s_divisor_tvalid;
wire        s_divisor_tready;
reg         s_dividend_tvalid;
wire        s_dividend_tready;
wire [63:0] s_dout_tdata;
wire        s_dout_tvalid;
reg         u_divisor_tvalid;
wire        u_divisor_tready;
reg         u_dividend_tvalid;
wire        u_dividend_tready;
wire [63:0] u_dout_tdata;
wire        u_dout_tvalid;
wire [ 4:0] tlb_bus;
wire [ 4:0] inv_op;
//tlb->csr
   //tlb
wire  [4 : 0] tlbop_bus; //tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
wire          tlbsrch_hit;
wire  [31: 0] csr_tlbidx_wvalue;
wire  [31: 0] csr_tlbehi_wvalue;
wire  [31: 0] csr_tlbelo0_wvalue;
wire  [31: 0] csr_tlbelo1_wvalue;
wire  [31: 0] csr_asid_wvalue;
wire [31: 0] csr_tlbidx_rvalue;
wire [31: 0] csr_tlbehi_rvalue;
wire [31: 0] csr_tlbelo0_rvalue;
wire [31: 0] csr_tlbelo1_rvalue;
wire [31: 0]csr_asid_rvalue;
wire [31: 0] csr_crmd_rvalue;
wire [31: 0] csr_dmw0_rvalue;
wire [31: 0] csr_dmw1_rvalue;
wire [31: 0] csr_estat_rvalue;
wire [31: 0] ex_tlb_entry;
wire csr_tlbrd_re;
wire [              18:0]ls_vppn;
wire ls_va_bit12;
wire [               9:0]ls_asid;
//
wire [ 5: 0] tlb_ex_bus;
wire [ 2: 0] inst_op;
assign {tlb_bus        ,  //239:235
        inv_op         ,  //234:230
        clk_op         ,  //229:227
        inst_ertn      ,  //226:226
        ex_cause_bus   ,  //225:209
        csr_num        ,  //208:195
        csr_we         ,  //194:194
        csr_re         ,  //193:193
        csr_wmask      ,  //192:161
        es_store_op    ,  //160:159
        es_load_op     ,  //158:156
        es_mul_op      ,  //155:153
        es_div_op      ,  //152:150
        es_alu_op      ,  //149:138
        es_res_from_mem,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_mul_result ;
wire [31:0] es_div_result ;
wire [31:0] es_result;
//sramm_write_select
wire [3 :0] sb_wen;
wire [3 :0] sh_wen;
wire [3 :0] sw_wen;
//assign es_res_from_mem = es_load_op;
// kernel mode
wire [31:0] csr_rvalue;
reg [3:0] tlbfill_index;
wire tlb_reflush;
//tlb
wire dmw_hit;
assign es_to_fs_bus = {csr_crmd_rvalue, csr_dmw0_rvalue, csr_dmw1_rvalue, csr_asid_rvalue};
assign es_to_ms_bus = {es_ex          ,//213:213
                       es_mem_we      ,//212:212
                       es_mul_op      ,//211:209
                       mul_add1       ,//208:143
                       mul_add2       ,//142:77
                       mul_cin        ,//76:76
                       es_alu_result[1:0],//75:74
                       es_load_op     ,  //73:71
                       es_res_from_mem,  //70:70
                       es_gr_we & ~es_ex,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32
                       es_pc             //31:0
                      };

wire   raw_es_valid;
assign raw_es_valid = ~|es_mul_op & es_gr_we & es_valid;
assign raw_es_bus = {raw_es_valid ,  //37:37
                     es_dest      ,  //36:32
                     es_result   //31:0
                    };
assign blk_es_load = (es_res_from_mem || (es_div_op[2] && ~(s_dout_tvalid || u_dout_tvalid))) & es_valid;

assign es_ready_go    = es_div_op[2] ? (es_div_op[1] & s_dout_tvalid || ~es_div_op[1] & u_dout_tvalid) : ((es_res_from_mem||es_mem_we)&&~es_ex)? (data_sram_req&data_sram_addr_ok)||data_sram_addr_ok_r : 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go ;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end
reg s;
reg u;
always @(posedge clk) begin
    if(reset || !es_div_op[2]) begin
        s <= 1'b0;
    end
    else if(es_div_op[2] & es_div_op[1] & ~s_divisor_tready) begin
        s <= 1'b1;
    end
    
    if(reset || !es_div_op[2]) begin
        u <= 1'b0;
    end
    else if(es_div_op[2] & ~es_div_op[1] & ~u_divisor_tready) begin
        u <= 1'b1;
    end
end
always @(posedge clk) begin
    if(reset || !es_div_op[2]) begin
        s_divisor_tvalid <= 1'b0;
    end
    else if(es_div_op[2] & es_div_op[1] & ~s_divisor_tready & ~s) begin
        s_divisor_tvalid <= 1'b1;
    end
    else if(es_div_op[2] & es_div_op[1] & s_divisor_tready) begin
        s_divisor_tvalid <= 1'b0;
    end

    if(reset || !es_div_op[2]) begin
        s_dividend_tvalid <= 1'b0;
    end
    else if(es_div_op[2] & es_div_op[1] &  ~s_dividend_tready & ~s) begin
        s_dividend_tvalid <= 1'b1;
    end
    else if(es_div_op[2] & es_div_op[1] & s_dividend_tready) begin
        s_dividend_tvalid <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset || !es_div_op[2]) begin
        u_divisor_tvalid <= 1'b0;
    end
    else if(es_div_op[2] & ~es_div_op[1] & !u_divisor_tready & ~u) begin
        u_divisor_tvalid <= 1'b1;
    end
    else if(es_div_op[2] & ~es_div_op[1] & u_divisor_tready) begin
        u_divisor_tvalid <= 1'b0;
    end

    if(reset || !es_div_op[2]) begin
        u_dividend_tvalid <= 1'b0;
    end
    else if(es_div_op[2] & ~es_div_op[1] & !u_dividend_tready & ~u) begin
        u_dividend_tvalid <= 1'b1;
    end
    else if(es_div_op[2] & ~es_div_op[1] & u_dividend_tready) begin
        u_dividend_tvalid <= 1'b0;
    end
end

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;
alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );
wallace_tree_mul u_wallace_tree_mul(
    .mul_signed (es_mul_op[1] ),
    .x          (es_alu_src1  ),
    .y          (es_alu_src2  ),
    .A_add      (mul_add1),
    .B_add      (mul_add2),
    .cin_add    (mul_cin)
    );

my_ip_div_signed my_ip_div_signed(
    .aclk(clk),
    .s_axis_divisor_tdata(es_alu_src2),
    .s_axis_divisor_tvalid(s_divisor_tvalid),
    .s_axis_divisor_tready(s_divisor_tready),
    .s_axis_dividend_tdata(es_alu_src1),
    .s_axis_dividend_tvalid(s_dividend_tvalid),
    .s_axis_dividend_tready(s_dividend_tready),
    .m_axis_dout_tdata(s_dout_tdata),
    .m_axis_dout_tvalid(s_dout_tvalid)
);

my_ip_div_unsigned my_ip_div_unsigned(
    .aclk(clk),
    .s_axis_divisor_tdata(es_alu_src2),
    .s_axis_divisor_tvalid(u_divisor_tvalid),
    .s_axis_divisor_tready(u_divisor_tready),
    .s_axis_dividend_tdata(es_alu_src1),
    .s_axis_dividend_tvalid(u_dividend_tvalid),
    .s_axis_dividend_tready(u_dividend_tready),
    .m_axis_dout_tdata(u_dout_tdata),
    .m_axis_dout_tvalid(u_dout_tvalid)
);
assign es_div_result = {32{ es_div_op[0] &&  es_div_op[1]}} & s_dout_tdata[63:32] |
                       {32{ es_div_op[0] && !es_div_op[1]}} & u_dout_tdata[63:32] |
                       {32{!es_div_op[0] &&  es_div_op[1]}} & s_dout_tdata[31: 0] |
                       {32{!es_div_op[0] && !es_div_op[1]}} & u_dout_tdata[31: 0] ;
assign es_result       ={32{es_div_op[2]&~csr_re}}&es_div_result
                        |{32{~es_div_op[2]&~csr_re}}&es_alu_result
                        |{32{~es_div_op[2]&(csr_re|csr_we)}}&csr_rvalue
                        |{32{(|clk_op)}}& clk_rvalue;

assign sb_wen = es_alu_result[1:0] == 2'b00 ? 4'h1 :
                es_alu_result[1:0] == 2'b01 ? 4'h2 :
                es_alu_result[1:0] == 2'b10 ? 4'h4 :
                                              4'h8 ;
assign sh_wen = es_alu_result[1:0] == 2'b00 ? 4'h3 :
                                              4'hc ;
assign sw_wen = 4'hf;


    always @(posedge clk) begin
        if(reset) begin
            data_sram_addr_ok_r <= 1'b0;
        end
        else if(data_sram_addr_ok && data_sram_req && !ms_allowin) begin
            data_sram_addr_ok_r <= 1'b1;
        end
        else if(ms_allowin) begin
            data_sram_addr_ok_r <= 1'b0;
        end
    end
assign data_sram_req = (es_res_from_mem || es_mem_we) && es_valid && ~es_ex && !data_sram_addr_ok_r;
assign data_sram_wstrb =  es_store_op[1]  & ~es_store_op[0] ? sw_wen :
                       ~es_store_op[1]  &  es_store_op[0] ? sh_wen :
                       (&es_store_op) ? sb_wen :
                                         4'h0   ;


assign data_sram_wr = |data_sram_wstrb;
assign data_sram_size = ( es_load_op[2] | ( es_store_op[1]  & ~es_store_op[0])) ? 2'b10 :
                        ( es_load_op[0] | (~es_store_op[1]  &  es_store_op[0])) ? 2'b01 :
                        2'b00;
                        
//assign data_sram_addr  = es_alu_result;
assign data_sram_wdata =  es_store_op[1]  & ~es_store_op[0] ? es_rkd_value :
                         ~es_store_op[1]  &  es_store_op[0] ? {2{es_rkd_value[15:0]}} :
                                          {4{es_rkd_value[7:0]}} ;
//exception handle
wire inst_ale;
assign inst_ale = (es_load_op[0] & (es_alu_result[0]   != 1'b0)) 
                 |(es_load_op[2] & (es_alu_result[1:0] != 2'b0))
                 |(es_store_op[1:0]==2'b01 & (es_alu_result[0]   != 1'b0))
                 |(es_store_op[1:0]==2'b10 & (es_alu_result[1:0] != 2'b0));
assign ex_cause_bus_es [`ECODE_ALE] = inst_ale;
assign ex_cause_bus_es [`ECODE_PME] = tlb_ex_bus[5] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [`ECODE_PPI] = tlb_ex_bus[4] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [`ECODE_PIS] = tlb_ex_bus[3] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [`ECODE_PIL] = tlb_ex_bus[2] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [`ECODE_PIF] = tlb_ex_bus[1] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [        16] = tlb_ex_bus[0] & (es_res_from_mem||es_mem_we);
assign ex_cause_bus_es [`ECODE_ADE] = (es_res_from_mem||es_mem_we) & es_alu_result[31] & (csr_crmd_rvalue[1:0]!=0) & ~dmw_hit;
assign ex_cause_bus_es [         0] = 1'b0;
assign ex_cause_bus_es [       6:5] = 2'b0;
assign ex_cause_bus_es [     15:10] = 6'b0;

assign ertn_flush=inst_ertn;
assign es_ex =((|ex_cause_bus)||(|ex_cause_bus_es)) & (es_valid);
always @(posedge clk) begin
       es_ex_r <= es_ex;
end
assign es_reflush_fs_bus={es_valid&(inst_ertn|((|ex_cause_bus)||(|ex_cause_bus_es))|tlb_reflush|(csr_we&(csr_num== `CSR_CRMD ||csr_num == `CSR_DMW0|| csr_num==`CSR_DMW1||csr_num==`CSR_ASID))),
                          inst_ertn ? era_entry:((|ex_cause_bus)||(|ex_cause_bus_es)?((es_ecode==`ECODE_TLBR)?ex_tlb_entry:ex_entry):es_pc+4)
                            };                           
assign es_ecode = (ex_cause_bus[`ECODE_INT] & es_valid) ? `ECODE_INT
                : (ex_cause_bus[`ECODE_ADE] & es_valid) ? `ECODE_ADE
                : (ex_cause_bus[        16] & es_valid) ? `ECODE_TLBR
                : (ex_cause_bus[`ECODE_PIF] & es_valid) ? `ECODE_PIF
                : (ex_cause_bus[`ECODE_PIL] & es_valid) ? `ECODE_PIL
                : (ex_cause_bus[`ECODE_PIS] & es_valid) ? `ECODE_PIS
                : (ex_cause_bus[`ECODE_PPI] & es_valid) ? `ECODE_PPI
                : (ex_cause_bus[`ECODE_PME] & es_valid) ? `ECODE_PME
                : (ex_cause_bus[`ECODE_SYS] & es_valid) ? `ECODE_SYS
                : (ex_cause_bus[`ECODE_BRK] & es_valid) ? `ECODE_BRK
                : (ex_cause_bus[`ECODE_INE] & es_valid) ? `ECODE_INE
                : (ex_cause_bus_es [`ECODE_ALE] & es_valid) ? `ECODE_ALE
                : (ex_cause_bus_es [`ECODE_ADE] & es_valid) ? `ECODE_ADE
                : (ex_cause_bus_es [        16] & es_valid) ? `ECODE_TLBR
                : (ex_cause_bus_es [`ECODE_PIL] & es_valid) ? `ECODE_PIL  
                : (ex_cause_bus_es [`ECODE_PIS] & es_valid) ? `ECODE_PIS
                : (ex_cause_bus_es [`ECODE_PPI] & es_valid) ? `ECODE_PPI               
                : (ex_cause_bus_es [`ECODE_PME] & es_valid) ? `ECODE_PME            
                : 6'b0;
assign es_esubcode   = (ex_cause_bus [`ECODE_ADE] & es_valid) ? `ESUBCODE_ADEF
                      :(ex_cause_bus_es [`ECODE_ADE] & es_valid) ? `ESUBCODE_ADEM
                      :9'b0;
assign es_reflush_ds = es_valid&(inst_ertn|((|ex_cause_bus)||(|ex_cause_bus_es))|tlb_reflush|
                       (csr_we&(csr_num== `CSR_CRMD ||csr_num == `CSR_DMW0|| csr_num==`CSR_DMW1||csr_num==`CSR_ASID))
                       );
assign es_vaddr      = (|ex_cause_bus) ? es_pc
                       :(|ex_cause_bus_es) ? es_alu_result
                       : 32'b0;
assign hw_int_in     = 8'b0;
assign ipi_int_in    = 1'b0;

//clk
assign clk_rvalue    = clk_op[2]            ? tid_value
                     : clk_op[1]& clk_op[0] ? rdcnt[31: 0]
                     : clk_op[1]&~clk_op[0] ? rdcnt[63:32]
                     : 32'b0;
//tlb

assign we = tlb_bus[1] | tlb_bus[2];
assign tlb_reflush   = es_valid & (|tlb_bus);
assign tlbop_bus = tlb_bus & {5{~|ex_cause_bus}};

assign tlbsrch_hit = tlb_bus[4] & s1_found & ~|ex_cause_bus;//TLBSRCHÃüÖÐÊ±Îª1
assign csr_tlbrd_re = r_e & es_valid & ~|ex_cause_bus;
assign csr_tlbidx_wvalue = {~s1_found | ~r_e,
                            1'b0,
                            r_ps,
                            20'b0,
                            s1_index
                            };
assign r_index = csr_tlbidx_rvalue[3:0];
assign w_index = tlb_bus[2]?csr_tlbidx_rvalue[3:0]:(tlb_bus[1]?tlbfill_index[3:0]:4'b0);
assign w_ps = csr_tlbidx_rvalue[29:24];
assign w_e  = (csr_estat_rvalue[21:16]==6'h3f) || ~csr_tlbidx_rvalue[31];
assign csr_tlbehi_wvalue = {r_vppn,
                            13'b0
                            };
assign w_vppn =  csr_tlbehi_rvalue[31:13];
assign s1_vppn = (es_res_from_mem||es_mem_we)? ls_vppn:tlb_bus[0]?es_rkd_value[31:13]:csr_tlbehi_rvalue[31:13];
assign  csr_tlbelo0_wvalue = {r_ppn0,
                              1'b0,
                              r_g,
                              r_mat0,
                              r_plv0,
                              r_d0, 
                              r_v0
                             };
assign  csr_tlbelo1_wvalue = {r_ppn1,
                              1'b0,
                              r_g,
                              r_mat1,
                              r_plv1,
                              r_d1,
                              r_v1                            
                              };

assign w_v0 = csr_tlbelo0_rvalue [0];
assign w_d0 = csr_tlbelo0_rvalue [1];
assign w_plv0 = csr_tlbelo0_rvalue [3:2];
assign w_mat0 = csr_tlbelo0_rvalue [5:4];
assign w_ppn0 = csr_tlbelo0_rvalue [31:8];
assign w_v1 = csr_tlbelo1_rvalue [0];
assign w_d1 = csr_tlbelo1_rvalue [1];
assign w_plv1 = csr_tlbelo1_rvalue [3:2];
assign w_mat1 = csr_tlbelo1_rvalue [5:4];
assign w_ppn1 = csr_tlbelo1_rvalue [31:8];
assign w_g = csr_tlbelo1_rvalue[6] &  csr_tlbelo0_rvalue [6]; 
assign csr_asid_wvalue[9:0] = r_asid;
assign w_asid = csr_asid_rvalue[9:0];
assign s1_asid  =(es_res_from_mem||es_mem_we)?ls_asid:tlb_bus[0]?es_rj_value[9:0] : csr_asid_rvalue[9:0];

assign invtlb_valid = tlb_bus[0];
assign invtlb_op    = inv_op;
assign s1_va_bit12  = (es_res_from_mem||es_mem_we)?ls_va_bit12:1'b0;
reg tlbfill_valid;

always @(posedge clk)begin
    if(reset)begin
        tlbfill_index <= 4'b0;
    end
    else if(tlb_bus[1]&es_valid) begin
        if(tlbfill_index == 4'd15) begin
            tlbfill_index <= 4'b0;
        end
        else begin
            tlbfill_index <= tlbfill_index + 4'b1;
        end
    end
end

//csr
csr csr(
    .clk(clk),
    .reset(reset),
    .csr_re(csr_re|inst_ertn),
    .csr_num(csr_num),
    .csr_rvalue(csr_rvalue),
    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(es_rkd_value),
    .es_ex(es_ex&~es_ex_r),
    .es_ecode(es_ecode),
    .es_esubcode(es_esubcode),
    .ertn_flush(ertn_flush),
    .ex_entry(ex_entry),
    .ex_tlb_entry(ex_tlb_entry),
    .era_entry(era_entry),
    .has_int(has_int),
    .hw_int_in(hw_int_in),
    .ipi_int_in(ipi_int_in),
    .es_vaddr(es_vaddr),
    .es_pc(es_pc),
    .coreid_in(coreid_in),
    .rdcnt(rdcnt),
    .tid_value(tid_value),
  //tlb
    .tlbop_bus(tlbop_bus), //tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
    .tlbsrch_hit(tlbsrch_hit),
    .csr_tlbrd_re(csr_tlbrd_re),
    .csr_tlbidx_wvalue(csr_tlbidx_wvalue),
    .csr_tlbehi_wvalue(csr_tlbehi_wvalue),
    .csr_tlbelo0_wvalue(csr_tlbelo0_wvalue),
    .csr_tlbelo1_wvalue(csr_tlbelo1_wvalue),
    .csr_asid_wvalue(csr_asid_wvalue),
    .csr_tlbidx_rvalue(csr_tlbidx_rvalue),
    .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
    .csr_tlbelo0_rvalue(csr_tlbelo0_rvalue),
    .csr_tlbelo1_rvalue(csr_tlbelo1_rvalue),
    .csr_asid_rvalue(csr_asid_rvalue),
    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue),
    .csr_estat_rvalue(csr_estat_rvalue)   
);
assign inst_op = {es_res_from_mem,es_mem_we,1'b0};
vaddr_transfer data_transfer(
    .va        (es_alu_result),
    .inst_op   (inst_op),//{load.store,if}
    .pa        (data_sram_addr),
    .tlb_ex_bus(tlb_ex_bus),//{PME,PPE,PIS,PIL,PIF,TLBR}
    //tlb
    .s_vppn    (ls_vppn),
    .s_va_bit12(ls_va_bit12),
    .s_asid    (ls_asid),
    .s_found   (s1_found),
    .s_index   (s1_index),
    .s_ppn     (s1_ppn),
    .s_ps      (s1_ps),
    .s_plv     (s1_plv),
    .s_mat     (s1_mat),
    .s_d       (s1_d),
    .s_v       (s1_v),
    //crmd
    .csr_asid  (csr_asid_rvalue),
    .csr_crmd  (csr_crmd_rvalue),
    //dmw
    .dmw_hit   (dmw_hit),
    .csr_dmw0  (csr_dmw0_rvalue),
    .csr_dmw1  (csr_dmw1_rvalue)
    
);

endmodule
