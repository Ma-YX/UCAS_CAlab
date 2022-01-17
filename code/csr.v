`include "mycpu.h"

module csr
#(
    parameter TLBNUM = 16
)(
    input          clk,
    input          reset,
    input          csr_re,
    input  [13: 0] csr_num,
    output [31: 0] csr_rvalue,
    input          csr_we,
    input  [31: 0] csr_wmask,
    input  [31: 0] csr_wvalue,
    input          es_ex,       //exception tigger signal
    input  [5 : 0] es_ecode,    //exception type
    input  [8 : 0] es_esubcode,
    input          ertn_flush,  //ertn
    output [31: 0] ex_entry,    //to pre_IF
    output [31: 0] ex_tlb_entry,
    output [31: 0] era_entry,
    output         has_int,    //to ID
    input  [7 : 0] hw_int_in,
    input          ipi_int_in,
    input  [31: 0] es_vaddr,
    input  [31: 0] es_pc,
    input  [31: 0] coreid_in,
    //clock
    output [63: 0] rdcnt,
    output [31: 0] tid_value,

    //tlb
    input  [4 : 0] tlbop_bus, //tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
    input          tlbsrch_hit,
    input          csr_tlbrd_re,
    input  [31: 0] csr_tlbidx_wvalue,
    input  [31: 0] csr_tlbehi_wvalue,
    input  [31: 0] csr_tlbelo0_wvalue,
    input  [31: 0] csr_tlbelo1_wvalue,
    input  [31: 0] csr_asid_wvalue,
    output [31: 0] csr_tlbidx_rvalue,
    output [31: 0] csr_tlbehi_rvalue,
    output [31: 0] csr_tlbelo0_rvalue,
    output [31: 0] csr_tlbelo1_rvalue,
    output [31: 0] csr_asid_rvalue,
    output [31: 0] csr_crmd_rvalue,
    output [31: 0] csr_dmw0_rvalue,
    output [31: 0] csr_dmw1_rvalue,
    output [31: 0] csr_estat_rvalue
);

//CRMD
reg  [ 1: 0] csr_crmd_plv;
reg          csr_crmd_ie;
reg          csr_crmd_da;
reg          csr_crmd_pg;
//wire [31: 0] csr_crmd_rvalue;

//PRMD
reg  [ 1: 0] csr_prmd_pplv;
//reg  [ 1: 0] csr_prmd_pplv;
reg          csr_prmd_pie;
wire [31: 0] csr_prmd_rvalue;
 
//ECFG
reg  [12: 0] csr_ecfg_lie;
wire [31: 0] csr_ecfg_rvalue;

//ESTAT
reg  [12: 0] csr_estat_is;
reg  [21:16] csr_estat_ecode;
reg  [30:22] csr_estat_esubcode;
//wire [31: 0] csr_estat_rvalue;

//ERA
reg  [31: 0] csr_era_pc;
wire [31: 0] csr_era_rvalue;

//BADV
wire         es_ex_addr_err;
reg  [31: 0] csr_badv_vaddr;
wire [31: 0] csr_badv_rvalue;

//EENTRY
reg  [31: 6] csr_eentry_va;
wire [31: 0] csr_eentry_rvalue;

//SAVE0~3
reg  [31: 0] csr_save0_data;
reg  [31: 0] csr_save1_data;
reg  [31: 0] csr_save2_data;
reg  [31: 0] csr_save3_data;
wire [31: 0] csr_save0_rvalue;
wire [31: 0] csr_save1_rvalue;
wire [31: 0] csr_save2_rvalue;
wire [31: 0] csr_save3_rvalue;

//TID
reg  [31: 0] csr_tid_tid;
wire [31: 0] csr_tid_rvalue;

//TCFG
reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [31: 2] csr_tcfg_initval;
wire [31: 0] csr_tcfg_rvalue;

//TVAL
wire [31: 0] tcfg_next_value;
reg  [31: 0] timer_cnt;
wire [31: 0] csr_tval_timeval;
wire [31: 0] csr_tval_rvalue;

//TICLR
wire         csr_ticlr_clr;
wire [31: 0] csr_ticlr_rvalue;

//TLBIDX
reg  [3 : 0] csr_tlbidx_index;
reg  [29:24] csr_tlbidx_ps;
reg          csr_tlbidx_ne;

//TLBEHI
reg  [31:13] csr_tlbehi_vppn;

//TLBELO
reg          csr_tlbelo0_v;
reg          csr_tlbelo0_d;
reg  [3 : 2] csr_tlbelo0_plv;
reg  [5 : 4] csr_tlbelo0_mat;
reg          csr_tlbelo0_g;
reg  [31: 8] csr_tlbelo0_ppn;
reg          csr_tlbelo1_v;
reg          csr_tlbelo1_d;
reg  [3 : 2] csr_tlbelo1_plv;
reg  [5 : 4] csr_tlbelo1_mat;
reg          csr_tlbelo1_g;
reg  [31: 8] csr_tlbelo1_ppn;

//TLBRENTRY
reg  [31: 6] csr_tlbrentry_pa;
wire [31: 0] csr_tlbrentry_rvalue;

//ASID
reg  [9 : 0] csr_asid_asid;
wire [7 : 0] csr_asid_asidbits = 8'd10;

//DMW
reg          csr_dmw0_plv0;
reg          csr_dmw0_plv3;
reg  [5 : 4] csr_dmw0_mat;
reg  [27:25] csr_dmw0_pseg;
reg  [31:29] csr_dmw0_vseg; 
reg          csr_dmw1_plv0;
reg          csr_dmw1_plv3;
reg  [5 : 4] csr_dmw1_mat;
reg  [27:25] csr_dmw1_pseg;
reg  [31:29] csr_dmw1_vseg; 

//CRMD
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if(es_ex) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if(ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
    end
    else if(csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
        csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
                     | ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_crmd_da <= 1'b1;
    end
    else if(es_ex && es_ecode == 6'h3f) begin
        csr_crmd_da <= 1'b1;
    end
    else if(ertn_flush && csr_estat_ecode == 6'b111111) begin
        csr_crmd_da <= 1'b0;
    end
    else if(csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                    | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
    end 
end

always @(posedge clk ) begin
    if(reset) begin
        csr_crmd_pg <= 1'b0;
    end
    else if(es_ex && es_ecode == 6'h3f) begin
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_flush && csr_estat_ecode == 6'b111111) begin
        csr_crmd_pg <= 1'b1;
    end
    else if(csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                    | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
    end 
end

//PRMD
always @(posedge clk) begin
    if(es_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if(csr_we && csr_num == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
end

//ECFG
always @(posedge clk) begin
    if(reset)
        csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_num == `CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE]
                      | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
