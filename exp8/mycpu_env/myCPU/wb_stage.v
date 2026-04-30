`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    // WB 级写回信息同时用于寄存器堆写入和 ID 级前递。
    output [4:0] ws_to_ds_dest,
    output [31:0] wb_output
);

reg         ws_valid;    // WB 级当前是否保存有效指令
wire        ws_ready_go;  // WB 级是否准备好向前推进

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r; // MEM 级传入的写回信息缓存
wire        ws_gr_we;         // 是否写通用寄存器
wire [ 4:0] ws_dest;          // 写回目的寄存器号
wire [31:0] ws_final_result;  // 最终写回数据
wire [31:0] ws_pc;            // 当前指令 PC
assign {ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;      // 寄存器堆写使能
wire [4 :0] rf_waddr;   // 寄存器堆写地址
wire [31:0] rf_wdata;   // 寄存器堆写数据
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };
assign ws_to_ds_dest = (ws_valid && ws_gr_we) ? ws_dest : 5'b0;
assign wb_output = ws_final_result;
assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// Trace debug 接口给 testbench 对拍使用，不参与 CPU 内部控制。
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
