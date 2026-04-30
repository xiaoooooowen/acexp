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
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    // 后续流水级目的寄存器号，用于 RAW 冒险检测。
    input [4:0] es_to_ds_dest,
    input [4:0] ms_to_ds_dest,
    input [4:0] ws_to_ds_dest,

    // 前递数据：分别来自 EX/MEM/WB 级。
    input [31:0] alu_output,    // EX 级 ALU 结果
    input [31:0] mem_output,    // MEM 级最终结果
    input [31:0] wb_output,     // WB 级写回数据
    input        ex_ld_w         // EX 级当前指令是否为 load
);

reg         ds_valid   ;  // ID 级当前是否保存有效指令
wire        ds_ready_go;  // ID 级是否已经准备好向下游流动

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;  // IF 级送来的指令与 PC 缓存

wire [31:0] ds_inst;      // 当前译码的指令
wire [31:0] ds_pc  ;      // 当前指令对应的 PC
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;     // 寄存器堆写使能
wire [ 4:0] rf_waddr;     // 寄存器堆写地址
wire [31:0] rf_wdata;     // 寄存器堆写数据
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;     // 当前指令是否需要跳转/分支
wire [31:0] br_target;    // 跳转目标地址

wire [11:0] alu_op;       // 发给 ALU 的运算控制码
wire        load_op;      // 是否为 load 指令
wire        src1_is_pc;   // ALU 源操作数 1 是否选择 PC
wire        src2_is_imm;  // ALU 源操作数 2 是否选择立即数
wire        res_from_mem; // 结果是否来自数据存储器
wire        dst_is_r1;    // 目的寄存器是否固定为 r1
wire        gr_we;        // 通用寄存器写使能
wire        mem_we;       // 数据存储器写使能
wire        src_reg_is_rd;// 第二源寄存器是否使用 rd 字段
wire [4: 0] dest;         // 目的寄存器号
wire [31:0] rj_value;     // 源寄存器 rj 的值
wire [31:0] rkd_value;    // 第二源操作数的值
wire [31:0] ds_imm;       // 当前指令的立即数
wire [31:0] br_offs;      // 分支偏移量
wire [31:0] jirl_offs;    // jirl 偏移量

wire [ 5:0] op_31_26;    // 指令最高 6 位 opcode
wire [ 3:0] op_25_22;    // 指令第 25:22 位字段
wire [ 1:0] op_21_20;    // 指令第 21:20 位字段
wire [ 4:0] op_19_15;    // 指令第 19:15 位字段
wire [ 4:0] rd;          // rd 字段
wire [ 4:0] rj;          // rj 字段
wire [ 4:0] rk;          // rk 字段
wire [11:0] i12;         // 12 位立即数字段
wire [19:0] i20;         // 20 位立即数字段
wire [15:0] i16;         // 16 位立即数字段
wire [25:0] i26;         // 26 位立即数字段

wire [63:0] op_31_26_d;  // 6 位译码结果
wire [15:0] op_25_22_d;  // 4 位译码结果
wire [ 3:0] op_21_20_d;  // 2 位译码结果
wire [31:0] op_19_15_d;  // 5 位译码结果

wire        inst_add_w;   // add.w
wire        inst_sub_w;   // sub.w
wire        inst_slt;     // slt
wire        inst_sltu;    // sltu
wire        inst_nor;     // nor
wire        inst_and;     // and
wire        inst_or;      // or
wire        inst_xor;     // xor
wire        inst_slli_w;  // slli.w
wire        inst_srli_w;  // srli.w
wire        inst_srai_w;  // srai.w
wire        inst_addi_w;  // addi.w
wire        inst_ld_w;    // ld.w
wire        inst_st_w;    // st.w
wire        inst_jirl;    // jirl
wire        inst_b;       // b
wire        inst_bl;      // bl
wire        inst_beq;     // beq
wire        inst_bne;     // bne
wire        inst_lu12i_w; // lu12i.w

wire        need_ui5;    // 需要无符号 5 位立即数
wire        need_si12;   // 需要有符号 12 位立即数
wire        need_si16;   // 需要有符号 16 位立即数
wire        need_si20;   // 需要有符号 20 位立即数
wire        need_si26;   // 需要有符号 26 位立即数
wire        src2_is_4;   // 第二操作数是否固定为 4

wire [ 4:0] rf_raddr1;   // 寄存器堆读端口 1 地址
wire [31:0] rf_rdata1;   // 寄存器堆读端口 1 数据
wire [ 4:0] rf_raddr2;   // 寄存器堆读端口 2 地址
wire [31:0] rf_rdata2;   // 寄存器堆读端口 2 数据

wire        rj_eq_rd;    // rj 与第二操作数是否相等
// 源寄存器使用情况。只对真正被当前指令使用的寄存器做冒险判断，
// 避免把立即数字段或无关字段误判成 RAW 冲突。
wire rj_use;      // 当前指令是否使用 rj
wire rk_use;      // 当前指令是否使用 rk
wire rd_use;      // 当前指令是否使用 rd
wire load_hazard; // load-use 冒险标志

