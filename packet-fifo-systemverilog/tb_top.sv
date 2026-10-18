`timescale 1ns/1ps

module tb_top;

	logic clk = 1'b0;
	logic rst ;
	logic [31:0] in_data;
	logic in_eop;
	logic in_valid;
	logic out_ready;
	logic out_valid;

	logic in_ready;
	logic [31:0] out_data;
	logic out_eop ;
	int unsigned fail_test ;
	int unsigned pass_test ;


	int unsigned simultaneous_count = 0;
	int unsigned count_before;

	localparam int NumWords = 100;
	logic [32:0] expected [0:NumWords-1] ;

	int unsigned stall_cycles;
	int unsigned full_cycles;

	packet_fifo dut(
		.clk(clk) ,
		.rst(rst) ,
		.in_data(in_data),
		.in_eop(in_eop),
		.in_valid(in_valid),
		.out_ready(out_ready),

		.in_ready(in_ready),
		.out_data(out_data),
		.out_eop(out_eop) ,
		.out_valid( out_valid )
	);

	task automatic send_word(
		input logic [31:0] word ,
		input logic last
	);

		in_eop = last;
		in_data = word ;
		in_valid = 1'b1;

		 // Keep valid and data stable until a rising edge input handshake.
		do begin
			@(posedge clk);
		end while (in_ready !== 1'b1);

		@(negedge clk)
		in_valid = 1'b0 ;
	endtask

	task automatic receive_word(
		input logic [31:0] expected_word ,
		input logic expected_last
	);
		out_ready = 1'b1 ;

		 // Wait for a rising edge on which a valid word is taken.
		do begin
			@(posedge clk);
		end while (out_valid !== 1'b1);


		if ( {expected_word,expected_last} === {out_data, out_eop} )
			pass_test = pass_test + 1'b1;
		else begin
			fail_test = fail_test + 1'b1 ;
			$display("Time=%0t  expected_data=%h recieved_data=%h expected_EOP=%b recieved_EOP=%b", $time,  expected_word ,out_data,expected_last,out_eop);
		end
		@(negedge clk) ;
		out_ready = 1'b0;
	endtask

	task automatic apply_reset();

		@( negedge clk );
		rst = 1;
		@( negedge clk ) ;
		rst = 0 ;

	endtask

	always @(posedge clk) begin
    if (!rst &&in_valid  === 1'b1 && in_ready  === 1'b1 &&out_valid === 1'b1 && out_ready === 1'b1)
        simultaneous_count++;
	end


	initial begin
		in_data = 1'b0 ;
		in_eop = 1'b0 ;
		in_valid = 1'b0 ;
		out_ready = 1'b0 ;
		pass_test = 0;
		fail_test = 0;
		rst =1'b1;

		apply_reset();

		//(1) write 1 word packet and recieve it
		@(negedge clk ) ;
		send_word( 32'h12345678 , 1'b1) ;
		@(negedge clk ) ;
		receive_word( 32'h12345678 , 1'b1) ;

		//(2) write 3 word packet and recieve it
		@(negedge clk );
		send_word (32'h11111111 , 1'b0);
		@(negedge clk );
		send_word(32'h22222222, 1'b0);
		@(negedge clk );
		send_word(32'h33333333, 1'b1);
		@(negedge clk );
		receive_word(32'h11111111 , 1'b0);
		@(negedge clk );
		receive_word(32'h22222222, 1'b0);
		@(negedge clk );
		receive_word(32'h33333333, 1'b1);

		//(3) Write and Read after 3 cycle
		@(negedge clk );
		send_word(32'hABCDEF01, 1'b1);
		repeat(3) @(negedge clk) ;
		receive_word(32'hABCDEF01, 1'b1);

		//(4) Write ( 8 word packet ) to get Full FIFO and read
		for(int i=0 ; i<8 ; i++) begin
			@(negedge clk)
			send_word(  i + 32'd1, i==7) ;
		end

		//Check FULL FIFO control signals
		if (in_ready !== 1'b0 || out_valid !== 1'b1) begin
			fail_test++;
			$error("Full check failed: in_ready=%b out_valid=%b",in_ready, out_valid);
		end


		for(int i =0 ; i<8 ; i++) begin
			@(negedge clk)
			receive_word( i + 32'd1, i==7) ;
		end

		//Check EMPTY FIFO control signals
		if (out_valid !== 1'b0 || in_ready !== 1'b1) begin
			fail_test++;
			$error("Empty check failed: out_valid=%b in_ready=%b",out_valid, in_ready);
		end

		// (5) Fill the FIFO and then send a 9th word and recieve all
		for(int i=0 ; i<8 ; i++) begin
			@(negedge clk)
			send_word( i + 32'd8, i==7) ;
		end
		@(negedge clk) ;
		fork
			send_word( 32'h87654321 , 1'b1); //Has to wait until a recieve operation

			for(int i=0 ; i<8 ; i++) begin
				@(negedge clk)
				receive_word( i + 32'd8, i==7) ;
			end
		join

		@(negedge clk) ;
		receive_word( 32'h87654321 , 1'b1);

		// (6) Pointer wraparound
		//Send 1–8, receive 1–4, send 9–12, then receive the rest
		for(int i =0 ; i<8 ; i++) begin
			@(negedge clk)
			send_word( i + 32'd1, i==7) ;
		end

		for(int i =0 ; i<4 ; i++) begin
			@(negedge clk)
			receive_word( i + 32'd1, i==7) ;
		end

		for(int i=8 ; i<12 ; i++) begin
			@(negedge clk)
			send_word( i + 32'd1, i==11) ;
		end

		for(int i=4 ; i<12 ; i++) begin
			@(negedge clk)
			receive_word( i + 32'd1, (i == 7) || (i == 11)) ;
		end

		// (7) Simultaneous transfer , READ AND WRITE in same clock edge

		@(negedge clk);
		send_word( 32'hAAAA_AAAA, 1'b0) ;

		@(negedge clk);
		count_before = simultaneous_count;
		fork
			send_word(32'hBBBB_BBBB , 1'b1);
			receive_word(32'hAAAA_AAAA , 1'b0);

		join

		if (simultaneous_count != count_before + 1) begin
			fail_test++;
			$error("Read and write did not handshake on the same edge");
		end

		@(negedge clk);
		receive_word(32'hBBBB_BBBB , 1'b1);

		// (8) reset with stored words and check 1 send and recieve
		@(negedge clk);
		send_word( 32'hAAAA_1123, 1'b0) ;
		@(negedge clk);
		send_word( 32'hAAAA_1124, 1'b1) ;

		apply_reset();

		@(negedge clk);
		if (out_valid !== 1'b0 || in_ready !== 1'b1) begin
			fail_test++;
			    $error("Reset check failed: out_valid=%b in_ready=%b",out_valid, in_ready);
		end

		send_word(32'hAAAA_1125, 1'b1);
		@(negedge clk);
		receive_word( 32'hAAAA_1125, 1'b1) ;

		// (9) Output must remain stable while consumer is not ready
		@(negedge clk);
		send_word( 32'hCAFE_1234, 1'b1) ;

		for ( int i=0 ;i < 3; i++) begin
			@(negedge clk) ;
			if (out_valid !== 1'b1 ||{out_data, out_eop} !== {32'hCAFE_1234, 1'b1}) begin
				fail_test++;
				$error("Backpressure check failed at stall cycle %0d", i);
			end
		end
		receive_word(32'hCAFE_1234, 1'b1);

		//(10) Randomised Backpressure

		for( int i =0 ; i <NumWords ; i++) begin
			expected[i] = {i+32'd1 , (i% 4) == 3 }; //Packet of size 4 words
		end

		stall_cycles = 0;
		full_cycles = 0;

		fork
			// Producer: send 100 words in order
			begin : stress_producer
				for (int i =0; i<NumWords ; i++) begin
					@(negedge clk);
					send_word(expected[i][32:1], expected[i][0]);
				end
			end

			begin : stress_consumer
				int read_index ;
				bit was_stalled ;
				logic[32:0] held_word ;

				read_index =0;
				was_stalled = 0;

				while ( read_index < NumWords) begin
					@(negedge clk);
					out_ready = ($urandom_range(3,0) == 0 ); // Randomised stall by consumer

					@(posedge clk);

					if( in_valid === 1'b1 && in_ready === 1'b0 ) full_cycles++ ;

					// A word stalled on the previous edge must still be here.
					if (was_stalled &&(out_valid !== 1'b1 ||{out_data, out_eop} !== held_word)) begin
						fail_test++;
						$error("Output changed during backpressure");
					end

					if (out_valid === 1'b1 && out_ready === 1'b0) begin
						stall_cycles++;
						was_stalled = 1;
						held_word = {out_data, out_eop};
					end

					else begin
						was_stalled = 0;
					end

					// Compare only when the consumer actually accepts a word.
					if (out_valid === 1'b1 && out_ready === 1'b1) begin
						if ({out_data, out_eop} === expected[read_index])
							pass_test++;
						else begin
							fail_test++;
							$error("Word %0d: expected=%h received=%h",read_index, expected[read_index],{out_data, out_eop});
						end
						read_index++;
					end
				end

				@(negedge clk);
				out_ready = 1'b0;
			end
		join

		if (stall_cycles == 0 || full_cycles == 0 || out_valid !== 1'b0) begin
			fail_test++;
			$error("Stress test incomplete: stalls=%0d full_cycles=%0d out_valid=%b",stall_cycles, full_cycles, out_valid);
		end



		@(negedge clk) ;
		$display("Passed=%0d Failed=%0d", pass_test, fail_test);
		if (fail_test != 0)
			$fatal(1, "FIFO tests failed");
		$finish;

	end

	always #5 clk = ~clk ; // Clock period = 10 time units

	// watchdog
	initial begin
		#100000;
		$fatal(1, "GLOBAL TIMEOUT");
	end


endmodule
