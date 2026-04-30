module regfile(
    input         clk,
    // 读端口 1
    input  [ 4:0] raddr1,
    output [31:0] rdata1,
    // 读端口 2
    input  [ 4:0] raddr2,
    output [31:0] rdata2,
    // 写端口
    input         we,       // 写使能，高电平有效
    input  [ 4:0] waddr,    // 写地址
    input  [31:0] wdata     // 写数据
);
reg [31:0] rf[31:0];        // 32 个通用寄存器

// 写寄存器
always @(posedge clk) begin
    if (we) rf[waddr]<= wdata;
end

// 读出端口 1
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[raddr1];

// 读出端口 2
assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[raddr2];

endmodule
