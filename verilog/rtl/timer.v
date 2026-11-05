/*
    A simple user's project example - Part 1
    Minutes and Seconds clock. The design drives 4 multiplexed 7-Segment display digits.
    It uses Caravel system clock and reset and 11 I/O pads. 
    The 11 I/O pads are divided between 4 digit enables and 7 segment drivers.
    The RTL supports:
     - Common Anode (CC=0) or Common Cathode (CC=1) multiplexed display
     - Different clock frequencies (FREQ in Hertz)
     - Different scans by sec (SCAN_PER_SEC)
*/

module timer #(parameter  CC = 1,
                                FREQ = 2_000,
                                SCAN_PER_SEC = 25) 
(
    input   wire        clk,
    input   wire        rst,
    output  wire [6:0]  seven_seg,
    output  wire [3:0]  digit_en,
    // ROM interface:
    output  wire [9:0]  rom_addr,
    input   wire [7:0]  rom_data
);
    localparam DIG_DURATION = (FREQ)/(4 * SCAN_PER_SEC);

    // the counter
    reg [3:0]   sec_ones, sec_tens;
    reg [3:0]   min_ones, min_tens;
    wire        nine_sec        = (sec_ones == 4'd9);
    wire        fifty_nine_sec  = (sec_tens == 4'd5) & nine_sec;
    wire        nine_min        = (min_ones == 4'd9);
    wire        fifty_nine_min  = (min_tens == 4'd5) & nine_min;
    
    // Time Base Generators
    reg         sec;
    reg         scan;

    reg [31:0]  sec_div;
    reg [31:0]  scan_div;
    
    always @(posedge clk) begin
        if(rst)
            sec_div <= 32'b0;
        else if(sec_div == FREQ)
            sec_div <= 32'b0;
        else
            sec_div <= sec_div + 32'b1;
    end

    always @(posedge clk) begin
        if(rst)
            scan_div <= 32'b0;
        else if(scan_div == DIG_DURATION)
            scan_div <= 32'b0;
        else
            scan_div <= scan_div + 32'b1;
    end

    always @(posedge clk) begin
        if(rst)
            sec <= 1'b0;
        else if(sec_div == FREQ)
            sec <= 1'b1;
        else 
            sec <= 1'b0;
    end

    always @(posedge clk) begin
        if(rst)
            scan <= 1'b0;
        else if(scan_div == DIG_DURATION)
            scan <= 1'b1;
        else 
            scan <= 1'b0;
    end


    // Seconds Counters
    always @(posedge clk)
        if(rst) 
            sec_ones <=  4'b0;
        else if(sec) begin
            if(!nine_sec) 
                sec_ones <= sec_ones + 4'd1;
            else 
                sec_ones <= 0;
        end

    always @(posedge clk)
        if(rst) 
            sec_tens <=  4'b0;
        else if(sec) begin 
            if(fifty_nine_sec) 
                sec_tens <= 0;
            else if(nine_sec) 
                sec_tens <= sec_tens + 4'd1;
        end

    // Minutes Counters
    always @(posedge clk)
        if(rst) 
            min_ones <=  4'b0;
        else if(fifty_nine_sec & sec) begin
            if(!nine_min)
                min_ones <= min_ones + 4'd1;
            else
                min_ones <= 0;
        end

    always @(posedge clk)
        if(rst) 
            min_tens <=  4'b0;
        else if(fifty_nine_sec & sec) begin
            if(fifty_nine_min) 
                min_tens <= 0;
            else if(nine_min) 
                min_tens <= min_tens + 4'd1;
        end
    
    
        // Display TDM
        reg [1:0] dig_cnt;
        always @(posedge clk) begin
            if(rst)
                dig_cnt <= 2'b0;
            else
                if(scan) dig_cnt <= dig_cnt + 1'b1;
        end

        wire [3:0]  bcd_mux =   (dig_cnt == 2'b00) ? sec_ones :
                                (dig_cnt == 2'b01) ? sec_tens :
                                (dig_cnt == 2'b10) ? min_ones : min_tens;

        // BCD to 7SEG Decoder
        wire [7:0] ca_7seg;
        assign ca_7seg = rom_data;
        assign rom_addr = {6'b0, bcd_mux};
        /* ROM hex contents (see cf_rom_sync_7seg_hex.rom):
               01 // 0: 0_0000001
               4F // 1: 0_1001111
               12 // 2: 0_0010010
               06 // 3: 0_0000110
               4C // 4: 0_1001100
               24 // 5: 0_0100100
               20 // 6: 0_0100000
               0F // 7: 0_0001111
               00 // 8: 0_0000000
               04 // 9: 0_0000100
               00 // *: 0_0000000
        */

        // delay `digit_en` by one clk cycle to match `ca_7seg` ROM output:
        reg [3:0] digit_en_reg;
        always @(posedge clk) begin
            digit_en_reg <= (4'b1 << dig_cnt);
        end

        generate
            if(CC==0) begin
                assign seven_seg    =   ca_7seg[6:0];
                assign digit_en     =   digit_en_reg;
            end else begin
                assign seven_seg    =   ~ ca_7seg[6:0];
                assign digit_en     =   ~ digit_en_reg;
            end
        endgenerate

endmodule