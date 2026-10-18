module packet_fifo
(
	input logic clk ,
	input logic rst ,
	input logic [31:0] in_data,
	input logic in_eop,
	input logic in_valid,
	input logic out_ready,

	output logic in_ready,
	output logic [31:0] out_data,
	output logic out_eop ,
	output logic out_valid

);

	logic [32:0] memory [0:7];
	logic [2:0] write_ptr;
	logic [2:0] read_ptr ;
	logic [3:0] count ; //Counts the number of word in FIFO
	logic push , pop ;
	// Sequential block

	always_ff @(posedge clk) begin

		if (rst) begin
			write_ptr <= 3'd0;
			count <= 4'd0 ;
			read_ptr <= 3'd0;

		end

		else begin

			if (push) begin
				memory[ write_ptr ] <= { in_data , in_eop };
				write_ptr <= (write_ptr  + 1'b1) ; // it will roll back from 7 to 0
			end

			if(pop) begin
				read_ptr <= (read_ptr + 1'b1) ; // it will roll back from 7 to 0
			end

			case ({push ,pop})
				2'b10 : count <= count + 4'd1;
				2'b01 : count <= count - 4'd1;
				default : ;  // Counter is not chagned for 00 or 11
			endcase


		end
	end

	//combinational block

	always_comb begin

		in_ready = !rst && ( count < 4'd8  ); // Non FUll FIFO
		out_valid = !rst && (count != 4'd0) ; // Non Empty FIFO

		out_data = 32'd0;                 // First: default
		out_eop  = 1'b0;
		if (out_valid)  {out_data, out_eop} = memory[ read_ptr ] ;  // Required data is ready before the rising edge

	end

	assign pop = out_ready && out_valid ;
	assign push = in_ready && in_valid ;

endmodule
