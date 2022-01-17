
module mul(
    input [2:0] mul_op,// mul_op[1] : 1 signed 0 unsigned ;mul_op[0] : 1 hign 0 low
    input [31:0] mul_src1,
    input [31:0] mul_src2,
    output[31:0] mul_result
    );
    wire [32:0] src1;
    wire [32:0] src2;
    assign src1={33{ mul_op[1]}} & {mul_src1[31],mul_src1[31:0]}
               |{33{~mul_op[1]}} & {1'b0        ,mul_src1[31:0]};
    assign src2={33{ mul_op[1]}} & {mul_src2[31],mul_src2[31:0]}
               |{33{~mul_op[1]}} & {1'b0        ,mul_src2[31:0]};
    
    wire [65:0] prod;
    assign prod=$signed(src1) * $signed(src2);
    assign mul_result={32{ mul_op[0]}}&prod[63:32]
                     |{32{~mul_op[0]}}&prod[31: 0];
    
endmodule
module wallace_tree_mul(
    input mul_signed,
    input [31:0] x,
    input [31:0] y,
    output [65:0] A_add,
    output [65:0] B_add,
    output cin_add
    );
    wire [32:0] A;
    wire [33:0] B;
    wire [65:0] p [0:16];
    wire [65:0] e_A;
    wire [16:0]c;
    assign A={mul_signed&x[31],x[31:0]};
    assign B={{2{mul_signed&y[31]}},y[31:0]};
//  Booth*16
    assign e_A={{33{A[32]}},A[32:0]};
    booth b0(	
    	.y2(B[1]),
    	.y1(B[0]),
       	.y0(0),
    	.x(e_A),
    	.extend(0),
    	.p(p[0]),
    	.c(c[0])
    );    
    wire [5:0] extend[16:0];//error
    
    wire [5:0] label[16:0];
    genvar m;
    generate
        for(m=0;m<=16;m=m+1)
        begin: bit2
            assign extend[m]=m<<1;
        end
    endgenerate
    genvar n;
    generate
        for(n=1;n<=16;n=n+1)
        begin: bit3
            assign label[n]=n<<1;
        end
    endgenerate
    genvar i;
    generate
        for(i=1;i<=16;i=i+1)
        begin: booth
            booth b1(
                .y2(B[label[i]+1]),
                .y1(B[label[i]]),
                .y0(B[label[i]-1]),
                .x(e_A),
                .extend(extend[i]),
                .p(p[i]),
                .c(c[i])
            );
        end
    endgenerate 
    //switch
    wire[16:0] t_p[65:0];
    genvar j;
    generate
        for(j=0;j<=65;j=j+1)
        begin: bit 
           assign t_p[j][0]=p[0][j];
           assign t_p[j][1]=p[1][j];
           assign t_p[j][2]=p[2][j]; 
           assign t_p[j][3]=p[3][j]; 
           assign t_p[j][4]=p[4][j]; 
           assign t_p[j][5]=p[5][j]; 
           assign t_p[j][6]=p[6][j]; 
           assign t_p[j][7]=p[7][j]; 
           assign t_p[j][8]=p[8][j]; 
           assign t_p[j][9]=p[9][j]; 
           assign t_p[j][10]=p[10][j]; 
           assign t_p[j][11]=p[11][j]; 
           assign t_p[j][12]=p[12][j]; 
           assign t_p[j][13]=p[13][j]; 
           assign t_p[j][14]=p[14][j]; 
           assign t_p[j][15]=p[15][j]; 
           assign t_p[j][16]=p[16][j];
        end
    endgenerate
    wire [13:0] w_c[65:0];
    wire [65:0] S;
    wire [65:0] C;
    wallace w0(
        .n(t_p[0]),
        .cin(c[13:0]),
        .c(w_c[0]),
        .S(S[0]),
        .C(C[0])
    );
    genvar k;
    generate
        for(k=1;k<=65;k=k+1)
        begin:wallace
            wallace w_t(
                .n(t_p[k]),
                .cin(w_c[k-1]),
                .c(w_c[k]),
                .S(S[k]),
                .C(C[k])
            );
        end
    endgenerate
//   wire cin_add;
    assign B_add=S;
    assign A_add={C,c[14]};
    assign cin_add=c[15];
    
endmodule
module booth(
    input y2,
    input y1,
    input y0,
    input [65:0] x,
    input [5:0] extend,
    output [65:0] p,
    output c
);
    wire sub;
    wire sub2;
    wire add;
    wire add2;
    wire zero;
    wire [65:0] real_x;
    assign real_x=x<<extend;
    assign sub=(y2&y1&~y0)|(y2&~y1&y0);
    assign sub2=y2&~y1&~y0;
    assign add=(~y2&y1&~y0)|(~y2&~y1&y0);
    assign add2=~y2&y1&y0;
    assign zero= ~sub&~sub2&~add&~add2;
    wire [65:0] sub2_x;
    wire [65:0] add2_x;
    assign sub2_x={~real_x,1'b1};
    assign add2_x={real_x,1'b0};
    assign c=sub2|sub;
    assign p= ({66{sub}}&~real_x)|
              ({66{add}}&real_x)|
              ({66{sub2}}&sub2_x)|
              ({66{add2}}&add2_x)|
              ({66{zero}}&{66'b0});
    
              
endmodule
module adder(
    input A,
    input B,
    input cin,
    output sum,
    output cout
);
    assign sum=~A & ~B & cin | ~A & B & ~cin | A & ~B & ~cin | A & B & cin;
    assign cout=A & B | A & cin | B & cin;
    
endmodule
module h_adder(
    input A,
    input B,
    output sum,
    output cout
);
    assign sum=A&~B|~A&B;
    assign cout=A&B;
endmodule
module wallace(
    input [16:0] n,
    input [13:0] cin,//error cin c Á¬½Ó´íÎó
    output [13:0] c,
    output S,
    output C
);
    wire [13:0] s;
    wire [5:0] item [4:0];
     genvar i;
    //floor 1
    generate 
        for(i=0;i<=4;i=i+1)
        begin: bit4
            assign item[i]=i*3;
        end
    endgenerate   
    genvar l;
    //floor 1
    generate 
        for(l=0;l<=4;l=l+1)
        begin: adder
            adder a1(
                .A(n[item[l]]),
                .B(n[item[l]+1]),
                .cin(n[item[l]+2]),
                .sum(s[l]),
                .cout(c[l])
            );
        end
    endgenerate
    //floor 2
    adder a21(
        .A(s[0]),
        .B(s[1]),
        .cin(s[2]),
        .sum(s[5]),
        .cout(c[5])
    );
    adder a22(
        .A(s[3]),
        .B(s[4]),
        .cin(n[15]),
        .sum(s[6]),
        .cout(c[6])
    );
    adder a23(
        .A(n[16]),
        .B(cin[0]),
        .cin(cin[1]),
        .sum(s[7]),
        .cout(c[7])
    );
    adder a24(
        .A(cin[2]),
        .B(cin[3]),
        .cin(cin[4]),
        .sum(s[8]),
        .cout(c[8])
    );
    //floor 3
    adder a31(
        .A(s[5]),
        .B(s[6]),
        .cin(s[7]),
        .sum(s[9]),
        .cout(c[9])
    );
    adder a32(
        .A(s[8]),
        .B(cin[5]),
        .cin(cin[6]),
        .sum(s[10]),
        .cout(c[10])
    );
    adder a41(
        .A(s[9]),
        .B(s[10]),
        .cin(cin[7]),
        .sum(s[11]),
        .cout(c[11])
    );
    adder a42(
        .A(cin[8]),
        .B(cin[9]),
        .cin(cin[10]),
        .sum(s[12]),
        .cout(c[12])
    );
    adder a51(
        .A(s[11]),
        .B(s[12]),
        .cin(cin[11]),
        .sum(s[13]),
        .cout(c[13])
    );
    adder a61(
        .A(s[13]),
        .B(cin[12]),
        .cin(cin[13]),
        .sum(S),
        .cout(C)
    );
    
        
    
endmodule