end

//ESTAT
always @(posedge clk) begin
    if(reset)
        csr_estat_is[1:0] <= 2'b0;
    else if(csr_we && csr_num == `CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    
    csr_estat_is[9:2] <= hw_int_in[7:0];

    csr_estat_is[10] <= 1'b0;

    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) 
        csr_estat_is[11] <= 1'b0;

    csr_estat_is[12] <= ipi_int_in;
end

always @(posedge clk) begin
    if (es_ex) begin
        csr_estat_ecode <= es_ecode;
        csr_estat_esubcode <= es_esubcode;
    end
end

//ERA

always @(posedge clk) begin
    if (es_ex)
        csr_era_pc <= es_pc;
    else if (csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                   | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
end

assign es_ex_addr_err = es_ecode==`ECODE_ADE || es_ecode==`ECODE_ALE || es_ecode == `ECODE_TLBR || es_ecode == `ECODE_PIL || es_ecode == `ECODE_PIS || es_ecode == `ECODE_PIF
                     || es_ecode == `ECODE_PME || es_ecode == `ECODE_PPI;


//BADV
always @(posedge clk) begin
    if (es_ex && es_ex_addr_err)
        csr_badv_vaddr <= ((es_ecode==`ECODE_ADE && es_esubcode==`ESUBCODE_ADEF)) ? es_pc : es_vaddr;
end

//EENTRY
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                      | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
end

//SAVE
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end

//TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID] 
                    | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end

//TCFG
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN] 
                    | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    
    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                          | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
                          | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
end

//TVAL
assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
                       | ~csr_wmask[31:0]&{csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
    end
end

assign csr_tval_timeval = timer_cnt[31:0];

//TICLR
assign csr_ticlr_clr = 1'b0;

//TLBTID
always @(posedge clk ) begin
    if(reset) begin
        csr_tlbidx_index <= 4'b0;
    end
    else if(tlbop_bus[4] && tlbsrch_hit) begin
        csr_tlbidx_index <= csr_tlbidx_wvalue[`CSR_TLBIDX_INDEX];
    end
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                         | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_tlbidx_ps <= 6'b0;
    end
    else if(tlbop_bus[3] && csr_tlbrd_re) begin
        csr_tlbidx_ps <= csr_tlbidx_wvalue[`CSR_TLBIDX_PS];
    end
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                      | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_tlbidx_ne <= 1'b0;
    end
    else if(tlbop_bus[4]) begin
        if(tlbsrch_hit) begin
            csr_tlbidx_ne <= 1'b0;
        end
        else begin
            csr_tlbidx_ne <= 1'b1;
        end
    end
    else if(tlbop_bus[3]) begin
        csr_tlbidx_ne <= csr_tlbidx_wvalue[`CSR_TLBIDX_NE];
    end
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                      | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne; 
    end
