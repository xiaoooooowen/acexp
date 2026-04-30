`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    // MEM 级前递/冒险检测输出。
    output [4:0] ms_to_ds_dest,
    output [31:0] mem_output
);

reg         ms_valid;    // MEM 级当前是否保存有效指令
wire        ms_ready_go;  // MEM 级是否准备好向下游发送

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r; // EX 级传入的控制与结果缓存
wire        ms_res_from_mem;  // 结果是否来自数据存储器
wire        ms_gr_we;         // 是否写通用寄存器
wire [ 4:0] ms_dest;          // 目的寄存器号
wire [31:0] ms_alu_result;    // EX 级 ALU 计算结果
wire [31:0] ms_pc;            // 指令 PC
assign {ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;       // 从数据存储器读出的数据
wire [31:0] ms_final_result;  // MEM 级最终写回数据

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };
assign ms_to_ds_dest = (ms_valid && ms_gr_we) ? ms_dest : 5'b0;
assign mem_output = ms_final_result;
assign ms_ready_go    = 1'b1;
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

assign mem_result = data_sram_rdata;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

endmodule
