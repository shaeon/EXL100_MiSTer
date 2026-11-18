# Exelvision EXL 100 / Exeltel for MiSTer

*[Leer en español](README_es.md)*

MiSTer core for the French **Exelvision EXL 100** (1984) and its Videotex
sibling, the **Exeltel** (sold in Spain as the **Amper Exeltel-VX**). It is the
same core that runs on the Poseidon, SiDi, Calypso and MiST
([shaeon/exl100](https://github.com/shaeon/exl100)), wrapped in the MiSTer
framework: both TMS7000 processors with their original ROMs, the TMS3556,
TMS5220 speech, Exelbasic, cartridges, `.K7` tapes, the EXL135 disk unit and
the Exelmémoire.

Author: Shaeon (Carlos Palmero).

## Installation

- Copy the `.rbf` to `/media/fat/_Computer/`.
- Copy both files in the `SD/` folder to `/media/fat/games/EXL100/`:
  - `boot.rom`: every ROM of both machines, the EXL135, the Exelmémoire and
    the speech ROM. It is the other boards' `EXL100.ROM`, renamed. It loads by
    itself when the core starts.
  - `boot2.vhd`: the Exelmémoire (16K, blank). It is the other boards'
    `EXL100.HD2`. MiSTer mounts it in drive 2 at start-up and the core saves the
    Exelmémoire contents to it. Copy it again to clear it. It can also be
    mounted by hand (*Peripherals > Exelmemoire file*).
- Cartridges (`.rom`/`.bin`), tapes (`.k7`) and disks (`.fd`) can go in the
  same folder.

## OSD

| Option | |
|---|---|
| Load cartridge | EXL 100 cartridge (up to 31.5K) |
| Disk A: / Disk B: | EXL135 `.fd` images |
| Load tape, Tape play/pause, Tape stop & rewind | `.K7` tape |
| Machine | EXL 100 or Exeltel/Amper (changing it resets) |
| **Video & audio** | |
| Aspect ratio, Scandoubler Fx, Scale | The usual MiSTer ones |
| Speech (TMS5220) | Speech synthesizer |
| Tape sound | Hear the tape while loading |
| **Peripherals** | |
| Disk unit (EXL135) | *Auto*: connected when a disk is mounted, and boots from it |
| Exelmemoire 16K, Exelmemoire file | Battery-backed RAM cartridge, saved to the SD card |
| Exelmouse | The PS/2 mouse as an Exelmouse |
| Exeltel cartridge slot | The Exeltel's cartridge slot |
| Exeltel modem link | Speed of the modem's serial link |
| Modem carrier | *When off-hook*: carrier as soon as the software goes off-hook; *Always*: always |
| **Input** | |
| Keyboard | *Spanish*: what is printed on a Spanish PC keyboard; *Original*: AZERTY by position |
| Joystick | First pad on the keyboard receiver (orange) or the white one |
| **ROMs** | Reload EXL100.ROM or load single ROMs |

## What changes from the other boards

The machine (`rtl/exl100`) is a **submodule and is not modified**. The MiSTer
part lives in `EXL100.sv`, which does what `exl100_top.sv` does on the MiST
boards:

- **Clock**: a 50 to 29 MHz PLL (4 × 7.25 MHz, the TMS3556 dot clock). It is
  also `CLK_VIDEO`; one dot every 4 cycles.
- **Memory**: everything in block RAM, as on the Poseidon. **No SDRAM module
  is needed.**
- **Video**: the TMS3556's 8 colours through MiSTer's `video_mixer`
  (scandoubler, HQ2x, scanlines, HDMI scaler).
- **Keyboard and mouse**: `hps_io`'s `ps2_key` and `ps2_mouse`, converted to
  the `user_io` interface that `exl_ps2` and `exl_raton` expect.
- **Exelmémoire**: on MiST the firmware mounts `EXL100.HD2` by itself; here
  `boot2.vhd` does it.
- **Exeltel modem**: the serial link goes through MiSTer's UART (*UART* menu
  in the OSD) instead of the `PUERTO_MODEM` pins. The serial printer is not
  connected.

## Building

With Quartus 17.0 (`EXL100.qpf`) or `build.bat`. The submodule is needed:
`git clone --recursive` or `git submodule update --init`.

Every push builds the core on GitHub Actions (`raetro/quartus:17.0` Docker
image) and leaves the `.rbf` and the reports in the *Actions* tab. Pushing a
`v*` tag also creates a Release with the `.rbf`.

To update the core: `git -C rtl/exl100 pull` and commit the new submodule
pointer.

## Credits

Those of the core ([shaeon/exl100](https://github.com/shaeon/exl100#credits)):
TMS5220 by d18c7db, fdc1772 by Till Harbaum and gyurco, the **MAME** `exelv`
driver, DCexel and DCexeltel by Daniel Coulom, ti99.com, TOSEC and Gregory
(Torlus). The MiSTer framework (`sys/`, MiSTer-devel, Sorgelig).

To the **Retro-Wiki FPGA-dev Team**, especially Ron, Manuel (teiram), Somhi,
Roderick, Rampa, Kyp and Benito.

## License

GPL v3, like the core (the `sys/` framework is GPL v2 or later). The ROMs
belong to their owners and are not covered by this license.

---

Developed with the help of Claude (Anthropic).
