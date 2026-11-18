# Restricciones propias del core (las generales estan en sys/sys_top.sdc).
#
# Todo el core va con un solo reloj, clk_sys (29 MHz, rtl/pll.v), y no usa la
# SDRAM: no hace falta nada mas. sys_top.sdc ya deriva los relojes del PLL.
