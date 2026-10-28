// Synchronous FIFO (first-word fall-through)
// DEPTH must be a power of 2.
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input                    clk,
    input                    rst_n,
    input                    wr_en,
    input      [WIDTH-1:0]   din,
    input                    rd_en,
    output     [WIDTH-1:0]   dout,
    output                   full,
    output                   empty
);
    localparam AW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]    wptr, rptr;
    reg [AW:0]      cnt;

    assign full  = (cnt == DEPTH);
    assign empty = (cnt == 0);
    assign dout  = mem[rptr];            // FWFT: head of queue is always visible

    wire do_wr = wr_en && !full;         // writes while full are ignored
    wire do_rd = rd_en && !empty;        // reads while empty are ignored

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0;
            rptr <= 0;
            cnt  <= 0;
        end else begin
            if (do_wr) begin
                mem[wptr] <= din;
                wptr      <= wptr + 1'b1;
            end
            if (do_rd)
                rptr <= rptr + 1'b1;

            case ({do_wr, do_rd})
                2'b10:   cnt <= cnt + 1'b1;
                2'b01:   cnt <= cnt - 1'b1;
                default: cnt <= cnt;     // idle, or simultaneous read+write
            endcase
        end
    end
endmodule
