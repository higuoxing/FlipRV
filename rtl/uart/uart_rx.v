`default_nettype none `timescale 1 ns / 1 ps

module uart_rx #(
  parameter integer CLK_FREQ = 50_000_000,
  parameter integer BAUD_RATE = 115_200
) (
  input wire       clk,
  input wire       reset,
  input wire       uart_rxd,
  output reg [7:0] rx_data,
  output reg rx_ready,
  output reg rx_busy,
  output reg rx_err // High if stop bit is invalid
);

  localparam integer TickCount = CLK_FREQ / (BAUD_RATE * 16);

  // Synchronizer & glitch filter (majority voting)
  reg [1:0]          rxd_sync;
  reg [2:0]          filter_reg;
  reg                rxd_voted;
  wire               rxd_stable;

  assign rxd_stable = rxd_voted;
  always @ (posedge clk) begin
    rxd_sync <= {rxd_sync[0], uart_rxd};
    filter_reg <= {filter_reg[1:0], rxd_sync[1]};

    // 3-sample Majority vote:
    // If at least two bits are '1', the output is '1'.
    rxd_voted <= (filter_reg[0] & filter_reg[1]) |
                 (filter_reg[1] & filter_reg[2]) |
                 (filter_reg[2] & filter_reg[0]);
  end

  // Precise fractional baud generator
  reg [31:0] baud_acc;
  reg        tick_16x;
  reg        sync_reset_tick;

  localparam reg [31:0] INC = BAUD_RATE * 16;

  always @ (posedge clk) begin
    if (reset || sync_reset_tick) begin
      baud_acc <= 32'd0;
      tick_16x <= 1'b0;
    end else if (baud_acc >= CLK_FREQ) begin
      // Overflow, generate a tick and keep the fractional remainder
      baud_acc <= baud_acc - CLK_FREQ + INC;
      tick_16x <= 1'b1;
    end else begin
      baud_acc <= baud_acc + INC;
      tick_16x <= 1'b0;
    end
  end

  // FSM
  reg [1:0] state;
  localparam reg [1:0] IDLE = 2'b00,
                       START = 2'b01,
                       DATA = 2'b10,
                       STOP = 2'b11;

  reg [3:0]            s_count; // Counts 0-15 (oversamples)
  reg [2:0]            b_count; // Counts 0-7 (data bits)
  reg [7:0]            shift_reg;

  always @ (posedge clk) begin
    if (reset) begin
      state <= IDLE;
      rx_ready <= 1'b0;
      rx_busy <= 1'b0;
      rx_err <= 1'b0;
      rx_data <= 8'b0;
      sync_reset_tick <= 1'b0;
    end else begin
      // Default: don't reset the tick counter
      sync_reset_tick <= 1'b0;

      if (state == IDLE) begin
        rx_ready <= 0;
        if (rxd_stable == 1'b0) begin // Potential start bit
          rx_err <= 1'b0;
          state <= START;
          s_count <= 0;
          sync_reset_tick <= 1'b1; // Force the next tick of tick_16x to align with this edge
          rx_busy <= 1'b1;
        end else begin
          rx_busy <= 1'b0;
        end
      end else begin // if (state == IDLE)
        if (!tick_16x) begin
          rx_ready <= 1'b0;
        end else begin
          case (state)
            START: begin
              if (s_count == 7) begin // Center of start bit
                if (rxd_stable == 1'b0) begin
                  s_count <= 0;
                  b_count <= 0;
                  state <= DATA;
                end else begin
                  state <= IDLE; // False start (noise)
                end
              end else begin
                s_count <= s_count + 1;
              end
            end // case: START

            DATA: begin
              if (s_count == 15) begin
                s_count <= 0;
                shift_reg[b_count] <= rxd_stable; // Sample in the middle

                if (b_count == 7) begin
                  state <= STOP;
                end else begin
                  b_count <= b_count + 1;
                end
              end else begin
                s_count <= s_count + 1;
              end
            end


            STOP: begin
              if (s_count == 15) begin
                // Check for valid stop bit (should be 1'b1)
                if (rxd_stable == 1'b1) begin
                  rx_data <= shift_reg;
                  rx_ready <= 1'b1;
                  rx_err <= 1'b0;
                end else begin
                  rx_err <= 1'b1; // Framing error
                  rx_ready <= 1'b0;
                end

                state <= IDLE;
                rx_busy <= 1'b0;
              end else begin
                s_count <= s_count + 1;
              end
            end // case: STOP

            default:
              state <= IDLE;
          endcase // case (state)
        end
      end
    end
  end

endmodule // uart_rx
