// Packet parser FSM. Consumes one byte per cycle from the FIFO.
// Packet format:  0xA5 | LEN | PAYLOAD[LEN bytes] | CHK
// CHK = LEN ^ PAYLOAD[0] ^ ... ^ PAYLOAD[LEN-1]
module pkt_parser (
    input            clk,
    input            rst_n,
    input      [7:0] data,       // FIFO head
    input            empty,      // FIFO empty flag
    output           rd_en,      // pop FIFO
    output reg       pkt_valid,  // 1-cycle pulse: good packet
    output reg       pkt_err     // 1-cycle pulse: checksum mismatch
);
    localparam [1:0] IDLE    = 2'd0,
                     LEN     = 2'd1,
                     PAYLOAD = 2'd2,
                     CHK     = 2'd3;

    reg [1:0] state;
    reg [7:0] remaining;
    reg [7:0] acc;

    assign rd_en = !empty;       // consume whenever a byte is available

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            remaining <= 8'd0;
            acc       <= 8'd0;
            pkt_valid <= 1'b0;
            pkt_err   <= 1'b0;
        end else begin
            pkt_valid <= 1'b0;
            pkt_err   <= 1'b0;
            if (!empty) begin
                case (state)
                    IDLE: if (data == 8'hA5) state <= LEN;   // hunt for start byte

                    LEN: begin
                        acc       <= data;
                        remaining <= data;
                        state     <= (data == 8'd0) ? CHK : PAYLOAD;
                    end

                    PAYLOAD: begin
                        acc       <= acc ^ data;
                        remaining <= remaining - 1'b1;
                        if (remaining == 8'd1) state <= CHK;
                    end

                    CHK: begin
                        if (data == acc) pkt_valid <= 1'b1;
                        else             pkt_err   <= 1'b1;
                        state <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule
