@echo off
title AXI-SPI Waveform Viewer (GTKWave)
echo Opening GTKWave with simulation waveform...
wsl -d Ubuntu bash -c "cd /mnt/c/Users/devad/Downloads/axi-spi-ip-main/axi-spi-ip-main && gtkwave waveform.vcd"
