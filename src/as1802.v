`default_nettype none

module tt_um_as1802 #(parameter DFFRAM_SIZE = 128)(
  input [7:0] ui_in,
  output [7:0] uo_out,
  input [7:0] uio_in,
  output [7:0] uio_out,
  output [7:0] uio_oe,
  input ena,
  input clk,
  input rst_n
);

reg [15:0] regs [15:0];
reg [7:0] D;
reg [7:0] MHI;
reg DF;
reg [7:0] B;
reg [7:0] instr_latch;
reg [3:0] X;
reg [3:0] P;
reg [7:0] T;
reg [3:0] EF_l;
reg Q_l;
reg tpa_l;
reg mrd_l;
reg mwr_l;
reg idle;
reg IE;
reg [1:0] S;
reg will_interrupt;
//assign TPA = tpa_l;
//assign MRD = mrd_l;
//assign MWR = mwr_l;
assign uo_out[0] = Q_l;
//assign SC0 = S[0];
//assign SC1 = S[1];
wire intr = ui_in[4];

reg CS_ROM;
assign uo_out[1] = CS_ROM;
reg SCLK_ROM;
assign uo_out[2] = SCLK_ROM;
reg [3:0] ROM_DO;
reg [3:0] ROM_OEB;
assign uio_out[3:0] = ROM_DO;
assign uio_oe[3:0] = ~ROM_OEB;
wire [3:0] ROM_DAT = uio_in[3:0];

reg CS_RAM;
assign uo_out[3] = CS_RAM;
reg SCLK_RAM;
assign uo_out[4] = SCLK_RAM;
reg [3:0] RAM_DO;
reg [3:0] RAM_OEB;
assign uio_out[7:4] = RAM_DO;
assign uio_oe[7:4] = ~RAM_OEB;
wire [3:0] RAM_DAT = uio_in[7:4];

reg [7:0] data_in;
reg [15:0] last_addr;
reg [15:0] addr_buff;

reg lda;
reg mem_write;
reg [4:0] spi_cycle;
reg [7:0] spi_dat_out;
reg [7:0] mem_cycle;
reg [5:0] startup_cycle;
reg [3:0] instr_cycle;

reg EXTEND;
wire [3:0] op_high = instr_latch[7:4];
wire [3:0] ireg_addr = instr_latch[3:0];
wire [15:0] sel_reg = regs[ireg_addr];
wire cond_inv = instr_latch[3]; //Invert condition on branch instr.

reg branch_condition;
always @(*) begin
	case(instr_latch[2:0])
		0: branch_condition <= 1;
		1: branch_condition <= Q_l;
		2: branch_condition <= D == 0;
		3: branch_condition <= DF;
		4: branch_condition <= EF_l[0];
		5: branch_condition <= EF_l[1];
		6: branch_condition <= EF_l[2];
		7: branch_condition <= EF_l[3];
	endcase
end
wire should_branch = branch_condition ^ cond_inv;

reg longbranch_condition;
always @(*) begin
	case(instr_latch[3:0])
		0: longbranch_condition <= 1;
		1: longbranch_condition <= Q_l;
		2: longbranch_condition <= D == 0;
		3: longbranch_condition <= DF;
		4: longbranch_condition <= 0;
		5: longbranch_condition <= ~Q_l;
		6: longbranch_condition <= D != 0;
		7: longbranch_condition <= ~DF;
		
		8: longbranch_condition <= 1;
		9: longbranch_condition <= ~Q_l;
		10: longbranch_condition <= D != 0;
		11: longbranch_condition <= ~DF;
		12: longbranch_condition <= IE;
		13: longbranch_condition <= Q_l;
		14: longbranch_condition <= D == 0;
		15: longbranch_condition <= DF;
	endcase
end
wire is_skip = (instr_latch[3:0] >= 5 && instr_latch[3:0] <= 8) || (instr_latch[3:2] == 2'b11);

`ifdef SIM
wire [15:0] r0 = regs[0];
wire [15:0] r1 = regs[1];
wire [15:0] r2 = regs[2];
wire [15:0] r3 = regs[3];
wire [15:0] r4 = regs[4];
wire [15:0] r5 = regs[5];
wire [15:0] r6 = regs[6];
wire [15:0] r7 = regs[7];
wire [15:0] r8 = regs[8];
wire [15:0] r9 = regs[9];
wire [15:0] r10 = regs[10];
wire [15:0] r11 = regs[11];
wire [15:0] r12 = regs[12];
wire [15:0] r13 = regs[13];
wire [15:0] r14 = regs[14];
wire [15:0] r15 = regs[15];

