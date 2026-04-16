`default_nettype none `timescale 1 ns / 1 ps

module uart_tx #(
   parameter integer CLK_FREQ = 50_000_000,
   parameter integer BAUD_RATE = 115_200
) (
   input wire       clk,
   input wire       reset,
   input wire [7:0] tx_data,  // Byte to be transmitted
   input wire tx_start, // Trigger signal to start transmission
   output reg tx_busy, // High when UART is currently sending data
   output reg tx_done, // High for one clock cycle when finished
   output reg uart_txd // The actual serial output pin
);

  localparam integer ClocksPerBit = CLK_FREQ / BAUD_RATE;
  localparam reg [1:0] IDLE = 2'b00,
                       START = 2'b01,
                       DATA = 2'b10,
                       STOP = 2'b11;

  reg [1:0]          state;
  reg [31:0]         clk_count;
  reg [2:0]          bit_index;
  reg [7:0]          data_latch;

  always @ (posedge clk) begin
    if (reset) begin
      state <= IDLE;
      uart_txd <= 1'b1; // Idle state is high
      tx_busy <= 1'b0;
      tx_done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          uart_txd <= 1'b1;
          tx_done <= 1'b0;
          clk_count <= 32'd0;
          bit_index <= 3'd0;

          if (tx_start) begin
            data_latch <= tx_data; // Capture data immediately
            tx_busy <= 1'b1;
            state <= START;
          end else begin
            tx_busy <= 1'b0;
          end
        end

        START: begin
          uart_txd <= 1'b0; // Start bit (low)
          if (clk_count < ClocksPerBit - 1) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            state <= DATA;
          end
        end

        DATA: begin
          uart_txd <= data_latch[bit_index]; // Send LSB first
          if (clk_count < ClocksPerBit - 1) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            if (bit_index < 7) begin
              bit_index <= bit_index + 1;
            end else begin
              state <= STOP;
            end
          end
        end

        STOP: begin
          uart_txd <= 1'b1; // Stop bit (high)
          if (clk_count < ClocksPerBit - 1) begin
            clk_count <= clk_count + 1;
          end else begin
            tx_done <= 1'b1;
            tx_busy <= 1'b0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase // case (state)
    end
  end
endmodule // uart_rx
