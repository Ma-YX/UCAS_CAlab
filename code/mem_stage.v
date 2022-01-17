`include "mycpu.h"

module mem_stage(
    input                          clk            ,
    input                          reset          ,
    //allowin
    input                          ws_allowin     ,
    output                         ms_allowin     ,
    //from es
    input                          es_to_ms_valid ,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus   ,
    //to ws
    output                         ms_to_ws_valid ,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus   ,
    //to es
    output                         ms_to_es_valid,
    //from data-sram
    input                          data_sram_data_ok,
    input  [31                 :0] data_sram_rdata,
    //raw signals: to ds
    output  [`RAW_BUS_WD      -1:0] raw_ms_bus,
    output                          blk_ms_load
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_ex;
wire        ms_mem_we;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_alu_result_t;
wire [31:0] ms_pc;
wire [2:0]  ms_load_op;
wire [1:0]  lb_sle;  
wire [2:0]  ms_mul_op;
wire [65:0] ms_mul_add1;
wire [65:0] ms_mul_add2;
wire ms_mul_cin;
wire [65:0] prod;
wire [31:0] ms_mul_result;
assign {ms_ex          ,
        ms_mem_we      ,
        ms_mul_op      ,
        ms_mul_add1    ,
        ms_mul_add2    ,
        ms_mul_cin     ,
        lb_sle         ,  //75:74
        ms_load_op     ,  //73:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result_t,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;
assign prod=ms_mul_add1+ms_mul_add2+ms_mul_cin;
assign ms_mul_result={32{ ms_mul_op[0]}}&prod[63:32] 
          |{32{~ms_mul_op[0]}}&prod[31: 0];
assign ms_alu_result=(|ms_mul_op)?ms_mul_result:
                                  ms_alu_result_t;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
wire [7:0] load_datab_1;
wire [7:0] load_datab_2;
wire [7:0] load_datab_3;
wire [7:0] load_datab_4; 
wire [16:0] load_datah_1;
wire [16:0] load_datah_2;
wire [31:0] load_data_true_b;
wire [31:0] load_data_true_h;
assign load_datab_1=data_sram_rdata[7:0];
assign load_datab_2=data_sram_rdata[15:8];
assign load_datab_3=data_sram_rdata[23:16];
assign load_datab_4=data_sram_rdata[31:24];
assign load_datah_1=data_sram_rdata[15:0];
assign load_datah_2=data_sram_rdata[31:16];
wire [1:0]sh_wen;
wire [3:0]sb_wen;
assign sb_wen={lb_sle[1]&lb_sle[0],~lb_sle[0]&lb_sle[1],lb_sle[0]&~lb_sle[1],~lb_sle[0]&~lb_sle[1]};
assign sh_wen={~lb_sle[0]&lb_sle[1],~lb_sle[0]&~lb_sle[1]};
assign load_data_true_b = {32{sb_wen[0]}}&{4{load_datab_1}}
                         |{32{sb_wen[1]}}&{4{load_datab_2}}
                         |{32{sb_wen[2]}}&{4{load_datab_3}}
                         |{32{sb_wen[3]}}&{4{load_datab_4}}; 
assign load_data_true_h = {32{sh_wen[0]}}&{2{load_datah_1}}
                         |{32{sh_wen[1]}}&{2{load_datah_2}};
assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

wire   raw_ms_valid;
assign raw_ms_valid = ms_gr_we & ms_valid;
assign raw_ms_bus = {raw_ms_valid   ,  //37:37
                     ms_dest        ,  //36:32
                     ms_final_result  //31:0
                    };
assign blk_ms_load = ms_res_from_mem && ~ms_to_ws_valid;
assign ms_to_es_valid = ms_valid;
assign ms_ready_go    = ((ms_mem_we||ms_res_from_mem)&~ms_ex)?data_sram_data_ok :  1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign mem_result = {32{ms_load_op[2]}} & data_sram_rdata
                   |{32{~ms_load_op[2]& ms_load_op[1]& ms_load_op[0]}} & {16'b0,load_data_true_h[15:0]}
                   |{32{~ms_load_op[2]& ms_load_op[1]&~ms_load_op[0]}} & {24'b0,load_data_true_b[ 7:0]}
                   |{32{~ms_load_op[2]& ~ms_load_op[1]& ms_load_op[0]}} & {{16{load_data_true_h[15]}},load_data_true_h[15:0]}
                   |{32{~ms_load_op[2]& ~ms_load_op[1]&~ms_load_op[0]}} & {{24{load_data_true_b[ 7]}},load_data_true_b[7:0]};
                   

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

endmodule
