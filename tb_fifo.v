`timescale 1ns/1ps
module tb_fifo;
    reg        clk = 0, rst_n = 0, wr_en = 0, rd_en = 0;
    reg  [7:0] din = 0;
    wire [7:0] dout;
    wire       full, empty;
    integer    i, errors = 0;

    sync_fifo #(.WIDTH(8), .DEPTH(16)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .full(full), .empty(empty));

    always #5 clk = ~clk;

    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    task write(input [7:0] b);
        begin @(negedge clk); wr_en = 1; din = b; @(negedge clk); wr_en = 0; end
    endtask

    task read_check(input [7:0] expected);
        begin
            @(negedge clk);
            check(dout === expected, "read data mismatch");
            rd_en = 1;
            @(negedge clk); rd_en = 0;
        end
    endtask

    initial begin
        $dumpfile("fifo.vcd"); $dumpvars(0, tb_fifo);
        #22 rst_n = 1;
        @(negedge clk);
        check(empty && !full, "after reset: expect empty");

        // 1. Fill to full
        for (i = 0; i < 16; i = i + 1) write(i);
        check(full && !empty, "expect full after 16 writes");

        // 2. Overflow attempt must be ignored
        write(8'hFF);
        check(full, "still full");

        // 3. Drain: data must come out in order, 0xFF must not appear
        for (i = 0; i < 16; i = i + 1) read_check(i);
        check(empty && !full, "expect empty after 16 reads");

        // 4. Underflow attempt must be ignored
        @(negedge clk); rd_en = 1; @(negedge clk); rd_en = 0;
        check(empty, "still empty after underflow read");

        // 5. Simultaneous read + write keeps order
        write(8'hAA);
        @(negedge clk); wr_en = 1; din = 8'hBB; rd_en = 1;
        @(negedge clk); wr_en = 0; rd_en = 0;
        read_check(8'hBB);
        check(empty, "empty at end");

        if (errors == 0) $display("TB_FIFO: ALL TESTS PASSED");
        else             $display("TB_FIFO: %0d FAILURES", errors);
        $finish;
    end
endmodule
