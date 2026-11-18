//-------------------------------------------------------------------------------------------------
// Exelvision EXL 100 / Exeltel (Amper Exeltel-VX) para MiSTer
//
// Core: Shaeon (Carlos Palmero), https://github.com/shaeon/exl100 (submodulo rtl/exl100, el mismo
//       que usan la Poseidon, la SiDi, la Calypso y la MiST). Este fichero hace con el marco de
//       MiSTer lo que exl100_top.sv hace con el de MiST: reloj, hps_io, cargas, SD, teclado,
//       video, audio y LEDs. La maquina (rtl/exl100/rtl/exl100.v) va sin tocar.
//
// Reloj (rtl/pll.v): clk_sys = 29 MHz = 4 x 7,25 MHz, el reloj de punto del TMS3556 (464 puntos =
//   64 us, 313 lineas = 50 Hz). Las CPUs van con una habilitacion fraccionaria a 2,4576 MHz.
//
// Memoria: todo en block RAM (MEM_EXT = 0), como en la Poseidon: cartucho, EXL135, cinta,
//   Exelmemoire, ROM de sistema y ROM de voz del Exeltel. No hace falta el modulo de SDRAM.
//
// ROMs (games/EXL100/boot.rom, indice 0): el EXL100.ROM de las placas MiST (rtl/exl100/sd), con
//   todas las ROMs de las dos maquinas, del EXL135, de la Exelmemoire y de voz. La maquina se
//   queda en reset mientras se carga.
//
// Exelmemoire: la imagen de 16K (EXL100.HD2) va en la unidad 2. MiSTer monta sola, al arrancar el
//   core, games/EXL100/boot2.vhd: basta con copiar alli EXL100.HD2 con ese nombre.
//
// Modem del Exeltel: el enlace serie TTL va por la UART de MiSTer (menu UART del OSD).
//
// This program is free software; you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation; either version 3 of
// the License, or (at your option) any later version.
//-------------------------------------------------------------------------------------------------
`default_nettype none

module emu
(
	`include "sys/emu_ports.vh"
);
//--- defaults ------------------------------------------------------------------------------------

	assign USER_OUT = '1;
	assign {UART_RTS, UART_DTR} = 0;
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
	assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

	assign VGA_F1 = 0;
	assign VGA_SCALER = 0;
	assign VGA_DISABLE = 0;
	assign HDMI_FREEZE = 0;
	assign HDMI_BLACKOUT = 0;
	assign HDMI_BOB_DEINT = 0;

	assign BUTTONS = 0;
	assign LED_POWER = 0;

	assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_RD, DDRAM_DIN, DDRAM_BE, DDRAM_WE} = '0;

//--- config string -------------------------------------------------------------------------------
//
//  Los bits de la maquina (6-19) son los mismos que en las placas MiST.
//
//  bits usados: 0, 2-3, 6-25
//  0         1         2         3
//  01234567890123456789012345678901
//  X XX  XXXXXXXXXXXXXXXXXXXX
//

	`include "build_id.v"
	localparam CONF_STR =
	{
		"EXL100;UART1200,4800,9600,19200;",
		"-;",
		"F1,ROMBIN,Load cartridge;",
		"S0,FD ,Disk A:;",
		"S1,FD ,Disk B:;",
		"F3,K7 ,Load tape;",
		"T[14],Tape play/pause;",
		"T[15],Tape stop & rewind;",
		"-;",
		"O[12],Machine,EXL 100,Exeltel/Amper;",
		"-;",
		"P1,Video & audio;",
		"P1-;",
		"P1O[3:2],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P1O[22:20],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1O[24:23],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
		"P1-;",
		"P1O[10],Speech (TMS5220),Off,On;",
		"P1O[8],Tape sound,On,Off;",
		"P2,Peripherals;",
		"P2-;",
		"P2O[7],Disk unit (EXL135),Auto,Off;",
		"P2O[11],Exelmemoire 16K,Off,On;",
		"P2S2,HD2VHD,Exelmemoire file;",
		"P2O[13],Exelmouse (PS/2 mouse),Off,On;",
		"P2-;",
		"P2O[17],Exeltel cartridge slot,Empty,Cartridge;",
		"P2O[19:18],Exeltel modem link,1200,4800,9600,19200;",
		"P2O[25],Modem carrier,When off-hook,Always;",
		"P3,Input;",
		"P3-;",
		"P3O[16],Keyboard,Spanish,Original;",
		"P3O[6],Joystick,Orange (kbd),White;",
		"P4,ROMs;",
		"P4-;",
		"P4F0,ROM,Reload EXL100.ROM;",
		"P4F2,ROM,Load EXL135 boot ROM;",
		"P4F4,ROM,Load Exelmemoire ROM;",
		"P4F5,ROMBIN,Load Exeltel system ROM;",
		"-;",
		"J1,Fire;",
		"jn,A;",
		"R[0],Reset;",
		"V,v",`BUILD_DATE
	};

