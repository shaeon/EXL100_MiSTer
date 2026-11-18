// PLL del EXL 100 para MiSTer: 50 MHz -> 29 MHz (clk_sys)
//   29 MHz = 4 x 7,25 MHz, el reloj de punto del TMS3556 (464 puntos = 64 us,
//   313 lineas = 50 Hz), como en las placas MiST
`timescale 1 ps / 1 ps
module pll (
		input  wire  refclk,
		input  wire  rst,
		output wire  outclk_0,
		output wire  locked
	);

	pll_0002 pll_inst (
		.refclk   (refclk),
		.rst      (rst),
		.outclk_0 (outclk_0),
		.locked   (locked)
	);

endmodule
