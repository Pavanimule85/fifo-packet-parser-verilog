`timescale 1ns/1ps
module tb_pkt;
    reg        clk = 0, rst_n = 0, wr_en = 0;
    reg  [7:0] din = 0;
    wire [7:0] dout;
    wire       full, empty, rd_en, pkt_valid, pkt_err;
    integer    good = 0, bad = 0, errors = 0;

    sync_fifo #(.WIDTH(8), .DEPTH(16)) u_fifo (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .full(full), .empty(empty));

    pkt_parser u_parser (
        .clk(clk), .rst_n(rst_n), .data(dout), .empty(empty),
        .rd_en(rd_en), .pkt_valid(pkt_valid), .pkt_err(pkt_err));

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (pkt_valid) good <= good + 1;
        if (pkt_err)   bad  <= bad + 1;
    end

    task push(input [7:0] b);
        begin
            @(negedge clk);
            while (full) @(negedge clk);   // backpressure
            wr_en = 1; din = b;
            @(negedge clk); wr_en = 0;
        end
    endtask

    // Sends a packet; payload bytes are 'seed + k'. bad_chk corrupts checksum.
    task send_pkt(input [7:0] len, input [7:0] seed, input bad_chk);
        reg [7:0] chk; integer k;
        begin
            chk = len;
            push(8'hA5); push(len);
            for (k = 0; k < len; k = k + 1) begin
                push(seed + k); chk = chk ^ (seed + k);
            end
            push(bad_chk ? ~chk : chk);
        end
    endtask

    task expect_counts(input integer g, input integer b, input [255:0] msg);
        begin
            repeat (40) @(negedge clk);   // let FIFO drain
            if (good !== g || bad !== b) begin
                errors = errors + 1;
                $display("FAIL: %0s (good=%0d exp %0d, bad=%0d exp %0d)", msg, good, g, bad, b);
            end
        end
    endtask

    initial begin
        $dumpfile("pkt.vcd"); $dumpvars(0, tb_pkt);
        #22 rst_n = 1;

        send_pkt(4, 8'h10, 0);                 expect_counts(1, 0, "single good packet");
        send_pkt(3, 8'h20, 1);                 expect_counts(1, 1, "bad checksum detected");

        push(8'h00); push(8'h13); push(8'h77); // garbage before start byte
        send_pkt(5, 8'h30, 0);                 expect_counts(2, 1, "resync after garbage");

        send_pkt(0, 8'h00, 0);                 expect_counts(3, 1, "zero-length packet");

        // back-to-back packets stress the FIFO (can fill and backpressure)
        send_pkt(10, 8'h40, 0); send_pkt(10, 8'h50, 0); send_pkt(10, 8'h60, 0);
        expect_counts(6, 1, "back-to-back packets");

        if (errors == 0) $display("TB_PKT: ALL TESTS PASSED");
        else             $display("TB_PKT: %0d FAILURES", errors);
        $finish;
    end
endmodule
