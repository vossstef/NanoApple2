set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C

add_file mouse/jt6805/jt6805.v
add_file mouse/jt6805/jt6805_alu.v
add_file mouse/jt6805/jt6805_ctrl.v
add_file mouse/jt6805/jt6805_regs.v
add_file mouse/jt6805/jtframe_6805mcu.v
add_file mouse/pia6821.vhd
add_file src/dualshock2.v
add_file src/floppy_track.sv
add_file src/gen_uart.v
add_file src/gowin_dpb/gowin_dpb_trkbuf.v
add_file src/gowin_dpb/sector_dpram.v
add_file src/gowin_prom/gowin_prom_uc.v
add_file src/gowin_sp/gowin_sp_128b.v
add_file src/hdmi/audio_clock_regeneration_packet.sv
add_file src/hdmi/audio_info_frame.sv
add_file src/hdmi/audio_sample_packet.sv
add_file src/hdmi/auxiliary_video_information_info_frame.sv
add_file src/hdmi/hdmi.sv
add_file src/hdmi/packet_assembler.sv
add_file src/hdmi/packet_picker.sv
add_file src/hdmi/serializer.sv
add_file src/hdmi/source_product_description_info_frame.sv
add_file src/hdmi/tmds_channel.sv
add_file src/loader_sd_card.sv
add_file src/misc/hid.v
add_file src/misc/mcu_spi.v
add_file src/misc/osd_u8g2.v
add_file src/misc/scandoubler.v
add_file src/misc/sd_card.v
add_file src/misc/sd_rw.v
add_file src/misc/sdcmd_ctrl.v
add_file src/misc/sysctrl.v
add_file src/misc/video.v
add_file src/misc/video_analyzer.v
add_file src/misc/ws2812.v
add_file src/sdram_tn20k.sv
add_file T65/T65.vhd
add_file T65/T65_ALU.vhd
add_file T65/T65_MCode.vhd
add_file T65/T65_Pack.vhd
add_file mockingboard/mockingboard.vhd
add_file mockingboard/via6522.vhd
add_file mouse/applemouse.vhd
add_file mouse/applemouse_mcu_rom.vhd
add_file mouse/applemouse_rom.vhd
add_file src/CEGen.vhd
add_file src/R65Cx2.vhd
add_file src/apple2.vhd
add_file src/disk_ii.vhd
add_file src/disk_ii_rom.vhd
add_file src/drive_ii.vhd
add_file src/gowin_dpb/gowin_dpb_track_buffer_b.vhd
add_file src/gowin_prom/gowin_prom_apple2.vhd
add_file src/gowin_prom/gowin_prom_key.vhd
add_file src/gowin_rpll/gowin_rpll_tn20k.vhd
add_file src/hdd.vhd
add_file src/hdd_rom.vhd
add_file src/keyboard.vhd
add_file src/ssc.vhd
add_file src/ssc_rom.vhd
add_file src/tang/nano20k_bl616/nanoapple2.vhd
add_file src/timing_generator.vhd
add_file src/vga_controller.vhd
add_file src/gowin_sdpb/gowin_sdpb_palette.vhd
add_file src/video_generator.vhd
add_file src/tang/nano20k_bl616/nanoapple2.cst
add_file src/tang/nano20k_bl616/nanoapple2.sdc
add_file src/gowin_sdpb/gowin_sdpb_8k.vhd
add_file src/uart6551/io_fifo.v
add_file src/uart6551/uart_6551.v
add_file mockingboard/jt49/filter/jt49_dcrm.v
add_file mockingboard/jt49/filter/jt49_dcrm2.v
add_file mockingboard/jt49/filter/jt49_dly.v
add_file mockingboard/jt49/filter/jt49_mave.v
add_file mockingboard/jt49/jt49.v
add_file mockingboard/jt49/jt49_bus.v
add_file mockingboard/jt49/jt49_cen.v
add_file mockingboard/jt49/jt49_div.v
add_file mockingboard/jt49/jt49_eg.v
add_file mockingboard/jt49/jt49_exp.v
add_file mockingboard/jt49/jt49_noise.v

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name nanoapple2_tn20k_bl616
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -top_module nanoapple2
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_jtag_as_gpio 1
set_option -print_all_synthesis_warning 1
set_option -rw_check_on_ram 0
set_option -user_code 00000001
set_option -bit_security 1
set_option -power_on_reset_monitor 1
set_option -timing_driven 1
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
set_option -multi_boot 0
set_option -mspi_jump 0
set_option -cst_warn_to_error 1
set_option -rpt_auto_place_io_info 1
set_option -correct_hold_violation 1

#run syn
run all