//--- reloj ---------------------------------------------------------------------------------------

	wire clk_sys;
	wire pll_locked;

	pll pll
	(
		.refclk  (CLK_50M   ),
		.rst     (1'b0      ),
		.outclk_0(clk_sys   ),     // 29 MHz
		.locked  (pll_locked)
	);

	localparam CLK_HZ = 29_000_000;

	// cen_pix: 7,25 MHz (/4). cen_cpu: 2,4576 MHz por acumulador de fase
	// (2,4576/29 * 2^20 = 88880 por clk); nunca dos clk seguidos.
	reg [ 1:0] div4 = 2'd0;
	reg [19:0] acc_cpu = 20'd0;
	reg        cen_pix = 1'b0, cen_cpu = 1'b0;
	always @(posedge clk_sys) begin
		div4 <= div4 + 2'd1;
		cen_pix <= (div4 == 2'd3);
		{cen_cpu, acc_cpu} <= {1'b0, acc_cpu} + 21'd88880;   // el acarreo es cen_cpu
	end

//--- hps io --------------------------------------------------------------------------------------

	wire [127:0] status;
	wire [  1:0] buttons;
	wire         forced_scandoubler;
	wire [ 21:0] gamma_bus;

	wire [ 10:0] ps2_key;
	wire [ 24:0] ps2_mouse;
	wire [ 31:0] joy0, joy1;

	wire         ioctl_download;
	wire [ 15:0] ioctl_index;
	wire         ioctl_wr;
	wire [ 26:0] ioctl_addr;
	wire [  7:0] ioctl_dout;

	wire [  2:0] img_mounted;
	wire         img_readonly;
	wire [ 63:0] img_size;

	wire [ 31:0] sd_lba[3];
	wire [  2:0] sd_rd;
	wire [  2:0] sd_wr;
	wire [  2:0] sd_ack;
	wire [  8:0] sd_buff_addr;
	wire [  7:0] sd_buff_dout;
	wire [  7:0] sd_buff_din[3];
	wire         sd_buff_wr;

	hps_io #(.CONF_STR(CONF_STR), .VDNUM(3)) hps_io
	(
		.clk_sys           (clk_sys           ),
		.HPS_BUS           (HPS_BUS           ),
		.EXT_BUS           (                  ),
		.gamma_bus         (gamma_bus         ),

		.forced_scandoubler(forced_scandoubler),
		.buttons           (buttons           ),
		.status            (status            ),
		.status_menumask   (16'd0             ),

		.ps2_key           (ps2_key           ),
		.ps2_mouse         (ps2_mouse         ),
		.joystick_0        (joy0              ),
		.joystick_1        (joy1              ),

		.ioctl_download    (ioctl_download    ),
		.ioctl_index       (ioctl_index       ),
		.ioctl_wr          (ioctl_wr          ),
		.ioctl_addr        (ioctl_addr        ),
		.ioctl_dout        (ioctl_dout        ),
		.ioctl_wait        (1'b0              ),   // todo en block RAM: un byte por ciclo

		.img_mounted       (img_mounted       ),
		.img_readonly      (img_readonly      ),
		.img_size          (img_size          ),

		.sd_lba            (sd_lba            ),
		.sd_blk_cnt        ('{6'd0, 6'd0, 6'd0}),
		.sd_rd             (sd_rd             ),
		.sd_wr             (sd_wr             ),
		.sd_ack            (sd_ack            ),
		.sd_buff_addr      (sd_buff_addr      ),
		.sd_buff_dout      (sd_buff_dout      ),
		.sd_buff_din       (sd_buff_din       ),
		.sd_buff_wr        (sd_buff_wr        )
	);

//--- carga de ficheros (como en exl100_top.sv) ---------------------------------------------------
//
//   indice 0 = EXL100.ROM (boot.rom): 0000-07FF TMS7020, 0800-17FF TMS7041, 1800-95FF cartucho,
//              9600-B5FF bootstrap del EXL135, B600-D5FF CROS de la Exelmemoire, D600-E5FF TMS7040,
//              E600-F5FF TMS7042, F600-1F5FF ROM de sistema del Exeltel, 1F600-235FF ROM de voz
//   indice 1 = cartucho, 2 = bootstrap del EXL135, 3 = cinta .K7, 4 = CROS, 5 = sistema Exeltel

	wire rom_dl  = ioctl_download && (ioctl_index[5:0] == 6'd0);
	wire cart_dl = ioctl_download && (ioctl_index[5:0] == 6'd1);
	wire disk_dl = ioctl_download && (ioctl_index[5:0] == 6'd2);
	wire k7_dl   = ioctl_download && (ioctl_index[5:0] == 6'd3);
	wire cros_dl = ioctl_download && (ioctl_index[5:0] == 6'd4);
	wire sis_dl  = ioctl_download && (ioctl_index[5:0] == 6'd5);

	reg        xt_ok; reg [1:0] xt_sel; reg [15:0] xt_addr;
	always @(*) begin
		xt_ok = 1'b0; xt_sel = 2'd0; xt_addr = 16'd0;
		if (rom_dl && ioctl_addr >= 27'hD600 && ioctl_addr < 27'hE600) begin xt_ok = 1'b1; xt_sel = 2'd0; xt_addr = ioctl_addr[15:0] - 16'hD600; end
		else if (rom_dl && ioctl_addr >= 27'hE600 && ioctl_addr < 27'hF600) begin xt_ok = 1'b1; xt_sel = 2'd1; xt_addr = ioctl_addr[15:0] - 16'hE600; end
		else if (rom_dl && ioctl_addr >= 27'hF600 && ioctl_addr < 27'h1F600) begin xt_ok = 1'b1; xt_sel = 2'd2; xt_addr = ioctl_addr[15:0] - 16'hF600; end
		else if (sis_dl && ioctl_addr < 27'h10000) begin xt_ok = 1'b1; xt_sel = 2'd2; xt_addr = ioctl_addr[15:0]; end
	end
	wire xt_wr = ioctl_wr && xt_ok;

	wire        voz_ok   = rom_dl && ioctl_addr >= 27'h1F600 && ioctl_addr < 27'h23600;
	wire [13:0] voz_addr = ioctl_addr[13:0] - 14'h3600;          // 1F600 -> 0 (mod 16K)
	wire        voz_wr   = ioctl_wr && voz_ok;

	wire        cros_ok   = (cros_dl && ioctl_addr < 27'h2000) || (rom_dl && ioctl_addr >= 27'hB600 && ioctl_addr < 27'hD600);
	wire [12:0] cros_addr = cros_dl ? ioctl_addr[12:0] : ioctl_addr[12:0] - 13'h1600;   // B600 -> 0 (mod 8K)
	wire        cros_wr   = ioctl_wr && cros_ok;

	reg  [ 1:0] ld_sel;
	reg  [14:0] ld_addr;
	reg         ld_ok;
	always @(*) begin
		ld_ok = 1'b0; ld_sel = 2'd0; ld_addr = 15'd0;
		if (rom_dl) begin
			if (ioctl_addr < 27'h0800)      begin ld_ok = 1'b1; ld_sel = 2'd0; ld_addr = ioctl_addr[14:0]; end
			else if (ioctl_addr < 27'h1800) begin ld_ok = 1'b1; ld_sel = 2'd1; ld_addr = ioctl_addr[14:0] - 15'h0800; end
			else if (ioctl_addr < 27'h9600) begin ld_ok = 1'b1; ld_sel = 2'd2; ld_addr = ioctl_addr[14:0] - 15'h1800; end
			else if (ioctl_addr < 27'hB600) begin ld_ok = 1'b1; ld_sel = 2'd3; ld_addr = ioctl_addr[14:0] - 15'h1600; end  // 9600 -> 0 (mod 8K)
		end else if (cart_dl && ioctl_addr < 27'h7E00) begin ld_ok = 1'b1; ld_sel = 2'd2; ld_addr = ioctl_addr[14:0]; end
		else if (disk_dl && ioctl_addr < 27'h2000) begin ld_ok = 1'b1; ld_sel = 2'd3; ld_addr = ioctl_addr[14:0]; end
	end
	wire ld_wr = ioctl_wr && ld_ok;

	// cinta: la longitud es la ultima direccion escrita + 1
	reg [17:0] k7_len = 18'd0;
	always @(posedge clk_sys) if (k7_dl && ioctl_wr) k7_len <= ioctl_addr[17:0] + 18'd1;

//--- reset ---------------------------------------------------------------------------------------

	// conectar o quitar la Exelmemoire, o cambiar de maquina, reinicia (como en la real)
	reg memoire_ant = 1'b0, maquina_ant = 1'b0;
	always @(posedge clk_sys) begin memoire_ant <= status[11]; maquina_ant <= status[12]; end

	// Unidad de disquetes EXL135 en Auto (O7 = 0): se activa al montar un disquete en A: o B: y,
	// si no estaba activa, reinicia para que arranque desde el disco. Sigue activa aunque se
	// expulse el disco hasta el siguiente reset; al reiniciar sin ningun disco se desactiva.
	reg [1:0] disco_montado = 2'b00;
	reg       unidad_disco = 1'b0, unidad_ant = 1'b0;
	always @(posedge clk_sys) begin
		if (img_mounted[0]) disco_montado[0] <= |img_size;
		if (img_mounted[1]) disco_montado[1] <= |img_size;
		if (status[7]) unidad_disco <= 1'b0;
		else if (|disco_montado) unidad_disco <= 1'b1;
		else if (status[0] | buttons[1] | RESET) unidad_disco <= 1'b0;
		unidad_ant <= unidad_disco;
	end

	wire reset = RESET | status[0] | buttons[1] | ~pll_locked | (ioctl_download & ~k7_dl)   // cargar una cinta no reinicia
	           | (status[11] ^ memoire_ant) | (status[12] ^ maquina_ant)
	           | (unidad_disco & ~unidad_ant);

//--- teclado, mandos y raton ---------------------------------------------------------------------

	// ps2_key de hps_io -> la interfaz key_strobe/key_code de user_io (MiST)
	reg key_tgl = 1'b0, key_strobe = 1'b0;
	always @(posedge clk_sys) begin
		key_tgl    <= ps2_key[10];
		key_strobe <= ps2_key[10] ^ key_tgl;
	end

	wire [5:0] canal_kb_ps2;
	exl_ps2 #(.CLK_HZ(CLK_HZ)) ps2
	(
		.clk(clk_sys), .reset_n(~reset),
		.key_strobe(key_strobe), .key_code(ps2_key[7:0]), .key_pressed(ps2_key[9]), .key_extended(ps2_key[8]),
		.espanol(~status[16]), .amper(status[12]), .canal(canal_kb_ps2)
	);

	// mando: 0 derecha, 1 izquierda, 2 abajo, 3 arriba, 4 disparo (igual que en user_io)
	function [5:0] canal_joy; input [7:0] j;
		casez ({j[4], j[3], j[2], j[1], j[0]})     // disparo arriba abajo izq der
			5'b1????: canal_joy = 6'd6;            // disparo = barra espaciadora
			5'b01001: canal_joy = 6'd33;           // arriba+derecha
			5'b00101: canal_joy = 6'd34;           // abajo+derecha
			5'b01010: canal_joy = 6'd36;           // arriba+izquierda
			5'b00110: canal_joy = 6'd45;           // abajo+izquierda
			5'b01000: canal_joy = 6'd1;
			5'b00001: canal_joy = 6'd2;
			5'b00100: canal_joy = 6'd3;
			5'b00010: canal_joy = 6'd4;
			default:  canal_joy = 6'd63;
		endcase
	endfunction
	wire [5:0] canal_joy_a = canal_joy(joy0[7:0]);
	wire [5:0] canal_joy_b = canal_joy(joy1[7:0]);
	// el mando 1 va al receptor del teclado (naranja) o al blanco segun la opcion
	wire [5:0] canal_kb = (canal_kb_ps2 != 6'd63) ? canal_kb_ps2 : (status[6] ? canal_joy_b : canal_joy_a);
	wire [5:0] canal_j1 = status[6] ? canal_joy_a : canal_joy_b;

	// raton: ps2_mouse = {conmutador, Y, X, flags}; flags[4]/[5] = signo de X/Y, [1:0] botones
	reg mouse_tgl = 1'b0, raton_stb = 1'b0;
	always @(posedge clk_sys) begin
		mouse_tgl <= ps2_mouse[24];
		raton_stb <= ps2_mouse[24] ^ mouse_tgl;
	end
	wire [8:0] raton_x = {ps2_mouse[4], ps2_mouse[15:8]};
	wire [8:0] raton_y = {ps2_mouse[5], ps2_mouse[23:16]};

//--- SD: disquetes (0, 1) y Exelmemoire (2) ------------------------------------------------------

	wire [31:0] lba, fdc_sd_lba, memo_sd_lba;
	wire [ 1:0] fdc_sd_rd, fdc_sd_wr;
	wire [ 7:0] sd_din, fdc_sd_din, memo_sd_din;
	wire        memo_sd_rd, memo_sd_wr, memo_activo;
	wire        sd_ack_any = |sd_ack;

	assign lba       = memo_activo ? memo_sd_lba : fdc_sd_lba;
	assign sd_rd     = {memo_sd_rd, memo_activo ? 2'b00 : fdc_sd_rd};
	assign sd_wr     = {memo_sd_wr, memo_activo ? 2'b00 : fdc_sd_wr};
	assign sd_din    = memo_activo ? memo_sd_din : fdc_sd_din;
	assign sd_lba[0] = lba;  assign sd_lba[1] = lba;  assign sd_lba[2] = lba;
	assign sd_buff_din[0] = sd_din;  assign sd_buff_din[1] = sd_din;  assign sd_buff_din[2] = sd_din;

	wire        memo_cpu_wr;
	wire [13:0] memo_cpu_addr, memo_ram_addr;
	wire        memo_ram_rd, memo_ram_wr;
	wire [ 7:0] memo_ram_din, mram2_q;
	reg  [ 7:0] memo_ram_q;
	reg         memo_ram_ack;

	exl_memoire_sd #(.CLK_HZ(CLK_HZ)) memoire_sd
	(
		.clk(clk_sys), .reset(~pll_locked),
		.img_mounted(img_mounted[2]), .img_size(img_size[31:0]),
		.sd_rd(memo_sd_rd), .sd_wr(memo_sd_wr), .sd_lba(memo_sd_lba), .sd_ack(sd_ack_any),
		.sd_buff_addr(sd_buff_addr), .sd_dout(sd_buff_dout), .sd_dout_strobe(sd_buff_wr), .sd_din(memo_sd_din),
		.fdc_quieto(fdc_sd_rd == 2'b00 && fdc_sd_wr == 2'b00), .activo(memo_activo),
		.cpu_wr(memo_cpu_wr), .cpu_addr(memo_cpu_addr),
		.ram_rd(memo_ram_rd), .ram_wr(memo_ram_wr), .ram_addr(memo_ram_addr), .ram_din(memo_ram_din),
		.ram_q(memo_ram_q), .ram_ack(memo_ram_ack), .presente()
	);

	// RAM de la Exelmemoire en BRAM: segundo puerto de exl100, dato a los dos ciclos
	reg memo_d1 = 1'b0;
	always @(posedge clk_sys) begin
		memo_d1      <= memo_ram_rd | memo_ram_wr;
		memo_ram_ack <= memo_d1;
		memo_ram_q   <= mram2_q;
	end

//--- modem del Exeltel por la UART --------------------------------------------------------------

	wire modem_txd, modem_descolgado;
	reg  [1:0] rxd_s = 2'b11;
	always @(posedge clk_sys) rxd_s <= {rxd_s[0], UART_RXD};
	assign UART_TXD = modem_txd;
	// Portadora: con un enlace serie fijo no hay DCD de verdad. "When off-hook" la da en cuanto el
	// software descuelga (como si la llamada se hubiera establecido); "Always", siempre.
	wire modem_dcd = status[25] | modem_descolgado;

//--- maquina -------------------------------------------------------------------------------------

	wire        led_disco;
	wire signed [13:0] voz;
	wire        k7_marcha, k7_senal;
	wire        vr, vg, vb, vhs_n, vvs_n, vhb, vvb, cas_out;
	wire        prn_txd;

	exl100 #(.CLK_HZ(CLK_HZ), .MEM_EXT(0)) maquina
	(
		.clk(clk_sys), .cen_cpu(cen_cpu), .cen_pix(cen_pix), .reset_n(~reset),
		.ld_wr(ld_wr), .ld_sel(ld_sel), .ld_addr(cros_wr ? {2'b00, cros_addr} : ld_addr), .ld_data(ioctl_dout),
		.memoire_activa(status[11]), .cros_wr(cros_wr), .xt_cartucho(status[17]),
		.vozrom_wr(voz_wr), .vozrom_addr(voz_addr),
		.vsm_mem_rd(), .vsm_mem_addr(), .vsm_mem_q(8'hFF), .vsm_mem_ack(1'b0),
		.raton_activo(status[13]), .ps2_raton_stb(raton_stb), .ps2_raton_x(raton_x), .ps2_raton_y(raton_y),
		.ps2_raton_bot({ps2_mouse[1], ps2_mouse[0]}), .prn_txd(prn_txd), .prn_cts(1'b1),
		.modem_txd(modem_txd), .modem_rxd(rxd_s[1]), .modem_portadora(modem_dcd), .modem_descolgado(modem_descolgado),
		.modem_vel(status[19:18]),
		.exeltel(status[12]), .xt_wr(xt_wr), .xt_sel(xt_sel), .xt_addr(xt_addr),
		.mem_req(), .mem_we(), .mem_addr(), .mem_din(), .mem_q(8'hFF), .mem_ack(1'b0),
		.k7_mem_rd(), .k7_mem_addr(), .k7_mem_q(8'hFF), .k7_mem_ack(1'b0),
		.canal_kb(canal_kb), .canal_joy1(canal_j1),
		.cas_in(1'b0), .cas_out(cas_out),
		.r(vr), .g(vg), .b(vb), .hsync_n(vhs_n), .vsync_n(vvs_n), .hblank(vhb), .vblank(vvb), .disp_en(),
		.sp_data(), .sp_ws_n(), .sp_rs_n(), .voz(voz), .voz_activa(status[10]),
		.k7_wr(k7_dl && ioctl_wr), .k7_addr(ioctl_addr[16:0]), .k7_data(ioctl_dout), .k7_len(k7_len),
		.k7_play(status[14]), .k7_rewind(status[15]), .k7_marcha(k7_marcha), .k7_senal(k7_senal),
		.memo_cpu_wr(memo_cpu_wr), .memo_cpu_addr(memo_cpu_addr),
		.mram2_addr(memo_ram_addr), .mram2_we(memo_ram_wr), .mram2_din(memo_ram_din), .mram2_q(mram2_q),
		.disco_activo(unidad_disco), .img_mounted(img_mounted[1:0]), .img_size(img_size[31:0]), .img_wp(img_readonly),
		.sd_lba(fdc_sd_lba), .sd_rd(fdc_sd_rd), .sd_wr(fdc_sd_wr), .sd_ack(sd_ack_any & ~memo_activo), .sd_buff_addr(sd_buff_addr),
		.sd_dout(sd_buff_dout), .sd_din(fdc_sd_din), .sd_dout_strobe(sd_buff_wr & ~memo_activo), .led_disco(led_disco),
		.dbg_pc20(), .dbg_pc41(), .dbg_wx_wr()
	);

//--- video ---------------------------------------------------------------------------------------

	// TMS3556: 8 colores (un bit por componente), punto = clk_sys / 4. Zona visible con borde:
	// 384 x 290 (pantalla de 320 x 250 en el centro).
	wire [2:0] scale = status[22:20];
	wire       sl    = (scale >= 3'd2);
	wire [1:0] ar    = status[3:2];
	wire       vga_de;

	assign CLK_VIDEO = clk_sys;
	assign VGA_SL    = sl ? scale[1:0] - 2'd1 : 2'd0;

	video_freak video_freak
	(
		.CLK_VIDEO  (CLK_VIDEO  ),
		.CE_PIXEL   (CE_PIXEL   ),
		.VGA_VS     (VGA_VS     ),
		.HDMI_WIDTH (HDMI_WIDTH ),
		.HDMI_HEIGHT(HDMI_HEIGHT),
		.VGA_DE     (VGA_DE     ),
		.VIDEO_ARX  (VIDEO_ARX  ),
		.VIDEO_ARY  (VIDEO_ARY  ),
		.VGA_DE_IN  (vga_de     ),
		.ARX        ((!ar) ? 12'd4 : (ar - 1'd1)),
		.ARY        ((!ar) ? 12'd3 : 12'd0),
		.CROP_SIZE  (12'd0      ),
		.CROP_OFF   (5'd0       ),
		.SCALE      ({1'b0, status[24:23]})
	);

	video_mixer #(.LINE_LENGTH(480), .GAMMA(1)) video_mixer
	(
		.CLK_VIDEO  (CLK_VIDEO  ),
		.CE_PIXEL   (CE_PIXEL   ),
		.ce_pix     (cen_pix    ),
		.scandoubler(forced_scandoubler || scale != 3'd0),
		.hq2x       (scale == 3'd1),
		.gamma_bus  (gamma_bus  ),
		.R          ({8{vr}}    ),
		.G          ({8{vg}}    ),
		.B          ({8{vb}}    ),
		.HSync      (~vhs_n     ),
		.VSync      (~vvs_n     ),
		.HBlank     (vhb        ),
		.VBlank     (vvb        ),
		.HDMI_FREEZE(1'b0       ),
		.freeze_sync(           ),
		.VGA_R      (VGA_R      ),
		.VGA_G      (VGA_G      ),
		.VGA_B      (VGA_B      ),
		.VGA_VS     (VGA_VS     ),
		.VGA_HS     (VGA_HS     ),
		.VGA_DE     (vga_de     )
	);

//--- audio ---------------------------------------------------------------------------------------

	// mezcla con signo: la voz del TMS5220, la salida de cassette (B3 del 7020, que la ROM usa
	// tambien para la musica) y, mas baja, la cinta virtual
	wire tape_sound = ~status[8];
	wire signed [15:0] audio_mix = {voz[13], voz, 1'b0}
	                             + (cas_out ? 16'sd6144 : -16'sd6144)
	                             + ((tape_sound && k7_marcha) ? (k7_senal ? 16'sd1536 : -16'sd1536) : 16'sd0);

	reg [15:0] audio = 16'd0;
	always @(posedge clk_sys) audio <= audio_mix;

	assign AUDIO_S   = 1'b1;
	assign AUDIO_L   = audio;
	assign AUDIO_R   = audio;
	assign AUDIO_MIX = 2'd0;

//--- leds ----------------------------------------------------------------------------------------

	assign LED_USER = ioctl_download | k7_marcha;
	assign LED_DISK = {1'b0, led_disco};

//-------------------------------------------------------------------------------------------------
endmodule

`default_nettype wire
