//this is the working keyboard function
module key(
	  // Clock Input (50 MHz)
	  input  CLOCK_50,
	  //  Push Buttons
	  input  [3:0]  KEY,
	  //  DPDT Switches 
	  output  [8:0]  LEDG,  //  LED Green[8:0]
	  output  [2:0]  LEDR, 
	  //  PS2 data and clock lines        
	  input    PS2_DAT,
	  input    PS2_CLK,
	  //  GPIO Connections
	  inout  [35:0]  GPIO_0, GPIO_1
	);

	//  set all inout ports to tri-state
	assign  GPIO_0    =  36'hzzzzzzzzz;
	assign  GPIO_1    =  36'hzzzzzzzzz;

	wire RST;
	assign RST = KEY[0];

	// turn off green LEDs
	assign LEDG = 0;

	wire reset = 1'b0;
	wire [7:0] scan_code;

	reg [7:0] history[1:4];
	wire read, scan_ready;

	oneshot pulser(
		.pulse_out(read),
		.trigger_in(scan_ready),
		.clk(CLOCK_50)
	);

	keyboard kbd(
	  .keyboard_clk(PS2_CLK),
	  .keyboard_data(PS2_DAT),
	  .clock50(CLOCK_50),
	  .reset(reset),
	  .read(read),
	  .scan_ready(scan_ready),
	  .scan_code(scan_code)
	);

//	hex_7seg dsp0(history[1][3:0],HEX0);
//	hex_7seg dsp1(history[1][7:4],HEX1);
//
//	hex_7seg dsp2(history[2][3:0],HEX2);
//	hex_7seg dsp3(history[2][7:4],HEX3);
//
//	hex_7seg dsp4(history[3][3:0],HEX4);
//	hex_7seg dsp5(history[3][7:4],HEX5);
//
//	hex_7seg dsp6(history[4][3:0],HEX6);
//	hex_7seg dsp7(history[4][7:4],HEX7);

	//this is the right button on the keyboard (->)
	//74
	assign LEDR[0] = ((history[1][3:0] == 4'h4) && (history[1][7:4] == 4'h7));
	//middle down arrow button (|)
	//									(v)
	//72
	assign LEDR[1] = ((history[1][3:0] == 4'h2) && (history[1][7:4] == 4'h7));
	//(<-); 66
	assign LEDR[2] = ((history[1][3:0] == 4'h6) && (history[1][7:4] == 4'h6));



	always @(posedge scan_ready)
	begin
		 history[4] <= history[3];
		 history[3] <= history[2];
		 history[2] <= history[1];
		 history[1] <= scan_code;
	end
		 
endmodule

module keyboard(keyboard_clk, keyboard_data, clock50, reset, read, scan_ready, scan_code);

	input keyboard_clk;
	input keyboard_data;
	input clock50; // 50 Mhz system clock
	input reset;
	input read;
	output scan_ready;
	output [7:0] scan_code;
	reg ready_set;
	reg [7:0] scan_code;
	reg scan_ready;
	reg read_char;
	reg clock; // 25 Mhz internal clock

	reg [3:0] incnt;
	reg [8:0] shiftin;

	reg [7:0] filter;
	reg keyboard_clk_filtered;

	// scan_ready is set to 1 when scan_code is available.
	// user should set read to 1 and then to 0 to clear scan_ready

	always @ (posedge ready_set or posedge read)
	if (read == 1) scan_ready <= 0;
	else scan_ready <= 1;

	// divide-by-two 50MHz to 25MHz
	always @(posedge clock50)
		 clock <= ~clock;



	// This process filters the raw clock signal coming from the keyboard 
	// using an eight-bit shift register and two AND gates

	always @(posedge clock)
	begin
		filter <= {keyboard_clk, filter[7:1]};
		if (filter==8'b1111_1111) keyboard_clk_filtered <= 1;
		else if (filter==8'b0000_0000) keyboard_clk_filtered <= 0;
	end


	// This process reads in serial data coming from the terminal

	always @(posedge keyboard_clk_filtered)
	begin
		if (reset==1)
		begin
			incnt <= 4'b0000;
			read_char <= 0;
		end
		else if (keyboard_data==0 && read_char==0)
		begin
		 read_char <= 1;
		 ready_set <= 0;
		end
		else
		begin
			 // shift in next 8 data bits to assemble a scan code    
			 if (read_char == 1)
				  begin
					  if (incnt < 9) 
					  begin
						 incnt <= incnt + 1'b1;
						 shiftin = { keyboard_data, shiftin[8:1]};
						 ready_set <= 0;
					end
			  else
					begin
						 incnt <= 0;
						 scan_code <= shiftin[7:0];
						 read_char <= 0;
						 ready_set <= 1;
					end
			  end
		 end
	end

endmodule

module oneshot(output reg pulse_out, input trigger_in, input clk);
	reg delay;

	always @ (posedge clk)
	begin
		 if (trigger_in && !delay) pulse_out <= 1'b1;
		 else pulse_out <= 1'b0;
		 delay <= trigger_in;
	end 
endmodule

//module hex_7seg(hex_digit,seg);
//	input [3:0] hex_digit;
//	output [6:0] seg;
//	reg [6:0] seg;
//	// seg = {g,f,e,d,c,b,a};
//	// 0 is on and 1 is off
//
//	always @ (hex_digit)
//	case (hex_digit)
//			  4'h0: seg = 7'b1000000;
//			  4'h1: seg = 7'b1111001;     // ---a----
//			  4'h2: seg = 7'b0100100;     // |      |
//			  4'h3: seg = 7'b0110000;     // f      b
//			  4'h4: seg = 7'b0011001;     // |      |
//			  4'h5: seg = 7'b0010010;     // ---g----
//			  4'h6: seg = 7'b0000010;     // |      |
//			  4'h7: seg = 7'b1111000;     // e      c
//			  4'h8: seg = 7'b0000000;     // |      |
//			  4'h9: seg = 7'b0011000;     // ---d----
//			  4'ha: seg = 7'b0001000;
//			  4'hb: seg = 7'b0000011;
//			  4'hc: seg = 7'b1000110;
//			  4'hd: seg = 7'b0100001;
//			  4'he: seg = 7'b0000110;
//			  4'hf: seg = 7'b0001110;
//	endcase
//
//endmodule