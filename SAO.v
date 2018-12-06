`timescale 1ns/10ps

module SAO ( clk, reset, in_en, din, sao_type, sao_band_pos, sao_eo_class, sao_offset, lcu_x, lcu_y, lcu_size, busy, finish);
input   clk;
input   reset;
input   in_en;
input   [7:0]  din;
input   [1:0]  sao_type;
input   [4:0]  sao_band_pos;
input          sao_eo_class;
input   [15:0] sao_offset;
input   [2:0]  lcu_x;
input   [2:0]  lcu_y;
input   [1:0]  lcu_size;
output  busy;
output  finish;

wire cen;
wire wen;
wire [13:0] addr;
wire [7:0] m_out;
wire [7:0] buffer_i;
wire [7:0] above_i;
wire [7:0] below_i;
wire [7:0] read_i;

reg done;
reg nextdone;
reg [1:0] count;
reg [1:0] nextcount;
reg [1:0] state;
reg [1:0] nextstate;
reg [1:0] buffer_y;
reg [1:0] nextbuffer_y;
reg [1:0] read_y;
reg [1:0] nextread_y;
reg [5:0] buffer_x;
reg [5:0] nextbuffer_x;
reg [6:0] lcu_width;
reg [6:0] write_x;
reg [6:0] nextwrite_x;
reg [6:0] write_y;
reg [6:0] nextwrite_y;
reg [7:0] m_in;
reg [7:0] bo;
reg [7:0] eo;
//reg [7:0] last;
//wire [7:0] nextlast;
reg [7:0] buffer [0:191];
reg [7:0] nextbuffer [0:191];

integer i;

parameter FIRST = 2'b00;
parameter INIT = 2'b01;
parameter READ = 2'b10;
parameter FILT = 2'b11;

  sram_16384x8 golden_sram(.Q(m_out), .CLK(clk), .CEN(cen), .WEN(wen), .A(addr), .D(m_in)); 

assign cen = wen;
assign wen = state != FILT;
assign buffer_i = buffer_y*lcu_width + buffer_x;
assign read_i = read_y*lcu_width + write_x;
assign addr = (lcu_y*lcu_width + write_y)*128 + lcu_x*lcu_width + write_x;
assign busy = state == FIRST || (((nextstate == FILT && write_y == lcu_width-2) || state == FILT) && sao_type == 2'd2 && nextstate != FIRST); 
assign above_i = read_y == 0 ? 2*lcu_width+write_x : read_i-lcu_width;
assign below_i = read_y == 2 ? write_x : read_i+lcu_width;
assign finish = count ==3;//state == FILT && nextstate == FIRST && (lcu_x+1)*lcu_width == 128 && (lcu_y+1)*lcu_width == 128;

//assign nextlast = din;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		state <= INIT;
		count <= 0;
		buffer_x <= 0;
		buffer_y <= 0;
		write_x <= 0;
		write_y <= 127;
		read_y <= 0;
		done <= 0;
		for (i = 0; i <= 191; i = i + 1) begin
			buffer[i] <= 0;
		end
	end else begin
		state <= nextstate;
		count <= nextcount;
		buffer_x <= nextbuffer_x;
		buffer_y <= nextbuffer_y;
		write_x <= nextwrite_x;
		write_y <= nextwrite_y;
		read_y <= nextread_y;
		done <= nextdone;
		for (i = 0; i <= 191; i = i + 1) begin
			buffer[i] <= nextbuffer[i];
		end
	end
end

/*always @(negedge clk) begin
	last <= nextlast;
end*/
    
always @(*) begin
	case (state)
		FIRST: 	if(!in_en) nextstate = FIRST;
				else if (sao_type == 2'd2) nextstate = INIT;
				else nextstate = FILT;
		INIT: 	if (buffer_i == 2*lcu_width-1) nextstate = FILT;
				else if(write_y == 127) nextstate = FIRST;
				else nextstate = INIT;
		READ:	if (buffer_x == lcu_width-1)nextstate = FILT;
				else nextstate = READ;
		FILT: 	if (write_x == lcu_width-1 && write_y == lcu_width-1)nextstate = FIRST;
				else if(write_x == lcu_width-1 && sao_type==2'd2 && write_y < lcu_width-2) nextstate = READ;
				else nextstate = FILT;
	endcase 
end

always @(*) begin
	nextbuffer_x = buffer_x;
	nextbuffer_y = buffer_y;
	nextwrite_x = write_x;
	nextwrite_y = write_y;
	nextread_y = read_y;
	nextdone = done;
	nextcount = count;
	for (i = 0; i <= 191; i = i + 1) begin
		nextbuffer[i] = buffer[i];
	end
	case (state)
		FIRST:	begin
					nextbuffer_x = 0;
					nextbuffer_y = 0;
					nextwrite_x = 0; 	
					nextwrite_y = 0; 	
					nextread_y = 0;
					nextcount = count+1;
				end
		INIT:	begin
					nextbuffer[buffer_i] = din;
					nextbuffer_x = buffer_x == lcu_width-1 ? 0 : buffer_x+1;
					nextbuffer_y = buffer_x == lcu_width-1 ? buffer_y+1 : buffer_y;
				end
		READ:	begin
					nextbuffer[buffer_i] = din;
					nextbuffer_x = buffer_x == lcu_width-1 ? 0 : buffer_x+1;
					if(buffer_x == lcu_width-1 && buffer_y != 2) nextbuffer_y = buffer_y+1;
					else if(buffer_x == lcu_width-1 && buffer_y == 2) nextbuffer_y = 0;
				end
		FILT: 	begin
					nextcount = 0;
					nextwrite_x = write_x == lcu_width-1 ? 0 : write_x+1;
					nextwrite_y = write_x == lcu_width-1 ? write_y+1 : write_y;
					if(sao_type == 2'd2) begin
						if(write_x == lcu_width-1 && read_y != 2) nextread_y = read_y+1;
						else if(write_x == lcu_width-1 && read_y == 2) nextread_y = 0; 
					end
					if(write_x == lcu_width-1 && write_y == lcu_width-1 && (lcu_x+1)*lcu_width == 128 && (lcu_y+1)*lcu_width == 128)nextdone = 1;
				end
	endcase  
end

//Input Data
always @(*) begin 
	case (sao_type)
		2'd1:	if(din >= 245 && bo <= 10)m_in = 255;
				else if(din <= 10 && bo >= 245)m_in = 0;
				else m_in = bo;
		2'd2:	if(buffer[read_i] >= 245 && eo <= 10)m_in = 255;
				else if(buffer[read_i] <= 10 && eo >= 245)m_in = 0;
				else m_in = eo;
		default: m_in = din;
	endcase
end
	 
//Band Offset
always @(*) begin
	if (din >= sao_band_pos*8 && din <= sao_band_pos*8 + 7) bo = din + {{4{sao_offset[15]}}, sao_offset[15:12]};
	else if (din >= sao_band_pos*8 + 8 && din <= sao_band_pos*8 + 15) bo = din + {{4{sao_offset[11]}}, sao_offset[11:8]};
	else if (din >= sao_band_pos*8 + 16 && din <= sao_band_pos*8 + 23) bo = din + {{4{sao_offset[7]}}, sao_offset[7:4]};
	else if (din >= sao_band_pos*8 + 24 && din <= sao_band_pos*8 + 31) bo = din + {{4{sao_offset[3]}}, sao_offset[3:0]};
	else bo = din;
end

//Edge Offset
always @(*) begin
	case (sao_eo_class)
		1'b0:	if(write_x == 0 || write_x == lcu_width-1) eo = buffer[read_i];
				else if (buffer[read_i]<buffer[read_i-1] && buffer[read_i]<buffer[read_i+1])eo = buffer[read_i]+{{4{sao_offset[15]}}, sao_offset[15:12]};
				else if ((buffer[read_i]<buffer[read_i-1] && buffer[read_i]==buffer[read_i+1]) || (buffer[read_i]==buffer[read_i-1] && buffer[read_i]<buffer[read_i+1]))eo = buffer[read_i]+{{4{sao_offset[11]}}, sao_offset[11:8]};
				else if ((buffer[read_i]>buffer[read_i-1] && buffer[read_i]==buffer[read_i+1]) || (buffer[read_i]==buffer[read_i-1] && buffer[read_i]>buffer[read_i+1]))eo = buffer[read_i]+{{4{sao_offset[7]}}, sao_offset[7:4]};
				else if (buffer[read_i]>buffer[read_i-1] && buffer[read_i]>buffer[read_i+1])eo = buffer[read_i]+{{4{sao_offset[3]}}, sao_offset[3:0]};
				else eo = buffer[read_i];
		1'b1:	if(write_y == 0 || write_y == lcu_width-1) eo = buffer[read_i];
				else if (buffer[read_i]<buffer[below_i] && buffer[read_i]<buffer[above_i])eo = buffer[read_i]+{{4{sao_offset[15]}}, sao_offset[15:12]};
				else if ((buffer[read_i]<buffer[below_i] && buffer[read_i]==buffer[above_i]) || (buffer[read_i]==buffer[below_i] && buffer[read_i]<buffer[above_i]))eo = buffer[read_i]+{{4{sao_offset[11]}}, sao_offset[11:8]};
				else if ((buffer[read_i]>buffer[below_i] && buffer[read_i]==buffer[above_i]) || (buffer[read_i]==buffer[below_i] && buffer[read_i]>buffer[above_i]))eo = buffer[read_i]+{{4{sao_offset[7]}}, sao_offset[7:4]};
				else if (buffer[read_i]>buffer[below_i] && buffer[read_i]>buffer[above_i])eo = buffer[read_i]+{{4{sao_offset[3]}}, sao_offset[3:0]};
				else eo = buffer[read_i];
		default: eo = buffer[read_i];
	endcase
end

always @(*) begin
	case (lcu_size)
		2'd0:	lcu_width = 16;
		2'd1:	lcu_width = 32;
		2'd2:	lcu_width = 64;
		default:lcu_width = 16;
	endcase
end	
	
endmodule

