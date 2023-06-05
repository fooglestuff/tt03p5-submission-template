module RAM(
	input CSn,
	input CLK,
	inout IO0,
	inout IO1,
	inout IO2,
	inout IO3
);

reg [7:0] memory [16*1024*1024-1:0];

wire [7:0] test_val = memory[200];

reg [3:0] output_enables = 4'h0;
reg [3:0] out_vals = 4'h0;

reg [7:0] DOUT = 0;
reg [3:0] step_counter = 0;
reg [7:0] DIN = 0;
reg [7:0] CMD = 0;
reg has_cmd = 0;
reg quad_mode = 0;
reg [1:0] address_step = 0;
reg [23:0] address = 0;
reg [3:0] delay_steps = 0;

assign IO0 = output_enables[0] ? out_vals[0] : 1'bz;
assign IO1 = output_enables[1] ? out_vals[1] : 1'bz;
assign IO2 = output_enables[2] ? out_vals[2] : 1'bz;
assign IO3 = output_enables[3] ? out_vals[3] : 1'bz;

always @(posedge CSn) begin
	if(CMD == 8'h35) begin
		quad_mode <= 1;
	end else if(CMD == 8'hF5) begin
		quad_mode <= 0;
	end
	
	delay_steps <= 0;
	address <= 0;
	address_step <= 0;
	has_cmd <= 0;
	step_counter <= 0;
	CMD <= 0;
	DIN <= 0;
	output_enables <= 4'h0;
	out_vals <= 4'h0;
end

always @(posedge CLK) begin
	if(!CSn) begin
		if(delay_steps > 0) begin
			delay_steps <= delay_steps - 1;
		end else begin
			if(CMD != 8'hEB || address_step != 0) begin
				step_counter <= step_counter + 1;
				if(quad_mode) begin
					case(step_counter)
						0: DIN[7:4] <= {IO3, IO2, IO1, IO0};
						1: DIN[3:0] <= {IO3, IO2, IO1, IO0};
					endcase
				end else begin
					DIN <= {DIN[6:0], IO0};
				end
			end
		end
	end
end

always @(negedge CLK) begin
	if(delay_steps == 0) begin
		if(CMD == 8'hEB && address_step == 0) begin
			step_counter <= step_counter + 1;
			if(quad_mode) begin
				out_vals <= DOUT[7:4];
				DOUT <= {DOUT[3:0], 4'h0};
			end else begin
				out_vals <= {2'b00, DOUT[7], 1'b0};
				DOUT <= {DOUT[6:0], 1'b0};
			end
		end
		if((quad_mode && step_counter == 2) || (!quad_mode && step_counter == 8)) begin
			step_counter <= 0;
			if(CMD == 8'hEB && address_step == 0) begin
				output_enables <= quad_mode ? 4'hF : 4'b0010;
				address <= address + 1;
				DOUT <= memory[address];
			end else begin
				if(!has_cmd) begin
					has_cmd <= 1;
					CMD <= DIN;
					if(quad_mode && DIN == 8'hEB) begin
						//Begin read
						address_step <= 1;
					end else if(quad_mode && DIN == 8'h38) begin
						//Begin write
						address_step <= 1;
					end
				end else if(address_step != 0) begin
					address_step <= address_step + 1;
					address = {address[15:0], DIN};
					if(address_step == 3 && CMD == 8'hEB) begin
						delay_steps <= 3;
					end
				end else if(CMD == 8'h38) begin
					address <= address + 1;
					memory[address] <= DIN;
				end
			end
		end
	end
end

endmodule
