# Exelvision EXL 100 / Exeltel para MiSTer

*[Read in English](README.md)*

Core de MiSTer del **Exelvision EXL 100** (1984) y de su hermano Videotex, el
**Exeltel** (vendido en España como **Amper Exeltel-VX**). Es el mismo core que
funciona en Poseidon, SiDi, Calypso y MiST
([shaeon/exl100](https://github.com/shaeon/exl100)), con el marco de MiSTer
alrededor: los dos TMS7000 con sus ROMs originales, el TMS3556, la voz del
TMS5220, Exelbasic, cartuchos, cintas `.K7`, la unidad de disco EXL135 y la
Exelmémoire.

Autor: Shaeon (Carlos Palmero).

## Instalación

- Copia el `.rbf` a `/media/fat/_Computer/`.
- Copia los dos ficheros de la carpeta `SD/` a `/media/fat/games/EXL100/`:
  - `boot.rom`: todas las ROMs de las dos máquinas, del EXL135, de la
    Exelmémoire y de voz. Es el `EXL100.ROM` de las otras placas con otro
    nombre. Se carga solo al arrancar el core.
  - `boot2.vhd`: la Exelmémoire (16K, vacía). Es el `EXL100.HD2` de las otras
    placas. MiSTer la monta sola en la unidad 2 al arrancar y el core guarda en
    ella lo que se escriba en la Exelmémoire. Para vaciarla, vuelve a copiarla.
    También se puede montar a mano (*Peripherals > Exelmemoire file*).
- Cartuchos (`.rom`/`.bin`), cintas (`.k7`) y disquetes (`.fd`) pueden ir en
  la misma carpeta.

## OSD

| Opción | |
|---|---|
| Load cartridge | Cartucho del EXL 100 (hasta 31,5K) |
| Disk A: / Disk B: | Imágenes `.fd` del EXL135 |
| Load tape, Tape play/pause, Tape stop & rewind | Cinta `.K7` |
| Machine | EXL 100 o Exeltel/Amper (cambiarla reinicia) |
| **Video & audio** | |
| Aspect ratio, Scandoubler Fx, Scale | Las de siempre de MiSTer |
| Speech (TMS5220) | Voz del sintetizador |
| Tape sound | Oír la cinta mientras carga |
| **Peripherals** | |
| Disk unit (EXL135) | *Auto*: se conecta al montar un disquete y arranca de él |
| Exelmemoire 16K, Exelmemoire file | Cartucho de RAM con batería, guardado en la SD |
| Exelmouse | El ratón PS/2 como Exelmouse |
| Exeltel cartridge slot | Ranura de cartucho del Exeltel |
| Exeltel modem link | Velocidad del enlace serie del módem |
| Modem carrier | *When off-hook*: hay portadora en cuanto el software descuelga; *Always*: siempre |
| **Input** | |
| Keyboard | *Spanish*: lo que pone en un teclado de PC español; *Original*: AZERTY por posición |
| Joystick | El primer mando en el receptor del teclado (naranja) o en el blanco |
| **ROMs** | Recargar EXL100.ROM o cargar ROMs sueltas |

## Qué cambia respecto a las otras placas

La máquina (`rtl/exl100`) es un **submódulo y no se toca**. Lo propio de
MiSTer está en `EXL100.sv`, que hace lo mismo que `exl100_top.sv` en las
placas MiST:

- **Reloj**: una PLL de 50 a 29 MHz (4 × 7,25 MHz, el reloj de punto del
  TMS3556). Es también `CLK_VIDEO`; el punto sale cada 4 ciclos.
- **Memoria**: todo en block RAM, como en la Poseidon. **No hace falta el
  módulo de SDRAM.**
- **Vídeo**: los 8 colores del TMS3556 por el `video_mixer` de MiSTer
  (scandoubler, HQ2x, scanlines, escalador HDMI).
- **Teclado y ratón**: `ps2_key` y `ps2_mouse` de `hps_io`, convertidos a la
  interfaz de `user_io` que esperan `exl_ps2` y `exl_raton`.
- **Exelmémoire**: en MiST el firmware monta solo `EXL100.HD2`; aquí lo hace
  `boot2.vhd`.
- **Módem del Exeltel**: el enlace serie va por la UART de MiSTer (menú
  *UART* del OSD), en vez de los pines `PUERTO_MODEM`. La impresora serie no
  está conectada.

## Compilar

Con Quartus 17.0 (`EXL100.qpf`) o `build.bat`. Hay que descargar el
submódulo: `git clone --recursive` o `git submodule update --init`.

Cada `push` compila el core en GitHub Actions (imagen Docker
`raetro/quartus:17.0`) y deja el `.rbf` y los informes en la pestaña
*Actions*. Al subir una etiqueta `v*` se crea además una Release con el `.rbf`.

Para actualizar el core: `git -C rtl/exl100 pull` y hacer commit del nuevo
puntero del submódulo.

## Créditos

Los del core ([shaeon/exl100](https://github.com/shaeon/exl100#credits)):
TMS5220 de d18c7db, fdc1772 de Till Harbaum y gyurco, el driver `exelv` de
**MAME**, DCexel y DCexeltel de Daniel Coulom, ti99.com, TOSEC y Gregory
(Torlus). El marco de MiSTer (`sys/`, MiSTer-devel, Sorgelig).

Al **Retro-Wiki FPGA-dev Team**, en especial a Ron, Manuel (teiram), Somhi,
Roderick, Rampa, Kyp y Benito.

## Licencia

GPL v3, como el core (el marco `sys/` es GPL v2 o posterior). Las ROMs son de
sus propietarios y no están cubiertas por esta licencia.

---

Desarrollado con la ayuda de Claude (Anthropic).
