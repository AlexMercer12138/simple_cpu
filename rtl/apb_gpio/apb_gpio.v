`timescale 1ns/1ps
module apb_gpio #(
    parameter GPIO_WIDTH = 32
)(
    input  wire        s_apb_pclk,
    input  wire        s_apb_presetn,
    input  wire        s_apb_psel,
    input  wire        s_apb_penable,
    input  wire        s_apb_pwrite,
    input  wire [31:0] s_apb_paddr,
    input  wire [31:0] s_apb_pwdata,
    input  wire [3:0]  s_apb_pstrb,
    output wire        s_apb_pready,
    output wire        s_apb_pslverr,
    output wire [31:0] s_apb_prdata,
    input  wire [GPIO_WIDTH-1:0] gpio_i,
    output wire [GPIO_WIDTH-1:0] gpio_o,
    output wire [GPIO_WIDTH-1:0] gpio_t,
    output wire        interrupt
);
wire _1_;wire _2_;wire[9:0]_3_;wire _4_;wire _5_;wire _6_;wire _7_;wire _8_;wire[31:0]_9_;wire _10_;wire _11_;wire[31:0]_12_;wire[31:0]_13_;wire[31:0]_14_;wire _15_;wire _16_;reg _17_;reg[31:0]_18_;reg[31:0]_19_;reg[31:0]_20_;reg[31:0]_21_;reg[31:0]_22_;reg[1:0]_23_;reg[31:0]_24_;reg _25_;reg[2:0]_26_;reg[31:0]_27_;reg[31:0]_28_;reg[31:0]_29_;reg[GPIO_WIDTH-1:0]_30_;reg[31:0]_31_[0:GPIO_WIDTH-1];genvar _32_;assign _1_=s_apb_pclk;assign _2_=s_apb_presetn;assign _3_=s_apb_paddr[11:2];assign _4_=s_apb_psel&&!s_apb_penable;assign _13_={{8{s_apb_pstrb[3]}},{8{s_apb_pstrb[2]}},{8{s_apb_pstrb[1]}},{8{s_apb_pstrb[0]}}};assign _14_=s_apb_pwdata&_13_;assign _15_=|s_apb_pstrb;assign _5_=s_apb_psel&&s_apb_penable&&s_apb_pwrite&&_17_&&_15_;assign _6_=_5_&&(_3_==10'd0)&&s_apb_pstrb[3];assign _7_=_6_&&_14_[31];assign s_apb_pready=_17_;assign s_apb_pslverr=1'b0;assign s_apb_prdata=_18_;assign gpio_o=_20_[GPIO_WIDTH-1:0];assign gpio_t=~_19_[GPIO_WIDTH-1:0];assign _8_=_23_[1];assign _9_=!_8_ ? 32'd0 : (_29_==32'd0) ? _22_ : _30_;assign _16_=_5_&&(_3_==10'd10);assign _10_=_5_&&(_3_==10'd7)&&s_apb_pstrb[0];assign _11_=_5_&&(_3_==10'd9);assign _12_=(_8_&&!_10_) ? (~_19_&_33_(_26_,_9_,_24_,_25_)) : 32'd0;assign interrupt=|(_28_&_27_);function[31:0]_33_;input[2:0]_34_;input[31:0]_35_;input[31:0]_36_;input _37_;begin case(_34_)3'd0: _33_=~_35_;3'd1: _33_=_35_;3'd2: _33_=_37_ ? _35_&~_36_ : 32'd0;3'd3: _33_=_37_ ? ~_35_&_36_ : 32'd0;3'd4: _33_=_37_ ? _35_^_36_ : 32'd0;default: _33_=32'd0;endcase end endfunction always@(posedge _1_)begin if(!_2_)_17_<=1'b0;else if(s_apb_psel&&_17_)_17_<=1'b0;else if(s_apb_psel)_17_<=1'b1;else _17_<=1'b0;end always@(posedge _1_)begin if(!_2_||_7_)begin _18_<=32'd0;end else if(_4_)begin case(_3_)10'd0: _18_<=32'd0;10'd1: _18_<=_19_;10'd2: _18_<=_20_;10'd3: _18_<=32'd0;10'd4: _18_<=32'd0;10'd5: _18_<=32'd0;10'd6: _18_<=_9_;10'd7: _18_<={29'd0,_26_};10'd8: _18_<=_27_;10'd9: _18_<=_28_;10'd10: _18_<=_29_;default: _18_<=32'd0;endcase end end always@(posedge _1_)begin _21_<=gpio_i;_22_<=_21_;end always@(posedge _1_)begin if(!_2_||_7_)_23_<=2'b00;else _23_<={_23_[0],1'b1};end always@(posedge _1_)begin if(!_2_||_7_)_29_<=32'd0;else if(_16_)_29_<=(_29_&~_13_)|_14_;end generate for(_32_=0;_32_<GPIO_WIDTH;_32_=_32_+1)begin : _38_ always@(posedge _1_)begin if(!_2_||_7_||!_8_)begin _30_[_32_]<=1'b0;_31_[_32_]<=32'd0;end else if(_16_||(_29_==32'd0))begin _30_[_32_]<=_9_[_32_];_31_[_32_]<=32'd0;end else if(_22_[_32_]==_30_[_32_])begin _31_[_32_]<=32'd0;end else if(_31_[_32_]==_29_-32'd1)begin _30_[_32_]<=_22_[_32_];_31_[_32_]<=32'd0;end else begin _31_[_32_]<=_31_[_32_]+32'd1;end end end endgenerate always@(posedge _1_)begin if(!_2_||_7_)begin _19_<=32'd0;_20_<=32'd0;end else if(_5_)begin case(_3_)10'd1: _19_<=(_19_&~_13_)|_14_;10'd2: _20_<=(_20_&~_13_)|_14_;10'd3: _20_<=_20_|_14_;10'd4: _20_<=_20_&~_14_;10'd5: _20_<=_20_^_14_;default: begin end endcase end end always@(posedge _1_)begin if(!_2_||_7_)begin _26_<=3'd7;_27_<=32'd0;end else if(_5_)begin case(_3_)10'd7: _26_<=(_26_&~_13_[2:0])|_14_[2:0];10'd8: _27_<=(_27_&~_13_)|_14_;default: begin end endcase end end always@(posedge _1_)begin if(!_2_||_7_)begin _24_<=32'd0;_25_<=1'b0;end else if(_8_)begin _24_<=_9_;_25_<=1'b1;end end always@(posedge _1_)begin if(!_2_||_7_)begin _28_<=32'd0;end else if(_10_)begin _28_<=32'd0;end else begin _28_<=(_28_&~(_11_ ? _14_ : 32'd0))|_12_;end end
endmodule