end

//TLBEHI
always @(posedge clk ) begin
    if(reset) begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(tlbop_bus[3] && csr_tlbrd_re) begin
        csr_tlbehi_vppn <= csr_tlbehi_wvalue[`CSR_TLBEHI_VPPN];
    end
    else if(es_ecode == `ECODE_PIL || es_ecode == `ECODE_PIS || es_ecode == `ECODE_TLBR || es_ecode == `ECODE_PIF || es_ecode == `ECODE_PME || es_ecode == `ECODE_PPI) begin
        csr_tlbehi_vppn <= es_vaddr[31:13];
    end
    else if(csr_we && csr_num == `CSR_TLBEHI) begin
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                        | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;   
    end
end

//TLBELO01
always @(posedge clk ) begin
    if(reset) begin
        csr_tlbelo0_v   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_ppn <= 24'b0;
    end
    else if (tlbop_bus[3] && csr_tlbrd_re) begin
        csr_tlbelo0_v   <= csr_tlbelo0_wvalue[`CSR_TLBELO_V];
        csr_tlbelo0_d   <= csr_tlbelo0_wvalue[`CSR_TLBELO_D];
        csr_tlbelo0_plv <= csr_tlbelo0_wvalue[`CSR_TLBELO_PLV];
        csr_tlbelo0_mat <= csr_tlbelo0_wvalue[`CSR_TLBELO_MAT];
        csr_tlbelo0_ppn <= csr_tlbelo0_wvalue[`CSR_TLBELO_PPN];
        csr_tlbelo0_g   <= csr_tlbelo0_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO0) begin
        csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo0_v; 
        csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo0_g;    
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_tlbelo1_v   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_ppn <= 24'b0;
    end
    else if (tlbop_bus[3] && csr_tlbrd_re) begin
        csr_tlbelo1_v   <= csr_tlbelo1_wvalue[`CSR_TLBELO_V];
        csr_tlbelo1_d   <= csr_tlbelo1_wvalue[`CSR_TLBELO_D];
        csr_tlbelo1_plv <= csr_tlbelo1_wvalue[`CSR_TLBELO_PLV];
        csr_tlbelo1_mat <= csr_tlbelo1_wvalue[`CSR_TLBELO_MAT];
        csr_tlbelo1_ppn <= csr_tlbelo1_wvalue[`CSR_TLBELO_PPN];
        csr_tlbelo1_g   <= csr_tlbelo1_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO1) begin
        csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo1_v; 
        csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo1_g;    
    end
end

