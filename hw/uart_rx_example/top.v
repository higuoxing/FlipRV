`default_nettype none
`timescale 1 ns / 1 ps

module top (
   input wire  clk,   // 27 MHz
   input wire  reset, // Active high reset
   input wire  uart_rxd,
   output wire uart_txd
);

  localparam integer CLK_FREQ  = 27_000_000;
  localparam integer BAUD_RATE = 115_200;
  localparam integer BUF_SIZE  = 256;

  // UART Interconnects
  wire [7:0]         rx_data;
  wire               rx_ready, rx_busy, rx_err;
  reg [7:0]          tx_data;
  reg                tx_start;
  wire               tx_busy, tx_done;

  // Buffer and Pointers
  reg [7:0]          buffer [0: BUF_SIZE-1];
  reg [7:0]          wr_ptr;   // Index for receiving bytes
  reg [7:0]          rd_ptr;   // Index for transmitting bytes
  reg [7:0]          line_len; // Stores length of line to echo

  // FSM States
  localparam reg [1:0] StateRx      = 2'b00,
                       StateTxInit = 2'b01,
                       StateTxWait = 2'b10;
  reg [1:0]            state;

  always @(posedge clk) begin
    if (reset) begin
      state    <= StateRx;
      wr_ptr   <= 0;
      rd_ptr   <= 0;
      line_len <= 0;
      tx_start <= 1'b0;
    end else begin
      case (state)
        // --- Phase 1: Fill the buffer ---
        StateRx: begin
          tx_start <= 1'b0;
          if (rx_ready) begin
            // Store character in buffer
            buffer[wr_ptr] <= rx_data;

            // Check for line ending (\r or \n) or buffer full
            if (rx_data == 8'h0a || rx_data == 8'h0d || wr_ptr == BUF_SIZE - 1) begin
              // Count '\r\n' in
              buffer[wr_ptr+1] <= 8'h0a;
              buffer[wr_ptr+2] <= 8'h0d;
              line_len <= wr_ptr + 2;
              rd_ptr   <= 0;
              state    <= StateTxInit;
            end else begin
              wr_ptr <= wr_ptr + 1;
            end
          end
        end

        // --- Phase 2: Start Transmission of one byte ---
        StateTxInit: begin
          if (!tx_busy) begin
            tx_data  <= buffer[rd_ptr];
            tx_start <= 1'b1;
            state    <= StateTxWait;
          end
        end

        // --- Phase 3: Wait for byte to clear, then loop ---
        StateTxWait: begin
          tx_start <= 1'b0;
          if (tx_done) begin
            if (rd_ptr == line_len) begin
              wr_ptr <= 0; // Reset write pointer for next line
              state  <= StateRx;
            end else begin
              rd_ptr <= rd_ptr + 1;
              state  <= StateTxInit;
            end
          end
        end

        default: state <= StateRx;
      endcase
    end
  end

  uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) u_rx (
    .clk(clk), .reset(reset), .uart_rxd(uart_rxd),
    .rx_data(rx_data), .rx_ready(rx_ready), .rx_busy(rx_busy), .rx_err(rx_err)
  );

  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) u_tx (
    .clk(clk), .reset(reset), .tx_data(tx_data),
    .tx_start(tx_start), .tx_busy(tx_busy), .tx_done(tx_done), .uart_txd(uart_txd)
  );

endmodule
