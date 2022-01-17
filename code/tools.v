module decoder_2_4(
    input  [ 1:0] in,
    output [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  [ 3:0] in,
    output [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module fifo_buffer_r #(
    parameter DATA_WIDTH = 32,
    parameter BUFF_DEPTH = 5,
    parameter ADDR_WIDTH = 3
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full,
    input  [DATA_WIDTH - 1:0] input_data,
    output [DATA_WIDTH - 1:0] output_data
);
    
    reg [DATA_WIDTH - 1:0] buff [BUFF_DEPTH - 1:0];
    reg [ADDR_WIDTH - 1:0] head;
    reg [ADDR_WIDTH - 1:0] tail;
    reg [ADDR_WIDTH - 1:0] count;

    wire do_read;
    wire do_write;

    assign do_read  = ren && !empty;
    assign do_write = wen && !full;

    assign empty       = count == 0;
    assign full        = count == (BUFF_DEPTH - 1);
    assign output_data = buff[tail];

    always @(posedge clk ) begin
        if(!resetn) begin
            count <= 0;
        end
        else if(do_read && !do_write) begin
            count <= count - 1;
        end
        else if(!do_read && do_write) begin
            count <= count + 1;
        end
    end

    always @(posedge clk ) begin
        if(!resetn) begin
            head <= 0;
        end
        else if(do_write) begin
            if(head == (BUFF_DEPTH - 1)) begin
                head <= 0;
            end
            else begin
                head <= head + 1;
            end
        end
    end

    always @(posedge clk ) begin
        if(!resetn) begin
            tail <= 0;
        end
        else if(do_read) begin
            if(tail == (BUFF_DEPTH - 1)) begin
                tail <= 0;
            end
            else begin
                tail <= tail + 1;
            end
        end
    end

    genvar i;
    generate for (i = 0; i < BUFF_DEPTH; i = i + 1) begin:gen_buff
        always @ (posedge clk) begin
            if (!resetn) begin
                buff[i] <= 0;
            end else if (do_read && tail == i) begin
                buff[i] <= 0;
            end else if (do_write && head == i) begin
                buff[i] <= input_data;
            end
        end
    end endgenerate

endmodule

module fifo_buffer_w #(
    parameter BUFF_DEPTH = 5,
    parameter ADDR_WIDTH = 3
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full
);

    reg [ADDR_WIDTH - 1:0] count;

    wire do_read;
    wire do_write;
    
    assign do_read  = ren && !empty;
    assign do_write = wen && !full;

    assign empty       = count == 0;
    assign full        = count == (BUFF_DEPTH - 1);

    always @(posedge clk ) begin
        if(!resetn) begin
            count <= 0;
        end
        else if(do_read && !do_write) begin
            count <= count - 1;
        end
        else if(!do_read && do_write) begin
            count <= count + 1;
        end
    end
endmodule

module fifo_buffer_data #(
    parameter DATA_WIDTH = 33,
    parameter BUFF_DEPTH = 5,
    parameter ADDR_WIDTH = 3,
    parameter RELA_WIDTH = 32
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full,
    input  [DATA_WIDTH - 1:0] input_data, //address
    output [DATA_WIDTH - 1:0] output_data,
    output                    related,
    input  [RELA_WIDTH - 1:0] check_addr
);
    
    reg [DATA_WIDTH - 1:0] buff [BUFF_DEPTH - 1:0];
    reg [BUFF_DEPTH - 1:0] valid;
    reg [ADDR_WIDTH - 1:0] head;
    reg [ADDR_WIDTH - 1:0] tail;
    reg [ADDR_WIDTH - 1:0] count;

    wire [BUFF_DEPTH - 1: 0] related_valid;

    wire do_read;
    wire do_write;

    assign do_read  = ren && !empty;
    assign do_write = wen && !full;

    assign empty       = count == 0;
    assign full        = count == (BUFF_DEPTH - 1);
    assign output_data = buff[tail];
    assign related     = |related_valid;

    always @(posedge clk ) begin
        if(!resetn) begin
            count <= 0;
        end
        else if(do_read && !do_write) begin
            count <= count - 1;
        end
        else if(!do_read && do_write) begin
            count <= count + 1;
        end
    end

    always @(posedge clk ) begin
        if(!resetn) begin
            head <= 0;
        end
        else if(do_write) begin
            if(head == (BUFF_DEPTH - 1)) begin
                head <= 0;
            end
            else begin
                head <= head + 1;
            end
        end
    end

    always @(posedge clk ) begin
        if(!resetn) begin
            tail <= 0;
        end
        else if(do_read) begin
            if(tail == (BUFF_DEPTH - 1)) begin
                tail <= 0;
            end
            else begin
                tail <= tail + 1;
            end
        end
    end

    genvar i;
    generate for (i = 0; i < BUFF_DEPTH; i = i + 1) begin:gen_buff
        always @ (posedge clk) begin
            if (!resetn) begin
                buff[i]  <= 0;
                valid[i] <= 0;
            end else if (do_read && tail == i) begin
                buff[i]  <= 0;
                valid[i] <= 0;
            end else if (do_write && head == i) begin
                buff[i]  <= input_data;
                valid[i] <= 1;
            end
        end
    
        assign related_valid[i] = valid[i] && (related_valid == buff[i][RELA_WIDTH - 1:0]);
    end endgenerate
endmodule