//TLBRENTRY
always @(posedge clk ) begin
    if(reset)begin
        csr_tlbrentry_pa <= 26'b0;
    end 
    else if(csr_we && csr_num == `CSR_TLBRENTRY) begin
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                         | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa; 
    end
end

//ASID
always @(posedge clk ) begin
    if(reset) begin
        csr_asid_asid <= 10'b0;
    end
    else if(tlbop_bus[3] && csr_tlbrd_re) begin
        csr_asid_asid <= csr_asid_wvalue[`CSR_ASID_ASID];
    end
    else if(csr_we && csr_num == `CSR_ASID)begin
        csr_asid_asid  <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                       | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid; 
    end
end

//DMW01
always @(posedge clk ) begin
    if(reset) begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW0)begin
        csr_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0; 
        csr_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3; 
        csr_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat; 
        csr_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
        csr_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;   
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW1)begin
        csr_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0; 
        csr_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3; 
        csr_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat; 
        csr_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
        csr_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;   
    end
end

//rvalue
assign csr_crmd_rvalue      = {27'b0, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_prmd_rvalue      = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_ecfg_rvalue      = {19'b0, csr_ecfg_lie};
assign csr_estat_rvalue     = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
assign csr_era_rvalue       = csr_era_pc;
assign csr_badv_rvalue      = csr_badv_vaddr;
assign csr_eentry_rvalue    = {csr_eentry_va, 6'b0};
assign csr_save0_rvalue     = csr_save0_data;
assign csr_save1_rvalue     = csr_save1_data;
assign csr_save2_rvalue     = csr_save2_data;
assign csr_save3_rvalue     = csr_save3_data;
assign csr_tid_rvalue       = csr_tid_tid;
assign csr_tcfg_rvalue      = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tval_rvalue      = csr_tval_timeval;
assign csr_ticlr_rvalue     = {31'b0, csr_ticlr_clr};
assign csr_tlbidx_rvalue    = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
assign csr_tlbehi_rvalue    = {csr_tlbehi_vppn, 13'b0};
assign csr_tlbelo0_rvalue   = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v}; 
assign csr_tlbelo1_rvalue   = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v}; 
assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0}; 
assign csr_asid_rvalue      = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};
assign csr_dmw0_rvalue      = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
assign csr_dmw1_rvalue      = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};

assign csr_rvalue = {32{csr_num == `CSR_CRMD  }}    & csr_crmd_rvalue
                  | {32{csr_num == `CSR_PRMD  }}    & csr_prmd_rvalue 
                  | {32{csr_num == `CSR_ECFG  }}    & csr_ecfg_rvalue
                  | {32{csr_num == `CSR_ESTAT }}    & csr_estat_rvalue
                  | {32{csr_num == `CSR_ERA   }}    & csr_era_rvalue
                  | {32{csr_num == `CSR_BADV  }}    & csr_badv_rvalue
                  | {32{csr_num == `CSR_EENTRY}}    & csr_eentry_rvalue
                  | {32{csr_num == `CSR_SAVE0 }}    & csr_save0_rvalue
                  | {32{csr_num == `CSR_SAVE1 }}    & csr_save1_rvalue
                  | {32{csr_num == `CSR_SAVE2 }}    & csr_save2_rvalue
                  | {32{csr_num == `CSR_SAVE3 }}    & csr_save3_rvalue
                  | {32{csr_num == `CSR_TID   }}    & csr_tid_rvalue
                  | {32{csr_num == `CSR_TCFG  }}    & csr_tcfg_rvalue
                  | {32{csr_num == `CSR_TVAL  }}    & csr_tval_rvalue
                  | {32{csr_num == `CSR_TICLR }}    & csr_ticlr_rvalue
                  | {32{csr_num == `CSR_TLBIDX}}    & csr_tlbidx_rvalue
                  | {32{csr_num == `CSR_TLBEHI}}    & csr_tlbehi_rvalue
                  | {32{csr_num == `CSR_TLBELO0}}   & csr_tlbelo0_rvalue
                  | {32{csr_num == `CSR_TLBELO1}}   & csr_tlbelo1_rvalue
                  | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                  | {32{csr_num == `CSR_ASID}}      & csr_asid_rvalue
                  | {32{csr_num == `CSR_DMW0}}      & csr_dmw0_rvalue
                  | {32{csr_num == `CSR_DMW1}}      & csr_dmw1_rvalue;

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

assign ex_entry = csr_eentry_rvalue;
assign ex_tlb_entry = csr_tlbrentry_rvalue;
assign era_entry = csr_era_rvalue;

//clock
reg [63:0] counter;
always @(posedge clk) begin
    if(reset) begin
        counter <= 64'b0;
    end
    else begin
        counter <= counter + 1'b1;
    end
end
assign rdcnt = counter;
assign tid_value = csr_tid_rvalue;

endmodule