wire [15:0] PC = regs[P];
wire [15:0] SP = regs[X];

wire flag_init_done = startup_cycle == 0;
`endif

//UART REGS
reg [15:0] uart_div;
reg uart_start;
wire [7:0] uart_rec_byte;
wire uart_busy;
wire uart_has_byte;
reg uart_clear_status;
//

//SPI REGS
reg [7:0] spi_div;
reg spi_start;
wire [7:0] spi_rec_byte;
wire spi_busy;
//

//RAM
reg [7:0] DFFRAM [DFFRAM_SIZE-1:0];
reg [3:0] RAM_delay_cycs;
reg [3:0] RAM_delay_counter;
//

always @(posedge clk) begin
	EF_l <= ~ui_in[3:0];
	uart_start <= 0;
	spi_start <= 0;
	uart_clear_status <= 0;
	if(!rst_n) begin
		regs[0] <= 0;
		X <= 0;
		P <= 0;
		tpa_l <= 0;
		mrd_l <= 1;
		mwr_l <= 1;
		idle <= 0;
		IE <= 1;
		Q_l <= 0;
		DF <= 0;
		D <= 0;
		MHI <= 0;
		T <= 0;
		RAM_delay_cycs <= 6;
		CS_ROM <= 1;
		SCLK_ROM <= 0;
		SCLK_RAM <= 0;
		RAM_DO <= 0;
		RAM_OEB <= 4'b1111;
		CS_RAM <= 1;
		ROM_OEB <= 4'b1111;
		ROM_DO <= 0;
		last_addr <= 8'hFF;
		instr_cycle <= 0;
		startup_cycle <= 1;
		spi_cycle <= 0;
		EXTEND <= 0;
		will_interrupt <= 0;
		mem_cycle <= 0;
	end else begin
		if(spi_cycle != 0) begin
			spi_cycle <= spi_cycle == 17 ? 0 : spi_cycle + 1;
			if(spi_cycle[0]) begin
				SCLK_ROM <= 0;
				ROM_OEB[0] <= spi_cycle == 17;
				ROM_DO[0] <= spi_dat_out[7];
				spi_dat_out <= {spi_dat_out[6:0], 1'b0};
			end else begin
				SCLK_ROM <= 1;
			end
		end else if(startup_cycle != 0) begin
			startup_cycle <= startup_cycle + 1;
			case(startup_cycle)
				1: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'hFF;
					spi_cycle <= 1;
					ROM_OEB[3:2] <= 2'b00;
					ROM_DO[3:2] <= 2'b11;
					RAM_OEB <= 4'b0000;
					SCLK_RAM <= 0;
					RAM_DO <= 4'hF;
					CS_RAM <= 0;
				end
				2: begin
					CS_ROM <= 1;
					SCLK_RAM <= 1;
				end
				3: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'hAB;
					spi_cycle <= 1;
					SCLK_RAM <= 0;
					RAM_DO <= 4'h5;
				end
				4: begin
					CS_ROM <= 1;
					SCLK_RAM <= 1;
				end
				5: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'h06;
					spi_cycle <= 1;
					SCLK_RAM <= 0;
					CS_RAM <= 1;
				end
				6: CS_ROM <= 1;
				7: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'h01;
					spi_cycle <= 1;
				end
				8: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'b00000010;
					spi_cycle <= 1;
				end
				9: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'b0000010;
					spi_cycle <= 1;
				end
				10: CS_ROM <= 1;
				11: begin
					CS_ROM <= 0;
					spi_dat_out <= 8'hEB;
					spi_cycle <= 1;
				end
				12: begin
					ROM_OEB <= 4'b0000;
					ROM_DO <= 0;
					CS_RAM <= 0;
					RAM_OEB <= 4'b1110;
					RAM_DO[0] <= 0;
				end
				13: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				14: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
				end
				15: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				16: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					RAM_DO[0] <= 1;
				end
				17: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				18: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
				end
				19: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				20: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					RAM_DO[0] <= 0;
				end
				21: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				22: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					RAM_DO[0] <= 1;
				end
				23: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				24: begin
					ROM_DO <= 4'b1010;
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					RAM_DO[0] <= 0;
				end
				25: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				26: begin
					ROM_DO <= 4'b0101;
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					RAM_DO[0] <= 1;
				end
				27: begin
					SCLK_ROM <= 1;
					SCLK_RAM <= 1;
				end
				28: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
				end
				29: begin
					ROM_OEB <= 4'b1111;
					SCLK_ROM <= 1;
					CS_RAM <= 1;
					RAM_OEB <= 4'b1111;
				end
				30: SCLK_ROM <= 0;
				31: SCLK_ROM <= 1;
				32: SCLK_ROM <= 0;
				33: SCLK_ROM <= 1;
				34: SCLK_ROM <= 0;
				35: SCLK_ROM <= 1;
				36: SCLK_ROM <= 0;
				37: SCLK_ROM <= 1;
				38: SCLK_ROM <= 0;
				39: SCLK_ROM <= 1;
				40: SCLK_ROM <= 0;
				41: begin
					startup_cycle <= 0;
					CS_ROM <= 1;
				end
			endcase
		end else if(mem_cycle != 0) begin
			mem_cycle <= mem_cycle + 1;
			case(mem_cycle)
				1: begin
					if(addr_buff[15] == 0) begin //ROM location
						if(mem_write) begin
							mem_cycle <= 0;
						end else begin
							last_addr <= addr_buff;
							if(last_addr + 1 == addr_buff) begin
								mem_cycle <= 27;
							end else begin
								CS_ROM <= 1;
								SCLK_ROM <= 0;
							end
						end
					end else if(addr_buff[15:4] == 12'hFFF) begin //IO location
						if(mem_write) begin
							case(addr_buff[3:0])
								0: uart_div[7:0] <= B;
								1: uart_div[15:8] <= B;
								2: uart_start <= 1;
								3: RAM_delay_cycs <= B[3:0];
								4: spi_div <= B;
								5: spi_start <= 1;
							endcase
							mem_cycle <= 0;
						end else begin
							case(addr_buff[3:0])
								0: data_in <= uart_div[7:0];
								1: data_in <= uart_div[15:8];
								2: begin
									data_in <= uart_rec_byte;
									uart_clear_status <= 1;
								end
								3: data_in <= {5'b0, spi_busy, uart_has_byte, uart_busy};
								4: data_in <= spi_rec_byte;
								default: data_in <= 0;
							endcase
							mem_cycle <= 30;
						end
					end else if(addr_buff[14:0] < DFFRAM_SIZE) begin //Internal RAM
						if(mem_write) begin
							DFFRAM[addr_buff[14:0]] <= B;
							mem_cycle <= 0;
						end else begin
							data_in <= DFFRAM[addr_buff[14:0]];
							mem_cycle <= 30;
						end
					end else begin //External RAM
						mem_cycle <= 100;
					end
				end
				2: begin
					CS_ROM <= 0;
					ROM_DO <= 4'b0000;
					ROM_OEB <= 4'b0000;
				end
				3: SCLK_ROM <= 1;
				4: SCLK_ROM <= 0;
				5: SCLK_ROM <= 1;
				6: begin
					SCLK_ROM <= 0;
					ROM_DO <= addr_buff[15:12];
				end
				7: SCLK_ROM <= 1;
				8: begin
					SCLK_ROM <= 0;
					ROM_DO <= addr_buff[11:8];
				end
				9: SCLK_ROM <= 1;
				10: begin
					SCLK_ROM <= 0;
					ROM_DO <= addr_buff[7:4];
				end
				11: SCLK_ROM <= 1;
				12: begin
					SCLK_ROM <= 0;
					ROM_DO <= addr_buff[3:0];
				end
				13: SCLK_ROM <= 1;
				14: begin
					SCLK_ROM <= 0;
					ROM_DO <= 4'b1010;
				end
				15: SCLK_ROM <= 1;
				16: begin
					SCLK_ROM <= 0;
					ROM_DO <= 4'b0101;
				end
				17: SCLK_ROM <= 1;
				18: begin
					SCLK_ROM <= 0;
					ROM_OEB <= 4'b1111;
				end
				19: SCLK_ROM <= 1;
				20: SCLK_ROM <= 0;
				21: SCLK_ROM <= 1;
				22: SCLK_ROM <= 0;
				23: SCLK_ROM <= 1;
				24: SCLK_ROM <= 0;
				25: SCLK_ROM <= 1;
				26: SCLK_ROM <= 0;
				
				27: begin
					SCLK_ROM <= 1;
					data_in[7:4] = ROM_DAT;
				end
				28: begin
					SCLK_ROM <= 0;
				end
				29: begin
					SCLK_ROM <= 1;
					data_in[3:0] = ROM_DAT;
				end
				30: begin
					SCLK_ROM <= 0;
					SCLK_RAM <= 0;
					CS_RAM <= 1;
					if(instr_cycle == 1) begin
						S <= 2'b01;
						instr_latch <= data_in;
					end else if(lda) begin
						D <= data_in;
					end else begin
						B <= data_in;
					end
					mem_cycle <= 0;
				end
				
				//External RAM access
				100: begin
					CS_RAM <= 1'b0;
					RAM_OEB <= 4'b0000;
					SCLK_RAM <= 0;
				end
				101: RAM_DO <= mem_write ? 4'h3 : 4'hE;
				102: SCLK_RAM <= 1;
				103: begin
					SCLK_RAM <= 0;
					RAM_DO <= mem_write ? 4'h8 : 4'hB;
				end
				104: SCLK_RAM <= 1;
				105: begin
					SCLK_RAM <= 0;
					RAM_DO <= 0;
				end
				106: SCLK_RAM <= 1;
				107: SCLK_RAM <= 0;
				108: SCLK_RAM <= 1;
				109: begin
					SCLK_RAM <= 0;
					RAM_DO <= {1'b0, addr_buff[14:12]};
				end
				110: SCLK_RAM <= 1;
				111: begin
					SCLK_RAM <= 0;
					RAM_DO <= addr_buff[11:8];
				end
				112: SCLK_RAM <= 1;
				113: begin
					SCLK_RAM <= 0;
					RAM_DO <= addr_buff[7:4];
				end
				114: SCLK_RAM <= 1;
				115: begin
					SCLK_RAM <= 0;
					RAM_DO <= addr_buff[3:0];
				end
				116: SCLK_RAM <= 1;
				117: begin
					SCLK_RAM <= 0;
					if(mem_write) begin
						mem_cycle <= 200;
					end else begin
						RAM_delay_counter <= RAM_delay_cycs;
					end
				end
				118: begin
					SCLK_RAM <= 1;
					RAM_OEB <= 4'b1111;
				end
				119: begin
					SCLK_RAM <= 0;
					RAM_delay_counter <= RAM_delay_counter - 1;
					if(RAM_delay_counter != 1) begin
						mem_cycle <= 118;
					end
				end
				120: begin
					SCLK_RAM <= 1;
					data_in[7:4] <= RAM_DAT;
				end
				121: SCLK_RAM <= 0;
				122: begin
					SCLK_RAM <= 1;
					data_in[3:0] <= RAM_DAT;
					mem_cycle <= 30;
				end
				
				//External RAM write
				200: begin
					RAM_DO <= B[7:4];
					SCLK_RAM <= 0;
				end
				201: SCLK_RAM <= 1;
				202: begin
					RAM_DO <= B[3:0];
					SCLK_RAM <= 0;
				end
				203: SCLK_RAM <= 1;
				204: begin
					SCLK_RAM <= 0;
					CS_RAM <= 1;
					RAM_OEB <= 4'b1111;
					mem_cycle <= 0;
				end
			endcase
		end else begin
			if(instr_cycle == 0) begin
				if(will_interrupt) begin
					will_interrupt <= 0;
					if(IE) begin
						idle <= 0;
						S <= 2'b11;
						IE <= 0;
						T <= {X, P};
						P <= 1;
						X <= 2;
					end
				end else if(intr && IE) begin
					will_interrupt <= 1;
				end else if(!idle) begin
					S <= 2'b00;
					addr_buff <= regs[P];
					regs[P] <= regs[P] + 1;
					mem_cycle <= 1;
					mem_write <= 0;
					lda <= 0;
					instr_cycle <= 1;
				end
			end else begin
				EXTEND <= instr_latch == 8'h68;
				if(op_high == 0) begin
					if(instr_latch[3:0] == 0) begin //IDL
						idle <= 1;
						instr_cycle <= 0;
					end else begin //LDN [reg]
						addr_buff <= sel_reg;
						mem_write <= 0;
						mem_cycle <= 1;
						lda <= 1;
						instr_cycle <= 0;
					end
				end else if(op_high == 1) begin //INC [reg]
					regs[ireg_addr] <= sel_reg + 1;
					instr_cycle <= 0;
				end else if(op_high == 2) begin //DEC [reg]
					regs[ireg_addr] <= sel_reg - 1;
					instr_cycle <= 0;
				end else if(op_high == 3) begin //Branch instrs
					if(instr_cycle == 1) begin
						if(should_branch) begin
							addr_buff <= regs[P];
							regs[P] <= regs[P] + 1;
							mem_write <= 0;
							mem_cycle <= 1;
							lda <= 0;
							instr_cycle <= 2;
						end else begin
							regs[P] <= regs[P] + 1;
							instr_cycle <= 0;
						end
					end else begin
						//New low-order address now in B
						regs[P][7:0] <= B;
						instr_cycle <= 0;
					end
				end else if(op_high == 4) begin //LDA [reg]
					addr_buff <= sel_reg;
					regs[ireg_addr] <= sel_reg + 1;
					mem_write <= 0;
					mem_cycle <= 1;
					lda <= 1;
					instr_cycle <= 0;
				end else if(op_high == 5) begin //STR [reg]
					B <= D;
					addr_buff <= sel_reg;
					mem_write <= 1;
					mem_cycle <= 1;
					instr_cycle <= 0;
				end else if(op_high == 6) begin //IO instrs
					if(instr_latch[3:0] == 0) begin //IRX
						regs[X] <= regs[X] + 1;
					end else if(instr_latch[3:0] == 8) begin
						
					end else begin
						if(instr_latch[3]) begin //INP
							D <= 0;
						end else begin //OUT
						
						end
					end
					instr_cycle <= 0;
				end else if(op_high == 7) begin //Various
					if(instr_cycle == 1 && (instr_latch[3:0] == 0 || instr_latch[3:0] == 1 || instr_latch[3:0] == 4 || instr_latch[3:0] == 5 || instr_latch[3:0] == 7 || instr_latch[3:0] == 12 || instr_latch[3:0] == 13 || instr_latch[3:0] == 15)) begin
						addr_buff <= instr_latch[3] ? regs[P] : regs[X];
						regs[P] <= instr_latch[3] ? regs[P] + 1 : regs[P];
						mem_write <= 0;
						mem_cycle <= 1;
						lda <= 0;
						instr_cycle <= 2;
					end else begin
						instr_cycle <= 0;
						case(instr_latch[3:0])
							0: begin
								//RET
								X <= B[7:4];
								P <= B[3:0];
								regs[X] <= regs[X] + 1;
								IE <= 1;
							end
							1: begin
								//DIS
								X <= B[7:4];
								P <= B[3:0];
								regs[X] <= regs[X] + 1;
								IE <= 0;
							end
							2: begin
								//LDXA
								addr_buff <= regs[X];
								regs[X] <= regs[X] + 1;
								mem_write <= 0;
								mem_cycle <= 1;
								lda <= 1;
							end
							3: begin
								//STXD
								addr_buff <= regs[X];
								regs[X] <= regs[X] - 1;
								mem_write <= 1;
								B <= D;
								mem_cycle <= 1;
							end
							4: begin
								//ADC
								{DF, D} <= D + DF + B;
							end
							5: begin
								//SDB
								{DF, D} <= B - D - (~DF);
							end
							6: begin
								//RSHR
								DF <= D[0];
								D <= {DF, D[7:1]};
							end
							7: begin
								//SMB
								{DF, D} <= D - B - (~DF);
							end
							8: begin
								//SAV
								addr_buff <= regs[X];
								B <= T;
								mem_write <= 1;
								mem_cycle <= 1;
							end
							9: begin
								//MARK
								T <= {X, P};
								addr_buff <= regs[2];
								B <= {X, P};
								mem_write <= 1;
								mem_cycle <= 1;
								X <= P;
								regs[2] <= regs[2] - 1;
							end
							10: begin
								//REQ
								Q_l <= 0;
							end
							11: begin
								//SEQ
								if(EXTEND) begin
									D <= {D[3:0], D[7:4]};
								end else begin
									Q_l <= 1;
								end
							end
							12: begin
								//ADCI
								{DF, D} <= D + DF + B;
							end
							13: begin
								//SDBI
								D <= B + ~D + DF;
								DF <= ~(B < D);
							end
							14: begin
								//RSHL
								DF <= D[7];
								D <= {D[6:0], DF};
							end
							15: begin
								//SMBI
								D <= D + ~B + DF;
								DF <= ~(D < B);
							end
						endcase
					end
				end else if(op_high == 8) begin //GLO [reg]
					D <= sel_reg[7:0];
					instr_cycle <= 0;
				end else if(op_high == 9) begin //GHI [reg]
					if(EXTEND) begin
						D <= MHI;
					end else begin
						D <= sel_reg[15:8];
					end
					instr_cycle <= 0;
				end else if(op_high == 10) begin //PLO [reg]
					regs[ireg_addr][7:0] <= D;
					instr_cycle <= 0;
				end else if(op_high == 11) begin //PHI [reg]
					if(EXTEND) begin
						MHI <= ireg_addr == 0 ? 0 : D;
					end else begin
						regs[ireg_addr][15:8] <= D;
					end
					instr_cycle <= 0;
				end else if(op_high == 12) begin //skips & long branch (& NOP)
					if(instr_latch[3:0] == 4) begin
						instr_cycle <= 0; //NOP
					end else begin
						if(is_skip) begin
							if(longbranch_condition) begin
								regs[P] <= regs[P] + 2;
							end
							instr_cycle <= 0;
						end else begin
							if(instr_cycle == 1) begin
								if(!longbranch_condition) begin
									regs[P] <= regs[P] + 2;
									instr_cycle <= 0;
								end else begin
									addr_buff <= regs[P];
									regs[P] <= regs[P] + 1;
									mem_write <= 0;
									mem_cycle <= 1;
									lda <= 0;
									instr_cycle <= 2;
								end
							end else if(instr_cycle == 2) begin
								addr_buff <= regs[P];
								mem_write <= 0;
								regs[P][15:8] <= B;
								mem_cycle <= 1;
								instr_cycle <= 3;
							end else begin
								regs[P][7:0] <= B;
								instr_cycle <= 0;
							end
						end
					end
				end else if(op_high == 13) begin //SEP [reg]
					P <= ireg_addr;
					instr_cycle <= 0;
				end else if(op_high == 14) begin //SEX [reg]
					X <= ireg_addr;
					instr_cycle <= 0;
				end else if(op_high == 15) begin //Various
					if(instr_latch[3:0] == 0 || instr_latch[3:0] == 8) begin
						addr_buff <= instr_latch[3] ? regs[P] : regs[X];
						regs[P] <= instr_latch[3] ? regs[P] + 1 : regs[P];
						mem_write <= 0;
						lda <= 1;
						mem_cycle <= 1;
						instr_cycle <= 0;
					end else begin
						if(instr_cycle == 1 && instr_latch[3:0] != 6 && instr_latch[3:0] != 14) begin
							instr_cycle <= 2;
							mem_write <= 0;
							lda <= 0;
							mem_cycle <= 1;
							if(instr_latch[3]) begin
								addr_buff <= regs[P];
								regs[P] <= regs[P] + 1;
							end else begin
								addr_buff <= regs[X];
							end
						end else begin
							instr_cycle <= 0;
							case(instr_latch[2:0])
								1: begin
									//OR,ORI
									D <= D | B;
								end
								2: begin
									//AND,ANI
									D <= D & B;
								end
								3: begin
									//XOR,XRI
									D <= D ^ B;
								end
								4: begin
									//ADD,ADI
									if(EXTEND) begin
										{MHI, D} <= D * B;
									end else begin
										{DF, D} <= D + B;
									end
								end
								5: begin
									//SD,SDI
									if(EXTEND) begin
										D <= D / B;
									end else begin
										D <= B + ~D + 1;
										DF <= ~(B < D);
									end
								end
								6: begin
									if(instr_latch[3]) begin
										//SHL
										DF <= D[7];
										D <= {D[6:0], 1'b0};
									end else begin
										//SHR
										DF <= D[0];
										D <= {1'b0, D[7:1]};
									end
								end
								7: begin
									//SM,SMI
									D <= D + ~B + 1;
									DF <= ~(D < B);
								end
							endcase
						end
					end
				end
			end
		end
	end
end

uart uart(
	.divisor(uart_div),
	.din(B),
	.dout(uart_rec_byte),
	.TX(uo_out[5]),
	.RX(ui_in[5]),
	.start(uart_start),
	.busy(uart_busy),
	.has_byte(uart_has_byte),
	.clr_hb(uart_clear_status),
	.clk(clk),
	.rst(~rst_n)
);

spi spi(
	.divisor(spi_div),
	.din(B),
	.dout(spi_rec_byte),
	.SCLK(uo_out[6]),
	.DO(uo_out[7]),
	.DI(ui_in[6]),
	.start(spi_start),
	.busy(spi_busy),
	.clk(clk),
	.rst(~rst_n)
);

endmodule
