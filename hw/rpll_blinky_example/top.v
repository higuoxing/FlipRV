`default_nettype none
`timescale 1 ns / 1 ps

module top (
   input wire        clk,
   input wire        s1,
   output wire [5:0] led
);

  wire clk_sys;
  wire pll_lock;
  wire reset = s1;

  // Frequency Calculation:
  // input params are calculated as described in GOWIN doc (UG286-1.7E_Gowin Clock User Guide)
  // f_vco = (f_clkin * (fbdiv + 1)) / (idiv + 1)
  // f_clkout = f_vco / odiv
  // f_clkoutd = f_clkout / sdiv
  // f_pfd = f_clkin / idiv = f_clkout / fbdiv
  rpll #(
    .FCLKIN("27"),
    .IDIV_SEL(0),
    .FBDIV_SEL(9),
    .ODIV_SEL(4),
    .DEVICE("GW2AR-18C")
  ) my_pll (
    .clkin(clk),
    .clkfb(1'b0),
    .reset(reset),
    .reset_p(1'b0),
    .fbdsel(6'b0),
    .idsel(6'b0),
    .odsel(6'b0),
    .dutyda(4'b0),
    .psda(4'b0),
    .fdly(4'b0),
    .clkout(clk_sys),
    .lock(pll_lock),
    .clkoutp(),
    .clkoutd(),
    .clkoutd3()
  );

  reg [15:0] lock_timer;
  reg        pll_stable;

  // Monitor pll_lock for at least 2ms.
  always @ (posedge clk) begin
    if (!pll_lock || reset) begin
      lock_timer <= 16'd0;
      pll_stable <= 1'b0;
    end else begin
      if (lock_timer < 16'd54_000) begin
        lock_timer <= lock_timer + 1;
        pll_stable <= 1'b0;
      end else begin
        pll_stable <= 1'b1;
      end
    end
  end

  wire sys_reset = reset || !pll_stable;

  reg [26:0] counter;
  reg        led_state;

  always @(posedge clk_sys) begin
    if (sys_reset) begin
      counter   <= 27'd0;
      led_state <= 1'b0;
    end else begin
      if (counter >= 27'd67_500_000 - 1) begin
        counter   <= 27'd0;
        led_state <= ~led_state;
      end else begin
        counter <= counter + 1;
      end
    end
  end

  // --- LED Output Logic ---
  // Note: LEDs on Tang Nano 20K are Active-Low (0 = ON, 1 = OFF)
  // led[4:0]: Blink pattern
  // If led_state is 1, {5{1'b0}} makes them all 0 (ON)
  assign led[4:0] = led_state ? 5'b00000 : 5'b11111;

  // led[5]: Lock indicator
  // We want it ON (0) when locked (1). So we use NOT.
  assign led[5] = !pll_stable;

endmodule
