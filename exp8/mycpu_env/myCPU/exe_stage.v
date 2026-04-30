`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    // 流水线允许信号
    input                          ms_allowin    ,
    output                         es_allowin    ,
    // 来自译码级
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    // 发送到访存级
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // 数据 SRAM 接口
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    // 传给 ID 级的目的寄存器号，用于数据冒险判断
    output [4:0] es_to_ds_dest,
    // EX 级可前递的数据，以及当前 EX 指令是否为 load
    output [31:0] alu_output,
    output        ex_ld_w
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
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

wire        es_res_from_mem;

assign {es_alu_op      ,  // 149:138
    es_res_from_mem,  // 137:137，是否从数据存储器取结果
    es_src1_is_pc  ,  // 136:136，ALU 源操作数 1 是否选 PC
    es_src2_is_imm ,  // 135:135，ALU 源操作数 2 是否选立即数
    es_gr_we       ,  // 134:134，是否写通用寄存器
    es_mem_we      ,  // 133:133，是否写数据存储器
    es_dest        ,  // 132:128，目的寄存器号
    es_imm         ,  // 127:96，立即数
    es_rj_value    ,  // 95:64，rj 寄存器值
    es_rkd_value   ,  // 63:32，rk/rd 寄存器值
    es_pc             // 31:0，当前指令 PC
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

//assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  // 70:70
                       es_gr_we       ,  // 69:69
                       es_dest        ,  // 68:64
                       es_alu_result  ,  // 63:32
                       es_pc             // 31:0
                      };
assign es_to_ds_dest = (es_valid && es_gr_we) ? es_dest : 5'b0;
assign alu_output = es_alu_result;
assign ex_ld_w    = es_res_from_mem;
assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
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

assign data_sram_en    = (es_res_from_mem || es_mem_we) && es_valid;
assign data_sram_wen   = es_mem_we ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;

endmodule