assign rj_use = inst_add_w || inst_addi_w || inst_sub_w || inst_slt || inst_sltu || 
                inst_slli_w || inst_srli_w || inst_srai_w || inst_and || inst_or || 
                inst_nor || inst_xor || inst_beq || inst_bne || inst_jirl || 
                inst_ld_w || inst_st_w;

assign rk_use = inst_add_w || inst_sub_w || inst_slt || inst_sltu || 
                inst_and || inst_or || inst_nor || inst_xor;

assign rd_use = inst_beq || inst_bne || inst_st_w;

// 前递优先级：EX > MEM > WB > 寄存器堆。
// EX 级如果是 load，数据还没有从数据 RAM 返回，不能直接前递。
wire [31:0] rj_value_forwarding; // rj 的前递后结果
assign rj_value_forwarding = 
    (es_to_ds_dest != 5'b0 && rj == es_to_ds_dest && !ex_ld_w) ? alu_output :
    (ms_to_ds_dest != 5'b0 && rj == ms_to_ds_dest) ? mem_output :
    (ws_to_ds_dest != 5'b0 && rj == ws_to_ds_dest) ? wb_output  :
    rf_rdata1;

wire [31:0] rk_value_forwarding; // rk 的前递后结果
assign rk_value_forwarding = 
    (es_to_ds_dest != 5'b0 && rk == es_to_ds_dest && !ex_ld_w) ? alu_output :
    (ms_to_ds_dest != 5'b0 && rk == ms_to_ds_dest) ? mem_output :
    (ws_to_ds_dest != 5'b0 && rk == ws_to_ds_dest) ? wb_output  :
    rf_rdata2;

wire [31:0] rd_value_forwarding; // rd 的前递后结果
assign rd_value_forwarding = 
    (es_to_ds_dest != 5'b0 && rd == es_to_ds_dest && !ex_ld_w) ? alu_output :
    (ms_to_ds_dest != 5'b0 && rd == ms_to_ds_dest) ? mem_output :
    (ws_to_ds_dest != 5'b0 && rd == ws_to_ds_dest) ? wb_output  :
    rf_rdata2;

// 第二个源操作数根据指令类型选择 rk 或 rd。
assign rkd_value = rk_use ? rk_value_forwarding : rd_value_forwarding;
assign rj_value  = rj_value_forwarding;

// load-use 冒险：load 指令在 EX 级时数据尚未返回，
// 下一条依赖它的指令必须在 ID 级暂停一拍。
assign load_hazard = ex_ld_w && 
    ((rj_use && es_to_ds_dest != 5'b0 && rj == es_to_ds_dest) ||
     (rk_use && es_to_ds_dest != 5'b0 && rk == es_to_ds_dest) ||
     (rd_use && es_to_ds_dest != 5'b0 && rd == es_to_ds_dest)) ? 1'b1 : 1'b0;

wire [4:0] rf_raddr1_tmp = rj;              // 便于观察的读地址 1
wire [4:0] rf_raddr2_tmp = src_reg_is_rd ? rd : rk;  // 便于观察的读地址 2

// 保留 raw_conflict 便于波形观察；当前真正阻塞流水线的是 load_hazard。
wire raw_conflict;  // 原始 RAW 冲突标志，仅用于观察
assign raw_conflict = (ds_valid && (rf_raddr1_tmp != 5'b0) && 
                       ((rf_raddr1_tmp == es_to_ds_dest) ||
                        (rf_raddr1_tmp == ms_to_ds_dest) ||
                        (rf_raddr1_tmp == ws_to_ds_dest)))
                   || (ds_valid && (rf_raddr2_tmp != 5'b0) && 
                       ((rf_raddr2_tmp == es_to_ds_dest) ||
                        (rf_raddr2_tmp == ms_to_ds_dest) ||
                        (rf_raddr2_tmp == ws_to_ds_dest)));

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {alu_op      ,  //149:138，ALU 控制码
                       load_op     ,  //137:137，是否为 load 指令
                       src1_is_pc  ,  //136:136，ALU 源操作数 1 是否选 PC
                       src2_is_imm ,  //135:135，ALU 源操作数 2 是否选立即数
                       gr_we       ,  //134:134，是否写通用寄存器
                       mem_we      ,  //133:133，是否写数据存储器
                       dest        ,  //132:128，目的寄存器号
                       ds_imm      ,  //127:96，立即数
                       rj_value    ,  //95 :64，rj 的值
                       rkd_value   ,  //63 :32，rk/rd 的值
                       ds_pc          //31 :0，当前指令 PC
                      };

// ID 级只有在没有 load-use 冒险时才允许继续向 EX 级流动。
assign ds_ready_go = !load_hazard;

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (br_taken && !load_hazard) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
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

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

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

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign load_op = inst_ld_w;//change411

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


assign ds_imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
  /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;


assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

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


//assign rj_value  = rf_rdata1;
//assign rkd_value = rf_rdata2;
assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

endmodule
