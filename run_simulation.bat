@echo off
title AXI-SPI IP Behavioral Simulation
color 0A
echo ========================================================
echo        AXI-SPI MASTER IP VERILOG SIMULATION
echo ========================================================
echo.
echo Running Icarus Verilog simulation via WSL...
echo.

wsl -d Ubuntu bash -c "cd /mnt/c/Users/devad/Downloads/axi-spi-ip-main/axi-spi-ip-main && iverilog -o sim_axi_spi src/rtl/*.v src/tb/tb_axi_spi.v && vvp sim_axi_spi"

echo.
echo ========================================================
echo Simulation finished! Press any key to exit.
echo ========================================================
pause > nul
