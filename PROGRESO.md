# Port del EXL 100 / Exeltel a MiSTer — progreso

Para retomar con "sigue".

## Hecho (18/11/2026)

- Estructura MiSTer copiada de FP1100_MiSTer (`sys/` de la misma versión, qsf, workflow,
  `build.bat`, `clean.bat`). Sin `tools/rutas_sdram.tcl`: este core no usa SDRAM.
- `rtl/exl100`: submódulo shaeon/exl100. `files.qip` usa su `rtl/` salvo `exl100_top.sv`,
  `exl_mem.v` y `exl_sdram.v`.
- `EXL100.sv` (emu): PLL 50 → 29 MHz (`clk_sys` = `CLK_VIDEO`), `MEM_EXT = 0` (todo en block
  RAM, como la Poseidon), hps_io con VDNUM 3 (A:, B:, Exelmemoire), las mismas cargas que
  `exl100_top.sv` (índices 0-5, boot.rom = EXL100.ROM), `ps2_key`/`ps2_mouse` convertidos a la
  interfaz de user_io, módem por la UART de MiSTer, video_mixer + video_freak, audio, LEDs.
  Los bits de status de la máquina (6-19) son los mismos que en MiST.
- Exelmemoire: `games/EXL100/boot2.vhd` (copia de EXL100.HD2), que Main_MiSTer monta solo.
- Cambio en el core (shaeon/exl100): `(* ramstyle = "no_rw_check" *)` en `mram` (exl100.v) y
  `buf_` (exl_memoire_sd.v). Sin él, en Cyclone V la RAM de la Exelmemoire salía con 131.000
  biestables (el M10K no da "dato antiguo" en doble puerto verdadero).
- README en inglés y español.

## Pendiente (probar en la placa)

- Que arranque Exelbasic con boot.rom y que suene la melodía de arranque (TMS5220).
- Teclado español y original, mandos, Exelmouse.
- Cartuchos, cinta .K7, disquetes .fd en A y B (Auto), ExelDOS.
- Exelmemoire con boot2.vhd: que guarde y recupere tras apagar.
- Exeltel/Amper: menús, voz, cartucho; módem por la UART (modo de la UART en el OSD).
- Scandoubler / HQ2x / scanlines, salida analógica a 15 kHz y HDMI.
