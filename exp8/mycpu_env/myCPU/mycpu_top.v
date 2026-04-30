module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
// resetn 是外部低有效复位，这里转成流水级内部使用的高有效 reset。
reg         reset;  // 内部高有效复位信号
always @(posedge clk) reset <= ~resetn;

// 五级流水线握手信号：
// valid 表示本级保存的是有效指令，allowin 表示本级可以接收上一级的新指令。
wire         ds_allowin;      // ID 级允许接收信号
wire         es_allowin;      // EX 级允许接收信号
wire         ms_allowin;      // MEM 级允许接收信号
wire         ws_allowin;      // WB 级允许接收信号
wire         fs_to_ds_valid;  // IF 到 ID 的有效标志
wire         ds_to_es_valid;  // ID 到 EX 的有效标志
wire         es_to_ms_valid;  // EX 到 MEM 的有效标志
wire         ms_to_ws_valid;  // MEM 到 WB 的有效标志
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus; // IF->ID 打包总线
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus; // ID->EX 打包总线
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus; // EX->MEM 打包总线
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus; // MEM->WB 打包总线
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus; // WB->寄存器堆写回总线
wire [`BR_BUS_WD       -1:0] br_bus;       // ID->IF 分支总线
// EXP8 数据冒险检测：EX/MEM/WB 级把目的寄存器号回传给 ID 级。
wire [4:0] es_to_ds_dest; // EX 级目的寄存器号
wire [4:0] ms_to_ds_dest; // MEM 级目的寄存器号
wire [4:0] ws_to_ds_dest; // WB 级目的寄存器号

// 前递数据通路：后续流水级的计算结果回送到 ID 级参与源操作数选择。
wire [31:0] alu_output; // EX 级 ALU 前递数据
wire        ex_ld_w;    // EX 级当前是否为 load
wire [31:0] mem_output; // MEM 级前递数据
wire [31:0] wb_output;  // WB 级前递数据

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
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
    // 后续流水级目的寄存器号，用于 RAW 冒险检测。
    .es_to_ds_dest  (es_to_ds_dest  ),
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .ws_to_ds_dest  (ws_to_ds_dest  ),
    // 前递数据：EX/MEM/WB 级结果。
    .alu_output     (alu_output     ),
    .mem_output     (mem_output     ),
    .wb_output      (wb_output      ),
    .ex_ld_w        (ex_ld_w        )
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
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    // EX 级目的寄存器号和 ALU 结果，用于 ID 级前递/阻塞判断。
    .es_to_ds_dest  (es_to_ds_dest  ),
    .alu_output     (alu_output     ),
    .ex_ld_w        (ex_ld_w        )
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
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    // MEM 级写回目的寄存器号和最终结果，用于 ID 级前递。
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .mem_output     (mem_output     )
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
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    // WB 级目的寄存器号和写回数据，用于 ID 级前递。
    .ws_to_ds_dest  (ws_to_ds_dest  ),
    .wb_output      (wb_output      )
);

endmodule
