################################################################################
# $Id: signalduino_protocols.pm 3510 2024-09-14 22:00:00Z v3.5.1-Ralf9 $
#
# The file is part of the SIGNALduino project
#
# !!! useful hints !!!
# --------------------
# name        => ' '       # name of device or group of all devices
# comment     => ' '       # exact description or example of devices
# changed     => ' '       # date off the last bigger change, e.g. "20181229 new", "20181219 moved to ID 0.3"
# id          => ' '       # number of the protocol definition, each number only once use (accepted no .)
# knownFreqs  => ' '       # known receiver frequency 433.92 | 868.35 (some sensor families or remote send on more frequencies)
#
# Time for one, zero, start, sync, float and pause are calculated by clockabs * value = result in microseconds, positive value stands for high signal, negative value stands for low signal
# clockrange  => [ , ]     # only MC signals | min , max of pulse / pause times in microseconds
# clockabs    => ' '       # only MU + MS signals | value for calculation of pulse / pause times in microseconds
# clockabs    => '-1'      # only MS signals | value pulse / pause times is automatically
# clockpos    => [ , ]     # nur MU - enthaelt die Info wo die clock enthalten ist (cp, one oder zero). https://github.com/Ralf9/RFFHEM/issues/1
# one         => [ , ]     # only MU + MS signals | value pair for a one bit, must be always a positive and negative factor of clockabs (accepted . | example 1.5)
# zero        => [ , ]     # only MU + MS signals | value pair for a zero bit, must be always a positive and negative factor of clockabs (accepted . | example -1.5)
# start       => [ , ]     # only MU - value pair or more for start message
# preSync     => [ , ]     # only MU + MS - value pair or more for preamble pulse of signal
# sync        => [ , ]     # only MS - value pair or more for sync pulse of signal
# float       => [ , ]     # only MU + MS signals | Convert 0F -> 01 (F) to be compatible with CUL
# pause       => [ ]       # delay when sending between two signals (clockabs * pause must be < 32768
#
# length_min  => ' '       # minimum number of bits of message length
# length_max  => ' '       # maximum number of bits of message length
# paddingbits => ' '       # pad up to x bits before call module, default is 4.
# paddingbits => '1'       # will disable padding, use this setting when using dispatchBin
# paddingbits => '2'       # is padded to an even number, that is a maximum of 1 bit
# remove_zero => 1         # removes leading zeros from output
# reconstructBit => 1      # if set, then the last bit is reconstructed if the rest is missing
#
# developId   => 'm'       # logical module is under development
# developId   => 'p'       # protocol is under development or to reserve IDs, the ID in the development attribute with developId => 'p' are only used without the other entries
# developId   => 'y'       # protocol is under development, all IDs in the development attribute with developId => 'y' are used
#
# preamble    => ' '       # prepend to converted message
# preamble    => 'u..'     # message is unknown and without module, forwarding SIGNALduino_un or FHEM DOIF
# preamble    => 'U..'     # message can be unknown and without module, no forwarding SIGNALduino_un but forwarding can FHEM DOIF
# postamble   => ' '       # appends a string to the demodulated signal
#
# clientmodule => ' '      # FHEM module for processing
# filterfunc  => \&        # only MU - SIGNALduino_filterSign | SIGNALduino_compPattern --> SIGNALduino internal filter function, it remove the sign from the pattern, and compress message and pattern
#                          # SIGNALduino_filterMC --> SIGNALduino internal filter function, it will decode MU data via Manchester encoding
# dispatchBin => 1,        # If set to 1, data will be dispatched in binary representation to other logcial modules.
#                            If not set (default) or set to 0, data will be dispatched in hex mode to other logical modules.
# postDemodulation => \&   # only MU + MS - SIGNALduino internal sub for processing before dispatching to a logical module
# method      => \&        # only MC - call to process this message
# format      => ' '       # twostate | pwm | manchester --> modulation type of the signal, only manchester use SIGNALduino internal, other types only comment
# modulematch => ' '       # RegEx on the exact message including preamble | if defined, it will be evaluated
# polarity    => 'invert'  # only MC signals | invert bits of the signal
#
##### notice #### or #### info ############################################################################################################
# !!! Between the keys and values ​​no tabs not equal to a width of 8 or please use spaces !!!
###########################################################################################################################################
# Please provide at least three messages for each new MU/MC/MS protocol and a URL of issue in GitHub or discussion in FHEM Forum
###########################################################################################################################################

package SD_Protocols;

# use vars qw(%ProtocolListSIGNALduino);
# use vars qw(%VersionProtocolList);

our %VersionProtocolList = (
		"version" => 'v3.5.1-ralf_14.09.24'
		);

our %rfmode = (
    "SlowRF_ccFactoryReset"  => 'e',  # sduino default   012E                   0B06 0C00                                                     1A6C    1D91|90 2156 2211 23E9 242A 2500 261F 2741 2800
    "Lacrosse_mode1_WS1080_TX38__B12_N1_17241"   => 'CW0001,0246,0302,042D,05D4,06FF,0700,0802,0D21,0E65,0F6A,1089,115C,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D00,3E04,404d,4131,425f,4349,4454,452b,4600',
    "Lacrosse_mode2__B12_N2_9579"    => 'CW0001,0246,0302,042D,05D4,06FF,0700,0802,0D21,0E65,0F6A,1088,1182,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D02,3E03,404d,4132,425f,4349,4454,452b,4600',
    "PCA301_mode3__B32_N3_6631"      => 'CW0001,0246,0307,042D,05D4,06FF,0700,0802,0D21,0E6B,0FD0,1088,110B,1206,1322,14F8,1553,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D03,3E03,4050,4143,4241,435f,4433,4530,4631,4700',
    "KOPP_FC__B20_N4_4785"           => 'CW0001,0246,0304,04AA,0554,060F,07E0,0800,0D21,0E65,0FCA,10C7,1183,1216,1373,14F8,1540,170C,1829,1936,1B07,1C40,1D91,23E9,242A,2500,261F,3D04,3E02,404b,416f,4270,4370,445f,4546,4643,4700',
    "WS1600_TX22_mode5__B16_N5_8842" => 'CW0001,0246,0303,042D,05D4,06FF,0700,0802,0D21,0E65,0F6A,1088,1165,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D05,3E04,404d,4135,425f,4349,4454,452b,4600',
 "DP100_WH51_WH57_868__B16_N6_17241" => 'CW0001,0246,0303,042D,05D4,06FF,0700,0802,0D21,0E66,0F1A,1089,115C,1206,1322,14F8,1543,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D06,3E04,4057,4148,4235,4331,4457,4548,4635,4737',
 "DP100_WH51_WH57_433__B16_N16_17241" =>'CW0001,0246,0303,042D,05D4,06FF,0700,0802,0D10,0EB0,0F71,1089,115C,1206,1322,14F8,1543,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D10,3E04,4057,4148,4235,4331,4457,4548,4635,4737',
 "Bresser_5in1_u_7in1__B28_N7_8220"  => 'CW0001,0246,0306,042D,05D4,06FF,07C0,0802,0D21,0E65,0FE8,1088,114C,1202,1322,14F8,1551,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D07,3E04,4042,4172,4265,4373,4473,4535,4631,4700',
    "Bresser_6in1__B20_N7_8220"      => 'CW0001,0246,0304,042D,05D4,06FF,07C0,0802,0D21,0E65,0FE8,1088,114C,1202,1322,14F8,1551,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D07,3E04,4042,4172,4265,4373,4473,4536,4631,4700',
    "HoneywActivL__SlowRf_FSK"       => 'CW000D,022D,0307,04D3,0591,063D,0704,0832,0D21,0E65,0FE8,1087,11F8,1200,1323,14B9,1550,1700,1818,1914,1B43,1C00,1D91,23E9,242A,2500,2611,3D00,3E00,4048,4177,4253,436C,446F,4577,4652,4746',
    "Rojaflex_433__B12_N8_GFSK"      => 'CW0007,0246,0302,04D3,0591,060C,0788,0805,0D10,0EB0,0F71,10C8,1193,1213,1322,14F8,1535,170F,1818,1916,1B43,1C40,1D91,23E9,242A,2500,2611,3D08,3E04,4052,416f,426a,4361,4466,456c,4665,4778',
    "Avantek_433__B8_N9_FSK"         => 'CW0001,0246,0301,0408,0569,06FF,0780,0802,0D10,0EAA,0F56,108A,11F8,1202,1322,14F8,1551,1700,1818,1916,1B43,1C40,1D91,23E9,242A,2500,2611,3D09,3E04,4041,4176,4261,436e,4474,4565,466b,4700',
    "WH24_WH25__B20_N1_17241"        => 'CW0001,0246,0304,042D,05D4,06FF,0700,0802,0D21,0E65,0F6A,1089,115C,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D00,3E04,4057,4148,4232,4334,4457,4548,4632,4735',
    "W136__B24_N10_4798"             => 'CW0001,0246,0305,042D,05D4,06FF,0700,0802,0D21,0E65,0F6A,1087,1183,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D0A,3E04,4057,4131,4233,4336,4400',
    "WMBus_S__N11_ab_firmware_V422"  => 'CW0006,0200,0307,0476,0596,06FF,0704,0800,0B08,0D21,0E65,0F6A,106A,114A,1206,1322,14F8,1547,1700,1818,192E,1A6D,1B04,1C09,1DB2,21B6,23EA,242A,2500,261F,3AA6,3D0B,3E08,4057,414D,4242,4375,4473,4553,4600',
    "WMBus_T_u_C__N12_ab_firmw_V422" => 'CW0006,0200,0307,0454,053D,06FF,0704,0800,0B08,0D21,0E6B,0FD0,105C,1104,1206,1322,14F8,1544,1700,1818,192E,1ABF,1B43,1C09,1DB5,21B6,23EA,242A,2500,261F,3AA6,3D0C,3E08,4057,414D,4242,4375,4473,4554,465F,4743'
    );

our %rfmodeTesting = (
                                      # sduino default   012E                   0B06 0C00                                                     1A6C    1D91|90 2156 2211 23E9 242A 2500 261F 2741 2800
"Lacrosse_mode1_TX38__B5_N1_17241"   => 'CW0001,0246,0301,042D,05D4,0605,0700,0800,0D21,0E65,0F6A,1089,115C,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D00,3E01,404d,4131,425f,4349,4454,452b,4600',
"Lacrosse_mode1_WS1080_TX38__B10_N1_17241" => 'CW0001,0246,0302,042D,05D4,060A,0700,0800,0D21,0E65,0F6A,1089,115C,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D00,3E01,404d,4131,425f,4349,4454,452b,4600',
    "Lacrosse_mode2__B5_N2_9579"     => 'CW0001,0246,0301,042D,05D4,0605,0700,0800,0D21,0E65,0F6A,1088,1182,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D02,3E01,404d,4132,425f,4349,4454,452b,4600',
    "PCA301_mode3__B12_N3_6631"      => 'CW0001,0246,0307,042D,05D4,060C,0700,0800,0D21,0E6B,0FD0,1088,110B,1206,1322,14F8,1553,170F,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D03,3E01,4050,4143,4241,435f,4433,4530,4631,4700',
    "WS1600_TX22_mode5__B5_N5_8842"  => 'CW0001,0246,0301,042D,05D4,0605,0700,0800,0D21,0E65,0F6A,1088,1165,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D05,3E01,404d,4135,425f,4349,4454,452b,4600',
 "DP100_WH51_WH57_868__B14_N6_17241" => 'CW0001,0246,0303,042D,05D4,060E,0700,0800,0D21,0E66,0F1A,1089,115C,1206,1322,14F8,1543,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D06,3E01,4057,4148,4235,4331,4457,4548,4635,4737',
 "DP100_WH51_WH57_433__B14_N16_17241" =>'CW0001,0246,0303,042D,05D4,060E,0700,0800,0D10,0EB0,0F71,1089,115C,1206,1322,14F8,1543,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D10,3E01,4057,4148,4235,4331,4457,4548,4635,4737',
 "Bresser_5in1_u_7in1__B26_N7_8220"  => 'CW0001,0246,0306,042D,05D4,061A,07C0,0800,0D21,0E65,0FE8,1088,114C,1202,1322,14F8,1551,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D07,3E01,4042,4172,4265,4373,4473,4535,4631,4700',
    "Bresser_6in1__B18_N7_8220"      => 'CW0001,0246,0304,042D,05D4,0612,07C0,0800,0D21,0E65,0FE8,1088,114C,1202,1322,14F8,1551,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D07,3E01,4042,4172,4265,4373,4473,4536,4631,4700',
    "Avantek_433__B5_N9_FSK"         => 'CW0001,0246,0301,0408,0569,0605,0780,0800,0D10,0EAA,0F56,108A,11F8,1202,1322,14F8,1551,1700,1818,1916,1B43,1C40,1D91,23E9,242A,2500,2611,3D09,3E01,4041,4176,4261,436e,4474,4565,466b,4700',
    "Inkbird_433__B18_N14_FSK"       => 'CW0001,0246,0304,042D,05D4,0612,07C0,0800,0D10,0EB0,0F71,10C8,1193,1202,1322,14F8,1543,1700,1818,1916,1B43,1C48,1D91,23E9,242A,2500,2611,3D0E,3E01,4049,416E,426B,4362,4469,4572,4664,4700',
    "WH24_WH25__B16_N1_17241"        => 'CW0001,0246,0304,042D,05D4,0610,0700,0800,0D21,0E65,0F6A,1089,115C,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D00,3E01,4057,4148,4232,4334,4457,4548,4632,4735',
    "W136__B24_N10_4798"             => 'CW0001,0246,0305,042D,05D4,0616,0700,0800,0D21,0E65,0F6A,1087,1183,1206,1322,14F8,1556,1700,1818,1916,1B43,1C68,1D91,23E9,242A,2500,2611,3D0A,3E01,4057,4131,4233,4336,4400',
    "Elero__N13_ab_firmw_V335_u_V422"=> 'CW0007,0209,0307,04D3,0591,063C,078C,0845,0B08,0D21,0E71,0F7A,107B,1183,1213,1352,14F8,1543,173F,1818,191D,1A1C,1BC7,1C00,1DB2,21B6,23EA,242A,2500,261F,2C81,2D35,2E09,3AA5,3B60,3D0D,3E01,4045,416C,4265,4372,446F,4500',
    "MAX__N15"                       => 'CW0007,0246,0307,04C6,0526,06FF,070C,0845,0D21,0E65,0F6A,10C8,1193,1203,1322,14F8,1534,173F,1916,1B43,1C40,1D91,23E9,242A,251F,2611,3D0F,3E01,404D,4141,4258,435F,4400'
    );

our %ProtocolListSIGNALduino  = (
	"0"	=>	## various weather sensors (500 | 9100)
					# CUL_TCM97001 Typ - Prologue
					# MS;P0=-4152;P1=643;P2=-2068;P3=-9066;D=1310121210121212101210101212121212121212121212121010121012121212121012101212;CP=1;SP=3;R=220;O;m2;
					# MS;P0=-4149;P2=-9098;P3=628;P4=-2076;D=3230343430343434303430303434343434343434343434343030343030343434343034303434;CP=3;SP=2;R=218;O;m2;
					# CUL_TCM97001 Typ - AURIOL / Mebus / TCM...
					# MS;P0=-9298;P1=495;P2=-1980;P3=-4239;D=1012121312131313121313121312121212121212131212131312131212;CP=1;SP=0;R=223;O;m2;
		{
			name			=> 'weather (v1)',
			comment			=> 'Logilink, NC, WS, TCM97001 etc',
			id			=> '0',
			one			=> [1,-7],
			zero			=> [1,-3],
			sync			=> [1,-16],
			clockabs   		=> -1,   # '500',
			format     		=> 'twostate',  # not used now
			preamble		=> 's',			# prepend to converted message	 	
			postamble		=> '00',		# Append to converted message	 	
			clientmodule    => 'CUL_TCM97001',
			#modulematch     => '^s[A-Fa-f0-9]+', # not used now
			length_min      => '24',
			length_max      => '40',
			paddingbits     => '8',				 # pad up to 8 bits, default is 4
		},
	"0.1"	=>	## other Sensors  (380 | 9650)
						# CUL_TCM97001 Typ - AURIOL | Mebus
						# MS;P1=416;P2=-9618;P3=-4610;P4=-2036;D=1213141313131313141313141314141414141414141313141314131414;CP=1;SP=2;R=220;O;m0;
						# MS;P1=397;P2=-2033;P3=-4627;P4=-9630;D=1413121313131313121313121312121212121212121313121312131212;CP=1;SP=4;R=221;
						# MS;P0=-9690;P3=354;P4=-4662;P5=-2107;D=3034343434343535343534343435353535353535353434353535343535;CP=3;SP=0;R=209;O;m2;
						## LIDL Wetterstation
						# https://github.com/RFD-FHEM/RFFHEM/issues/63
						# MS;P1=367;P2=-2077;P4=-9415;P5=-4014;D=141515151515151515121512121212121212121212121212121212121212121212;CP=1;SP=4;O;
		{
			name			=> 'weather (v2)',
			comment			=> 'temperature / humidity or other sensors',
			changed			=> '20181216 move from ID 38',
			id			=> '0.1',
			one			=> [1,-12],
			zero			=> [1,-6],
			sync			=> [1,-25],
			clockabs		=> -1,
			format			=> 'twostate',		# not used now
			preamble		=> 's',						# prepend to converted message
			postamble		=> '00',					# Append to converted message
			clientmodule	=> 'CUL_TCM97001',
			#modulematch	=> '^s[A-Fa-f0-9]+',
			length_min		=> '24',
			length_max		=> '32',
			paddingbits		=> '8',
		},
	"0.2"	=>	## other Sensors | for sensors how tol is runaway (260+tol | 9650)
						# MS;P1=-2140;P2=309;P3=-4690;P4=-9695;D=2421232323232121232123232321212121212121212123212121232121;CP=2;SP=4;R=211;m1;
						# MS;P0=-9703;P1=304;P2=-2133;P3=-4689;D=1012131312131212131213131312121212121212121212131312131212;CP=1;SP=0;R=208;
						# MS;P0=138;P1=-2140;P2=315;P3=-9704;P4=-4713;P5=234;D=2321212421242454210424212421512121215121512124212121542121;CP=2;SP=3;R=210;
		{
			name			=> 'weather (v3)',
			comment			=> 'temperature / humidity or other sensors',
			changed			=> '20181219 new',
			id			=> '0.2',
			one			=> [1,-18],
			zero			=> [1,-9],
			sync			=> [1,-37],
			clockabs		=> -1,
			format			=> 'twostate',		# not used now
			preamble		=> 's',						# prepend to converted message
			postamble		=> '00',					# Append to converted message
			clientmodule	=> 'CUL_TCM97001',
			#modulematch	=> '^s[A-Fa-f0-9]+',
			length_min		=> '24',
			length_max		=> '32',
			paddingbits		=> '8',
		},
	"0.3"	=>	## Pollin PFR-130
						# CUL_TCM97001 Typ - AURIOL | W174
						# MS;P0=-3890;P1=386;P2=-2191;P3=-8184;D=1312121212121012121212121012121212101012101010121012121210121210101210101012;CP=1;SP=3;R=20;O;
						# MS;P0=-2189;P1=371;P2=-3901;P3=-8158;D=1310101010101210101010101210101010121210121212101210101012101012121012121210;CP=1;SP=3;R=20;O;
						# Ventus W174
						# MS;P3=-2009;P4=479;P5=-9066;P6=-4047;D=45434343464343434643464643464643434643464646434346464343434343434346464643;CP=4;SP=5;R=55;O;m2;
		{
			name			=> 'weather (v4)',
			comment			=> 'temperature / humidity or other sensors | Pollin PFR-130, Ventus W174 ...',
			changed			=> '20181219 move from ID 68',
			id			=> '0.3',
			one			=> [1,-10],
			zero			=> [1,-5],
			sync			=> [1,-21],
			clockabs		=> -1,
			preamble		=> 's',				# prepend to converted message
			postamble		=> '00',			# Append to converted message
			clientmodule	=> 'CUL_TCM97001',
			length_min		=> '36',
			length_max		=> '42',
			paddingbits		=> '8',				 # pad up to 8 bits, default is 4
		},
	"0.4"	=>	## Auriol Z31092  (450 | 9200)
						# CUL_TCM97001 Typ - AURIOL
						# MS;P0=443;P3=-9169;P4=-1993;P5=-3954;D=030405040505050505050404040404040404040505050504050405050504040405;CP=0;SP=3;R=14;O;m0;
						# MS;P0=-9102;P1=446;P2=-3956;P3=-2008;D=10121312121212121312131213131313131313131212121313121213121213121314;CP=1;SP=0;R=212;O;m2;
		{
			name			=> 'weather (v5)',
			comment			=> 'temperature / humidity or other sensors | Auriol Z31092',
			changed			=> '20190101 new',
			id			=> '0.4',
			one			=> [1,-9],
			zero			=> [1,-4],
			sync			=> [1,-20],
			clockabs		=> 450,
			preamble		=> 's',				# prepend to converted message
			postamble		=> '00',			# Append to converted message
			clientmodule	=> 'CUL_TCM97001',
			length_min		=> '32',
			length_max		=> '36',
			paddingbits		=> '8',				 # pad up to 8 bits, default is 4
		},
	"0.5"	=>	## various weather sensors (475 | 8000)
						# ABS700 | Id:79 T: 3.3 Bat:low     MS;P1=-7949;P2=492;P3=-1978;P4=-3970;D=21232423232424242423232323232324242423232323232424;CP=2;SP=1;R=245;O;
						# ABS700 | Id:69 T: 9.3 Bat:low     MS;P1=-7948;P2=471;P3=-1997;P4=-3964;D=21232423232324232423232323242323242423232323232424;CP=2;SP=1;R=246;O;m2;
		{
			name			=> 'weather (v6)',
			comment			=> 'temperature / humidity or other sensors | ABS700',
			changed			=> '20200110 new',
			id			=> '0.5',
			one			=> [1,-8],
			zero			=> [1,-4],
			sync			=> [1,-16],
			clockabs		=> 475,
			format			=> 'twostate',	# not used now
			preamble		=> 's',					# prepend to converted message
			postamble		=> '00',				# Append to converted message
			clientmodule	=> 'CUL_TCM97001',
			#modulematch	=> '^s[A-Fa-f0-9]+',
			length_min		=> '24',
			length_max		=> '24',
			paddingbits		=> '8',					# pad up to 8 bits, default is 4
		},
	"1"	=>	## Conrad RSL
							# on   MS;P1=1154;P2=-697;P3=559;P4=-1303;P5=-7173;D=351234341234341212341212123412343412341234341234343434343434343434;CP=3;SP=5;R=247;O;
							# on   MS;P0=561;P1=-1291;P2=-7158;P3=1174;P4=-688;D=023401013401013434013434340134010134013401013401010101010101010101;CP=0;SP=2;R=248;m1;
		{
			name			=> 'Conrad RSL v1',
			comment			=> 'remotes and switches',
			id			=> '1',
			one			=> [2,-1],
			zero			=> [1,-2],
			sync			=> [1,-11],		
			clockabs   		=> '560',
			format     		=> 'twostate',  		# not used now
			preamble		=> 'P1#',					# prepend to converted message	 	
			#postamble		=> '',					# Append to converted message	 	
			clientmodule    => 'SD_RSL',
			modulematch     => '^P1#[A-Fa-f0-9]{8}',
			length_min 		=> '20',   # 23
			length_max 		=> '40',   # 24
        },
    "2"    => 
        {
			name			=> 'AS, Self build arduino sensor',
			comment         => 'developModule. SD_AS module is only in github available.',
			developId 		=> 'm',
			id          	=> '2',
			one				=> [1,-2],
			zero			=> [1,-1],
			sync			=> [1,-20],
			clockabs     	=> '500',
			format 			=> 'twostate',	
			preamble		=> 'P2#',		# prepend to converted message		
			clientmodule    => 'SD_AS',
			modulematch      => '^P2#.{8,10}',
			length_min       => '32', # without CRC
			length_max       => '40', # with CRC
        },
	"3"	=>	## itv1 - remote like WOFI Lamp | Intertek Modell 1946518 // ELRO
					# need more Device Infos / User Message
		{
			name			=> 'itv1',
			comment			=> 'remote for benon|ELRO|Kangtai|Intertek|REWE|WOFI / PIR JCHENG',
			id			=> '3',
			one			=> [3,-1],
			zero			=> [1,-3],
			#float			=> [-1,3],		# not full supported now later use
			sync			=> [1,-31],
			clockabs     	=> -1,	# -1=auto	
			format 			=> 'twostate',	# not used now
			preamble		=> 'i',			
			clientmodule    => 'IT',
			modulematch     => '^i......',
			length_min      => '24',
			length_max      => '24'
			},
    "3.1"    => # https://forum.fhem.de/index.php/topic,58397.msg757459.html#msg757459
				# MS;P0=-11440;P1=-1121;P2=-416;P5=309;P6=1017;D=150516251515162516251625162516251515151516251625151;CP=5;SP=0;R=66;
			    # MS;P1=309;P2=-1130;P3=1011;P4=-429;P5=-11466;D=15123412121234123412141214121412141212123412341234;CP=1;SP=5;R=38;  Gruppentaste, siehe Kommentar in sub SIGNALduino_bit2itv1
			    # need more Device Infos / User Message
		{
			name			=> 'itv1_sync40',
			comment			=> 'IT remote control PAR 1000, ITS-150, AB440R',
			id			=> '3',
			one			=> [3.5,-1],
			zero			=> [1,-3.8],
			float			=> [1,-1],	# fuer Gruppentaste (nur bei ITS-150,ITR-3500 und ITR-300), siehe Kommentar in sub SIGNALduino_bit2itv1
			sync			=> [1,-44],
			clockabs     	=> -1,	# -1=auto	
			format 			=> 'twostate',	# not used now
			preamble		=> 'i',			
			clientmodule    => 'IT',
			modulematch     => '^i......',
			length_min      => '24',
			length_max      => '24',
			postDemodulation => \&main::SIGNALduino_postDemo_bit2itv1,
			},
    "4"    => # need more Device Infos / User Message
        {
			name			=> 'arctech2',	
			id			=> '4',
			#one			=> [1,-5,1,-1],  
			#zero			=> [1,-1,1,-5],  
			one				=> [1,-5],  
			zero			=> [1,-1],  
			#float			=> [-1,3],		# not full supported now, for later use
			sync			=> [1,-14],
			clockabs     	=> -1,			# -1 = auto
			format 			=> 'twostate',	# tristate can't be migrated from bin into hex!
			preamble		=> 'i',			# Append to converted message	
			postamble		=> '00',		# Append to converted message	 	
			clientmodule    => 'IT',
			modulematch     => '^i......',
			length_min      => '32',
			length_max		=> '44',		# Don't know maximal lenth of a valid message
		},
    "5"    => 	# Unitec, Modellnummer 6899/45108
				# https://github.com/RFD-FHEM/RFFHEM/pull/389#discussion_r237232347 | https://github.com/RFD-FHEM/RFFHEM/pull/389#discussion_r237245943
				# MU;P0=-31960;P1=660;P2=401;P3=-1749;P5=276;D=232353232323232323232323232353535353232323535353535353535353535010;CP=5;R=38;
				# MU;P0=-1757;P1=124;P2=218;P3=282;P5=-31972;P6=644;P7=-9624;D=010201020303030202030303020303030202020202020203030303035670;CP=2;R=32;
				# MU;P0=-1850;P1=172;P3=-136;P5=468;P6=236;D=010101010101310506010101010101010101010101010101010101010;CP=1;R=30;
				# A AN:
				# MU;P0=132;P1=-4680;P2=508;P3=-1775;P4=287;P6=192;D=123434343434343634343436363434343636343434363634343036363434343;CP=4;R=2;
				# A AUS:
				# MU;P0=-1692;P1=132;P2=194;P4=355;P5=474;P7=-31892;D=010202040505050505050404040404040404040470;CP=4;R=27;
		{
			name				=> 'Unitec',
			comment				=> 'remote control model 6899/45108',
			id				=> '5',
			one				=> [3,-1], # ?
			zero			=> [1,-3], # ?
			clockabs		=> 500,    # ?
			developId		=> 'y',
			format 			=> 'twostate',
			preamble		=> 'u5#',
			clientmodule	=> 'SIGNALduino_un',
			#modulematch	=> '',
			length_min      => '24',   # ?
			length_max      => '24',   # ?
		},
		"6"	=>	## TCM 218943, Eurochron
						# https://github.com/RFD-FHEM/RFFHEM/issues/692 @ Ralf9 2019-11-15
						# T:22.9, H:24     MS;P0=-970;P1=254;P3=-1983;P4=-8045;D=14101310131010101310101010101010101010101313101010101010101313131010131013;CP=1;SP=4;
						# T:22.7, H:23, tx MS;P0=-2054;P1=236;P2=-1032;P3=-7760;D=13121012101212121012121210121212121212121012101010121212121010101212121010;CP=1;SP=3;
			{
				name         => 'TCM 218943',
				comment      => 'Weatherstation TCM 218943, Eurochron',
				changed      => '20191113 new',
				id           => '6',
				one          => [1,-5],
				zero         => [1,-10],
				sync         => [1,-32],
				clockabs     => 248,
				format       => 'twostate',
				preamble     => 's',  # prepend to converted message	 	
				postamble    => '00', # append to converted message	 	
				clientmodule => 'CUL_TCM97001',
				length_min   => '36', # sync, postamble und paddingbits werden nicht mitgezaehlt
				length_max   => '36', # sync, postamble und paddingbits werden nicht mitgezaehlt
				paddingbits  => '8',  # pad up to 8 bits, default is 4
			},
	"7"    => ## weather sensors like EAS800z
			  # MS;P1=-3882;P2=504;P3=-957;P4=-1949;D=21232424232323242423232323232323232424232323242423242424242323232324232424;CP=2;SP=1;R=249;m=2;
        {
			name			=> 'weatherID7',	
			comment			=> 'EAS800z, FreeTec NC-7344, HAMA TS34A, Auriol AFW 2 A1',
			id			=> '7',
			one			=> [1,-4],
			zero			=> [1,-2],
			sync			=> [1,-8],		 
			clockabs     	=> 484,			
			format 			=> 'twostate',	
			preamble		=> 'P7#',		# prepend to converted message	
			clientmodule	=> 'SD_WS07',
			modulematch		=> '^P7#.{6}[AF].{2}',
			length_min		=> '35',
			length_max		=> '40',
		}, 
	"8"    =>   ## TX3 (ITTX) Protocol
				# MU;P0=-392;P1=1285;P2=-1024;P3=506;P4=-27790;D=0121212123212321232323212323212123212321212321232123232121212121212321232123232121232121412121212321232123232321232321212321232121232123212323212121212121232123212323212123212141212121232123212323232123232121232123212123212321232321212121212123212321232;CP=3;R=0;O;
        {
			name		=> 'TX3 Protocol',	
			id          	=> '8',
			one			=> [1,-2],
			zero			=> [2,-2],
			#start			=> [2,-55],
			clockabs     	=> 470,
			clockpos		=> ['one',0],
			format 			=> 'pwm',
			preamble		=> 'TX',		# prepend to converted message	
			clientmodule    => 'CUL_TX',
			modulematch     => '^TX......',
			length_min      => '43',
			length_max      => '44',
			remove_zero     => 1,           # Removes leading zeros from output
		}, 	
	"9"    => 			## Funk Wetterstation CTW600
		{
			name			=> 'weatherID9',	
			comment			=> 'Weatherstation WH1080, WH3080, WH5300SE, CTW600',
			id          => '9',
			knownFreqs      => '433.92 | 868.35',
			zero			=> [3,-2],
			one			=> [1,-2],
			#float			=> [-1,3],		# not full supported now, for later use
			#sync			=> [1,-8],		# 
			clockabs     	=> 480,			# -1 = auto undef=noclock
			clockpos		=> ['one',0],
			reconstructBit	=> '1',
			format 			=> 'twostate',
			preamble		=> 'P9#',		# prepend to converted message	
			clientmodule    => 'SD_WS09',
			#modulematch     => '^u9#.....',  # not used now
			length_min      => '60',
			length_max      => '120',
		}, 	
	"10"	=>	## Oregon Scientific 2
				# https://forum.fhem.de/index.php/topic,60170.msg875919.html#msg875919 @David1
				# OSV2 T: 17.8 H: 32 BAT: ok  MC;LL=-997;LH=967;SL=-506;SH=460;D=AAAAAAAA66959A6555655AA55556A9955565A5566AA56A96;C=488;L=192;s1;b1;
				# OSV3 T: 20.2 H: 37 BAT: ok  MC;LL=-1002;LH=952;SL=-489;SH=475;D=000000A0EBDDC4FBFBF13EF5B6;C=486;L=104;s48;b1;
		{
			name		=> 'Oregon Scientific v2|v3',
			comment		=> 'temperature / humidity or other sensors',
			id          	=> '10',
			clockrange     	=> [300,520],			# min , max
			format 			=> 'manchester',	    # tristate can't be migrated from bin into hex!
			clientmodule    => 'OREGON',
			modulematch     => '^(3[8-9A-F]|[4-6][0-9A-F]|7[0-8]).*',
			length_min      => '64',
			length_max      => '220',
			method          => \&main::SIGNALduino_OSV2, # Call to process this message
			polarity        => 'invert',			
		}, 	
	"11"	=>	## Arduino Sensor
		{
			name		=> 'Arduino',
			comment		=> 'for Arduino based sensors',	
			id          	=> '11',
			clockrange     	=> [380,425],			# min , max
			format 			=> 'manchester',	    # tristate can't be migrated from bin into hex!
			preamble		=> 'P2#',		# prepend to converted message	
			clientmodule    => 'SD_AS',
			modulematch     => '^P2#.{7,8}',
			length_min      => '52',
			length_max      => '56',
			method          => \&main::SIGNALduino_AS, # Call to process this message
		}, 
	"12"	=>	## Hideki
				# MC;LL=-1040;LH=904;SL=-542;SH=426;D=A8C233B53A3E0A0783;C=485;L=72;R=213;
		{
			name		=> 'Hideki',
			comment		=> 'temperature / humidity or other sensors',
			id          	=> '12',
			clockrange     	=> [420,510],                   # min, max better for Bresser Sensors, OK for hideki/Hideki/TFA too     
			format 			=> 'manchester',	
			preamble		=> 'P12#',						# prepend to converted message	
			clientmodule    => 'Hideki',   				# not used now
			modulematch     => '^P12#75.+',  						# not used now
			length_min      => '71',
			length_max      => '128',
			method          => \&main::SIGNALduino_Hideki,	# Call to process this message
			polarity        => 'invert',			
		}, 	
	"12.1"    => 			## hideki
		{
            name			=> 'Hideki protocol not invert',
			comment		=> 'only for test of the firmware dev-r33_fixmc',
			id          	=> '12',
			clockrange     	=> [420,510],                   # min, max better for Bresser Sensors, OK for hideki/Hideki/TFA too     
			format 			=> 'manchester',	
			preamble		=> 'P12#',						# prepend to converted message	
			clientmodule    => 'Hideki',   				# not used now
			modulematch     => '^P12#75.+',  						# not used now
			length_min      => '71',
			length_max      => '128',
			method          => \&main::SIGNALduino_Hideki,	# Call to process this message
			developId		=> 'y',
		}, 	
	"13"	=>	## FLAMINGO FA21
						# https://github.com/RFD-FHEM/RFFHEM/issues/21
						# https://github.com/RFD-FHEM/RFFHEM/issues/233
						# MS;P0=-1413;P1=757;P2=-2779;P3=-16079;P4=8093;P5=-954;D=1345121210101212101210101012121012121210121210101010;CP=1;SP=3;R=33;O;
		{
			name						=> 'FLAMINGO FA21',
			comment					=> 'FLAMINGO FA21 smoke detector (message decode as MS)',
			id							=> '13',
			one							=> [1,-2],
			zero						=> [1,-4],
			sync						=> [1,-20,10,-1],
			clockabs				=> 800,
			format					=> 'twostate',
			preamble				=> 'P13#',				# prepend to converted message
			clientmodule		=> 'FLAMINGO',
			#modulematch		=> 'P13#.*',
			length_min			=> '24',
			length_max			=> '26',
		},		
	"13.1"  =>	## FLAMINGO FA20RF
				# MU;P0=-1384;P1=815;P2=-2725;P3=-20001;P4=8159;P5=-891;D=01010121212121010101210101345101210101210101212101010101012121212101010121010134510121010121010121210101010101212121210101012101013451012101012101012121010101010121212121010101210101345101210101210101212101010101012121212101010121010134510121010121010121;CP=1;O;
				# MU;P0=-17201;P1=112;P2=-1419;P3=-28056;P4=8092;P5=-942;P6=777;P7=-2755;D=12134567676762626762626762626767676762626762626267626260456767676262676262676262676767676262676262626762626045676767626267626267626267676767626267626262676262604567676762626762626762626767676762626762626267626260456767676262676262676262676767676262676262;CP=6;O;
				## FLAMINGO FA22RF (only MU Message)
				# MU;P0=-5684;P1=8149;P2=-887;P3=798;P4=-1393;P5=-2746;P6=-19956;D=0123434353534353434343434343435343534343534353534353612343435353435343434343434343534353434353435353435361234343535343534343434343434353435343435343535343536123434353534353434343434343435343534343534353534353612343435353435343434343434343534353434353435;CP=3;R=0;
				# Times measured
				# Sync 8100 microSec, 900 microSec | Bit1 2700 microSec low - 800 microSec high | Bit0 1400 microSec low - 800 microSec high | Pause Repeat 20000 microSec | 1 Sync + 24Bit, Totaltime 65550 microSec without Sync
		{
			name			=> 'FLAMINGO FA22RF / FA21RF / LM-101LD',
			comment			=> 'FLAMINGO | Unitec smoke detector (message decode as MU)',
			id			=> '13.1',
			one			=> [1,-1.8],
			zero			=> [1,-3.5],
			start			=> [10,-1],
			pause			=> [-25],
			clockabs		=> 800,
			clockpos	=> ['cp'],
			format 			=> 'twostate',
			preamble		=> 'P13.1#',				# prepend to converted message
			clientmodule    => 'FLAMINGO', 
			#modulematch     => 'P13#.*',  				# not used now
			length_min      => '24',
			length_max      => '24',
		}, 		
	"13.2"	=>	## LM-101LD Rauchm
					# https://github.com/RFD-FHEM/RFFHEM/issues/233
					# MS;P1=-2708;P2=796;P3=-1387;P4=-8477;P5=8136;P6=-904;D=2456212321212323232321212121212121212123212321212121;CP=2;SP=4;
		{
			name		=> 'LM-101LD',
			comment		=> 'Unitec smoke detector (message decode as MS)',
			id		=> '13',
			zero		=> [1,-1.8],
			one		=> [1,-3.5],
			sync		=> [1,-11,10,-1.2],
			clockabs     	=> 790,
			format 		=> 'twostate',
			preamble	=> 'P13#',	# prepend to converted message	
			clientmodule    => 'FLAMINGO',
			#modulematch     => '', # not used now
			length_min      => '24',
			length_max      => '24',
		},
	"14"	=>	## LED X-MAS Chilitec model 22640
						# https://github.com/RFD-FHEM/RFFHEM/issues/421 | https://forum.fhem.de/index.php/topic,94211.msg869214.html#msg869214
						# MS;P0=988;P1=-384;P2=346;P3=-1026;P4=-4923;D=240123012301230123012323232323232301232323;CP=2;SP=4;R=0;O;m=1;
						# MS;P0=-398;P1=974;P3=338;P4=-1034;P6=-4939;D=361034103410341034103434343434343410103434;CP=3;SP=6;R=0;
		{
			name				=> 'LED X-MAS',
			comment				=> 'Chilitec model 22640',
			changed				=> '20181210 new, old Heidemann HX BELL (moved to ID 79)',
			id				=> '14',
			one				=> [3,-1],
			zero				=> [1,-3],
			sync				=> [1,-14],
			clockabs			=> 350,
			format				=> 'twostate',
			preamble			=> 'P14#',				# prepend to converted message
			clientmodule		=> 'SD_UT',
			#modulematch		=> '^P14#.*',
			length_min			=> '20',
			length_max			=> '20',
		}, 			
	"15"    => 			## TCM 234759
		{
			name			=> 'TCM 234759 Bell',	
			comment         => 'wireless doorbell TCM 234759 Tchibo',
			id          	=> '15',
			one				=> [1,-1],
			zero			=> [1,-2],
			sync			=> [1,-45],
			clockabs		=> 700,
			format					=> 'twostate',
			preamble				=> 'P15#',				# prepend to converted message
			clientmodule		=> 'SD_BELL',
			modulematch			=> '^P15#.*',
			length_min      => '10',
			length_max      => '20',
		}, 	
	"16"	=>	## Rohrmotor24 und andere Funk Rolladen / Markisen Motoren
						# ! same definition how ID 72 !
						# https://forum.fhem.de/index.php/topic,49523.0.html
						# MU;P0=-1608;P1=-785;P2=288;P3=650;P4=-419;P5=4676;D=1212121213434212134213434212121343434212121213421213434212134345021213434213434342121212121343421213421343421212134343421212121342121343421213432;CP=2;
						# MU;P0=-1562;P1=-411;P2=297;P3=-773;P4=668;P5=4754;D=1232341234141234141234141414123414123232341232341412323414150234123234123232323232323234123414123414123414141412341412323234123234141232341415023412323412323232323232323412341412341412341414141234141232323412323414123234142;CP=2;
		{
			name			=> 'Dooya',
			comment			=> 'Rohrmotor24 and other radio shutters / awnings motors',
			id			=> '16',
			one			=> [2,-1],
			zero			=> [1,-3],
			start           => [17,-5],
			clockabs		=> 280,
			clockpos	=> ['zero',0],
			reconstructBit	=> '1',			# bei der letzten Wiederholung ist das Paar am Ende unvollstaendig
			format 			=> 'twostate',
			preamble		=> 'P16#',				# prepend to converted message	
			clientmodule    => 'Dooya',
			#modulematch     => '',  				# not used now
			length_min      => '39',
			length_max      => '40',
		},
	"17"	=>	## arctech / intertechno
						# need more Device Infos / User Message
		{
			name			=> 'arctech / Intertechno',
			id          	=> '17',
			one				=> [1,-5,1,-1],  
			zero			=> [1,-1,1,-5],  
			#one			=> [1,-5],  
			#zero			=> [1,-1],  
			sync			=> [1,-10],
			float			=> [1,-1,1,-1],
			end			=> [1,-40],
			clockabs     	=> -1,			# -1 = auto
			format 			=> 'twostate',	# tristate can't be migrated from bin into hex!
			preamble		=> 'i',			# Append to converted message	
			#postamble		=> '00',		# Append to converted message	 	
			clientmodule    => 'IT',
			modulematch     => '^i......',
			length_min      => '32',
			length_max      => '36',				# Don't know maximal lenth of a valid message
			postDemodulation => \&main::SIGNALduino_postDemo_bit2Arctec,
		},
	 "17.1"	=> # intertechno --> MU anstatt sonst MS (ID 17)
			# MU;P0=344;P1=-1230;P2=-200;D=01020201020101020102020102010102010201020102010201020201020102010201020101020102020102010201020102010201010200;CP=0;R=0;
			# MU;P0=346;P1=-1227;P2=-190;P4=-10224;P5=-2580;D=0102010102020101020201020101020102020102010102010201020102010201020201020102010201020101020102020102010102020102010201020104050201020102010102020101020201020101020102020102010102010201020102010201020201020102010201020101020102020102010102020102010201020;CP=0;R=0;
			# MU;P0=351;P1=-1220;P2=-185;D=01 0201 0102 020101020201020101020102020102010102010201020102010201020201020102010201020101020102020102010201020102010201020100;CP=0;R=0;
			# MU;P0=355;P1=-189;P2=-1222;P3=-10252;P4=-2604;D=0102020101020102020102010102010202010201020102010201020101020102010201020102020102010102010201020102010201020102030401020102010202010102020101020102020102010102010202010201020102010201020101020102010201020102020102010102010201020102010201020102030401020;CP=0;R=0;
			# https://www.sweetpi.de/blog/329/ein-ueberblick-ueber-433mhz-funksteckdosen-und-deren-protokolle
        {
			name			=> 'Intertechno',
			comment 		=> 'PIR-1000 | ITT-1500',
			id          	=> '17.1',
 			one			=> [1,-5,1,-1],
 			zero			=> [1,-1,1,-5],
 			start			=> [-11],
			clockabs    	=> 230,			# -1 = auto
			clockpos	=> ['cp'],
			format 			=> 'twostate',	# tristate can't be migrated from bin into hex!
			preamble		=> 'i',			# Append to converted message	
			#postamble		=> '00',		# Append to converted message	 	
			clientmodule    => 'IT',
			modulematch     => '^i......',
 			length_min      => '28',
			length_max     	=> '36',				# Don't know maximal lenth of a valid message
			postDemodulation => \&main::SIGNALduino_postDemo_bit2Arctec,
		},
	"18"	=>	## Oregon Scientific v1
						# MC;LL=-2721;LH=3139;SL=-1246;SH=1677;D=1A51FF47;C=1463;L=32;R=12;
		{
			name		=> 'Oregon Scientific v1',
			comment		=> 'temperature / humidity or other sensors',
			id          	=> '18',
			clockrange     	=> [1400,1500],			# min , max
			format 			=> 'manchester',	    # tristate can't be migrated from bin into hex!
			preamble		=> '',					
			clientmodule    => 'OREGON',
			modulematch     => '^[0-9A-F].*',
			length_min      => '31',
			length_max      => '32',
			polarity        => 'invert',		    # invert bits
			method          => \&main::SIGNALduino_OSV1,   # Call to process this message
		},
	"19"	=>	## minify Funksteckdose
						# https://github.com/RFD-FHEM/RFFHEM/issues/114
						# MU;P0=293;P1=-887;P2=-312;P6=-1900;P7=872;D=6727272010101720172720101720172010172727272720;CP=0;
						# MU;P0=9078;P1=-308;P2=180;P3=-835;P4=881;P5=309;P6=-1316;D=0123414141535353415341415353415341535341414141415603;CP=5;
		{
			name			=> 'minify',
			comment			=> 'remote control RC202',
			changed			=> '20181004 new',
			id			=> '19',
			one			=> [3,-1],
			zero			=> [1,-3],
			clockabs		=> 300,
			format 			=> 'twostate',	  		
			preamble		=> 'u19#',				# prepend to converted message
			clientmodule    => 'SIGNALduino_un',   				# not used now
			#modulematch     => '',  				# not used now
			length_min		=> '19',
			length_max		=> '23',					# not confirmed, length one more as MU Message
			},
		"20"	=>	## Remote control with 4 buttons for diesel heating
							# https://forum.fhem.de/index.php/topic,58397.msg999475.html#msg999475 @ fhem_user0815 2019-12-04
							# RCnoName20_17E9 on     MS;P0=-740;P2=686;P3=-283;P5=229;P6=-7889;D=5650505023502323232323235023505023505050235050502323502323505050;CP=5;SP=6;R=67;O;m2;
							# RCnoName20_17E9 off    MS;P1=-754;P2=213;P4=681;P5=-283;P6=-7869;D=2621212145214545454545452145212145212121212145214521212121452121;CP=2;SP=6;R=69;O;m2;
							# RCnoName20_17E9 plus   MS;P1=-744;P2=221;P3=679;P4=-278;P5=-7860;D=2521212134213434343434342134212134212121213421212134343434212121;CP=2;SP=5;R=66;O;m2;
							# RCnoName20_17E9 minus  MS;P0=233;P1=-7903;P3=-278;P5=-738;P6=679;D=0105050563056363636363630563050563050505050505630563050505630505;CP=0;SP=1;R=71;O;m1;
			{
				name         => 'RCnoName20',
				comment      => 'Remote control with 4 (diesel heating) or 10 (fan) buttons',
				changed      => '20191218 new, old Livolo deleted',
				id           => '20',
				one          => [3,-1],  # 720,-240
				zero         => [1,-3],  # 240,-720
				sync         => [1,-33], # 240,-7920
				clockabs     => 240,
				format       => 'twostate',
				preamble     => 'P20#',
				clientmodule => 'SD_UT',
				modulematch  => '^P20#.{8}',
				length_min   => '31',
				length_max   => '32',
			},
		"20.1" => ## Remote control with 10 buttons for fan (messages mostly recognized as MS, sometimes MU)
              # https://forum.fhem.de/index.php/topic,53282.msg1233431.html#msg1233431 @ steffen83 2022-09-01
              # RCnoName20_10_3E00 light_on   MU;P0=-8774;P1=282;P2=-775;P3=815;P4=-253;P5=-32001;D=10121234343434341212121212121212121212123434343412121234343412343415;CP=1;
              # RCnoName20_10_3E00 light_off  MU;P0=-238;P1=831;P3=300;P4=-762;P5=-363;P6=192;P7=-8668;D=01010101010343434343434343434343434103415156464156464641564646734341010101010343434343434343434343434103410103434103434341034343734341010101010343434343434343434343434103410103434103434341034343734341010101010343434343434343434343434103410103434103434341;CP=3;O;
              # RCnoName20_10_3E00 fan_stop   MU;P0=184;P1=-380;P2=128;P3=-9090;P4=-768;P5=828;P6=-238;P7=298;D=45656565656747474747474747474747474567474560404515124040451040374745656565656747474747474747474747474567474567474565674747456747374745656565656747474747474747474747474567474567474565674747456747374745656565656747474747474747474747474567474567474565674747;CP=7;O;
			{
				name         => 'RCnoName20',
				comment      => 'Remote control with 4 (diesel heating) or 10 (fan) buttons',
				changed      => '20220927 new',
				id           => '20.1',
				one          => [3,-1],  # 720,-240
				zero         => [1,-3],  # 240,-720
				start        => [1,-33], # 240,-7920
				clockabs     => 240,
				clockpos     => ['zero',0],
				format       => 'twostate',
				preamble     => 'P20#',
				clientmodule => 'SD_UT',
				modulematch  => '^P20#.{8}',
				length_min   => '31',
				length_max   => '32',
			},
	"21"	=>	## Einhell Garagentor
						# https://forum.fhem.de/index.php?topic=42373.0 | user have no RAWMSG
						# static adress: Bit 1-28 | channel remote Bit 29-32 | repeats 31 | pause 20 ms
						# Channelvalues dez
						# 1 left 1x kurz | 2 left 2x kurz | 3 left 3x kurz | 5 right 1x kurz | 6 right 2x kurz | 7 right 3x kurz ... gedrueckt
		{
			name		=> 'Einhell Garagedoor',
			comment         => 'remote ISC HS 434/6',
			id          	=> '21',
			one				=> [-3,1],
			zero			=> [-1,3],
			#sync			=> [-50,1],	
			start  			=> [-50,1],	
			clockabs		=> 400,                  #ca 400us
			clockpos	=> ['one',1],
			format 			=> 'twostate',	  		
			preamble		=> 'u21#',				# prepend to converted message	
			clientmodule    => 'SIGNALduino_un',   				# not used now
			#modulematch    => '',  				# not used now
			length_min      => '32',
			length_max      => '32',				
			paddingbits     => '1',					# This will disable padding 
		},
	"22" => ## HAMULiGHT LED Trafo
					# https://forum.fhem.de/index.php?topic=89301.0
					# MU;P0=-589;P1=209;P2=-336;P3=32001;P4=-204;P5=1194;P6=-1200;P7=602;D=0123414145610747474101010101074741010747410741074101010101074741010741074741414141456107474741010101010747410107474107410741010101010747410107410747414141414561074747410101010107474101074741074107410101010107474101074107474141414145610747474101010101074;CP=1;R=25;
					# MU;P0=204;P1=-596;P2=598;P3=-206;P4=1199;P5=-1197;D=0123230123012301010101012323010123012323030303034501232323010101010123230101232301230123010101010123230101230123230303030345012323230101010101232301012323012301230101010101232301012301232303030303450123232301010101012323010123230123012301010101012323010;CP=0;R=25;
		{
			name					=> 'HAMULiGHT',
			comment					=> 'remote control for LED Transformator',
			changed					=> '20181204 new, old move to ID 33',
			id					=> '22',
			one					=> [1,-3],
			zero					=> [3,-1],
			start					=> [1,-1,1,-1,6,-6],
			end						=> [1,-1,1,-1],
			clockabs				=> 200,
			format					=> 'twostate',
			preamble				=> 'P22#',				# prepend to converted message
			clientmodule    => 'SD_UT',
			#modulematch     => '',
			length_min				=> '32',
			length_max				=> '32',
		},
	"23"	=>	## Pearl Sensor
		{
			name			=> 'Pearl',
			comment			=> 'unknown sensortyp',	
			id			=> '23',
			one			=> [1,-6],
			zero			=> [1,-1],
			sync			=> [1,-50],				
			clockabs		=> 200,                  #ca 200us
			format 			=> 'twostate',	  		
			preamble		=> 'u23#',				# prepend to converted message	
			clientmodule    => 'SIGNALduino_un',   				# not used now
			#modulematch     => '',  				# not used now
			length_min      => '36',
			length_max      => '44',				
		},
	"24" => ## visivo
			# https://github.com/RFD-FHEM/RFFHEM/issues/39 @sidey79
			# Visivo_7DF825 up    MU;P0=132;P1=500;P2=-233;P3=-598;P4=-980;P5=4526;D=012120303030303120303030453120303121212121203121212121203121212121212030303030312030312031203030303030312031203031212120303030303120303030453120303121212121203121212121203121212121212030303030312030312031203030303030312031203031212120303030;CP=0;O;
			# https://forum.fhem.de/index.php/topic,42273.0.html @MikeRoxx
			# Visivo_7DF825 up    MU;P0=505;P1=140;P2=-771;P3=-225;P5=4558;D=012031212030303030312030303030312030303030303121212121203121203120312121212121203120312120303031212121212031212121252031212030303030312030303030312030303030303121212121203121203120312121212121203120312120303031212121212031212121252031212030;CP=1;O;
			# Visivo_7DF825 down  MU;P0=147;P1=-220;P2=512;P3=-774;P5=4548;D=001210303210303212121210303030321030303035321030321212121210321212121210321212121212103030303032103032103210303030303210303210303212121210303030321030303035321030321212121210321212121210321212121212103030303032103032103210303030303210303210;CP=0;O;
			# Visivo_7DF825 stop  MU;P0=-764;P1=517;P2=-216;P3=148;P5=4550;D=012303012121212123012121212123012121212121230303030301230301230123030303012303030123012303030123030303012303030305012303012121212123012121212123012121212121230303030301230301230123030303012303030123012303030123030303012303030305012303012120;CP=3;O;
		{
			name			=> 'Visivo remote',
			comment			=> 'Remote control for motorized screen',
			changed			=> '20201220',
			id			=> '24',
			knownFreqs		=> '315',
			one			=> [3,-1],  #  546,-182
			zero			=> [1,-4],  #  182,-728
			start			=> [25,-4], # 4550,-728
			clockabs		=> 182,
			clockpos		=> ['zero',0],
			reconstructBit	=> '1',
			format 			=> 'twostate',
			preamble		=> 'P24#',				# prepend to converted message	
			clientmodule    => 'SD_UT',
			#modulematch     => '',  				# not used now
			length_min      => '55',
			length_max      => '56',				
		},
	"25" => # LES remote for led lamp
            # https://github.com/RFD-FHEM/RFFHEM/issues/40
	        # MS;P0=-376;P1=697;P2=-726;P3=322;P4=-13188;P5=-15982;D=3530123010101230123230123010101010101232301230123234301230101012301232301230101010101012323012301232;CP=3;SP=5;O;
		{
			name		=> 'les led remote',	
			id          	=> '25',
			one				=> [-2,1],
			zero			=> [-1,2],
			sync			=> [-46,1],				# this is a end marker, but we use this as a start marker
			clockabs		=> 350,                 #ca 350us
			format 			=> 'twostate',	  		
			preamble		=> 'u25#',				# prepend to converted message	
			clientmodule    => 'SIGNALduino_un',   				# not used now
			#modulematch     => '',  				# not used now
			length_min      => '24',
			length_max      => '50',				# message has only 24 bit, but we get more than one message, calculation has to be corrected
		},
		"26"	=>	## xavax 00111939 Funksteckdosen Set
							# https://github.com/RFD-FHEM/RFFHEM/issues/717 @codeartisan-de 2019-12-14
							# xavax_DAAB2554 Ch1_on   MU;P0=412;P1=-534;P2=-1356;P3=-20601;P4=3360;P5=-3470;D=01020102010201020201010201010201020102010201020101020101010102020203010145020201020201020102010201020102020101020101020102010201020102010102010101010202020301014502020102020102010201020102010202010102010102010201020102010201010201010101020202030101450202;CP=0;R=0;O;
							# xavax_DAAB2554 Ch1_off  MU;P0=-3504;P1=416;P2=-1356;P3=-535;P4=-20816;P5=3324;D=01212131212131213121312131213121213131213131213121312131213121313131212121213131314131350121213121213121312131213121312121313121313121312131213121312131313121212121313131413135012121312121312131213121312131212131312131312131213121312131213131312121212131;CP=1;R=50;O;
							# xavax_DAAB2554 Ch2_on   MU;P0=5656;P1=-21857;P2=413;P3=-1354;P4=-536;P6=3350;P7=-3487;D=01232423232424232424232423242324232423242424232424232423232124246723232423232423242324232423242323242423242423242324232423242324242423242423242323212424672323242323242324232423242324232324242324242324232423242324232424242324242324232321242467232324232324;CP=2;R=0;O;
							# xavax_DAAB2554 Ch2_off  MU;P0=3371;P1=-3479;P2=420;P3=-31868;P4=-541;P5=272;P6=-1343;P7=-20621;D=23245426242426242624262426242624242624262624262424272424012626242626242624262426242624262624242624242624262426242624262424262426262426242427242401262624262624262426242624262426262424262424262426242624262426242426242626242624242724240126262426262426242624;CP=2;R=45;O;
			{
				name          => 'xavax',
				comment       => 'Remote control xavax 00111939',
				changed       => '20191226 new',
				id            => '26',
				one           => [1,-3],            # 460,-1380
				zero          => [1,-1],            # 460,-460
				start         => [1,-1,1,-1,7,-7],  # 460,-460,460,-460,3220,-3220
				clockpos      => ['cp'],
				# end           => [1],     # 460 - end funktioniert nicht (wird erst nach pause angehangen), ein bit ans Ende haengen geht, dann aber pause 44 statt 45
				pause         => [-44],             # -20700 mit end, 20240 mit bit 0 am Ende
				clockabs      => 460,
				format        => 'twostate',
				preamble      => 'P26#',
				clientmodule  => 'SD_UT',
				modulematch   => '^P26#.{10}',
				length_min    => '40',
				length_max    => '40',
			},
		"27"  =>  ## Temperatur-/Feuchtigkeitssensor EuroChron EFTH-800 (433 MHz) - https://github.com/RFD-FHEM/RFFHEM/issues/739
							# SD_WS_27_TH_2 - T: 15.5 H: 48 - MU;P0=-224;P1=258;P2=-487;P3=505;P4=-4884;P5=743;P6=-718;D=0121212301212303030301212123012123012123030123030121212121230121230121212121212121230301214565656561212123012121230121230303030121212301212301212303012303012121212123012123012121212121212123030121;CP=1;R=53;
							# SD_WS_27_TH_3 - T:  3.8 H: 76 - MU;P0=-241;P1=251;P2=-470;P3=500;P4=-4868;P5=743;P6=-718;D=012121212303030123012301212123012121212301212303012121212121230303012303012123030303012123014565656561212301212121230303012301230121212301212121230121230301212121212123030301230301212303030301212301;CP=1;R=23;
							# SD_WS_27_TH_3 - T:  5.3 H: 75 - MU;P0=-240;P1=253;P2=-487;P3=489;P4=-4860;P5=746;P6=-725;D=012121212303030123012301212123012121212303012301230121212121230303012301230303012303030301214565656561212301212121230303012301230121212301212121230301230123012121212123030301230123030301230303030121;CP=1;R=19;
							# Eurochron Zusatzsensor fuer EFS-3110A - https://github.com/RFD-FHEM/RFFHEM/issues/889
							# short pulse of 244 us followed by a 488 us gap is a 0 bit
							# long pulse of 488 us followed by a 244 us gap is a 1 bit
							# sync preamble of pulse, gap, 732 us each, repeated 4 times
							# sensor sends two messages at intervals of about 57-58 seconds
			{
				name            => 'EFTH-800',
				comment         => 'EuroChron weatherstation EFTH-800, EFS-3110A',
				changed         => '20191227 new',
				id              => '27',
				one             => [2,-1],
				zero            => [1,-2],
				start           => [3,-3],
				clockpos        => ['zero',0],
				clockabs        => '244',
				format          => 'twostate',
				preamble        => 'W27#',
				clientmodule    => 'SD_WS',
				modulematch     => '^W27#.{12}',
				length_min      => '48',	# 48 Bit + 1 Puls am Ende
				length_max      => '48',
			},
	"28" => # some remote code, send by aldi IC Ledspots
		{
			name			=> 'IC Ledspot',	
			id          	=> '28',
			one				=> [1,-1],
			zero			=> [1,-2],
			start			=> [4,-5],				
			clockabs		=> 600,                 #ca 600
			clockpos	=> ['cp'],
			format 			=> 'twostate',	  		
			preamble		=> 'u28#',				# prepend to converted message
			clientmodule    => 'SIGNALduino_un',   				# not used now
			#modulematch     => '',  				# not used now
			length_min      => '8',
			length_max      => '8',				
		},
	"29" => # example remote control with HT12E chip
           # MU;P0=250;P1=-492;P2=166;P3=-255;P4=491;P5=-8588;D=052121212121234121212121234521212121212341212121212345212121212123412121212123452121212121234121212121234;CP=0;
           # https://forum.fhem.de/index.php/topic,58397.960.html
		{
			name		=> 'HT12e remote',
			comment         => 'remote control for example Westinghouse airfan with 5 buttons',
			id          	=> '29',
			one				=> [-2,1],
			zero			=> [-1,2],
			start           => [-35,1],         # Message is not provided as MS, worakround is start
			clockabs        => 235,             # ca 220
			clockpos	=> ['one',1],
			format          => 'twostate',      # there is a pause puls between words
			preamble        => 'P29#',				# prepend to converted message	
			clientmodule    => 'SD_UT', 
			modulematch     => '^P29#.{3}',
			length_min      => '12',
			length_max      => '12',
		},
	"30" => # a unitec remote door reed switch
			# https://forum.fhem.de/index.php?topic=43346.0
			# MU;P0=-10026;P1=-924;P2=309;P3=-688;P4=-361;P5=637;D=123245453245324532453245320232454532453245324532453202324545324532453245324532023245453245324532453245320232454532453245324532453202324545324532453245324532023245453245324532453245320232454532453245324532453202324545324532453245324532023240;CP=2;O;
			# MU;P0=307;P1=-10027;P2=-691;P3=-365;P4=635;D=0102034342034203420342034201020343420342034203420342010203434203420342034203420102034342034203420342034201020343420342034203420342010203434203420342034203420102034342034203420342034201;CP=0;
		{
			name			=> 'unitec47031',	
			comment         => 'remote control unitec | door reed switch 47031',
			id          	=> '30',
			one			=> [-2,1],
			zero			=> [-1,2],
			start			=> [-30,1],				# Message is not provided as MS, worakround is start
			clockabs		=> 330,                 # ca 300 us
			clockpos		=> ['one',1],
			format 			=> 'twostate',	  		# there is a pause puls between words
			preamble		=> 'P30#',				# prepend to converted message	
			clientmodule    => 'SD_UT', 
			modulematch     => '^P30#.{3}',
			length_min      => '12',
			length_max      => '12',				# message has only 10 bit but is paddet to 12
		},
		"31"  =>	## LED Controller LTECH, LED M Serie RF RGBW - M4 & M4-5A
							# https://forum.fhem.de/index.php/topic,107868.msg1018434.html#msg1018434 | https://forum.fhem.de/index.php/topic,107868.msg1020521.html#msg1020521 @Devirex
							## note: command length 299, now - not supported by all firmware versions
							# 0490DCFF function: 00 off               MU;P0=-16118;P1=315;P2=-281;P4=-1204;P5=-563;P6=618;P7=1204;D=01212121212121212121214151562151515151515151515621515621515626262156262626262626262626215626262626262626262626262626262151515151515151515151515151515151515151515151515626262626262626215151515151515156215156262626262626262626262621570121212121212121212121;CP=1;R=26;O;
							# 0490DCFF function: 01 rgbcolor: FF0000  MU;P0=-32001;P1=314;P2=-285;P3=-1224;P4=-573;P5=601;P6=1204;P7=-15304;CP=1;R=31;D=012121212121212121212131414521414141414141414145214145214145252521452525252525252525252145252525252525252525252525252521414141414141414141414141414141452141414141414145252525252525252141414141414141414525252141452525252525214145214671212121212121212121213141452;p;i;
							# 04444EFF function: 01 rgbcolor: 202000  MU;P0=1194;P1=597;P2=-6269;P3=306;P4=-298;P5=-1216;P6=-559;D=123434343434343434343536361436363636363636143636361436361414143636143614141414141414143614141414141414141414141414141414141414141414143636363636363636143636363636363636363636361436363636363636363636363614361436363614141414143614360;CP=3;R=28;
							{
				name            => 'LTECH',
				comment			=> 'remote control for LED Controller M4-5A',
				changed			=> '20200211 new. Old moved to ID 34',
				id              => '31',
				developId       => 'm',
				one             => [2,-0.9],
				zero            => [1,-1.8],
				start           => [1,-0.9, 1,-3.8],
				preSync         => [1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9, 1,-0.9],
				end             => [3.8, -51],
				clockabs        => 315,
				clockpos		=> ['zero',0],
				format          => 'twostate',
				preamble        => 'P31#',
				clientmodule	=> 'LTECH',
				length_min      => '104',
			},
	"32"	=>	## FreeTec PE-6946 -> http://www.free-tec.de/Funkklingel-mit-Voic-PE-6946-919.shtml
						# OLD
						# https://github.com/RFD-FHEM/RFFHEM/issues/49
						# MS;P0=-266;P1=160;P3=-690;P4=580;P5=-6628;D=15131313401340134013401313404040404040404040404040;CP=1;SP=5;O;
						# NEW
						# https://github.com/RFD-FHEM/RFFHEM/issues/315
						# MU;P0=-6676;P1=578;P2=-278;P4=-680;P5=176;P6=-184;D=541654165412545412121212121212121212121250545454125412541254125454121212121212121212121212;CP=1;R=0;
						# MU;P0=146;P1=245;P3=571;P4=-708;P5=-284;P7=-6689;D=14351435143514143535353535353535353535350704040435043504350435040435353535353535353535353507040404350435043504350404353535353535353535353535070404043504350435043504043535353535353535353535350704040435043504350435040435353535353535353535353507040404350435;CP=3;R=0;O;
						# MU;P0=-6680;P1=162;P2=-298;P4=253;P5=-699;P6=555;D=45624562456245456262626262626262626262621015151562156215621562151562626262626262626262626210151515621562156215621515626262626262626262626262;CP=6;R=0;
		{
			name			=> 'FreeTec PE-6946',	
			comment         => 'wireless doorbell',
			id          	=> '32',
			one				=> [4,-2],
			zero			=> [1,-5],
			start           => [1,-46],
			clockabs		=> 150,
			clockpos		=> ['zero',0],
			format 			=> 'twostate',	  		
			preamble		=> 'P32#',				# prepend to converted message
			clientmodule	=> 'SD_BELL',
			modulematch		=> '^P32#.*',
			length_min      => '24',
			length_max      => '24',				
    	},
	"32.1" => #FreeTec PE-6946 -> http://www.free-tec.de/Funkklingel-mit-Voic-PE-6946-919.shtml
			# https://github.com/RFD-FHEM/RFFHEM/issues/49
			# MS;P0=-266;P1=160;P3=-690;P4=580;P5=-6628;D=15131313401340134013401313404040404040404040404040;CP=1;SP=5;O;
    	{   
			name			=> 'FreeTec PE-6946',
			comment			=> 'wireless doorbell (MS decode)',
			id			=> '32',
			one			=> [4,-2],
			zero			=> [1,-4],
			sync			=> [1,-43],				
			clockabs		=> 150,                 #ca 150us
			format 			=> 'twostate',	  		
			preamble		=> 'P32#',				# prepend to converted message
			clientmodule	=> 'SD_BELL',
			modulematch		=> '^P32#.*',
			length_min      => '24',
			length_max      => '24',				
    	},
	"33"	=>	## Thermo-/Hygrosensor S014, renkforce E0001PA, Conrad S522, TX-EZ6 (Weatherstation TZS First Austria)
						# https://forum.fhem.de/index.php?topic=35844.0
						# MS;P0=-7871;P2=-1960;P3=578;P4=-3954;D=030323232323434343434323232323234343434323234343234343234343232323432323232323232343234;CP=3;SP=0;R=0;m=0;
						# sensor id=62, channel=1, temp=21.1, hum=76, bat=ok
						# !! ToDo Tx-EZ6 neues Attribut ins Modul bauen um Trend + CRC auszuwerten !!
		{
			name			=> 'weather33',
			comment			=> 'S014, TFA 30.3200, TCM, Conrad S522, renkforce E0001PA, TX-EZ6 (CP=500)',
			id			=> '33',
			one			=> [1,-8],		# 500, -4000
			zero			=> [1,-4],	# 500, -2000
			sync			=> [1,-16],	# 500, -8000
			clockabs   		=> '500',
			format     		=> 'twostate',  		# not used now
			preamble		=> 'W33#',				# prepend to converted message	
			clientmodule    => 'SD_WS',
			#modulematch     => '',     			# not used now
			length_min      => '42',
			length_max      => '44',
		},
	"33.1"	=>	## Thermo-/Hygrosensor TFA 30.3200
							# https://github.com/RFD-FHEM/SIGNALDuino/issues/113
							# SD_WS_33_TH_1   T: 18.8 H: 53   MS;P1=-7796;P2=745;P3=-1976;P4=-3929;D=21232323242324232324242323232323242424232323242324242323242324232324242323232323232424;CP=2;SP=1;R=30;O;m2;
							# SD_WS_33_TH_2   T: 21.9 H: 49   MS;P1=-7762;P2=747;P3=-1976;P4=-3926;D=21232324232324242323242323232424242424232423232324242323232324232324242323232324242424;CP=2;SP=1;R=32;O;m1;
							# SD_WS_33_TH_3   T: 19.7 H: 53   MS;P1=758;P2=-1964;P3=-3929;P4=-7758;D=14121213121313131213121212131212131313121213121213131212131213121213131212121212121212;CP=1;SP=4;R=48;O;m1;
			{
				name          => 'TFA 30.3200',
				comment       => 'Thermo-/Hygrosensor TFA 30.3200 (CP=750)',
				changed       => '20190415 new',
				id            => '33.1',
				one           => [1,-5.6],		# 736,-4121
				zero          => [1,-2.8],		# 736,-2060
				sync          => [1,-11],		# 736,-8096
				clockabs      => 736,
				format        => 'twostate',	# not used now
				preamble      => 'W33#',
				clientmodule  => 'SD_WS',
				length_min    => '42',
				length_max    => '44',
			},
	"33.2" => ## Tchibo Wetterstation
							# https://forum.fhem.de/index.php/topic,58397.msg880339.html#msg880339 @Doublefant
							# passt bei 33 und 33.2:
							# SD_WS_33_TH_1   T: 5.1 H: 41   MS;P1=399;P2=-7743;P3=-2038;P4=-3992;D=12131314141414141313131413131314141414131313141314131414131314131314131313131314131314;CP=1;SP=2;R=230;O;m2;
							# SD_WS_33_TH_1   T: 5.1 H: 41   MS;P1=399;P2=-7733;P3=-2043;P4=-3991;D=12131314141414141313131413131314141414131313141314131414131314131314131313131314131314;CP=1;SP=2;R=230;O;
							# passt nur bei 33.2:
							# SD_WS_33_TH_1   T: 5.1 H: 41   MS;P1=393;P2=-7752;P3=-2047;P4=-3993;D=12131314141414141313131413131314141414131313141314131414131314131314131313131314131314;CP=1;SP=2;R=230;O;m1;
							# SD_WS_33_TH_1   T: 5.1 H: 41   MS;P1=396;P2=-7759;P3=-2045;P4=-4000;D=12131314141414141313131413131314141414131313141314131414131314131314131313131314131314;CP=1;SP=2;R=230;O;m0;
			{
				name          => 'Tchibo',
				comment       => 'Tchibo weatherstation (CP=400)',
				changed       => '20190415 new',
				id            => '33.2',
				one           => [1,-10],     # 400,-4000
				zero          => [1,-5],      # 400,-2000
				sync          => [1,-19],     # 400,-7600
				clockabs      => 400,
				format        => 'twostate',
				preamble      => 'W33#',
				clientmodule  => 'SD_WS',
				length_min    => '42',
				length_max    => '44',
			},
	"34"	=>	## QUIGG GT-7000 Funk-Steckdosendimmer | transmitter DMV-7000 - receiver DMV-7009AS
							# https://github.com/RFD-FHEM/RFFHEM/issues/195 | https://forum.fhem.de/index.php/topic,38831.msg361341.html#msg361341 @StefanW
							# Ch1_on       MU;P0=-5284;P1=583;P2=-681;P3=1216;P4=-1319;D=012341412323232341412341412323234123232341;CP=1;R=16;
							# Ch1_off      MU;P0=-9812;P1=589;P2=-671;P3=1261;P4=-1320;D=012341412323232341412341412323232323232323;CP=3;R=19;
							# Ch2_on       MU;P0=-9832;P1=577;P2=-670;P3=1219;P4=-1331;D=012341412323232341412341414123234123234141;CP=1;R=16;
							# Ch2_off      MU;P0=-8816;P1=594;P2=-662;P3=1263;P4=-1330;D=012341412323232341412341414123232323234123;CP=1;R=16;
							# Ch3_on       MU;P0=-677;P1=581;P2=1250;P3=-1319;D=010231310202020231310231310231023102020202;CP=1;R=18;
							# Ch3_off      MU;P0=-29120;P1=603;P2=-666;P3=1235;P4=-1307;D=012341412323232341412341412341232323232341;CP=1;R=16;
							## LIBRA GmbH (LIDL) TR-502MSV
							# no decode!   MU;P0=-12064;P1=71;P2=-669;P3=1351;P4=-1319;D=012323414141234123232323232323232323232323;
							# Ch1_off      MU;P0=697;P1=-1352;P2=-679;P3=1343;D=01010101010231023232323232323232323232323;CP=0;R=27;
							## Mandolyn Funksteckdosen Set
							# https://github.com/RFD-FHEM/RFFHEM/issues/716 @codeartisan-de
							## Pollin ISOTRONIC - 12 Tasten remote | model 58608 (war alt ID 31)
							# remote basicadresse with 12bit -> changed if push reset behind battery cover
							# https://github.com/RFD-FHEM/RFFHEM/issues/44 @kaihs
							# P34#891EE    MU;P0=-9584;P1=592;P2=-665;P3=1223;P4=-1311;D=01234141412341412341414123232323412323234;CP=1;R=0;
							# P34#891FF   MU;P0=-12724;P1=597;P2=-667;P3=1253;P4=-1331;D=01234141412341412341414123232323232323232;CP=1;R=0;
		{   
			name 			=> 'QUIGG | LIBRA | Mandolyn | Pollin ISOTRONIC',
			comment         => 'remote control DMV-7000, TR-502MSV, 58608',
			changed			=> '20181025 new',
			id 			=> '34',
			one			=> [-1,2],
			zero            => [-2,1],
			start			=> [1],
			pause			=> [-15],   # 9900
			clockabs   		=> '635',
			clockpos		=> ['zero',1],
			format			=> 'twostate', 
			preamble 		=> 'P34#',
			clientmodule 	=> 'SD_UT',
			reconstructBit  => '1',
			#modulematch 		=> '',
			length_min 		=> '19',
			length_max 		=> '20',
		},
	"35"	=>	## Homeeasy
			 # MS;P0=907;P1=-376;P2=266;P3=-1001;P6=-4860;D=2601010123230123012323230101012301230101010101230123012301;CP=2;SP=6;
		{
			name		=> 'HomeEasy HE800',
			id          	=> '35',
			one			=> [1,-4],
			zero			=> [3.4,-1],
			sync			=> [1,-18],
			clockabs   		=> '280',		
			format     		=> 'twostate',  		# not used now
			preamble		=> 'ih',				# prepend to converted message	
			#postamble		=> '',					# Append to converted message	 	
			clientmodule    => 'IT',
			#modulematch     => '',     			# not used now
			length_min      => '28',
			length_max      => '40',
			postDemodulation => \&main::SIGNALduino_postDemo_HE800,
		},
	"36"	=>	## remote - cheap wireless dimmer
						# https://forum.fhem.de/index.php/topic,38831.msg394238.html#msg394238
						# MU;P0=499;P1=-1523;P2=-522;P3=10220;P4=-10047;D=01020202020202020134010102020101010201020202020102010202020202020201340101020201010102010202020201020102020202020202013401010202010101020102020202010201020202020202020134010102020101010201020202020102010202020202020201340101020201010102010;CP=0;O;
						# MU;P0=-520;P1=500;P2=-1523;P3=10220;P4=-10043;D=01010101210121010101010101012341212101012121210121010101012101210101010101010123412121010121212101210101010121012101010101010101234121210101212121012101010101210121010101010101012341212101012121210121010101012101210101010101010123412121010;CP=1;O;
						# MU;P0=498;P1=-1524;P2=-521;P3=10212;P4=-10047;D=01010102010202020201020102020202020202013401010202010101020102020202010201020202020202020134010102020101010201020202020102010202020202020201340101020201010102010202020201020102020202020202013401010202010101020102020202010201020202020202020;CP=0;O;
		{
			name			=> 'remote',
			comment			=> 'cheap wireless dimmer',
			id			=> '36',
			one			=> [1,-3],
			zero			=> [1,-1],
			start		 	=> [20,-20],
			clockabs   		=> '500',		
			clockpos		=> ['cp'],
			format     		=> 'twostate',  		# not used now
			preamble		=> 'u36#',				# prepend to converted message	
			postamble		=> '',					# Append to converted message	 	
			clientmodule    => 'SIGNALduino_un',      			# not used now
			#modulematch     => '',     			# not used now
			length_min      => '24',
			length_max      => '24',
		},
	"37"	=>	## Bresser 7009994
			# MU;P0=729;P1=-736;P2=483;P3=-251;P4=238;P5=-491;D=010101012323452323454523454545234523234545234523232345454545232345454545452323232345232340;CP=4;
			# MU;P0=-790;P1=-255;P2=474;P4=226;P6=722;P7=-510;D=721060606060474747472121212147472121472147212121214747212147474721214747212147214721212147214060606060474747472121212140;CP=4;R=216;
			# short pulse of 250 us followed by a 500 us gap is a 0 bit
			# long pulse of 500 us followed by a 250 us gap is a 1 bit
			# sync preamble of pulse, gap, 750 us each, repeated 4 times
     	 {   
			name			=> 'Bresser 7009994',
			comment			=> 'temperature / humidity sensor',
			id      		=> '37',
			one			=> [2,-1],
			zero			=> [1,-2],
			start		 	=> [3,-3,3,-3],
			clockabs   		=> '250',		
			clockpos		=> ['zero',0],
			format     		=> 'twostate',  		# not used now
			preamble		=> 'W37#',				# prepend to converted message	
			clientmodule    => 'SD_WS', 
			length_min      => '40',
			length_max      => '41',
	},
	"38"	=>	## Rosenstein & Soehne, PEARL NC-3911, NC-3912, refrigerator thermometer - 2 channels
						# https://github.com/RFD-FHEM/RFFHEM/issues/504 - Support for NC-3911 Fridge Temp, MoskitoHorst, 2019-02-05
						# Id:8B, Ch:1, T: 6.3, MU;P0=-747;P1=-493;P2=231;P3=484;P4=-248;P6=-982;P7=718;D=1213434212134343421342121343434343434212670707070342121213421343434212134212134212121343421213434342134212134343434343421267070707034212121342134343421213421213421212134342121343434213421213434343434342126707070703421212134213434342121342121342121;CP=2;
						# Id:A8, Ch:2, T:-1.8, MU;P0=-241;P1=491;P2=249;P3=-482;P4=-962;P5=743;P6=-723;D=01023102323232310101010232323102310232323232310101010231024565656561023102310232323102310232323231010101023232310231023232323231010101023102456565656102310231023232310231023232323101010102323231023102323232323101010102310245656565610231023102323231023102;CP=2;O;
						# Id:A8, Ch:2, T: 5.4, MU;P0=-971;P1=733;P2=-731;P3=488;P4=-244;P5=248;P6=-480;P7=-368;D=01212121234563456345656563456345656563456575634563456345634345656345634343434345650121212123456345634565656345634565656345656563456345634563434565634563434343434565012121212345634563456565634563456565634565656345634563456343456563456343434343456501212121;CP=5;O;
		{
			name         => 'NC-3911',
			comment      => 'Refrigerator thermometer',
			changed      => '20190205 new, 20181216 old moved to ID 0.1',
			id           => '38',
			one          => [2,-1],
			zero         => [1,-2],
			start        => [3,-3,3,-3],
			clockabs     => 250,
			clockpos     => ['zero',0],
			format       => 'twostate',
			preamble     => 'W38#',
			clientmodule	=> 'SD_WS',
			modulematch	=> '^W38#.*',
			length_min   => '36',
			length_max   => '36',
		},
	"39"	=>	## X10 Protocol
         	# https://github.com/RFD-FHEM/RFFHEM/issues/65
         	# MU;P0=10530;P1=-2908;P2=533;P3=-598;P4=-1733;P5=767;D=0123242323232423242324232324232423242323232324232323242424242324242424232423242424232501232423232324232423242323242324232423232323242323232424242423242424242324232424242325012324232323242324232423232423242324232323232423232324242424232424242423242324242;CP=2;O;
		{
			name => 'X10 Protocol',
			id => '39',
			one => [1,-3],
			zero => [1,-1],
			start => [17,-7],
			clockabs => 560, 
			clockpos => ['cp'],
			format => 'twostate', 
			preamble => '', # prepend to converted message
			clientmodule => 'RFXX10REC',
			#modulematch => '^TX......', # not used now
			length_min => '32',
			length_max => '44',
			paddingbits     => '8',
			postDemodulation => \&main::SIGNALduino_postDemo_lengtnPrefix,
			filterfunc      => \&main::SIGNALduinoAdv_compPattern,
		},    
	"40" => ## Romotec
			# https://github.com/RFD-FHEM/RFFHEM/issues/71
			# MU;P0=300;P1=-772;P2=674;P3=-397;P4=4756;P5=-1512;D=4501232301230123230101232301010123230101230103;CP=0;
			# MU;P0=-132;P1=-388;P2=675;P4=271;P5=-762;D=012145212145452121454545212145452145214545454521454545452145454541;CP=4;
		{
			name => 'Romotec',
			comment	=> 'Tubular motor',
			id => '40',
			one => [3,-2],
			zero => [1,-3],
			start => [1,-2],
			clockabs => 270, 
			clockpos => ['zero',0],
			preamble => 'u40#', # prepend to converted message
			clientmodule => 'SIGNALduino_un', # not used now
			#modulematch => '', # not used now
			length_min => '12',
		},    
	"41"	=>	## Elro (Smartwares) Doorbell DB200 / 16 melodies
						# https://github.com/RFD-FHEM/RFFHEM/issues/70
						# MS;P0=-526;P1=1450;P2=467;P3=-6949;P4=-1519;D=231010101010242424242424102424101010102410241024101024241024241010;CP=2;SP=3;O;
						# MS;P0=468;P1=-1516;P2=1450;P3=-533;P4=-7291;D=040101230101010123230101232323012323010101012301232323012301012323;CP=0;SP=4;O;
						# unitec Modell:98156+98YK / 36 melodies
						# repeats 15, change two codes every 15 repeats --> one button push, 2 codes
						# MS;P0=1474;P1=-521;P2=495;P3=-1508;P4=-6996;D=242323232301232323010101230123232301012301230123010123230123230101;CP=2;SP=4;R=51;m=0;
						# MS;P1=-7005;P2=482;P3=-1511;P4=1487;P5=-510;D=212345454523452345234523232345232345232323234523454545234523234545;CP=2;SP=1;R=47;m=2;
						## KANGTAI Doorbell (Pollin 94-550405)
						# https://github.com/RFD-FHEM/RFFHEM/issues/365
						# The bell button alternately sends two different codes
						# P41#BA2885D3: MS;P0=1390;P1=-600;P2=409;P3=-1600;P4=-7083;D=240123010101230123232301230123232301232323230123010101230123230101;CP=2;SP=4;R=248;O;m0;
						# P41#BA2885D3: MS;P0=1399;P1=-604;P2=397;P3=-1602;P4=-7090;D=240123010101230123232301230123232301232323230123010101230123230101;CP=2;SP=4;R=248;O;m1;
						# P41#1791D593: MS;P1=403;P2=-7102;P3=-1608;P4=1378;P5=-620;D=121313134513454545451313451313134545451345134513454513134513134545;CP=1;SP=2;R=5;O;m0;
		{
			name					=> 'wireless doorbell',
			comment				=> 'Elro (DB200) / KANGTAI (Pollin 94-550405) / unitec',
			id						=> '41',
			zero					=> [1,-3],
			one						=> [3,-1],
			sync					=> [1,-14],
			clockabs			=> 500, 
			format				=> 'twostate',
			preamble			=> 'P41#', # prepend to converted message
			clientmodule	=> 'SD_BELL',
			modulematch		=> '^P41#.*',
			length_min		=> '32',
			length_max		=> '32',
		},
	"42"	=>	## Pollin 94-551227
						# https://github.com/RFD-FHEM/RFFHEM/issues/390
						# MU;P0=1446;P1=-487;P2=477;D=0101012121212121212121212101010101212121212121212121210101010121212121212121212121010101012121212121212121212101010101212121212121212121210101010121212121212121212121010101012121212121212121212101010101212121212121212121210101010121212121212121212121010;CP=2;R=93;O;
						# MU;P0=-112;P1=1075;P2=-511;P3=452;P5=1418;D=01212121232323232323232323232525252523232323232323232323252525252323232323232323232325252525;CP=3;R=77;
		{
			name				=> 'wireless doorbell',
			comment				=> 'Pollin 551227',
			changed				=> '20181210 new',
			id				=> '42',
			one				=> [1,-1],
			zero				=> [3,-1],
			start				=> [1,-1,1,-1,1,-1,],
			starti				=> [1,1,1],
			clockabs			=> 500,
			clockpos			=> ['one',0],
			format				=> 'twostate',
			preamble			=> 'P42#',
			clientmodule	=> 'SD_BELL',
			#modulematch		=> '^P42#.*',
			length_min		=> '28',
			length_max		=> '120',
		},
	"43" => ## Somfy RTS, mit verbessertem msg fix für nicht optimale Empfangsbedingungen
			# MC;LL=-1330;LH=1229;SL=-686;SH=597;D=A8B5B99A6CA088;C=640;L=56;R=63;
			# MC;LL=-1317;LH=1237;SL=-689;SH=594;D=545ADCCD365044;C=639;L=56;R=63;
			# MC;LL=-1281;LH=1282;SL=-635;SH=639;D=04747459CBF22;C=639;L=52;R=1;s11;b2;
		{
			name 			=> 'Somfy RTS',
			comment			=> 'with msg fix',
			id 				=> '43',
			knownFreqs      => '433.42',
			clockrange  	=> [610,680],			# min , max
			format			=> 'manchester', 
			preamble 		=> 'Ys',
			clientmodule	=> 'SOMFY', # not used now
			modulematch 	=> '^Ys[0-9A-F]{14}',
			length_min 		=> '52',
			length_max 		=> '81',
			method          => \&main::SIGNALduino_SomfyRTS, # Call to process this message
			msgIntro		=> 'SR;P0=-2560;P1=2560;P3=-640;D=10101010101010113;',
			#msgOutro		=> 'SR;P0=-30415;D=0;',
			frequency		=> '10AB85550A',
		},
	"43.1" => ## Somfy RTS, ohne verbessertem msg fix, fuer Wandsender deren msg nicht mit A anfangen
            # MC;LL=-1405;LH=1269;SL=-723;SH=620;D=98DBD153D631BB;C=669;L=56;R=229;
		{
			name 			=> 'Somfy RTS no fix',
			comment			=> 'wall transmitter',
			changed			=> '20201126 new',
			id 				=> '43',
			developId 		=> 'm',
			knownFreqs      => '433.42',
			clockrange  	=> [610,680],			# min , max
			format			=> 'manchester', 
			preamble 		=> 'Ys',
			clientmodule	=> 'SOMFY', # not used now
			modulematch 	=> '^Ys[0-9A-F]{14}',
			length_min 		=> '56',
			length_max 		=> '81',
			method          => \&main::SIGNALduino_SomfyRTS, # Call to process this message
			msgIntro		=> 'SR;P0=-2560;P1=2560;P3=-640;D=10101010101010113;',
			#msgOutro		=> 'SR;P0=-30415;D=0;',
			frequency		=> '10AB85550A',
		},
	"44" => ## Bresser Temeo Trend
		# MU;P0=-1947;P1=-3891;P2=3880;P3=-478;P4=494;P5=-241;P7=1963;D=34570712171717071707070717071717170707070717170707070707070707170707070717070717071717170717070707171717170707171717171717171707171717170717171707170717;CP=7;R=28;
		{
            		name 			=> 'BresserTemeo',
            		id 			=> '44',
            		comment			=> 'temperature / humidity sensor',
            		clockabs		=> 2000,
            		clockpos		=> ['cp'],
            		zero 			=> [1,-1],
            		one			=> [1,-2],
            		start	 		=> [2,-2],
            		preamble 		=> 'W44#',
            		clientmodule		=> 'SD_WS',
            		modulematch		=> '^W44#[A-F0-9]{18}',
            		length_min 		=> '64',
            		length_max 		=> '72',
		},
	"44.1" => ## Bresser Temeo Trend
		{
            		name 			=> 'BresserTemeo',
            		id 			=> '44',
            		comment			=> 'temperature / humidity sensor',
            		clockabs		=> 500,
            		zero 			=> [4,-4],
            		one			=> [4,-8],
            		start 			=> [8,-12],
            		preamble 		=> 'W44x#',
            		clientmodule		=> 'SD_WS',
            		modulematch		=> '^W44x#[A-F0-9]{18}',
            		length_min 		=> '64',
            		length_max 		=> '72',
		},
    "45"  => #  Revolt 
			 #	MU;P0=-8320;P1=9972;P2=-376;P3=117;P4=-251;P5=232;D=012345434345434345454545434345454545454543454343434343434343434343434543434345434343434545434345434343434343454343454545454345434343454345434343434343434345454543434343434345434345454543454343434543454345434545;CP=3;R=2;
		{
			name         => 'Revolt',
			id           => '45',
			one          => [2,-2],
			zero         => [1,-2],
			start        => [83,-3], 
			clockabs     => 120, 
			clockpos     => ['zero',0],
			preamble     => 'r', # prepend to converted message
			clientmodule => 'Revolt', 
			modulematch  => '^r[A-Fa-f0-9]{22}', 
			length_min   => '96',
			length_max   => '120',	
			postDemodulation => \&main::SIGNALduino_postDemo_Revolt,
		},    
		"46"	=>	## Tedsen Fernbedienungen u.a. für Berner Garagentorantrieb GA401 und Geiger Antriebstechnik Rolladensteuerung
							# https://github.com/RFD-FHEM/RFFHEM/issues/91
							# remote TEDSEN SKX1MD 433.92 MHz - 1 button | settings via 9 switch on battery compartment
							# compatible with doors: BERNER SKX1MD, ELKA SKX1MD, TEDSEN SKX1LC, TEDSEN SKX1 - 1 Button
							# MU;P0=-15829;P1=-3580;P2=1962;P3=-330;P4=245;P5=-2051;D=1234523232345234523232323234523234540 0 2345 2323 2345 2345 2323 2323 2345 2323 454 023452323234523452323232323452323454023452323234523452323232323452323454023452323234523452323232323452323454023452323234523452323;CP=2;
							# MU;P0=-1943;P1=1966;P2=-327;P3=247;P5=-15810;D=012301212123012301212121212301212303           5 1230 1212 1230 1230 1212 1212 1230 1212 303 5 1230 1212 1230 1230 1212 1212 1230 1212 303 51230121212301230121212121230121230351230121212301230121212121230121230351230;CP=1;
							## GEIGER GF0001, 2 Button, DIP-Schalter: + 0 + - + + - 0 0
							# https://forum.fhem.de/index.php/topic,39153.0.html
							# rauf:   MU;P0=-32001;P1=2072;P2=-260;P3=326;P4=-2015;P5=-15769;D=01212123412123434121212123434123412351212123412123434121212123434123412351212123412123434121212123434123412351212123412123434121212123434123412351212123412123434121212123434123412351212123412123434121212123434123412351212123412123434121212123434123412351;CP=3;R=37;O;
							# runter: MU;P0=-15694;P1=2009;P2=-261;P3=324;P4=-2016;D=01212123412123434121212123434123434301212123412123434121212123434123434301212123412123434121212123434123434301212123412123434121212123434123434301212123412123434121212123434123434301;CP=3;R=30;
							# ?
							# MU;P0=313;P1=1212;P2=-309;P4=-2024;P5=-16091;P6=2014;D=01204040562620404626204040404040462046204040562620404626204040404040462046204040562620404626204040404040462046204040562620404626204040404040462046204040;CP=0;R=236;
							# MU;P0=-15770;P1=2075;P2=-264;P3=326;P4=-2016;P5=948;D=012121234121234341212121234341234343012125;CP=3;R=208;		{
		{
			name				=> 'SKXxxx, GF0x0x',
			comment				=> 'remote controls Tedsen SKXxxx, GEIGER GF0x0x, Berner',
			changed				=> '20190323 ID 78 added',
			id					=> '46',
			one					=> [7,-1],
			zero					=> [1,-7],
			start					=> [-55],
			clockabs				=> 290,
			clockpos				=> ['zero',0],
			reconstructBit			=> '1',
			format					=> 'twostate',	# not used now
			preamble				=> 'P46#',
			clientmodule			=> 'SD_UT',
			modulematch			=> '^P46#.*',
			length_min			=> '17',       # old 14
			length_max			=> '18',
		},
	"47"	=>	## Maverick
						# MC;LL=-507;LH=490;SL=-258;SH=239;D=AA9995599599A959996699A969;C=248;L=104;
		{
			name				=> 'Maverick',
			comment				=> 'BBQ / food thermometer',
			id				=> '47',
			clockrange     	=> [180,260],
			format 			=> 'manchester',	
			preamble		=> 'P47#',						# prepend to converted message	
			clientmodule    => 'SD_WS_Maverick',   					
			modulematch     => '^P47#[569A]{12}.*',  					
			length_min      => '100',
			length_max      => '108',
			method          => \&main::SIGNALduino_Maverick,		# Call to process this message
			#polarity		=> 'invert'
		}, 			
     "48"    => ## Joker Dostmann TFA 30.3055.01
				# https://github.com/RFD-FHEM/RFFHEM/issues/92
				# MU;P0=591;P1=-1488;P2=-3736;P3=1338;P4=-372;P6=-988;D=23406060606063606363606363606060636363636363606060606363606060606060606060606060636060636360106060606060606063606363606363606060636363636363606060606363606060606060606060606060636060636360106060606060606063606363606363606060636363636363606060606363606060;CP=0;O;
				# MU;P0=96;P1=-244;P2=510;P3=-1000;P4=1520;P5=-1506;D=01232323232343234343232343234323434343434343234323434343232323232323232323232323234343234325232323232323232343234343232343234323434343434343234323434343232323232323232323232323234343234325232323232323232343234343232343234323434343434343234323434343232323;CP=2;O;
		{
			name			=> 'TFA Dostmann',	
			comment			=> 'Funk-Thermometer Joker TFA 30.3055.01',
			id          	=> '48',
			clockabs     	=> 250, 						# In real it is 500 but this leads to unprceise demodulation 
			clockpos     => ['zero',1],
			one				=> [-4,6],
			zero			=> [-4,2],
			start			=> [-6,2],
			format 			=> 'twostate',	
			preamble		=> 'U48#',						# prepend to converted message	
			#clientmodule    => '',   						# not used now
			modulematch     => '^U48#.*',
			length_min      => '47',
			length_max      => '48',
		},
		"49"	=>	## QUIGG GT-9000, EASY HOME RCT DS1 CR-A, uniTEC 48110 and other
							# The remote sends 8 messages in 2 different formats.
							# SIGNALduino decodes 4 messages from remote control as MS then ...
							# https://github.com/RFD-FHEM/RFFHEM/issues/667 - Oct 19, 2019
							# DMSG: 5A98B0   MS;P0=-437;P3=-1194;P4=1056;P6=297;P7=-2319;D=67634063404063406340636340406363634063404063636363;CP=6;SP=7;R=37;
							# DMSG: 887F92   MS;P1=-2313;P2=1127;P3=-405;P4=379;P5=-1154;D=41234545452345454545232323232323232345452345452345;CP=4;SP=1;R=251;
							# DMSG: E6D12E   MS;P0=1062;P1=-1176;P2=315;P3=-2283;P4=-433;D=23040404212104042104042104212121042121042104040421;CP=2;SP=3;R=26;
			{
				name            => 'GT-9000',
				comment         => 'Remote control EASY HOME RCT DS1 CR-A',
				changed         => '20191215 new',
				id              => '49',
				clockabs        => 383,
				one             => [3,-1],  # 1150,-385 (timings from salae logic)
				zero            => [1,-3],  # 385,-1150 (timings from salae logic)
				sync            => [1,-6],  # 385,-2295 (timings from salae logic)
				format          => 'twostate',
				preamble        => 'P49#',
				clientmodule    => 'SD_GT',
				modulematch     => '^P49.*',
				length_min      => '24',
				length_max      => '24',
			},
		"49.1"	=>	## QUIGG GT-9000
							# ... decodes 4 messages as MU
							# https://github.com/RFD-FHEM/RFFHEM/issues/667 @Ralf9 from https://forum.fhem.de/index.php/topic,104506.msg985295.html
							# DMSG: 8B2DB0   MU;P0=-563;P1=479;P2=991;P3=-423;P4=361;P5=-1053;P6=3008;P7=-7110;D=2345454523452323454523452323452323452323454545456720151515201520201515201520201520201520201515151567201515152015202015152015202015202015202015151515672015151520152020151520152020152020152020151515156720151515201520201515201520201520201520201515151;CP=1;R=21;
							# DMSG: 887F90   MU;P0=-565;P1=489;P2=991;P3=-423;P4=359;P5=-1047;P6=3000;P7=-7118;D=2345454523454545452323232323232323454523454545456720151515201515151520202020202020201515201515151567201515152015151515202020202020202015152015151515672015151520151515152020202020202020151520151515156720151515201515151520202020202020201515201515151;CP=1;R=17;
			{
				name            => 'GT-9000',
				comment         => 'Remote control is traded under different names',
				changed         => '20191215 new',
				id              => '49.1',
				clockabs        => 515,
				clockpos        => ['zero',0],
				one             => [2,-1],  # 1025,-515  (timings from salae logic)
				zero            => [1,-2],  # 515,-1030  (timings from salae logic)
				start           => [6,-14],	# 3075,-7200 (timings from salae logic)
				format          => 'twostate',
				preamble        => 'P49#',
				clientmodule    => 'SD_GT',
				modulematch     => '^P49.*',
				length_min      => '24',
				length_max      => '24',
			},
		"49.2"	=>	## Tec Star Modell 2335191R
							# SIGNALduino decodes 4 messages from remote control as MU then ... 49.1
							# https://forum.fhem.de/index.php/topic,43292.msg352982.html#msg352982 - Nov 01, 2015
							# message was receive with older firmware
							# DMSG: CA627C   MU;P0=1092;P1=-429;P2=335;P3=-1184;P4=-2316;P5=2996;D=010123230123012323010123232301232301010101012323240101232301230123230101232323012323010101010123232401012323012301232301012323230123230101010101232355;CP=2;
							# DMSG: C9AFAC   MU;P0=328;P1=-428;P3=1090;P4=-1190;P5=-2310;D=010131040431310431043131313131043104313104040531310404310404313104310431313131310431043131040405313104043104043131043104313131313104310431310404053131040431040431310431043131313131043104313104042;CP=0;
			{
				name            => 'GT-9000',
				comment         => 'Remote control Tec Star Modell 2335191R',
				changed         => '20191215 new',
				id              => '49.2',
				clockabs        => 383,
				clockpos        => ['zero',0],
				one             => [3,-1],
				zero            => [1,-3],
				start           => [1,-6],  # Message is not provided as MS
				format          => 'twostate',
				preamble        => 'P49#',
				clientmodule    => 'SD_GT',
				modulematch     => '^P49.*',
				length_min      => '24',
				length_max      => '24',
			},
	"50"	=>	## Opus XT300
						# https://github.com/RFD-FHEM/RFFHEM/issues/99
						# MU;P0=248;P1=-21400;P2=545;P3=-925;P4=1368;P5=-12308;D=01232323232323232343234323432343234343434343234323432343434343432323232323232323232343432323432345232323232323232343234323432343234343434343234323432343434343432323232323232323232343432323432345232323232323232343234323432343234343434343234323432343434343;CP=2;O;
						# MU;P2=-962;P4=508;P5=1339;P6=-12350;D=46424242424242424252425242524252425252525252425242525242424252425242424242424242424252524252524240;CP=4;R=0;
						# MU;P2=510;P3=-947;P5=1334;P6=-12248;D=26232323232323232353235323532323235353535353235323535323232353235323232323232323232353532353235320;CP=2;R=0;
						{
			name				=> 'Opus_XT300',
			comment				=> 'sensor for ground humidity',
			id				=> '50',
			clockabs     	=> 500, 						
			clockpos	=> ['one',0],
			zero			=> [3,-2],
			one				=> [1,-2],
		#	start			=> [1,-25],						# Wenn das startsignal empfangen wird, fehlt das 1 bit
			reconstructBit	=> '1',
			format 			=> 'twostate',	
			preamble		=> 'W50#',						# prepend to converted message	
			clientmodule    => 'SD_WS',
			modulematch     => '^W50#.*',
			length_min      => '47',
			length_max      => '48',
		},
	"51"	=>	## weather sensors
						# https://github.com/RFD-FHEM/RFFHEM/issues/118
						# IAN 275901 Id:08 Ch:3 T:6.3 H:95 MS;P0=-4074;P1=608;P2=-1825;P3=-15980;P4=1040;P5=-975;P6=-7862;D=16121212121012121212101212101212101210121012121010121010121012121012101210121210101345454545;CP=1;SP=6;
						# IAN 275901 Id:08 Ch:3 T:8.5 H:95 MS;P0=611;P1=-4073;P2=-1825;P3=-15980;P4=1041;P5=-974;P6=-7860;D=06020202020102020202020201010202010201020102010201010102010102020102010201020201010345454545;CP=0;SP=6;
						# https://github.com/RFD-FHEM/RFFHEM/issues/122
						# IAN 114324 Id:11 Ch:1 T:17.3 H:40 MS;P0=-1848;P1=577;P2=-4066;P3=-15997;P4=1013;P5=-1001;P6=-7875;D=16101010121010101210101210101012101012101212121212121012121012101010101010101010121345454545;CP=1;SP=6;O;
						# IAN 114324 Id:71 Ch:1 T:17.3 H:41 MS;P0=-16000;P1=1002;P2=-1010;P3=572;P4=-7884;P5=-1817;P6=-4102;D=34353636363535353635363535353535353536353636363636363536363536353535353536353535363012121212;CP=3;SP=4;O;
						# https://github.com/RFD-FHEM/RFFHEM/issues/161
						# IAN 60107 Id:F0 Ch:1 T:-2.9 H:76 MS;P2=594;P3=-7386;P4=-4081;P5=-1873;D=2324242424252525252525242425252525252425252425252524242424252424242524242525252524;CP=2;SP=3;R=242;
						# IAN 60107 Id:F0 Ch:1 T:0.9 H:81 MS;P2=604;P3=-7258;P4=-4179;P5=-1852;D=2324242424252525252525242525252524252425252424252425242524242525252525252425252524;CP=2;SP=3;R=242;
						# IAN 60107 Id:F0 Ch:1 T:13.6 H:51 MS;P2=634;P3=-8402;P4=-4079;P5=-1832;D=2324242424252525252425252425252524252425242425242424252524252425242525252425252524;CP=2;SP=3;R=244;
		{
			name			=> 'weather',
			comment			=> 'Lidl Weatherstation IAN60107, IAN 114324, IAN 275901',
			id          	=> '51',
			one				=> [1,-8],
			zero			=> [1,-4],
			sync			=> [1,-16],		
			clockabs   		=> '500',
			format     		=> 'twostate',  # not used now
			preamble		=> 'W51#',		# prepend to converted message	 	
			#postamble		=> '',			# Append to converted message	 	
			clientmodule    => 'SD_WS',   
			modulematch     => '^W51#.*',
			length_min      => '40',
			length_max      => '45',
		},
	"52"	=>	## Oregon Scientific PIR Protocol
						# https://forum.fhem.de/index.php/topic,63604.msg548256.html#msg548256
						# MC;LL=-1045;LH=1153;SL=-494;SH=606;D=FFFED518;C=549;L=30;
						#
						# FFFED5 = Adresse, die per DIP einstellt wird, FFF aendert sich nie
						# 1 = Kanal, per gesondertem DIP, bei mir bei beiden 1 (CH 1) oder 3 (CH 2)
						# C = wechselt, 0, 4, 8, C - dann faengt es wieder mit 0 an und wiederholt sich bei jeder Bewegung
		{
			name				=> 'Oregon Scientific PIR',
			comment			=> 'JMR868 / NR868',
			id				=> '52',
			clockrange     	=> [470,640],			# min , max
			format 			=> 'manchester',	    # tristate can't be migrated from bin into hex!
			clientmodule    => 'SIGNALduino_un',
			modulematch     => '^u52#F{3}|0{3}.*',
			preamble		=> 'u52#',
			length_min      => '30',
			length_max      => '32',
			method          => \&main::SIGNALduino_OSPIR, # Call to process this message
			polarity        => 'invert',			
		},
	"53"	=>	## Lidl AURIOL AHFL 433 B2 IAN 314695
							# https://github.com/RFD-FHEM/RFFHEM/issues/663 @Kreidler1221 05.10.2019
							# IAN 314695 Id:07 Ch:1 T:24.2 H:59   MS;P1=611;P2=-2075;P3=-4160;P4=-9134;D=14121212121213131312121212121212121313131312121312121313131213131212131212131213121213;CP=1;SP=4;R=0;O;m2;
							# IAN 314695 Id:07 Ch:1 T:22.3 H:61   MS;P1=608;P2=-2074;P3=-4138;P4=-9138;D=14121212121213131312121212121212121313121313131313121313131312131212131212131313121212;CP=1;SP=4;R=0;O;m1;
							# IAN 314695 Id:07 Ch:2 T:18.4 H:70   MS;P0=606;P1=-2075;P2=-4136;P3=-9066;D=03010101010102020201010102010101010201020202010101020101010202010101020101020201010202;CP=0;SP=3;R=0;O;m2;
			{
				name          => 'AHFL 433 B2',
				comment       => 'Auriol weatherstation IAN 314695',
				changed       => '20191109 new',
				id            => '53',
				one           => [1,-7],
				zero          => [1,-3.5],
				sync          => [1,-15],
				clockabs      => 600,
				format        => 'twostate',		# not used now
				preamble      => 'W53#',
				clientmodule  => 'SD_WS',
				modulematch   => '^W53#.*',
				length_min    => '42',
				length_max    => '44',
			},
		"54"	=>	## TFA Drop 30.3233.01 - Rain gauge
							# Rain sensor 30.3233.01 for base station 47.3005.01
							# https://github.com/merbanan/rtl_433/blob/master/src/devices/tfa_drop_30.3233.c | https://forum.fhem.de/index.php/topic,107998.0.html @sido
							# @sido
							# SD_WS_54_R_D9C43 R: 73.66   MU;P1=247;P2=-750;P3=722;P4=-489;P5=491;P6=-236;P7=-2184;D=1232141456565656145656141456565614141456141414145656141414141456561414141456561414145614561456145614141414141414145614145656145614141732321414565656561456561414565656141414561414141456561414141414565614141414565614141456145614561456141414141414141456141;CP=1;R=55;O;
							# SD_WS_54_R_D9C43 R: 74.422  MU;P0=-1672;P1=740;P2=-724;P3=260;P4=-468;P5=504;P6=-230;D=012123434565656563456563434565656343434563434343456563434343456345634343434565634565656345634563456343434343434343456563434345634345656;CP=3;R=4;
							# @punker
							# SD_WS_54_R_896E1 R: 28.702  MU;P0=-242;P1=-2076;P2=-13292;P3=242;P4=-718;P5=748;P6=-494;P7=481;CP=3;R=29;D=23454363670707036363670363670367070367070703636363670363636363670363636707036367070707036703670367036363636363636363636707036703636363154543636707070363636703636703670703670707036363636703636363636703636367070363670707070367036703670363636363636363636367;O;
							# SD_WS_54_R_896E1 R: 29.464  MU;P0=-236;P1=493;P2=235;P3=-503;P4=-2076;P5=734;P6=-728;CP=2;R=11;D=0101023101023245656232310101023232310232310231010231010102323232310232323232310102323101023102310231023102310231023232323232323232323101010231010232;e;i;
			{
				name           => 'TFA 30.3233.01',
				comment        => 'Rain sensor',
				changed        => '20200210 new',
				id             => '54',
				one            => [2,-1],
				zero           => [1,-2],
				start          => [3,-3],	# message provided as MU
				clockabs       => 250,
				clockpos       => ['zero',0],
				reconstructBit => '1',
				clientmodule   => 'SD_WS',
				format         => 'twostate',
				preamble       => 'W54#',
				length_min     => '64',
				length_max     => '68',
			},
		"54.1" => ## TFA Drop 30.3233.01 - Rain gauge
							# Rain sensor 30.3233.01 for base station 47.3005.01
							# https://github.com/merbanan/rtl_433/blob/master/src/devices/tfa_drop_30.3233.c | https://forum.fhem.de/index.php/topic,107998.0.html @punker
							# @punker
							# SD_WS_54_R_896E1 R: 28.702  MS;P0=-241;P1=486;P2=241;P3=-488;P4=-2098;P5=738;P6=-730;D=24565623231010102323231023231023101023101010232323231023232323231023232310102323101010102310231023102323232323232323232310102310232323;CP=2;SP=4;R=30;O;b=19;s=1;m0;
							# SD_WS_54_R_896E1 R: 29.464  MS;P0=-491;P1=242;P2=476;P3=-248;P4=-2096;P5=721;P6=-745;D=14565610102323231010102310102310232310232323101010102310101010102323101023231023102310231023102310231010101010101010101023232310232310;CP=1;SP=4;R=10;O;b=135;s=1;m0;
			{
				name           => 'TFA 30.3233.01',
				comment        => 'Rain sensor',
				changed        => '20200216 new',
				id             => '54.1',
				one            => [2,-1],
				zero           => [1,-2],
				sync           => [3,-3],	# message provided as MS
				clockabs       => 250,
				clientmodule   => 'SD_WS',
				format         => 'twostate',
				preamble       => 'W54#',
				length_min     => '64',
				length_max     => '68',
			},
		"55"	=>	## QUIGG GT-1000
		{
			name			=> 'QUIGG_GT-1000',
			comment			=> 'remote control',
			id          	=> '55',
			clockabs     	=> 300, 						
			zero			=> [1,-4],
			one				=> [4,-2],
			sync			=> [1,-8],						
			format 			=> 'twostate',	
			preamble		=> 'i',						# prepend to converted message	
			clientmodule    => 'IT',
			modulematch     => '^i.*',
			length_min      => '24',
			length_max      => '24',
		},	
	"56" => ## Celexon Motorleinwand
             # https://forum.fhem.de/index.php/topic,52025.0.html @Horst12345
              # AC114_01B_00587B down MU;P0=5036;P1=-624;P2=591;P3=-227;P4=187;P5=-5048;D=0123412341414123234141414141414141412341232341414141232323234123234141414141414123414141414141414141234141414123234141412341232323250123412341414123234141414141414141412341232341414141232323234123234141414141414123414141414141414141234141414123234141412;CP=4;O;
              # Alphavision Slender Line Plus motor canvas, remote control AC114-01B from Shenzhen A-OK Technology Grand Development Co.
              # https://github.com/RFD-FHEM/RFFHEM/issues/906 @TheChatty
              # AC114_01B_479696 up   MU;P0=-16412;P1=5195;P2=-598;P3=585;P4=-208;P5=192;D=01234523452525234345234525252343434345252345234345234525234523434525252525252525234525252525252525252525252345234345234343434343434341234523452525234345234525252343434345252345234345234525234523434525252525252525234525252525252525252525252345234345234343;CP=5;R=105;O;
              # AC114_01B_479696 stop MU;P0=-2341;P1=5206;P2=-571;P3=591;P4=-211;P5=207;D=01234523452525234345234525252343434345252345234345234525234523434525252525252525234525252525252525252523452525234343452523452343434341234523452525234345234525252343434345252345234345234525234523434525252525252525234525252525252525252523452525234343452523;CP=5;R=107;O;
		{
			name			=> 'AC114-xxB',
			comment			=> 'Remote control for motorized screen from Alphavision, Celexon',
			changed			=> '20201209',
			id			=> '56',
			clockabs		=> 200,
			clockpos		=> ['zero',0],
			reconstructBit	=> '1',
			zero			=> [1,-3],  #  200,-600
			one			=> [3,-1],  #  600,-200
			start			=> [25,-3], # 5000,-600
			pause			=> [-25],   # -5000, pause between repeats of send messages (clockabs*pause must be < 32768)
			format 			=> 'twostate',	
			preamble		=> 'P56#',						# prepend to converted message	
			clientmodule    => 'SD_UT',
			#modulematch     => '',  						# not used now
			length_min      => '64', # 65 - reconstructBit = 64
			length_max      => '65', # normal 65 Bit, 3 Bit werden aufgefuellt
		},		
	"57"	=>	## m-e doorbell fuer FG- und Basic-Serie
						# https://forum.fhem.de/index.php/topic,64251.0.html
						# MC;LL=-653;LH=665;SL=-317;SH=348;D=D55B58;C=330;L=21;
						# MC;LL=-654;LH=678;SL=-314;SH=351;D=D55B58;C=332;L=21;
						# MC;LL=-653;LH=679;SL=-310;SH=351;D=D55B58;C=332;L=21;
		{
			name		=> 'm-e',
			comment		=> 'radio gong transmitter for FG- and Basic-Serie',
			id				=> '57',
			clockrange			=> [300,360],						# min , max
			format				=> 'manchester',				# tristate can't be migrated from bin into hex!
			clientmodule		=> 'SD_BELL',
			modulematch			=> '^P57#.*',
			preamble				=> 'P57#',
			length_min      => '21',
			length_max      => '24',
			method          => \&main::SIGNALduino_MCRAW, # Call to process this message
			polarity        => 'invert',			
		},
	"58"	=>	## TFA 30.3208.0
				# MC;LL=-981;LH=964;SL=-480;SH=520;D=002BA37EBDBBA24F0015D1BF5EDDD127800AE8DFAF6EE893C;C=486;L=194;
		{
			name		=> 'TFA 30.3208.0',
			comment         => 'Temperature/humidity sensors (TFA 30.3208.02, 30.3228.02, 30.3229.02, Froggit/Renkforce FT007xx, Ambient Weather F007-xx)',
			id          	=> '58',
			clockrange     	=> [460,520],			# min , max
			format 			=> 'manchester',	    # tristate can't be migrated from bin into hex!
			clientmodule    => 'SD_WS',
			modulematch     => '^W58*',
			preamble		=> 'W58#',
			length_min      => '52',	# 54
			length_max      => '52',	# 136
			method          => \&main::SIGNALduino_MCTFA, # Call to process this message
			polarity        => 'invert',			
		},
	"59"	=>	## AK-HD-4 remote | 4 Buttons
                # https://github.com/RFD-FHEM/RFFHEM/issues/133
                # MU;P0=819;P1=-919;P2=234;P3=-320;P4=8602;P6=156;D=01230301230301230303012123012301230303030301230303412303012303012303030121230123012303030303012303034123030123030123030301212301230123030303030123030341230301230301230303012123012301230303030301230303412303012303012303030121230123012303030303012303034163;CP=0;O;
                # MU;P0=-334;P2=8581;P3=237;P4=-516;P5=782;P6=-883;D=23456305056305050563630563056305050505056305050263050563050563050505636305630563050505050563050502630505630505630505056363056305630505050505630505026305056305056305050563630563056305050505056305050263050563050563050505636305630563050505050563050502630505;CP=5;O;
		{
			name			=> 'AK-HD-4',	
			comment			=> 'remote control with 4 buttons',
			id          => '59',
			clockabs     	=> 230, 						
			clockpos		=> ['zero',1],
			zero			=> [-4,1],
			one			=> [-1,4],
			start			=> [-1,37],						
			format 			=> 'twostate',	# tristate can't be migrated from bin into hex!
			preamble		=> 'u59#',			# Append to converted message	
			#postamble		=> '',		# Append to converted message	 	
			clientmodule    => 'SIGNALduino_un',   		# not used now
			#modulematch     => '',  # not used now
			length_min      => '24',
			length_max      => '24',
		},			
	"60" =>	## ELV, LA CROSSE (WS2000/WS7000)
			# MU;P0=32001;P1=-381;P2=835;P3=354;P4=-857;D=01212121212121212121343421212134342121213434342121343421212134213421213421212121342121212134212121213421212121343421343430;CP=2;R=53;
			# tested sensors:   WS-7000-20, AS2000, ASH2000, S2000, S2000I, S2001A, S2001IA,
			#                   ASH2200, S300IA, S2001I, S2000ID, S2001ID, S2500H 
			# not tested:       AS3, S2000W, S2000R, WS7000-15, WS7000-16, WS2500-19, S300TH, S555TH
			# das letzte Bit (1) und mehrere Bit (0) Preambel fehlen meistens
			#  ___        _
			# |   |_     | |___
			#  Bit 0      Bit 1
			# kurz 366 mikroSek / lang 854 mikroSek / gesamt 1220 mikroSek - Sollzeiten 
		{
			name                 => 'WS2000',
			comment              => 'Series WS2000/WS7000 of various sensors',
			id                   => '60',
			one                  => [3,-7],	
			zero                 => [7,-3],
			clockabs             => 122,
			clockpos             => ['one',0],
			reconstructBit       => '1',
			pause                => [-70],
			preamble             => 'K',        # prepend to converted message
			#postamble            => '',         # Append to converted message
			clientmodule         => 'CUL_WS',   
			length_min           => '38',       # 46, letztes Bit fehlt = 45, 10 Bit Preambel = 35 Bit Daten
			length_max           => '82',
			postDemodulation     => \&main::SIGNALduino_postDemo_WS2000,
		}, 
	"61" =>	## ELV FS10
		# tested transmitter:   FS10-S8, FS10-S4, FS10-ZE
		# tested receiver:      FS10-ST, FS10-MS, WS3000-TV, PC-Wettersensor-Empfaenger
		# sends 2 messages with 43 or 48 bits in distance of 100 mS (on/off) , last bit 1 is missing
		# sends x messages with 43 or 48 bits in distance of 200 mS (dimm) , repeats second message
		# MU;P0=1776;P1=-410;P2=383;P3=-820;D=01212121212121212121212123212121232323212323232121212323232121212321212123232123212120;CP=2;R=74;
		#  __         __
		# |  |__     |  |____
		#  Bit 0      Bit 1
		# kurz 400 mikroSek / lang 800 mikroSek / gesamt 800 mikroSek = 0, gesamt 1200 mikroSek = 1 - Sollzeiten 
		{
			name		=> 'FS10',
			comment		=> 'remote control',
			id		=> '61',
			one		=> [1,-2],
			zero		=> [1,-1],
			clockabs	=> 400,
			clockpos	=> ['cp'],
			pause		=> [-81],				# 400*81=32400*6=194400 - pause between repeats of send messages (clockabs*pause must be < 32768)
			format 		=> 'twostate',
			preamble	=> 'P61#',      # prepend to converted message
			#postamble	=> '',         # Append to converted message
			clientmodule	=> 'FS10',
			#modulematch	=> '',
			length_min	=> '30',       # 43-1=42 (letztes Bit fehlt) 42-12=30 (12 Bit Preambel)
			length_max      => '48',	# eigentlich 46
		}, 
	"62" => ## Clarus_Switch  
			# MU;P0=-5893;P4=-634;P5=498;P6=-257;P7=116;D=45656567474747474745656707456747474747456745674567456565674747474747456567074567474747474567456745674565656747474747474565670745674747474745674567456745656567474747474745656707456747474747456745674567456565674747474747456567074567474747474567456745674567;CP=7;O;
		{
			name         => 'Clarus_Switch',
			id           => '62',
			one          => [3,-1],
			zero         => [1,-3],
			start        => [1,-35], # ca 30-40
			clockabs     => 189, 
			clockpos     => ['zero',0],
			preamble     => 'i', # prepend to converted message
			clientmodule => 'IT', 
			#modulematch => '', 
			length_min   => '24',
			length_max   => '24',		
		},
	"63" => ## Warema MU
            # https://forum.fhem.de/index.php/topic,38831.msg395978/topicseen.html#msg395978 | https://www.mikrocontroller.net/topic/264063
			# MU;P0=-2988;P1=1762;P2=-1781;P3=-902;P4=871;P5=6762;P6=5012;D=0121342434343434352434313434243521342134343436;
			# MU;P0=6324;P1=-1789;P2=864;P3=-910;P4=1756;D=0123234143212323232323032321234141032323232323232323;CP=2;
		{
			name         => 'Warema',
			comment      => 'developId, is still experimental',
			id           => '63',
			developId    => 'y',
			one          => [1],
			zero         => [0],
			clockabs     => 800, 
			syncabs      => '6700',  # Special field for filterMC function
			preamble     => 'u63#', # prepend to converted message
			clientmodule => 'SIGNALduino_un', 
			#modulematch => '', 
			length_min   => '24',
			filterfunc   => \&main::SIGNALduinoAdv_filterMC,
		},
	"64" => ##  WH2
			# W64#FF48D0C9FFBA
			# no value!    MU;P0=134;P1=-113;P3=412;P4=-1062;P5=1379;D=01010101013434343434343454345454345454545454345454545454343434545434345454345454545454543454543454345454545434545454345;CP=3;
		{
			name         => 'WH2',
			comment      => 'temperature / humidity sensor',
			id           => '64',
			one          => [1,-2],
			zero         => [3,-2],
			clockabs     => 490,
			clockpos     => ['one',0],
			clientmodule => 'SD_WS',
			modulematch  => '^W64*',
			preamble     => 'W64#',       # prepend to converted message
			#postamble    => '',           # Append to converted message       
			#clientmodule => '',
			length_min   => '48',
			length_max   => '54',
		},
	"65" => ## Homeeasy
			# MS;P1=231;P2=-1336;P4=-312;P5=-8920;D=15121214141412121212141414121212121414121214121214141212141212141212121414121414141212121214141214121212141412141212;CP=1;SP=5;
		{
			name         => 'HomeEasy HE_EU',
			id           => '65',
			one          => [1,-5.5],
			zero         => [1,-1.2],
			sync         => [1,-38],
			clockabs     => 230,
			format       => 'twostate',  # not used now
			preamble     => 'ih',
			clientmodule => 'IT',
			length_min   => '57',
			length_max   => '72',
			postDemodulation => \&main::SIGNALduino_postDemo_HE_EU,
		},
	"66"	=>	## TX2 Protocol (Remote Temp Transmitter & Remote Thermo Model 7035)
						# https://github.com/RFD-FHEM/RFFHEM/issues/160
						# MU;P0=13312;P1=-2785;P2=4985;P3=1124;P4=-6442;P5=3181;P6=-31980;D=0121345434545454545434545454543454545434343454543434545434545454545454343434545434343434545621213454345454545454345454545434545454343434545434345454345454545454543434345454343434345456212134543454545454543454545454345454543434345454343454543454545454545;CP=3;R=73;O;
		{
			name         => 'WS7035',
			comment      => 'temperature sensor',
			id           => '66',
			one          => [1,-5.2],
			zero         => [2.7,-5.2],
			start        => [-2.1,4.2,-2.1],
			clockabs     => 1220,
			clockpos     => ['one',0],
			reconstructBit  => '1',
			format       => 'pwm',  # not used now
			preamble     => 'TX',
			clientmodule => 'CUL_TX',
			modulematch  => '^TX......',
			length_min   => '43',
			length_max   => '44',
			postDemodulation => \&main::SIGNALduino_postDemo_WS7035,
		},
	"67"	=>	## TX2 Protocol (Remote Datalink & Remote Thermo Model 7053, 7054)
						# https://github.com/RFD-FHEM/RFFHEM/issues/162
						# MU;P0=3381;P1=-672;P2=-4628;P3=1142;P4=-30768;D=010 2320232020202020232020232020202320232323202323202020202020202020 4 010 2320232020202020232020232020202320232323202323202020202020202020 0;CP=0;R=45;
						# MU;P0=1148;P1=3421;P6=-664;P7=-4631;D=161 7071707171717171707171707171717171707070717071717171707071717171 0;CP=1;R=29;
						# Message repeats 4 x with pause of ca. 30-34 mS
						#           __               ____
						#  ________|  |     ________|    |
						#      Bit 1             Bit 0
						#    4630  1220       4630   3420   mikroSek - mit Oszi gemessene Zeiten
		{
				name             => 'WS7053',
				comment          => 'temperature sensor',
				id               => '67',
				one              => [-38,10],     # -4636, 1220
				zero             => [-38,28],     # -4636, 3416
				clockabs         => 122,
				clockpos         => ['one',1],
				preamble         => 'TX',         # prepend to converted message
				clientmodule     => 'CUL_TX',
				modulematch      => '^TX......',
				length_min       => '32',
				length_max       => '34',
				postDemodulation => \&main::SIGNALduino_postDemo_WS7053,
		},
		"68"	=>	## Medion OR28V RF Vista Remote Control (Made in china by X10)
							# sendet zwei verschiedene Codes pro Taste
							# Taste ok    739E0  MS;P1=-1746;P2=513;P3=-571;P4=-4612;P5=2801;D=24512321212123232121212323212121212323232323;CP=2;SP=4;R=58;#;#;
							# Taste ok    F31E0  MS;P1=-1712;P2=518;P3=-544;P4=-4586;P5=2807;D=24512121212123232121232323212121212323232323;CP=2;SP=4;R=58;m2;#;#;
							# Taste Vol+  E00B0  MS;P1=-1620;P2=580;P3=-549;P4=-4561;P5=2812;D=24512121212323232323232323232123212123232323;CP=2;SP=4;R=69;O;m2;#;#;
							# Taste Vol+  608B0  MS;P1=-1645;P2=574;P3=-535;P4=-4556;P5=2811;D=24512321212323232323212323232123212123232323;CP=2;SP=4;R=57;m2;#;#;
			{
				name         => 'OR28V',
				comment      => 'Medion OR28V RF Vista Remote Control',
				changed      => '20190723 new, old moved to ID 0.3',
				id           => '68',
				knownFreqs   => '433.92',
				one          => [1,-3],
				zero         => [1,-1],
				sync         => [1,-8,5,-3],
				clockabs     => 550,
				format       => 'twostate',
				preamble     => 'P68#',
				clientmodule => 'SD_UT',
				modulematch  => '^P68#.{5}',
				length_min   => '20',
				length_max   => '20',
			},
	"69"	=>	## Hoermann HSM2, HSM4, HS1-868-BS (868 MHz)
							# https://github.com/RFD-FHEM/RFFHEM/issues/149
							# HSM4 | button_1   MU;P0=-508;P1=1029;P2=503;P3=-1023;P4=12388;D=01010232323232310104010101010101010102323231010232310231023232323231023101023101010231010101010232323232310104010101010101010102323231010232310231023232323231023101023101010231010101010232323232310104010101010101010102323231010232310231023232323231023101;CP=2;R=37;O;
							# Remote control HS1-868-BS (one button):
							# https://github.com/RFD-FHEM/RFFHEM/issues/344
							# HS1_868_BS | receive   MU;P0=-578;P1=1033;P2=506;P3=-1110;P4=13632;D=0101010232323101040101010101010101023232323102323101010231023102310231010232323101010101010101010232323101040101010101010101023232323102323101010231023102310231010232323101010101010101010232323101040101010101010101023232323102323101010231023102310231010;CP=2;R=77;
							# HS1_868_BS | receive   MU;P0=-547;P1=1067;P2=553;P3=-1066;P4=13449;D=0101010101010232323101040101010101010101023232323102323101010231023102310231010232323101010101010101010232323101040101010101010101023232323102323101010231023102310231010232323101010101010101010232323101040101010101010101023232323102323101010231023102310;CP=2;R=71;
							# https://forum.fhem.de/index.php/topic,71877.msg642879.html (HSM4, Taste 1-4)
							# HSM4 | button_1   MU;P0=-332;P1=92;P2=-1028;P3=12269;P4=-510;P5=1014;P6=517;D=01234545454545454545462626254546262546254626262626254625454625454546254545454546262626262545434545454545454545462626254546262546254626262626254625454625454546254545454546262626262545434545454545454545462626254546262546254626262626254625454625454546254545;CP=6;R=37;O;
							# HSM4 | button_2   MU;P0=509;P1=-10128;P2=1340;P3=-517;P4=1019;P5=-1019;P6=12372;D=01234343434343434343050505434305054305430505050505430543430543434305434343430543050505054343634343434343434343050505434305054305430505050505430543430543434305434343430543050505054343634343434343434343050505434305054305430505050505430543430543434305434343;CP=0;R=52;O;
							# HSM4 | button_3   MU;P0=12376;P1=360;P2=-10284;P3=1016;P4=-507;P6=521;P7=-1012;D=01234343434343434343467676734346767346734676767676734673434673434346734343434676767346767343404343434343434343467676734346767346734676767676734673434673434346734343434676767346767343404343434343434343467676734346767346734676767676734673434673434346734343;CP=6;R=55;O;
							# HSM4 | button_4   MU;P0=-3656;P1=12248;P2=-519;P3=1008;P4=506;P5=-1033;D=01232323232323232324545453232454532453245454545453245323245323232453232323245453245454532321232323232323232324545453232454532453245454545453245323245323232453232323245453245454532321232323232323232324545453232454532453245454545453245323245323232453232323;CP=4;R=48;O;
		{
			name            => 'Hoermann',
			comment         => 'remote control HS1-868-BS, HSM4',
			id              => '69',
			knownFreqs		=> '433.92 | 868.35',
			zero			=> [2,-1],     # 1020,510
			one				=> [1,-2],     # 510,1020
			start			=> [25,-1],    # 12750,510
			clockabs        => 510,
			clockpos        => ['one',0],
			format          => 'twostate',  # not used now
			clientmodule    => 'SD_UT',
			modulematch     => '^P69#.{11}',
			preamble        => 'P69#',
			length_min      => '44',
			length_max      => '44',
		},
	"70"	=>	## FHT80TF (Funk-Tuer-Fenster-Melder FHT 80TF und FHT 80TF-2)
						# https://github.com/RFD-FHEM/RFFHEM/issues/171 @HomeAutoUser
	# closed MU;P0=-24396;P1=417;P2=-376;P3=610;P4=-582;D=012121212121212121212121234123434121234341212343434121234123434343412343434121234341212121212341212341234341234123434;CP=1;R=35;
	# open   MU;P0=-21652;P1=429;P2=-367;P4=634;P5=-555;D=012121212121212121212121245124545121245451212454545121245124545454512454545121245451212121212124512451245451245121212;CP=1;R=38;
		{
			name         	=> 'FHT80TF',
			comment		=> 'door/window switch',
			id           	=> '70',
			knownFreqs      => '868.35',
			one         	=> [1.5,-1.5],	# 600
			zero         	=> [1,-1],	# 400
			clockabs     	=> 400,
			clockpos		=> ['zero',0],
			format          => 'twostate',  # not used now
			clientmodule    => 'CUL_FHTTK',
			preamble     	=> 'T',
			length_min     => '50',
			length_max     => '58',
			postDemodulation => \&main::SIGNALduino_postDemo_FHT80TF,
		},
	"71" => ## PV-8644 infactory Poolthermometer
		# MU;P0=1735;P1=-1160;P2=591;P3=-876;D=0123012323010101230101232301230123010101010123012301012323232323232301232323232323232323012301012;CP=2;R=97;
		{
			name		=> 'PV-8644',
			comment		=> 'infactory Poolthermometer',
			id         	=> '71',
			clockabs	=> 580,
			clockpos	=> ['one',0],
			zero		=> [3,-2],
			one		=> [1,-1.5],
			format		=> 'twostate',	
			preamble	=> 'W71#',		# prepend to converted message	
			clientmodule    => 'SD_WS',
			#modulematch     => '^W71#.*'
			length_min      => '48',
			length_max      => '48',
		},
	"72" => # Siro blinds MU    @Dr. Smag
			# ! same definition how ID 16 !
			# https://forum.fhem.de/index.php?topic=77167.0
			# MU;P0=-760;P1=334;P2=693;P3=-399;P4=-8942;P5=4796;P6=-1540;D=01010102310232310101010102310232323101010102310101010101023102323102323102323102310101010102310232323101010102310101010101023102310231023102456102310232310232310231010101010231023232310101010231010101010102310231023102310245610231023231023231023101010101;CP=1;R=45;O;
			# MU;P0=-8848;P1=4804;P2=-1512;P3=336;P4=-757;P5=695;P6=-402;D=0123456345656345656345634343434345634565656343434345634343434343456345634563456345;CP=3;R=49;	
		{
			name			=> 'Siro shutter',
			comment			=> 'message decode as MU',
			id			=> '72',
			dispatchequals	=>  'true',
			one			=> [2,-1.2],    # 680, -400
			zero			=> [1,-2.2],    # 340, -750
			start			=> [14,-4.4],   # 4800,-1520
			clockabs		=> 340,
			clockpos		=> ['zero',0],
			format 			=> 'twostate',	  		
			preamble		=> 'P72#',		# prepend to converted message	
			clientmodule	=> 'Siro',
			#modulematch 	=> '',  			
			length_min   	=> '39',
			length_max   	=> '40',
			msgOutro		=> 'SR;P0=-8500;D=0;',
		},
 	"72.1" => # Siro blinds MS     @Dr. Smag
			  # MS;P0=4803;P1=-1522;P2=333;P3=-769;P4=699;P5=-393;P6=-9190;D=2601234523454523454523452323232323452345454523232323452323232323234523232345454545;CP=2;SP=6;R=61;
		{
			name			=> 'Siro shutter',
			comment			=> 'message decode as MS',
			id			=> '72',
			developId		=> 'm',
			dispatchequals  =>  'true',
			one			=> [2,-1.2],    # 680, -400
			zero			=> [1,-2.2],    # 340, -750
			sync			=> [14,-4.4],   # 4800,-1520
			clockabs		=> 340,
			clockpos		=> ['zero',0],
			format 			=> 'twostate',	  		
			preamble		=> 'P72#',		# prepend to converted message	
			clientmodule	=> 'Siro',
			#modulematch 	=> '',  			
			length_min   	=> '39',
			length_max   	=> '40',
			#msgOutro	=> 'SR;P0=-8500;D=0;',
		},
	"73" => ## FHT80 - Raumthermostat (868Mhz),  @HomeAutoUser
			# MU;P0=136;P1=-112;P2=631;P3=-392;P4=402;P5=-592;P6=-8952;D=0123434343434343434343434325434343254325252543432543434343434325434343434343434343254325252543254325434343434343434343434343252525432543464343434343434343434343432543434325432525254343254343434343432543434343434343434325432525254325432543434343434343434;CP=4;R=250;
		{
			name		=> 'FHT80',
			comment 	=> 'roomthermostat (only receive)',
			id		=> '73',
			knownFreqs      => '868.35',
			one		=> [1.5,-1.5], # 600
			zero		=> [1,-1], # 400
			pause		=> [-25],
			clockabs	=> 400,
			clockpos	=> ['zero',0],
			format		=> 'twostate', # not used now
			clientmodule	=> 'FHT',
			preamble	=> '810c04xx0909a001',
			length_min	=> '59',
			length_max	=> '67',
			postDemodulation => \&main::SIGNALduino_postDemo_FHT80,
		},
	"74"	=>	## FS20 - 'Remote Control (868Mhz),  @HomeAutoUser
						# MU;P0=-10420;P1=-92;P2=398;P3=-417;P5=596;P6=-592;D=1232323232323232323232323562323235656232323232356232356232323232323232323232323232323235623232323562356565623565623562023232323232323232323232356232323565623232323235623235623232323232323232323232323232323562323232356235656562356562356202323232323232323;CP=2;R=72;
		{
			name			=> 'FS20',
			comment			=> 'remote control (decode as MU)',
			id			=> '74',
			knownFreqs      => '868.35',
			one			=> [1.5,-1.5], # 600
			zero			=> [1,-1], # 400
			pause			=> [-25],
			clockabs		=> 400,
			clockpos		=> ['zero',0],
			#reconstructBit	=> '1',
			format			=> 'twostate', # not used now
			clientmodule		=> 'FS20',
			preamble		=> '810b04f70101a001',
			length_min		=> '50',
			length_max		=> '67',
			postDemodulation => \&main::SIGNALduino_postDemo_FS20,
		},
	"74.1"	=>	## FS20 - Remote Control (868Mhz) @HomeAutoUser
								# dim100%   MS;P1=-356;P2=448;P3=653;P4=-551;P5=-10412;D=2521212121212121212121212134212121343421212121213421213421212121212121212121212121212121342121212134213434342134342134;CP=2;SP=5;R=72;O;!;4;
		{
			name             => 'FS20',
			comment          => 'remote control (decode as MS)',
			changed          => '20190424 new',
			id               => '74.1',
			knownFreqs       => '868.35',
			one              => [1.5,-1.5],	# 600
			zero             => [1,-1],	# 400
			sync             => [-25],
			clockabs         => 400,
			#reconstructBit   => '1',
			format           => 'twostate',	# not used now
			clientmodule     => 'FS20',
			preamble         => '810b04f70101a001',
			paddingbits      => '1',      # disable padding
			length_min       => '50',
			length_max       => '67',
			postDemodulation => \&main::SIGNALduino_postDemo_FS20,
		},
	"75"	=>	## Conrad RSL (Erweiterung v2) @litronics https://github.com/RFD-FHEM/SIGNALDuino/issues/69
						# ! same definition how ID 5, but other length !
						# !! protocol needed revision - start or sync failed !! https://github.com/RFD-FHEM/SIGNALDuino/issues/69#issuecomment-440349328
						# MU;P0=-1365;P1=477;P2=1145;P3=-734;P4=-6332;D=01023202310102323102423102323102323101023232323101010232323231023102323102310102323102423102323102323101023232323101010232323231023102323102310102323102;CP=1;R=12;
		{
			name					=> 'Conrad RSL v2',
			comment				=> 'remotes and switches',
			id			=> '75',
			one			=> [3,-1],
			zero			=> [1,-3],
			clockabs		=> 500, 
			clockpos		=> ['zero',0],
			format			=> 'twostate', 
			developId		=> 'y',
			clientmodule		=> 'SD_RSL',
			preamble		=> 'P1#',  
			modulematch		=> '^P1#[A-Fa-f0-9]{8}', 
			length_min		=> '32',
			length_max 		=> '40',
		},
	"76"	=>	## Kabellose LED-Weihnachtskerzen XM21-0
							# ! min length not work - must CHECK !
							# https://github.com/RFD-FHEM/RFFHEM/pull/437#issuecomment-448019192 @sidey79
							# on -> P76#FFFFFFFFFFFFFFFF
							# LED_XM21_0 | on    MU;P0=-205;P1=113;P3=406;D=010101010101010101010101010101010101010101010101010101010101030303030101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010103030303010101010101010101010100;CP=1;R=69;
							# LED_XM21_0 | on    MU;P0=-198;P1=115;P4=424;D=0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101040404040;CP=1;R=60;O;
							# LED_XM21_0 | on    MU;P0=114;P1=-197;P2=419;D=0121212121010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101012121212101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010;CP=0;R=54;O;
							# off -> P76#FFFFFFFFFFFFFFC
							# LED_XM21_0 | off   MU;P0=-189;P1=115;P4=422;D=0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010104040404010101010;CP=1;R=73;O;
							# LED_XM21_0 | off   MU;P0=-203;P1=412;P2=114;D=01010101020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020101010102020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200;CP=2;R=74;
							# LED_XM21_0 | off   MU;P0=-210;P1=106;P3=413;D=0101010101010101010303030301010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101030303030100;CP=1;R=80;
		{
			name			=> 'LED XM21',
			comment			=> 'remote with 2-buttons for LED X-MAS light string',
			id			=> '76',
			developId		=> 'y',
			one			=> [1.2,-2],			# 120,-200
			#zero			=> [],						# existiert nicht
			start			=> [4.5,-2,4.5,-2,4.5,-2,4.5,-2],			# 450,-200 Starsequenz
			clockabs		=> 100,
			format			=> 'twostate',		# not used now
			clientmodule	=> 'SD_UT',
			preamble		=> 'P76#',
			length_min		=> 58,
			length_max		=> 64,
		},
	"77"	=>	## https://github.com/juergs/NANO_DS1820_4Fach
						# MU;P0=102;P1=236;P2=-2192;P3=971;P6=-21542;D=01230303030103010303030303010103010303010303010101030301030103030303010101030301030303010163030303010301030303030301010301030301030301010103030103010303030301010103030103030301016303030301030103030303030101030103030103030101010303010301030303030101010303;CP=0;O;
						# MU;P0=-1483;P1=239;P2=970;P3=-21544;D=01020202010132020202010201020202020201010201020201020201010102020102010202020201010102020102020201013202020201020102020202020101020102020102020101010202010201020202020101010202010202020101;CP=1;
						# MU;P0=-168;P1=420;P2=-416;P3=968;P4=-1491;P5=242;P6=-21536;D=01234343434543454343434343454543454345434543454345434343434343434343454345434343434345454363434343454345434343434345454345434543454345434543434343434343434345434543434343434545436343434345434543434343434545434543454345434543454343434343434343434543454343;CP=3;O;
						# MU;P0=-1483;P1=969;P2=236;P3=-21542;D=01010102020131010101020102010101010102020102010201020102010201010101010101010102010201010101010202013101010102010201010101010202010201020102010201020101010101010101010201020101010101020201;CP=1;
						# MU;P0=-32001;P1=112;P2=-8408;P3=968;P4=-1490;P5=239;P6=-21542;D=01234343434543454343434343454543454345454343454345434343434343434343454345434343434345454563434343454345434343434345454345434545434345434543434343434343434345434543434343434545456343434345434543434343434545434543454543434543454343434343434343434543454343;CP=3;O;
						# MU;P0=-1483;P1=968;P2=240;P3=-21542;D=01010102020231010101020102010101010102020102010202010102010201010101010101010102010201010101010202023101010102010201010101010202010201020201010201020101010101010101010201020101010101020202;CP=1;
						# MU;P0=-32001;P1=969;P2=-1483;P3=237;P4=-21542;D=01212121232123212121212123232123232121232123212321212121212121212123212321212121232123214121212123212321212121212323212323212123212321232121212121212121212321232121212123212321412121212321232121212121232321232321212321232123212121212121212121232123212121;CP=1;O;
						# MU;P0=-1485;P1=967;P2=236;P3=-21536;D=010201020131010101020102010101010102020102020101020102010201010101010101010102010201010101020102013101010102010201010101010202010202010102010201020101010101010101010201020101010102010201;CP=1;
		{
			name			=> 'NANO_DS1820_4Fach',
			comment			=> 'self build sensor',
			id			=> '77',
			developId		=> 'y', 
			zero			=> [4,-6],
			one			=> [1,-6],
			clockabs		=> 250,
			clockpos		=> ['one',0],
			format			=> 'pwm',				#
			preamble		=> 'TX',				# prepend to converted message
			clientmodule	=> 'CUL_TX',
			modulematch		=> '^TX......',
			length_min		=> '43',
			length_max		=> '44',
			remove_zero		=> 1,					# Removes leading zeros from output
		},
    "78"  =>  ## Remote control SEAV BeSmart S4 for BEST Cirrus Draw (07F57800) Deckenluefter
                # https://github.com/RFD-FHEM/RFFHEM/issues/909 @TheChatty
                # BeSmart_S4_534 light_toggle MU;P0=-19987;P1=205;P2=-530;P3=501;P4=-253;P6=-4094;D=01234123412123434123412123412123412121216123412341212343412341212341212341212121612341234121234341234121234121234121212161234123412123434123412123412123412121216123412341212343412341212341212341212121;CP=1;R=70;
                # BeSmart_S4_534 5min_boost   MU;P0=-23944;P1=220;P2=-529;P3=483;P4=-252;P5=-3828;D=01234123412123434123412123412121212121235123412341212343412341212341212121212123512341234121234341234121234121212121212351234123412123434123412123412121212121235123412341212343412341212341212121212123;CP=1;R=74;
                # BeSmart_S4_534 level_up     MU;P0=-8617;P1=204;P2=-544;P3=490;P4=-246;P6=-4106;D=01234123412123434123412123412121234121216123412341212343412341212341212123412121612341234121234341234121234121212341212161234123412123434123412123412121234121216123412341212343412341212341212123412121;CP=1;R=70;
                # BeSmart_S4_534 level_down   MU;P0=-14542;P1=221;P2=-522;P3=492;P4=-240;P5=-4114;D=01234123412123434123412123412121212341215123412341212343412341212341212121234121512341234121234341234121234121212123412151234123412123434123412123412121212341215123412341212343412341212341212121234121;CP=1;R=62;
      {
        name            => 'BeSmart_Sx',
        comment         => 'Remote control SEAV BeSmart S4',
        changed			=> '20210122 new',
        id              => '78',
        zero            => [1,-2], # 250,-500
        one             => [2,-1], # 500,-250
        start           => [-14],  # -3500 + low time from last bit
        clockabs        => 250,
        clockpos        => ['zero',0],
        reconstructBit  => '1',
        format          => 'twostate',
        preamble        => 'P78#',
        clientmodule    => 'SD_UT',
        modulematch     => '^P78#',
        length_min      => '19', # length - reconstructBit = length_min
        length_max      => '20',
      },
	"79"	=>	## Heidemann | Heidemann HX | VTX-BELL
						# https://github.com/RFD-FHEM/SIGNALDuino/issues/84
						# MU;P0=656;P1=-656;P2=335;P3=-326;P4=-5024;D=0123012123012303030301 24 230123012123012303030301 24 230123012123012303030301 24 2301230121230123030303012423012301212301230303030124230123012123012303030301242301230121230123030303012423012301212301230303030124230123012123012303030301242301230121230123030303;CP=2;O;
						# https://forum.fhem.de/index.php/topic,64251.0.html
						# MU;P0=540;P1=-421;P2=-703;P3=268;P4=-4948;D=4 323102323101010101010232 34 323102323101010101010232 34 323102323101010101010232 34 3231023231010101010102323432310232310101010101023234323102323101010101010232343231023231010101010102323432310232310101010101023234323102323101010101010232343231023231010101010;CP=3;O;
						# https://github.com/RFD-FHEM/RFFHEM/issues/252
						# MU;P0=-24096;P1=314;P2=-303;P3=615;P4=-603;P5=220;P6=-4672;D=0123456123412341414141412323234 16 123412341414141412323234 16 12341234141414141232323416123412341414141412323234161234123414141414123232341612341234141414141232323416123412341414141412323234161234123414141414123232341612341234141414141232323416123412341414;CP=1;R=26;O;
						# MU;P0=-10692;P1=602;P2=-608;P3=311;P4=-305;P5=-4666;D=01234123232323234141412 35 341234123232323234141412 35 341234123232323234141412 35 34123412323232323414141235341234123232323234141412353412341232323232341414123534123412323232323414141235341234123232323234141412353412341232323232341414123534123412323232323414;CP=3;R=47;O;
						# MU;P0=-7152;P1=872;P2=-593;P3=323;P4=-296;P5=622;P6=-4650;D=01234523232323234545452 36 345234523232323234545452 36 345234523232323234545452 36 34523452323232323454545236345234523232323234545452363452345232323232345454523634523452323232323454545236345234523232323234545452363452345232323232345454523634523452323232323454;CP=3;R=26;O;
						# https://forum.fhem.de/index.php/topic,58397.msg879878.html#msg879878
						# MU;P0=-421;P1=344;P2=-699;P4=659;P6=-5203;P7=259;D=1612121040404040404040421216121210404040404040404212161212104040404040404042121612121040404040404040421216121210404040404040404272761212104040404040404042121612121040404040404040421216121210404040404040404212167272104040404040404042721612127040404040404;CP=4;R=0;O;
		{
			name			=> 'wireless doorbell',
			comment			=> 'Heidemann | Heidemann HX | VTX-BELL',
			id			=> '79',
			zero			=> [-2,1],
			one			=> [-1,2],
			start  			=> [-15,1],
			clockabs		=> 330,
			clockpos		=> ['zero',1],
			format			=> 'twostate',	# 
			preamble		=> 'P79#',			# prepend to converted message
			clientmodule	=> 'SD_BELL',
			modulematch		=> '^P79#.*',
			length_min		=> '12',
			length_max		=> '12',
		},
	"80"	=>	## EM1000WZ (Energy-Monitor) Funkprotokoll (868Mhz),  @HomeAutoUser | Derwelcherichbin
						# https://github.com/RFD-FHEM/RFFHEM/issues/253
						# MU;P1=-417;P2=385;P3=-815;P4=-12058;D=42121212121212121212121212121212121232321212121212121232321212121212121232323212323212321232121212321212123232121212321212121232323212121212121232121212121212121232323212121212123232321232121212121232123232323212321;CP=2;R=87;
		{	
			name			=> 'EM1000WZ',
			comment         => 'EM (Energy-Monitor)',
			id			=> '80',
			knownFreqs      	=> '868.35',
			one			=> [1,-2],	# 800
			zero			=> [1,-1],	# 400
			clockabs		=> 400,
			clockpos		=> ['cp'],
			format			=> 'twostate', # not used now
			clientmodule	=> 'CUL_EM',
			preamble        => 'E',
			length_min		=> '104',
			length_max		=> '114',
			postDemodulation => \&main::SIGNALduino_postDemo_EM,
		},
	"81" => ## Remote control SA-434-1 based on HT12E @ elektron-bbs
			# MU;P0=-485;P1=188;P2=-6784;P3=508;P5=1010;P6=-974;P7=-17172;D=0123050505630505056305630563730505056305050563056305637305050563050505630563056373050505630505056305630563730505056305050563056305637305050563050505630563056373050505630505056305630563730505056305050563056305637305050563050505630563056373050505630505056;CP=3;R=0;
			# MU;P0=-1756;P1=112;P2=-11752;P3=496;P4=-495;P5=998;P6=-988;P7=-17183;D=0123454545634545456345634563734545456345454563456345637345454563454545634563456373454545634545456345634563734545456345454563456345637345454563454545634563456373454545634545456345634563734545456345454563456345637345454563454545634563456373454545634545456;CP=3;R=0;
			#      __        ____
			# ____|  |    __|    |
			#  Bit 1       Bit 0
			# short 500 microSec / long 1000 microSec / bittime 1500 mikroSek / pilot 12 * bittime, from that 1/3 bitlength high
		{
			name             => 'SA-434-1',
			comment          => 'remote control SA-434-1 mini 923301 based on HT12E',
			changed          => '20180906 new',
			id               => '81',
			one              => [-2,1],			# i.O.
			zero             => [-1,2],			# i.O.
			start            => [-35,1],		# Message is not provided as MS, worakround is start
			clockabs		 => 500,
			clockpos         => ['one',1],
			format           => 'twostate',
			preamble	     => 'P81#',			# prepend to converted message
			modulematch      => '^P81#.{3}',
			clientmodule	 => 'SD_UT',
			length_min       => '12',
			length_max       => '12',
		},
	"82" => ## Fernotron shutters and light switches   
			# MU;P0=-32001;P1=435;P2=-379;P4=-3201;P5=831;P6=-778;D=01212121212121214525252525252521652161452525252525252161652141652521652521652521614165252165252165216521416521616165216525216141652161616521652165214165252161616521652161416525216161652161652141616525252165252521614161652525216525216521452165252525252525;CP=1;O;
			# the messages received are usual missing 12 bits at the end for some reason. So the checksum byte is missing.
			# Fernotron protocol is unidirectional. Here we can only receive messages from controllers send to receivers.
			# https://github.com/RFD-FHEM/RFFHEM/issues/257
		{
			name           => 'Fernotron',
			id             => '82',
			comment        => 'developModule. Fernotron is not in github.com/RFD-FHEM or svn',
			changed        => '20180906 new',
			developId      => 'm',
			dispatchBin    => '1',
			paddingbits    => '1',        # This will disable padding 
			one            => [1,-2],     # on=400us, off=800us
			zero           => [2,-1],     # on=800us, off=400us
			float          => [1,-8],     # on=400us, off=3200us. the preamble and each 10bit word has one [1,-8] in front
			pause          => [1,-1],     # preamble (7x)
			clockabs       => 400,        # 400us
			clockpos       => ['one',0],
			format         => 'twostate',
			preamble       => 'P82#',     # prepend our protocol number to converted message
			clientmodule   => 'Fernotron',
			length_min     => '100',      # actual 120 bit (12 x 10bit words to decode 6 bytes data), but last 20 are for checksum
			length_max     => '3360',     # 3360 bit (336 x 10bit words to decode 168 bytes data) for full timer message
	    },
	"83" => ## Remote control RH787T based on MOSDESIGN SEMICONDUCTOR CORP (CMOS ASIC encoder) M1EN compatible HT12E
			# for example Westinghouse Deckenventilator Delancey, 6 speed buttons, @zwiebelxxl
			# https://github.com/RFD-FHEM/RFFHEM/issues/250
			# Taste 1 MU;P0=388;P1=-112;P2=267;P3=-378;P5=585;P6=-693;P7=-11234;D=0123035353535356262623562626272353535353562626235626262723535353535626262356262627235353535356262623562626272353535353562626235626262723535353535626262356262627235353535356262623562626272353535353562626235626262723535353535626262356262627235353535356262;CP=2;R=43;O;
			# Taste 2 MU;P0=-176;P1=262;P2=-11240;P3=112;P5=-367;P6=591;P7=-695;D=0123215656565656717171567156712156565656567171715671567121565656565671717156715671215656565656717171567156712156565656567171715671567121565656565671717156715671215656565656717171567156712156565656567171715671567121565656565671717171717171215656565656717;CP=1;R=19;O;
			# Taste 3 MU;P0=564;P1=-392;P2=-713;P3=245;P4=-11247;D=0101010101023231023232323431010101010232310232323234310101010102323102323232343101010101023231023232323431010101010232310232323234310101010102323102323232343101010101023231023232323431010101010232310232323234310101010102323102323232343101010101023231023;CP=3;R=40;O;
		{
			name		=> 'RH787T',	
			comment         => 'remote control for example Westinghouse Delancey 7800140',
			changed			=> '20180908 new',
			id          	=> '83',
			one				=> [-2,1],
			zero			=> [-1,2],
			start			=> [-35,1],				# calculated 12126,31579 µS
			clockabs		=> 335,                 # calculated ca 336,8421053 µS short - 673,6842105µS long 
			clockpos     	=> ['one',1],
			format 			=> 'twostate',	  		# there is a pause puls between words
			preamble		=> 'P83#',				# prepend to converted message	
			clientmodule    => 'SD_UT', 
			modulematch     => '^P83#.{3}',
			length_min      => '12',
			length_max      => '12',
		},
	"84"	=>	## Funk Wetterstation Auriol IAN 283582 Version 06/2017 (Lidl), Modell-Nr.: HG02832D, 09/2018@roobbb
						# https://github.com/RFD-FHEM/RFFHEM/issues/263
						# Ch:1 T: 25.3 H: 53 Bat:ok  MU;P0=-28796;P1=376;P2=-875;P3=834;P4=220;P5=-632;P6=592;P7=-268;D=0123232324545454545456767454567674567456745674545454545456767676767674567674567676767456;CP=4;R=22;
						# Ch:2 T: 13.1 H: 78 Bat:ok  MU;P0=-28784;P1=340;P2=-903;P3=814;P4=223;P5=-632;P6=604;P7=-248;D=0123232324545454545456767456745456767674545674567454545456745454545456767454545456745676;CP=4;R=22;
						# Ch:1 T: 6.9 H: 66 Bat:ok   MU;P0=-21520;P1=235;P2=-855;P3=846;P4=620;P5=-236;P7=-614;D=012323232454545454545451717451717171745171717171717171717174517171745174517174517174545;CP=1;R=217;
						## Sempre 92596/65395, Hofer/Aldi, WS97210-1, WS97230-1, WS97210-2, WS97230-2
						# https://github.com/RFD-FHEM/RFFHEM/issues/223
						# Ch:3 T: 20.8 H: 78 Bat:ok  MU;P0=11916;P1=-852;P2=856;P3=610;P4=-240;P5=237;P6=-610;D=01212134563456563434565634565634343456565634565656565634345634565656563434563456343430;CP=5;R=254;
						# Ch:3 T: 21.3 H: 77 Bat:ok  MU;P0=-30004;P1=815;P2=-910;P3=599;P4=-263;P5=234;P6=-621;D=0121212345634565634345656345656343456345656345656565656343456345634563456343434565656;CP=5;R=5;
						## TECVANCE TV-4848 (Amazon) @HomeAutoUser
						# (L39) MU;P0=-218;P1=254;P2=-605;P4=616;P5=907;P6=-799;P7=-1536;D=012121212401212124012401212121240125656565612401240404040121212404012121240121212121212124012121212401212124012401212121247;CP=1;
						# (L41) MU;P0=239;P1=-617;P2=612;P3=-245;P4=862;P5=-842;D=01230145454545012301232323230101012323010101230123010101010123010101012301230123232301012301230145454545012301232323230101012323010101230123010101010123010101012301230123232301012301230145454545012301232323230101012323010101230123010101010123010101012301;CP=0;R=89;O;
		{
			name					=> 'IAN 283582 / TV-4848',
			comment					=> 'Weatherstation Auriol IAN 283582 / Sempre 92596/65395 / TECVANCE',
			changed					=> '20180930 new',
			id						=> '84',
			one						=> [3,-1],
			zero					=> [1,-3],
			start					=> [4,-4,4,-4],
			clockabs			=> 215, 
			clockpos			=> ['zero',0],
			format				=> 'twostate',
			preamble			=> 'W84#',						# prepend to converted message
			#postamble			=> '',								# append to converted message
			clientmodule	=> 'SD_WS',
			length_min		=> '39',							# das letzte Bit fehlt meistens
			length_max		=> '41',
		},
	"85"	=>	## Funk Wetterstation TFA 35.1140.01 mit Temperatur-/Feuchte- und Windsensor TFA 30.3222.02 09/2018@Iron-R
						# https://github.com/RFD-FHEM/RFFHEM/issues/266
						# CH:1 T: 8.7 H: 85 MU;P0=-509;P1=474;P2=-260;P3=228;P4=718;P5=-745;D=01212303030303012301230123012301230301212121230454545453030303012123030301230303012301212123030301212303030303030303012303012303012303012301212303030303012301230123012301230301212121212454545453030303012123030301230303012301212123030301212303030303030303;CP=3;R=46;O;
						# CH:1 Ws: 0.6      MU;P0=242;P1=-506;P2=467;P3=-248;P4=723;P5=-736;D=01012323010123010123014545454501010101232301010101232301230123230123010123230101010101010123010101010101010123012301230101010101010101010101012323010123010123234545454501010101232301010101232301230123230123010123230101010101010123010101010101010123012301;CP=0;R=52;O;
						# CH:1 T: 7.6 H: 89 MU;P0=7944;P1=-724;P2=742;P3=241;P4=-495;P5=483;P6=-248;D=01212121343434345656343434563434345634565656343434565634343434343434345634345634345634343434343434343434345634565634345656345634343456563421212121343434345656343434563434345634565656343434565634343434343434345634345634345634343434343434343434345634565634;CP=3;R=47;O;
						# CH:1 Ws: 1.6 Wd: 58/ENE MU;P0=-28464;P1=493;P2=-238;P3=244;P4=-492;P5=728;P6=-732;D=01212123434343412121212343434343434123434343434343412121234121234343434343412121234123412343412123434343456565656343434341234121212121212121212123434343412121212343434343434123434343434343412121234121234343434343412121234123412343412123434343456565656343;CP=3;R=20;O;
						{
			name					=> 'TFA 30.3222.02 / TFA 30.3251.10',
			comment				=> 'Combisensor TFA 30.3222.02, Windsensor TFA 30.3251.10',
			changed					=> '20181021 new',
			id						=> '85',
			one						=> [2,-1],
			zero					=> [1,-2],
			start					=> [3,-3,3,-3,3,-3],
			start2					=> [3,-3],
			starti					=> [2,2,2],
			clockabs			=> 250, 
			clockpos			=> ['zero',0],
			format				=> 'twostate',
			preamble			=> 'W85#',					# prepend to converted message
			#postamble			=> '',							# append to converted message
			clientmodule	=> 'SD_WS',
			length_min		=> '64',
			length_max		=> '68',
		},
	"86"	=>	### for remote controls:  Novy 840029, CAME TOP 432EV, OSCH & Neff Transmitter SF01 01319004
						### CAME TOP 432EV 433,92 MHz fuer z.B. Drehtor Antrieb:
						# https://forum.fhem.de/index.php/topic,63370.msg849400.html#msg849400
						# https://github.com/RFD-FHEM/RFFHEM/issues/151
						# MU;P0=711;P1=-15288;P4=132;P5=-712;P6=316;P7=-313;D=4565656705656567056567056 16 565656705656567056567056 16 56565670565656705656705616565656705656567056567056165656567056565670565670561656565670565656705656705616565656705656567056567056165656567056565670565670561656565670565656705656705616565656705656567056;CP=6;R=52;
						# MU;P0=-322;P1=136;P2=-15241;P3=288;P4=-735;P6=723;D=012343434306434343064343430623434343064343430643434306 2343434306434343064343430 623434343064343430643434306234343430643434306434343062343434306434343064343430623434343064343430643434306234343430643434306434343062343434306434343064343430;CP=3;R=27;
						# MU;P0=-15281;P1=293;P2=-745;P3=-319;P4=703;P5=212;P6=152;P7=-428;D=0 1212121342121213421213421 01 212121342121213421213421 01 21212134212121342121342101212121342121213421213421012121213421212134212134210121243134212121342121342101252526742121213425213421012121213421212134212134210121212134212;CP=1;R=23;
						# rechteTaste: 0x112 (000100010010), linkeTaste: 0x111 (000100010001), the least significant bits distinguish the keys
						### remote control Novy 840029 for Novy Pureline 6830 kitchen hood:
						# https://github.com/RFD-FHEM/RFFHEM/issues/331
						# light on/off button  # MU;P0=710;P1=353;P2=-403;P4=-761;P6=-16071;D=20204161204120412041204120414141204120202041612041204120412041204141412041202020416120412041204120412041414120412020204161204120412041204120414141204120202041;CP=1;R=40;
						# plus button          # MU;P0=22808;P1=-24232;P2=701;P3=-765;P4=357;P5=-15970;P7=-406;D=012345472347234723472347234723454723472347234723472347234547234723472347234723472345472347234723472347234723454723472347234723472347234;CP=4;R=39;
						# minus button         # MU;P0=-8032;P1=364;P2=-398;P3=700;P4=-760;P5=-15980;D=0123412341234123412341412351234123412341234123414123512341234123412341234141235123412341234123412341412351234123412341234123414123;CP=1;R=40;
						# power button         # MU;P0=-756;P1=718;P2=354;P3=-395;P4=-16056;D=01020202310231310202 42 310231023102310231020202310231310202 42 31023102310231023102020231023131020242310231023102310231020202310231310202;CP=2;R=41;
						# novy button          # MU;P0=706;P1=-763;P2=370;P3=-405;P4=-15980;D=0123012301230304230123012301230123012303042;CP=2;R=42;
						### Neff Transmitter SF01 01319004 (SF01_01319004) 433,92 MHz
						# https://github.com/RFD-FHEM/RFFHEM/issues/376
						# MU;P0=-707;P1=332;P2=-376;P3=670;P5=-15243;D=01012301232323230123012301232301010123510123012323232301230123012323010101235101230123232323012301230123230101012351012301232323230123012301232301010123510123012323232301230123012323010101235101230123232323012301230123230101012351012301232323230123012301;CP=1;R=3;O;
						# MU;P0=-32001;P1=348;P2=-704;P3=-374;P4=664;P5=-15255;D=01213421343434342134213421343421213434512134213434343421342134213434212134345121342134343434213421342134342121343451213421343434342134213421343421213434512134213434343421342134213434212134345121342134343434213421342134342121343451213421343434342134213421;CP=1;R=15;O;
						# MU;P0=-32001;P1=326;P2=-721;P3=-385;P4=656;P5=-15267;D=01213421343434342134213421343421342134512134213434343421342134213434213421345121342134343434213421342134342134213451213421343434342134213421343421342134512134213434343421342134213434213421345121342134343434213421342134342134213451213421343434342134213421;CP=1;R=10;O;
						# MU;P0=-372;P1=330;P2=684;P3=-699;P4=-14178;D=010231020202023102310231020231310231413102310202020231023102310202313102314;CP=1;R=253;
						# MU;P0=-710;P1=329;P2=-388;P3=661;P4=-14766;D=01232301410123012323232301230123012323012323014;CP=1;R=1;
						### BOSCH Transmitter SF01 01319004 (SF01_01319004_Typ2) 433,92 MHz
						# MU;P0=706;P1=-160;P2=140;P3=-335;P4=-664;P5=385;P6=-15226;P7=248;D=01210103045303045453030304545453030454530653030453030454530303045454530304747306530304530304545303030454545303045453065303045303045453030304545453030454530653030453030454530303045454530304545306530304530304545303030454545303045453065303045303045453030304;CP=5;O;
						# MU;P0=-15222;P1=379;P2=-329;P3=712;P6=-661;D=30123236123236161232323616161232361232301232361232361612323236161612323612323012323612323616123232361616123236123230123236123236161232323616161232361232301232361232361612323236161612323612323012323612323616123232361616123236123230123236123236161232323616;CP=1;O;
						# MU;P0=705;P1=-140;P2=-336;P3=-667;P4=377;P5=-15230;P6=248;D=01020342020343420202034343420202020345420203420203434202020343434202020203654202034202034342020203434342020202034542020342020343420202034343420202020345420203420203434202020343434202020203454202034202034342020203434342020202034542020342020343420202034343;CP=4;O;
						# MU;P0=704;P1=-338;P2=-670;P3=378;P4=-15227;P5=244;D=01023231010102323231010102310431010231010232310101023232310101025104310102310102323101010232323101010231043101023101023231010102323231010102310431010231010232310101023232310101023104310102310102323101010232323101010231043101023101023231010102323231010102;CP=3;O;
						# MU;P0=-334;P1=709;P2=-152;P3=-663;P4=379;P5=-15226;P6=250;D=01210134010134340101013434340101340134540101340101343401010134343401013601365401013401013434010101343434010134013454010134010134340101013434340101340134540101340101343401010134343401013401345401013401013434010101343434010134013454010134010134340101013434;CP=4;O;
		{
			name					=> 'BOSCH | CAME | Novy | Neff | Refsta Topdraft',
			comment				=> 'remote control CAME TOP 432EV, Novy 840029, BOSCH / Neff or Refsta Topdraft SF01 01319004',
			changed				=> '20181024 new',
			id						=> '86',
			one						=> [-2,1],
			zero					=> [-1,2],
			start					=> [-44,1],
			clockabs			=> 350,
			clockpos			=> ['one',1],
			format				=> 'twostate',
			preamble			=> 'P86#',				# prepend to converted message
			clientmodule	=> 'SD_UT',
			#modulematch	=> '^P86#.*',
			length_min		=> '12',
			length_max		=> '18',
		},
	"87"	=>	## JAROLIFT Funkwandsender TDRC 16W / TDRCT 04W
						# https://github.com/RFD-FHEM/RFFHEM/issues/380
						# MS;P1=1524;P2=-413;P3=388;P4=-3970;P5=-815;P6=778;P7=-16024;D=34353535623562626262626235626262353562623535623562626235356235626262623562626262626262626262626262623535626235623535353535626262356262626262626267123232323232323232323232;CP=3;SP=4;R=226;O;m2;
						# MS;P0=-15967;P1=1530;P2=-450;P3=368;P4=-3977;P5=-835;P6=754;D=34353562623535623562623562356262626235353562623562623562626235353562623562626262626262626262626262623535626235623535353535626262356262626262626260123232323232323232323232;CP=3;SP=4;R=229;O;
						# KeeLoq is a registered trademark of Microchip Technology Inc.
						# sendMsg P87#000101100110110010010001101011100000000000000000011001011111000100000000P#R3
		{
			name					=> 'JAROLIFT',
			comment				=> 'remote control JAROLIFT TDRC_16W / TDRCT_04W',
			changed				=> '20181025 new',
			id				=> '87',
			one				=> [1,-2],
			zero				=> [2,-1],
			preSync				=> [3.8,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1],
			sync				=> [1,-10],				# this is a end marker, but we use this as a start marker
			pause				=> [-40],
			clockabs			=> 400,						# ca 400us
			reconstructBit			=> '1',
			developId			=> 'm',
			format				=> 'twostate',
			preamble			=> 'P87#',				# prepend to converted message	
			clientmodule	=> 'SD_Keeloq',
			#modulematch	=> '',
			length_min		=> '72',					# 72
			length_max		=> '85',					# 85
		},
	"88"	=>	## Roto Dachfensterrolladen | Aurel Fernbedienung "TX-nM-HCS" (HCS301 Chip) | three buttons -> up, stop, down
						# https://forum.fhem.de/index.php/topic,91244.0.html
						# MS;P1=361;P2=-435;P4=-4018;P5=-829;P6=759;P7=-16210;D=141562156215156262626215151562626215626215621562151515621562151515156262156262626215151562156215621515151515151562151515156262156215171212121212121212121212;CP=1;SP=4;R=66;O;m0;
						# MS;P0=-16052;P1=363;P2=-437;P3=-4001;P4=-829;P5=755;D=131452521452145252521452145252521414141452521452145214141414525252145252145252525214141452145214521414141414141452141414145252145252101212121212121212121212;CP=1;SP=3;R=51;O;m1;
						# Waeco_MA650_TX | too buttons
						# KeeLoq is a registered trademark of Microchip Technology Inc.
		{
			name				=> 'HCS300/HCS301',
			comment				=> 'remote controls Aurel TX-nM-HCS, enjoy motors HS, Rademacher RP-S1-HS-RF11, SCS Sentinel PR3-4207-002, Waeco MA650_TX',
			changed				=> '20181204 new',
			id				=> '88',
			knownFreqs		=> '433.92 | 868.35',
			one				=> [1,-2],
			zero				=> [2,-1],
			preSync				=> [1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1, 1,-1,],	# 11 pulses preambel, 1 sync, 66 data, pause ... repeat
			sync				=> [1,-10],				# this is a end marker, but we use this as a start marker
			pause         => [-39],         # Guard Time typ. 15.6 mS
			clockabs			=> 400,						# Basic pulse element typ. 0.4 mS (Timings from table CODE WORD TRANSMISSION TIMING REQUIREMENTS in PDF)
			reconstructBit			=> '1',
			developId			=> 'm',
			format				=> 'twostate',
			preamble			=> 'P88#',
			clientmodule	=> 'SD_Keeloq',
			#modulematch	=> '',
			length_min		=> '65',
			length_max		=> '78',
		},
	"89" => ## Funk Wetterstation TFA 35.1140.01 mit Temperatur-/Feuchtesensor TFA 30.3221.02 12/2018@Iron-R
					# https://github.com/RFD-FHEM/RFFHEM/issues/266
					# MU;P0=-900;P1=390;P2=-499;P3=-288;P4=193;P7=772;D=1213424213131342134242424213134242137070707013424213134242131342134242421342424213421342131342421313134213424242421313424213707070701342421313424213134213424242134242421342134213134242131313421342424242131342421;CP=4;R=43;
					# MU;P0=-491;P1=382;P2=-270;P3=179;P4=112;P5=778;P6=-878;D=01212304012123012303030123030301230123012303030121212301230301230121212121256565656123030121230301212301230303012303030123012301230303012121230123030123012121212125656565612303012123030121230123030301230303012301230123030301212123012303012301212121212565;CP=3;R=43;O;
					# MU;P0=-299;P1=384;P2=169;P3=-513;P5=761;P6=-915;D=01023232310101010101023565656561023231010232310102310232323102323231023231010232323101010102323231010101010102356565656102323101023231010231023232310232323102323101023232310101010232323101010101010235656565610232310102323101023102323231023232310232310102;CP=2;R=43;O;
					# MU;P0=-32001;P1=412;P2=-289;P3=173;P4=-529;P5=777;P6=-899;D=01234345656541212341234123434121212121234123412343412343456565656121212123434343434343412343412343434121234123412343412121212123412341234341234345656565612121212343434343434341234341234343412123412341234341212121212341234123434123434565656561212121234343;CP=3;R=22;O;
					# MU;P0=22960;P1=-893;P2=775;P3=409;P4=-296;P5=182;P6=-513;D=01212121343434345656565656565634565634565656343456563434565634343434345656565656565656342121212134343434565656565656563456563456565634345656343456563434343434565656565656565634212121213434343456565656565656345656345656563434565634345656343434343456565656;CP=5;R=22;O;
					# CH:2 T: 6.1 H: 66  MU;P0=172;P1=-533;P2=401;P3=-296;P5=773;P6=-895;D=01230101230101012323010101230123010101010101230101230101012323010101230123010301230101010101012301012301010123230101012301230101010123010101010101012301565656562323232301010101010101230101230101012323010101230123010101012301010101010101230156565656232323;CP=0;R=23;O;
		{
			name         => 'TFA 30.3221.02',
			comment      => 'temperature / humidity sensor for weatherstation TFA 35.1140.01',
			changed      => '20181209 new',
			id           => '89',
			one          => [2,-1],
			zero         => [1,-2],
			start        => [3,-3,3,-3,3,-3],
			start2       => [3,-3],
			starti       => [2,2,2],
			clockabs     => 250,
			clockpos     => ['zero',0],
			format       => 'twostate',
			preamble     => 'W89#',
			#postamble    => '',
			clientmodule => 'SD_WS',
			length_min   => '40',
			length_max   => '40',
		},
	"90"	=>	## mumbi m-FS300 / manax MX-RCS250 (CP 258-298)
						# https://forum.fhem.de/index.php/topic,94327.15.html
						# MS;P0=-9964;P1=273;P4=-866;P5=792;P6=-343;D=10145614141414565656561414561456561414141456565656561456141414145614;CP=1;SP=0;R=35;O;m2;		//A	AN
						# MS;P0=300;P1=-330;P2=-10160;P3=804;P7=-840;D=02073107070707313131310707310731310707070731313107310731070707070707;CP=0;SP=2;R=23;O;m1;	//A	AUS
						# MS;P1=260;P2=-873;P3=788;P4=-351;P6=-10157;D=16123412121212343434341212341234341212121234341234341234121212341212;CP=1;SP=6;R=21;O;m2;	//B	AN
						# MS;P1=268;P3=793;P4=-337;P6=-871;P7=-10159;D=17163416161616343434341616341634341616161634341616341634161616343416;CP=1;SP=7;R=24;O;m2;	//B	AUS
		{
			name         => 'mumbi | MANAX',
			comment      => 'remote control mumbi RC-10, MANAX MX-RCS250',
			changed      => '20181219 new',
			id           => '90',
			one          => [3,-1],
			zero         => [1,-3],
			sync         => [1,-36],
			clockabs     => 280,						# -1=auto	
			format       => 'twostate',
			preamble     => 'P90#',			
			length_min   => '33',
			length_max   => '36',
			clientmodule => 'SD_UT',
			#modulematch	=> '^P90#.*',
		},
	"91"	=>	## Atlantic Security / Focus Security China Devices
						# https://forum.fhem.de/index.php/topic,58397.msg876862.html#msg876862
						# MU;P0=800;P1=-813;P2=394;P3=-410;P4=-3992;D=0123030303030303012121230301212304230301212301230301212123012301212303012301230303030303030121212303012123042303012123012303012121230123012123030123012303030303030301212123030121230;CP=2;R=46;
						# MU;P0=406;P1=-402;P2=802;P3=-805;P4=-3994;D=012123012301212121212121230303012123030124012123030123012123030301230123030121230123012121212121212303030121230301240121230301230121230303012301230301212301230121212121212123030301212303012;CP=0;R=52;
						# MU;P0=14292;P1=-10684;P2=398;P3=-803;P4=-406;P5=806;P6=-4001;D=01232324532453232454532453245454532324545323232453245324562454532324532454532323245324532324545324532454545323245453232324532453245624545323245324545323232453245323245453245324545453232454532323245324532456245453232453245453232324532453232454532453245454;CP=2;R=50;O;
		{
			name					=> 'Atlantic security',
			comment				=> 'example sensor MD-210R | MD-2018R | MD-2003R (MU decode)',
			id			=> '91',
			changed			=> '20181228 new',
			knownFreqs		=> '433.92 | 868.35',
			one			=> [-2,1],
			zero			=> [-1,2],
			start			=> [-10,1],
			clockabs		=> 400,
			clockpos		=> ['zero',1],
			format			=> 'twostate',
			preamble		=> 'P91#',
			length_min		=> '35', # 36 - reconstructBit = 35
			length_max		=> '36',
			clientmodule	=> 'SD_UT',
			reconstructBit		=> '1',
		},
	"91.1"	=>	## Atlantic Security / Focus Security China Devices
						# https://forum.fhem.de/index.php/topic,58397.msg878008.html#msg878008
						# MS;P0=-399;P1=407;P2=820;P3=-816;P4=-4017;D=14131020231020202313131023131313131023102023131313131310202313131020202313;CP=1;SP=4;O;m0;
						# MS;P1=392;P2=-824;P3=-416;P4=804;P5=-4034;D=15121343421343434212121342121212121342134342121212121213434212121343434212;CP=1;SP=5;e;m2;
		{
			name			=> 'Atlantic security',
			comment			=> 'example sensor MD-210R | MD-2018R | MD-2003R (MS decode)',
			changed			=> '20181230 new',
			id			=> '91',
			knownFreqs		=> '433.92 | 868.35',
			one			=> [-2,1],
			zero			=> [-1,2],
			sync			=> [-10,1],
			clockabs		=> 400,
			reconstructBit		=> '1',
			format			=> 'twostate',
			preamble		=> 'P91#',			# prepend to converted message
			length_min		=> '32',
			length_max		=> '36',
			clientmodule	=> 'SD_UT',
		},
	"92"	=>	## KRINNER Lumix - LED X-MAS
						# https://github.com/RFD-FHEM/RFFHEM/issues/452 | https://forum.fhem.de/index.php/topic,94873.msg876477.html?PHPSESSID=khp4ja64pcqa5gsf6gb63l1es5#msg876477
						# MU;P0=24188;P1=-16308;P2=993;P3=-402;P4=416;P5=-967;P6=-10162;D=0123234545454523234523234545454545454545232623452345454545454523234523234545454523234523234545454545454545232623452345454545454523234523234545454523234523234545454545454545232623452345454545454523234523234545454523234523234545454545454545232;CP=4;R=25;
						# MU;P0=11076;P1=-20524;P2=281;P3=-980;P4=982;P5=-411;P6=408;P7=-10156;D=0123232345456345456363636363636363634745634563636363636345456345456363636345456345456363636363636363634745634563636363636345456345456363636345456345456363636363636363634745634563636363636345456345456363636345456345456363636363636363634;CP=6;R=38;
		{
			name			=> 'KRINNER Lumix',
			comment			=> 'remote control LED X-MAS',
			changed			=> '20181228 new',
			id			=> '92',
			zero			=> [1,-2],
			one			=> [2,-1],
			start			=> [2,-24],
			clockabs		=> 420,
			clockpos		=> ['zero',1],
			format			=> 'twostate',	#
			preamble		=> 'P92#',			# prepend to converted message
			length_min		=> '32',
			length_max		=> '32',
			clientmodule	=> 'SD_UT',
			#modulematch	=> '^P92#.*',
		},
		"93"	=>	## ESTO Lighting GmbH | remote control KL-RF01 with 9 buttons (CP 375-395)
							# https://github.com/RFD-FHEM/RFFHEM/issues/449 @daniel89fhem 
							# light_color_cold_white   MS;P1=376;P4=-1200;P5=1170;P6=-409;P7=-12224;D=17141414561456561456565656145656141414145614141414565656145656565614;CP=1;SP=7;R=231;e;m0; 
							# dimup                    MS;P1=393;P2=-1174;P4=1180;P5=-401;P6=-12222;D=16121212451245451245454545124545124545451212121212121212454545454512;CP=1;SP=6;R=243;e;m0;
							# dimdown                  MS;P0=397;P1=-385;P2=-1178;P3=1191;P4=-12230;D=04020202310231310231313131023131023131020202020202020231313131313102;CP=0;SP=4;R=250;e;m0;
			{
			name         => 'ESTO Lighting GmbH',
			comment      => 'remote control KL-RF01',
			changed      => '20181229 new',
			id           => '93',
			one          => [3,-1],
			zero         => [1,-3],
			sync         => [1,-32],
			clockabs     => 385,						# -1=auto	
			format       => 'twostate',
			preamble     => 'P93#',
			length_min   => '32',           # 2. MSG:	32 Bit, bleibt so
			length_max   => '36',           # 1. MSG: 33 Bit, wird verlaengert auf 36 Bit
			clientmodule	=> 'SD_UT',
			#modulematch	=> '^P93#.*',
		},
		"94"	=>	# Atech wireless weather station (vermutlicher Name: WS-308)
							# https://github.com/RFD-FHEM/RFFHEM/issues/547 @Kreidler1221 2019-03-15
							# Sensor sends Bit 0 as "0", Bit 1 as "110"
							# Id:0C T:-14.6 MU;P0=-32001;P1=1525;P2=-303;P3=-7612;P4=-2008;D=01212121212121213141414141212141212141414141412121414141414121214141212141414141212141212141412121412121414121214121;CP=1;
							# Id:0C T:-0.4  MU;P0=-32001;P1=1533;P2=-297;P3=-7612;P4=-2005;D=0121212121212121314141414121214121214141414141212141414141414141414141412121414141212141412121414121;CP=1;
							# Id:0C T:0.2   MU;P0=-32001;P1=1532;P2=-299;P3=-7608;P4=-2005;D=0121212121212121314141414121214121214141414141414141414141414141414141212141412121412121412121414121;CP=1;
							# Id:0C T:10.2  MU;P0=-31292;P1=1529;P2=-300;P3=-7610;P4=-2009;D=012121212121212131414141412121412121414141414141414141412121414141414141412121414121214121214121214121214121012121212121212131414141412121412121414141414141414141412121414141414141412121414121214121214121214121214121;CP=1;
							# Id:0C T:27    MU;P0=-31290;P1=1533;P2=-297;P3=-7608;P4=-2006;D=012121212121212131414141412121412121414141414141414141212141414121214121214121214141414141212141414121214121012121212121212131414141412121412121414141414141414141212141414121214121214121214141414141212141414121214121;CP=1;
			{
				name				=> 'Atech',
				comment				=> 'Temperature sensor',
				changed				=> '20190318 new',
				id				=> '94',
				one				=> [5.3,-1],     # 1537, 290
				zero				=> [5.3,-6.9],   # 1537, 2001
				start				=> [5.3,-26.1],  # 1537, 7569
				clockabs			=> 290,
				clockpos			=> ['cp'],
				#reconstructBit		=> '1',		# funktioniert hier nicht da alle Paare gleich anfangen
				format				=> 'twostate',
				preamble			=> 'W94#',
				clientmodule		=> 'SD_WS',
				length_min			=> '24',         # minimal 24*0=24 Bit, kuerzeste bekannte aus Userlog: 36
				length_max			=> '96',         # maximal 24*110=96 Bit, laengste bekannte aus Userlog:  60
			},
		"95"	=>	# Techmar / Garden Lights Fernbedienung, 6148011 Remote control + 12V Outdoor receiver
							# https://github.com/RFD-FHEM/RFFHEM/issues/558 @BlackcatSandy
							# Group_1_on:  MU;P0=-972;P1=526;P2=-335;P3=-666;D=01213131312131313121212121312121313131313121312131313121313131312121212121312121313131313121313121212101213131312131313121212121312121313131313121312131313121313131312121212121312121313131313121313121212101213131312131313121212121312121313131313121312131;CP=1;R=44;O;
							# Group_5_on:  MU;P0=-651;P1=530;P2=-345;P3=-969;D=01212121312101010121010101212121210121210101010101210121010101210101010121212121012121210101010121010101212101312101010121010101212121210121210101010101210121010101210101010121212121012121210101010121010101212121312101010121010101212121210121210101010101;CP=1;R=24;O;
							# Group_8_off: MU;P0=538;P1=-329;P2=-653;P3=-964;D=01020301020202010202020101010102010102020202020102010202020102020202010101010101010201020202020202010202010301020202010202020101010102010102020202020102010202020102020202010101010101010201020202020202010201010301020202010202020101010102010102020202020102;CP=0;R=19;O;
							# bei den Wiederholungen sind die letzten 2 Bit unterschiedlich
			{
				name				=> 'Techmar',
				comment				=> 'Garden Lights remote control',
				changed				=> '20190331 new',
				id				=> '95',
				one				=> [1,-1.2],	# 550,-660
				zero				=> [1,-0.6],	# 550,-330
				start				=> [1,-1.8],	# 550,-990
				clockabs			=> 550,
				clockpos			=> ['cp'],
				#developId			=> 'y',
				format				=> 'twostate',
				preamble			=> 'P95#',
				clientmodule		=> 'SD_UT',
				#modulematch		=> '',
				length_min			=> '50',
				length_max			=> '50',
			},
		"96"	=>	# Funk-Gong | Taster Grothe Mistral SE 03.1 / 01.1, Innenteil Grothe Mistral 200M(E)
							# https://forum.fhem.de/index.php/topic,64251.msg940593.html?PHPSESSID=nufcvvjobdd8r7rgr0cq3qkrv0#msg940593 @coolheizer
							# SD_BELL_104762 Alarm        MC;LL=-430;LH=418;SL=-216;SH=226;D=23C823B1401F8;C=214;L=49;R=53;
							# SD_BELL_104762 ring         MC;LL=-439;LH=419;SL=-221;SH=212;D=238823B1001F8;C=215;L=49;R=69;
							# SD_BELL_104762 ring low bat MC;LL=-433;LH=424;SL=-214;SH=210;D=238823B100248;C=213;L=49;R=65;
							# SD_BELL_0253B3 Alarm        MC;LL=-407;LH=451;SL=-195;SH=239;D=23C129D9E78;C=215;L=41;R=241;
							# SD_BELL_0253B3 ring         MC;LL=-412;LH=458;SL=-187;SH=240;D=238129D9A78;C=216;L=41;R=241;
							# SD_BELL_024DB5 Alarm        MC;LL=-415;LH=454;SL=-200;SH=226;D=23C126DAE58;C=215;L=41;R=246;
							# SD_BELL_024DB5 ring         MC;LL=-409;LH=448;SL=-172;SH=262;D=238126DAA58;C=215;L=41;R=238;
			{
				name            => 'Grothe Mistral SE',
				comment         => 'Wireless doorbell Grothe Mistral SE 01.1 or 03.1',
				changed         => '20190518 new',
				id              => '96',
				knownFreqs      => '868.35',
				clockrange      => [170,260],
				format          => 'manchester',
				clientmodule    => 'SD_BELL',
				modulematch     => '^P96#',
				preamble        => 'P96#',
				length_min      => '40',
				length_max      => '49',
				method          => \&main::SIGNALduino_GROTHE,		# Call to process this message
			},
		"97"	=>	# Momento, remote control for wireless digital picture frame - elektron-bbs 2020-03-21
							# Short press repeatedly message 3 times, long press repeatedly until release.
							# When sending, the original message is not reproduced, but the recipient also reacts to the messages generated in this way.
							# Momento_0000064 play/pause MU;P0=-294;P1=237;P2=5829;P3=-3887;P4=1001;P5=-523;P6=504;P7=-995;D=01010101010101010101010234545454545454545454545454545454545454545456767454567454545456745456745456745454523454545454545454545454545454545454545454545676745456745454545674545674545674545452345454545454545454545454545454545454545454567674545674545454567454;CP=4;R=45;O; 
							# Momento_0000064 power      MU;P0=-998;P1=-273;P2=256;P3=5830;P4=-3906;P5=991;P6=-527;P7=508;D=12121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121345656565656565656565656565656565656565656567070565670565656565670567056565670707034565656565656565656565656565656565656565656707056567;CP=2;R=40;O;
							# Momento_0000064 up         MU;P0=-1005;P1=-272;P2=258;P3=5856;P4=-3902;P5=1001;P6=-520;P7=508;D=0121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121213456565656565656565656565656565656565656565670705656705656567056565670565670567056345656565656565656565656565656565656565656567070565;CP=2;R=63;O;
			{
				name            => 'Momento',
				comment         => 'Remote control for wireless digital picture frame',
				changed         => '20200330 new',
				id              => '97',
				one             => [2,-4],		# 500, -1000
				zero            => [4,-2],		# 1000, -500
				start           => [23,-15],	# 5750, -3750
				clockabs        => 250,
				clockpos        => ['one',0],
				format          => 'twostate',
				preamble        => 'P97#',
				clientmodule    => 'SD_UT',
				length_min      => '40',
				length_max      => '40',
			},
		"98"	=>	# Funk-Tuer-Gong: Modell GEA-028DB, Ningbo Rui Xiang Electrical Co.,Ltd., Vertrieb durch Walter Werkzeuge Salzburg GmbH, Art. Nr. K612021A
							# https://forum.fhem.de/index.php/topic,109952.0.html 2020-04-12
							# SD_BELL_6A2C   MU;P0=1488;P1=-585;P2=520;P3=-1509;P4=1949;P5=-5468;CP=2;R=38;D=01232301230123010101230123230101454501232301230123010101230123230101454501232301230123010101230123230101454501232301230123010101230123230101454501232301230123010101230123230101454501232301230123010101230123230101454501232301230123010101230123230101454501;O;
							# SD_BELL_6A2C   MU;P0=-296;P1=-1542;P2=1428;P3=-665;P4=483;P5=1927;P6=-5495;P7=92;CP=4;R=31;D=1234141232356562341412341234123232341234141232356562341412341234123232341234141232356562341412341234123232341234141232356562341412341234123232341234141232356562341412341234123232341234141232356562341412341234123232341234141232370;e;i;
			{
				name            => 'GEA-028DB',
				comment         => 'Wireless doorbell',
				changed         => '20200412 new',
				id              => '98',
				one             => [1,-2.9],
				zero            => [2.8,-1.1],
				start           => [3.7,-10.5],
				end             => [3.7,-10.5],
				clockabs        => 520,
				clockpos        => ['one',0],
				format          => 'twostate',
				clientmodule    => 'SD_BELL',
				modulematch     => '^P98#',
				preamble        => 'P98#',
				length_min      => '16',
				length_max      => '16',
			},
		"99"	=>	# NAVARIS touch light switch Model No.: 44344.04
							# https://github.com/RFD-FHEM/RFFHEM/issues/828
							# Navaris_211073   MU;P0=-302;P1=180;P2=294;P3=-208;P4=419;P5=-423;D=01023101010101023232310102323451010231010101023101010231010101010232323101023234510102310101010231010102310101010102323231010232345101023101010102310101023101010101023232310102323451010231010101023101010231010101010232323101023234510102310101010231010102;CP=1;R=36;O;
							# Navaris_13F8E3   MU;P0=406;P1=-294;P2=176;P3=286;P4=-191;P6=-415;D=01212134212134343434343434212121343434212121343406212121342121343434343434342121213434342121213434062121213421213434343434343421212134343421212134340621212134212134343434343434212121343434212121343406212121342121343434343434342121213434342121213434062121;CP=2;R=67;O;
			{
				name            => 'Navaris 44344.04',
				comment         => 'Wireless touch light switch',
				changed         => '20200421 new',
				id              => '99',
				one             => [1.6,-1],
				zero            => [1,-1.6],
				start           => [2.1,-2.1],
				clockabs        => 190,
				clockpos        => ['zero',0],
				format          => 'twostate',
				clientmodule    => 'SD_UT',
				modulematch     => '^P99#',
				preamble        => 'P99#',
				length_min      => '24',
				length_max      => '24',
			},
		"100"	=>	# Lacrosse, Mode 1 - IT+
					# MN;D=91C635424AAAAA0000B32587;R=41;
					# MN;D=97C589508DAAAA00003124C8;R=204;
					# MN;D=91C6323F50AAAA000065796B;R=39;  T: 23.2 H: 63  OK 9 7 1 4 208 63
			{
				name            => 'Lacrosse mode 1',
				changed         => '20200104 new',
				id              => '100',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'LaCrosse',
				length_min      => '10',     # 5 Byte
				method        => \&main::SIGNALduino_LaCrosse,
			},
		"101"	=>	# PCA 301
					# https://wiki.fhem.de/wiki/PCA301_Funkschaltsteckdose_mit_Energieverbrauchsmessung
					# MN;D=020503B7A100AAAAAAAA54D5AA18590B66A88797465D50AED898482A1E80E8CC;N=3;R=252;  addr: 03B7A1 state: on channel: 2
					# MN;D=020403B7A10101A7000031ECAAA9615CF878C1E17E3CDF4882A8D0045204CB0D;N=3;R=252;  addr: 03B7A1 state: on channel: 2 power: 42.3 statusRequest
			{
				name            => 'PCA 301',
				comment         => 'Energy socket',
				changed         => '20200124 new',
				id              => '101',
				knownFreqs      => '868.950',
				dispatchequals	=>  'true',
				N               => [3],
				datarate        => '6620.41',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				#match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'PCA301',
				length_min      => '24',      # 12 Byte 
				method        => \&main::SIGNALduino_PCA301,
			},
		"102"	=>	# Kopp
			{
				name            => 'KoppFreeControl',
				changed         => '20200104 new',
				id              => '102',
				knownFreqs      => '868.3',
				N               => [4],
				datarate        => '4785.5',
				sync            => 'AA54',
				modulation      => 'GFSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^0.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'KOPP_FC',
				method        => \&main::SIGNALduino_KoppFreeControl,
			},
		"103"	=>	# Lacrosse mode 2 - IT+
					# https://forum.fhem.de/index.php/topic,106278.msg1048506.html#msg1048506 @Ralf9
					# ID=103, addr=40 temp=19.2 hum=47 bat=0 batInserted=0   MN;D=9A05922F8180046818480800;N=2;
					# https://forum.fhem.de/index.php/topic,106594.msg1034378.html#msg1034378 @Ralf9
					# ID=103, addr=52 temp=21.5 hum=47 bat=0 batInserted=0   MN;D=9D06152F5484791062004090;N=2;
			{
				name            => 'Lacrosse mode 2',
				changed         => '20200228 new',
				id              => '103',
				knownFreqs      => '868.3',
				N               => [2],
				datarate        => '9.579',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'LaCrosse',
				length_min      => '10',     # 5 Byte
				method        => \&main::SIGNALduino_LaCrosse,
			},
		"104"	=>	# Remote control TR60C-1 with touch screen from Satellite Electronic (Zhongshan) Ltd., Importer Westinghouse Lighting for ceiling fan Bendan
							# https://forum.fhem.de/index.php?topic=53282.msg1045428#msg1045428 phoenix-anasazi 2020-04-21
							# TR60C1_0 light_off_fan_off  MU;P0=18280;P1=-737;P2=419;P3=-331;P4=799;P5=-9574;P6=-7080;D=012121234343434341212121212121252121212123434343434121212121212125212121212343434343412121212121212521212121234343434341212121212121252121212123434343434121212121212126;CP=2;R=2;
							# TR60C1_9 light_off_fan_4    MU;P0=14896;P1=-751;P2=394;P3=-370;P4=768;P5=-9572;P6=-21472;D=0121234123434343412121212121212523412123412343434341212121212121252341212341234343434121212121212125234121234123434343412121212121212523412123412343434341212121212121252341212341234343434121212121212126;CP=2;R=4;
							# TR60C1_B light_on_fan_2     MU;P0=-96;P1=152;P2=-753;P3=389;P4=-374;P5=769;P6=-9566;P7=-19920;D=012345454523232345454545634523454523234545452323234545454563452345452323454545232323454545456345234545232345454523232345454545634523454523234545452323234545454563452345452323454545232323454545457;CP=3;R=1;
							# https://github.com/RFD-FHEM/RFFHEM/issues/842
			{
				name            => 'TR60C-1',
				comment         => 'Remote control for example Westinghouse Bendan 77841B',
				changed         => '20200422 new',
				id              => '104',
				one             => [-1,2],  #  -380,760
				zero            => [-2,1],  #  -760,380
				start           => [-25,1], # -9500,380
				clockabs        => 380,
				clockpos        => ['zero',1],
				format          => 'twostate',
				clientmodule    => 'SD_UT',
				modulematch     => '^P104#',
				preamble        => 'P104#',
				length_min      => '16',
				length_max      => '16',
			},
		"105"	=>	# Remote control BF-301 (Roller shade system) from Shenzhen BOFU Mechanic & Electronic Co., Ltd.
							# Protocol description found on https://github.com/akirjavainen/markisol/blob/master/Markisol.ino
							# original remotes repeat 8 (multi) or 10 (single) times by default
							# https://github.com/RFD-FHEM/RFFHEM/issues/861 stsirakidis 2020-06-27
							# BF_301_FAD0 down   MU;P0=-697;P1=5629;P2=291;P3=3952;P4=-2459;P5=1644;P6=-298;P7=689;D=34567676767676207620767620762020202076202020762020207620202020207676762076202020767614567676767676207620767620762020202076202020762020207620202020207676762076202020767614567676767676207620767620762020202076202020762020207620202020207676762076202020767614;CP=2;R=41;O;
							# BF_301_FAD0 stop   MU;P0=5630;P1=3968;P2=-2458;P3=1642;P4=-285;P5=690;P6=282;P7=-704;D=12345454545454675467545467546767676754676767546754675467676767675454546754676767675402345454545454675467545467546767676754676767546754675467676767675454546754676767675402345454545454675467545467546767676754676767546754675467676767675454546754676767675402;CP=6;R=47;O;
							# BF_301_FAD0 up     MU;P0=-500;P1=5553;P2=-2462;P3=1644;P4=-299;P5=679;P6=298;P7=-687;D=01234545454545467546754546754676767675467676767675454546767676767545454675467546767671234545454545467546754546754676767675467676767675454546767676767545454675467546767671234545454545467546754546754676767675467676767675454546767676767545454675467546767671;CP=6;R=48;O;
			{
				name            => 'BF-301',
				comment         => 'Remote control, markisol',
				changed         => '20200704 new',
				id              => '105',
				one             => [2,-1],       # 660,-330
				zero            => [1,-2],       # 330,-660
				start           => [17,-7,5,-1], # 5610,-2310,1650,-330
				clockabs        => 330,
				clockpos        => ['zero',0],
				format          => 'twostate',
				clientmodule    => 'SD_UT',
				modulematch     => '^P105#',
				preamble        => 'P105#',
				length_min      => '40',
				length_max      => '40',
			},
		"106"	=>  ## BBQ temperature sensor GT-TMBBQ-01s (Sender), GT-TMBBQ-01e (Empfaenger)
				# https://forum.fhem.de/index.php/topic,114437.0.html KoelnSolar 2020-09-23
				# https://github.com/RFD-FHEM/RFFHEM/issues/892 Ralf9 2020-09-24
				# SD_WS_106_T  T: 22.6  MS;P0=525;P1=-2051;P3=-8905;P4=-4062;D=0301010401010404010101040401010401040401040404;CP=0;SP=3;R=35;e;b=2;m0;
				# SD_WS_106_T  T: 88.1  MS;P1=-8514;P2=488;P3=-4075;P4=-2068;D=2123242423232423242423242324232323232423242324;CP=2;SP=1;R=31;e;b=70;s=4;m0;
				# SD_WS_106_T  T: 97.8  MS;P1=-9144;P2=469;P3=-4101;P4=-2099;D=2123242423232423242423242323232423242423242424;CP=2;SP=1;R=58;O;b=70;s=4;m0;
				# Sensor sends every 5 seconds 1 message.
			{
				name            => 'GT-TMBBQ-01',
				comment         => 'BBQ temperature sensor',
				changed         => '20200923 new',
				id              => '106',
				one             => [1,-8],  # 500,-4000
				zero            => [1,-4],  # 500,-2000
				sync            => [1,-18], # 500,-9000
				clockabs        => 500,
				format          => 'twostate',
				preamble        => 'W106#',
				clientmodule    => 'SD_WS',
				#modulematch    => '',
				length_min      => '22',
				length_max      => '22',
			},
		"107"	=>	# Fine Offset WH51, ECOWITT WH51, MISOL/1 Soil Moisture Sensor Use with FSK
				# https://forum.fhem.de/index.php/topic,109056.0.html
				# H: 31 Bv: 1.6 ad: 186 id: 00C6BF MN;D=5100C6BF107F1FF8BAFFFFFF75A818CC;N=6;
				# H: 12 Bv: 1.3 ad: 112 id: 010310 MN;D=51010310ED7F0C007000000086D3204D;N=16;R=58;
			{
				name            => 'WH51 DP100',
				comment         => 'DP100, Fine Offset WH51, ECOWITT WH51, MISOL/1 Soil Moisture Sensor',
				changed         => '20201005 new',
				id              => '107',
				knownFreqs      => '433.92 | 868.37',
				N               => [6,16],
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^51.*',  # Family code 0x51 (ECOWITT/FineOffset WH51)
				preamble        => 'W107#',
				clientmodule    => 'SD_WS',
				length_min      => '28',  # 14 Byte
				method          => \&main::SIGNALduino_FSK_default,
			},
		"108"	=>  # BRESSER 5-in-1 Wetter Center
				# https://forum.fhem.de/index.php/topic,78809.0.html
				# T: 6.3  H: 70 Ws: 1 Wg: 0.8 Wd: SSW R: 31.2  MN;D=E9837FF76FEFEF9CFF8FEDFCFF167C80089010106300701203000002;N=7;R=215;  W108#7C8008901010630070120300
				# T: 12.7 H: 46 Ws: 1 Wg: 2 Wd: NW R: 7.6      MN;D=E5837FEB1FEFEFD8FEB989FFFF1A7C8014E010102701467600000002;N=7;R=215;  W108#7C8014E01010270146760000
				# T: 16   R: 102 id: CD  SD_WS_108_R           MN;D=EB3246FFFFFFEF9FFE96F7FBFF14CDB9000000106001690804000007;N=7;R=220;  W108#CDB900000010600169080400
				# https://forum.fhem.de/index.php/topic,124165.0.html
				# T: 23.2 H: 38  id: 83  SD_WS_108_TH Fody_E42 MN;D=EF7C6CF7FFFFFFCDEDC7FFFFFF108393080000003212380000000009;N=7;R=1;    W108#839308000000321238000000
				{
				name            => 'Bresser 5in1',
				comment         => 'BRESSER 5-in-1 weather center, rain gauge, Fody_E42',
				changed         => '20210422 new',
				id              => '108',
				knownFreqs      => '868.35',
				N               => [7],
				datarate        => '8220',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				#match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W108#',
				clientmodule    => 'SD_WS',
				length_min      => '52',      # 26 Byte
				method          => \&main::SIGNALduino_Bresser_5in1,
			},
		"109" =>  ## Rojaflex HSR-1, HSR-5, HSR-15, HSTR-5, HSTR-15, RHSM1
			# only tested remote control HSR-15
			# https://github.com/RFD-FHEM/RFFHEM/issues/955 - Hofyyy 2021-04-18
			# SD_Rojaflex_3122FD_9 down   MN;D=083122FD298A018A8E;N=8;R=0;
			# SD_Rojaflex_3122FD_9 stop   MN;D=083122FD290A010A8E;N=8;R=244;
			# SD_Rojaflex_3122FD_9 up     MN;D=083122FD291A011AAE;N=8;R=249;
			{
				name            => 'Rojaflex',
				comment         => 'Rojaflex shutter',
				changed         => '20210504 new',
				id              => '109',
				knownFreqs      => '433.92',
				N               => [8],
				datarate        => '9992.60',
				sync            => 'D391D391',
				modulation      => 'GFSK',
				regexMatch      => '^08',
				cc1101FIFOmode  => '1',     # use FIFOs for RX and TX
				preamble        => 'P109#',
				clientmodule    => 'SD_Rojaflex',
				length_min      => '18',    # 9 Byte
				#length_max      => '18',
				method          => \&main::SIGNALduino_FSK_default,
			},
		"110" =>  # ADE WS1907 Wetterstation mit Funk-Regenmesser
			# https://github.com/RFD-FHEM/RFFHEM/issues/965 docolli 2021-05-14
			# T: 16.3 R: 26.6   MU;P0=970;P1=-112;P2=516;P3=-984;P4=2577;P5=-2692;P6=7350;D=01234343450503450503434343434505034343434343434343434343434343434505050503450345034343434343450345050345034505034503456503434505050343434343450503450503434343434505034343434343434343434343434343434505050503450345034343434343450345050345034505034503456503;CP=0;R=12;O;
			# T: 12.6 R: 80.8   MU;P0=7344;P1=384;P2=-31380;P3=272;P4=-972;P5=2581;P6=-2689;P7=990;D=12345454545676745676745454545456745454545456767676745454545454545676767456745456767674545454545674567674545456745454545606745456767674545454545676745676745454545456745454545456767676745454545454545676767456745456767674545454545674567674545456745454545606;CP=7;R=19;O;
			# T: 11.8 R: 82.1   MU;P0=-5332;P1=6864;P2=-2678;P3=994;P4=-977;P5=2693;D=01234545232323454545454523234523234545454545234545454523452345232345454545454523232345452323454545454545454523452323454545452323454521234545232323454545454523234523234545454545234545454523452345232345454545454523232345452323454545454545454523452323454545;CP=3;R=248;O;
			# The sensor sends about every 45 seconds.
			{
				name            => 'ADE_WS_1907',
				comment         => 'Weather station with rain gauge',
				changed         => '20210522 new',
				id              => '110',
				one             => [-3,1], # 2700,-900
				zero            => [-1,3], # -900,2700
				start           => [8],    # 7200
				clockabs        => 900,
				clockpos        => ['one',1],
				format          => 'twostate',
				clientmodule    => 'SD_WS',
				#modulematch    => '^W110#',
				preamble        => 'W110#',
				reconstructBit  => '1',
				length_min      => '65',
				length_max      => '66',
			},
		"111" =>  # Water Tank Level Monitor TS-FT002
			# https://github.com/RFD-FHEM/RFFHEM/issues/977 docolli 2021-06-05
			# T: 16.8 D: 111   MU;P0=-21110;P1=484;P2=-971;P3=-488;D=01213121212121213121312121312121213131312131313131212131313131312121212131313121313131213131313121213131312131313131313131313131212131312131312101213121212121213121312121312121213131312131313131212131313131312121212131313121313131213131313121213131312131;CP=1;R=26;O;
			# T: 17.7 D: 111   MU;P0=-3508;P1=500;P2=-480;P3=-961;P4=-22648;CP=1;R=26;D=0121313131313121312131312131313121212131212121213131212121212131313131212121313121212121212121212131212131212121212121212121213121313131212131413121313131313121312131312131313121212131212121213131212121212131313131212121313121212121212121212131212131212121212121212121213121313131212131;
			# The sensor sends normally every 180 seconds
			{
				name            => 'TS-FT002',
				comment         => 'Water tank level monitor with temperature',
				changed         => '20210606 new',
				id              => '111',
				one             => [1,-2], # 480,-960
				zero            => [1,-1], # 480,-480
				start           => [1,-1, 1,-2, 1,-2, 1,-2, 1,-2, 1,-2], # Sync 01 1111 (0x5F 0101 1111)
				starti          => [0,1, 1,1,1,1],
				clockabs        => 480,
				clockpos        => ['cp'],
				format          => 'twostate',
				clientmodule    => 'SD_WS',
				#modulematch     => '^W111#',
				preamble        => 'W111#5F',
				length_min      => '64',
				length_max      => '64',
			},
		"112" =>  ## AVANTEK DB-LE
			# Wireless doorbell & LED night light
			# Sample: 20 Microseconds | 3 Repeats with ca. 1,57ms Pause
			# A7129 -> FSK/GFSK Sub 1GHz Transceiver
			#
			#       PPPPPSSSSDDDDDDDDDD
			#       |    |   |--------> Data
			#       |    ||||---------> Sync
			#       |||||-------------> Preambel
			#
			# URH:  aaaaa843484608a4224
			# FHEM: MN;D=08C114844FDA5CA2;N=9;R=48;
			#       MN;D=08C11484435D873B;N=9;R=47;
			# !!! receiver hardware is required to complete in SD_BELL module !!!
			{
				name            => 'Avantek',
				comment         => 'Wireless doorbell & LED night light',
				changed         => '20210607 new',
				id              => '112',
				knownFreqs      => '433.3',
				N               => [9],
				datarate        => '50.087',
				sync            => '0869',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				preamble        => 'P112#',
				clientmodule    => 'SD_BELL',
				length_min      => '9',
				method          => \&main::SIGNALduino_FSK_default,
			},
		"113" =>  ## Wireless Grill Thermometer, Model name: GFGT 433 B1, WDJ7036, FCC ID: 2AJ9O-GFGT433B1, 
			# https://github.com/RFD-FHEM/RFFHEM/issues/992 @ muede-de 2021-07-13
			# The sensor sends more than 12 messages every 2 seconds.
			# T: 201 T2: 257  MS;P2=-754;P3=247;P5=-2996;P6=718;P7=-272;D=35323267326767676732323232326767326767673232326767326732326732323267673267323232673232323232326732;CP=3;SP=5;R=3;O;m2;
			{
				name            => 'GFGT_433_B1',
				comment         => 'Wireless Grill Thermometer',
				changed         => '20210713 new',
				id              => '113',
				one             => [3,-1],  # 750,-250
				zero            => [1,-3],  # 250,-750
				sync            => [1,-12], # 250,-3000
				clockabs        => 250,
				format          => 'twostate',
				preamble        => 'W113#',
				clientmodule    => 'SD_WS',
				#modulematch     => '^W113#',
				reconstructBit   => '1',
				length_min      => '47',
				length_max      => '48',
			},
		"114"	=>	# Well-Light TR401
			# https://forum.fhem.de/index.php/topic,121103.0.html
			# P114#B1F TR401_0_2 off MU;P0=1264;P1=-782;P3=-1561;P4=566;P5=-23639;P7=-425;CP=4;R=239;D=701010103434343434543410343410101034343434345434103434101010343434343454341034341010103434343434543410343410101034343434345434103434101010343434343454341034341010103434343434543;e;
			# P114#31F TR401_0_2 on  MU;P0=-1426;P1=599;P2=-23225;P3=-748;P4=1281;P5=372;P6=111;P7=268;CP=1;R=235;D=0121343401013434340101010101252621343401013434340101010101252705012134340101343434010101010125;p;
			{
				name            => 'Well-Light',
				comment         => 'remote control TR401',
				changed         => '20210516 new',
				id              => '114',
				one             => [-2.6,1],
				zero            => [-1.4 ,2.2],
				start           => [-41,1],
				clockabs        => 570,
				clockpos        => ['one',1],
				format          => 'twostate',
				preamble        => 'P114#',
				clientmodule    => 'SD_UT',
				#modulematch     => '',
				length_min      => '12',
				length_max      => '12',
			},
		"115" =>  ## BRESSER 6-in-1 Weather Center, Bresser new 5-in-1 sensors 7002550
			# https://github.com/RFD-FHEM/RFFHEM/issues/607
			# https://forum.fhem.de/index.php/topic,78809.0.html
			# The sensor alternately sends two different messages every 12 seconds
			# T: 24.7 H: 65 Ws: 0 Wg: 0 Wd: SSW MN;D=C56620B00C1618FFFFFF2028247265FFF0C60000000000000000004B;N=7;R=34;
			# Ws: 1.9 Wg: 2.2 Wd: SSE R: 3.6    MN;D=F07D20B00C1618FDD6FE1588FFFFC9FF01C000000000000000000200;N=7;R=230;
			#
			# T: 21.2 H: 63 CH: 1 indoor         MN;D=6CD6197005FD2900000000002126630000A1FFFF07000000000000000000;N=7;R=28;
			# T: 25.2 H: 99 CH: 7 Soil Moisture  MN;D=F16E187000E347FFFFFF0000252216FFF004000;N=7;R=242;
			# T: 27.5 CH: 7 Pool Thermometer     MN;D=1B3F22C000B43F00000000002756000000ADFFFF0700000000000000;N=7;R=215;
			{
				name            => 'Bresser comfort 6in1 (5in1 neu)',
				comment         => 'BRESSER 6-in-1 and 5-in-1 new comfort weather center',
				changed         => '20210730 new',
				id              => '115',
				knownFreqs      => '868.35',
				N               => [7],
				datarate        => '8220',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				#match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W115#',
				clientmodule    => 'SD_WS',
				length_min      => '36',      # 18 Byte
				method          => \&main::SIGNALduino_Bresser_5in1_neu,
			},
		"116"	=>	# Fine Offset/ECOWITT/MISOL WH57, froggit DP60
				# https://forum.fhem.de/index.php/topic,122527
				# MN;D=5700C655053F00DF95A0026CA23745A3;N=16;R=68;
				# MN;D=5740C655053F02CBC3A0A7F1C30C3964;N=16;R=57;
				# MN;D=5780C655050A03A5A9E0A7CC404F8E81;N=16;R=52;
			{
				name            => 'WH57 DP60',
				comment         => 'Misol WH57, froggit DP60, lightning detector',
				changed         => '20210825 new',
				id              => '116',
				knownFreqs      => '433.92 | 868.35',
				N               => [6,16],
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^57.*',  # Family code 0x57
				preamble        => 'W116#',
				clientmodule    => 'SD_WS',
				length_min      => '18',     # 9 Byte
				method          => \&main::SIGNALduino_FSK_default,
			},
		"118" =>  # Meikee RGB LED Solar Wall Light
				# https://forum.fhem.de/index.php/topic,126110.0.html
				# learn P118#20D300  MU;P0=-509;P1=513;P2=-999;P3=1027;P4=-12704;D=01230121230301212121212121212141212301212121212303012301212303012121212121212121;CP=1;R=77;
				# off   P118#20D301  MU;P0=-516;P1=518;P2=-1015;P3=1000;P4=-12712;D=01230121230301212121212121230141212301212121212303012301212303012121212121212301;CP=1;R=35;
				# on    P118#20D302  MU;P0=-511;P1=520;P2=-998;P3=1015;P4=-12704;D=0121212121230301230121230301212121212123012141212301212121212303012301212303012121212121230121;CP=1;R=83;
			{
				name            => 'Meikee RGB LED Light',
				comment         => 'Solar Wall Light',
				changed         => '20220211 new',
				id              => '118',
				one             => [2,-1],
				zero            => [1,-2],
				start           => [-25],    # -12700
				end             => [1],    # 510
				clockabs        => 510,
				clockpos        => ['zero',0],
				format          => 'twostate',
				clientmodule    => 'SD_UT',
				#modulematch    => '^P118#',
				preamble        => 'P118#',
				length_min      => '24',
				length_max      => '25',
			},
		"118.1" =>  # Meikee RGB LED Solar Wall Light (MS-Nachricht)
				# https://forum.fhem.de/index.php/topic,126110.0.html
				# on P118#20D302  MS;P1=-12746;P2=528;P3=-1001;P4=1003;P5=-520;D=212323452323232323454523452323454523232323232345232;CP=2;SP=1;
			{
				name            => 'Meikee RGB LED Light',
				comment         => 'Solar Wall Light',
				changed         => '20220216 new',
				id              => '118.1',
				one             => [2,-1],
				zero            => [1,-2],
				sync            => [1,-25],    # -12700
				clockabs        => 510,
				format          => 'twostate',
				clientmodule    => 'SD_UT',
				#modulematch    => '^P118#',
				preamble        => 'P118#',
				length_min      => '24',
				length_max      => '25',
			},
		"119"	=>	## Funkbus
				# https://forum.fhem.de/index.php/topic,127189.0.html
				# FAE8_A_1: act=U  J2C175F300100 MC;LL=-1007;LH=1034;SL=-508;SH=514;D=9D4F3F7554AA0;C=510;L=49;R=50;s4;b4;
			{
				name            => 'Funkbus',
				comment         => 'only Typ 43',
				id              => '119',
				changed         => '20220409 new',
				knownFreqs      => '433.420',
				clockrange      => [490,520],			# min , max
				start           => [7.2],  # 3600
				clockabs        => 500,
				format          => 'manchester',	    # tristate can't be migrated from bin into hex!
				clientmodule    => 'IFB',
				#modulematch     => '',
				preamble        => 'J',
				length_min      => '47',
				length_max      => '52',
				method          => \&main::SIGNALduino_Funkbus, # Call to process this message
			},
		"119.1"	=>	## Funkbus
				#
			{
				name            => 'Funkbus',
				#comment         => '',
				id              => '119.1',
				developId       => 'y',
				changed         => '20220409 new',
				knownFreqs      => '433.420',
				clockrange      => [490,520],			# min , max
				format          => 'manchester',	    # tristate can't be migrated from bin into hex!
				clientmodule    => 'IFB',
				#modulematch     => '',
				preamble        => 'J',
				length_min      => '49',
				length_max      => '52',
				method          => \&main::SIGNALduino_Funkbus, # Call to process this message
			},
    "120" =>  ## Weather station TFA 35.1077.54.S2 with 30.3151 (T/H-transmitter), 30.3152 (rain gauge), 30.3153 (anemometer)
              # https://forum.fhem.de/index.php/topic,119335.msg1221926.html#msg1221926 2022-05-17 @ Ronny2510
              # T: 18.7 H: 60 Ws: 2.0 Wg: 2.7 R: 491.1  MU;P0=-4848;P1=984;P2=-981;P3=1452;P4=-17544;P5=480;P6=-31000;P7=320;D=01234525252525252523252325232523252523232323232523232523232523252523232525252523232323232323252523232323232523232323232323232525232325252323252325252323232523232565272525252525232523252325232525232323232325232325232325232525232325252525232323232323232525;CP=5;R=51;O;
              # T: 25.1 H: 48 Ws: 0.0 Wg: 0.0 Bat: low  MU;P0=112;P1=-5520;P2=480;P3=-973;P4=1468;P5=-31000;D=01232323232323234323432323232323232323434323234323434343234323234343232343434343434343434343434343434343434343434343434343434343434343434343434343234343434323252323232323232343234323232323232323234343232343234343432343232343432323434343434343434343434343;CP=2;R=80;O;
              # T: 22 H: 43 Ws: 0.3 Wg: 0.7 R: 530.4    MU;P0=-15856;P1=480;P2=-981;P3=1460;D=01212121212121232123212321232121232323232321232321212321212323232321232123212123232323232323212323232323232123232323232321212321212123212323232321212121232121;CP=1;R=47;
      {
        name            => 'TFA 35.1077.54.S2',
        comment         => 'Weatherstation with sensors 30.3151, 30.3152, 30.3153',
        id              => '120',
        changed         => '20220518 new',
        knownFreqs      => '868.35',
        one             => [1,-2], #  480,-960
        zero            => [3,-2], # 1440,-960
        clockabs        => 480,
        clockpos        => ['one',0],
        reconstructBit  => '1',
        format          => 'twostate',
        preamble        => 'W120#',
        clientmodule    => 'SD_WS',
        #modulematch     => '^W120#',
        length_min      => '78',
        length_max      => '80',
      },
    "121" => ## Remote control Busch-Transcontrol HF - Handsender 6861
             # 1 OFF   MU;P0=28479;P1=-692;P2=260;P3=574;P4=-371;D=0121212121212134343434213434342121213434343434342;CP=2;R=41;
             # 1 ON    MU;P0=4372;P1=-689;P2=254;P3=575;P4=-368;D=0121213434212134343434213434342121213434343434342;CP=2;R=59;
             # 2 OFF   MU;P0=7136;P1=-688;P2=259;P3=585;P4=-363;D=0121212121212134343434213434342121213434343434343;CP=2;R=59;
      {
        name            => 'Busch-Transcontrol',
        comment         => 'Remote control 6861',
        id              => '121',
        changed         => '20220617 new',
        one             => [2.2,-1.4], #   572,-364
        zero            => [1,-2.6],   #   260,-676
        start           => [-2.6],     #  -675
        pause           => [120,-2.6], # 31200,-676
        clockabs        => 260,
        clockpos        => ['zero',0],
        reconstructBit  => '1',
        format          => 'twostate',
        clientmodule    => 'SD_UT',
        modulematch     => '^P121#',
        preamble        => 'P121#',
        length_min      => '23',
        length_max      => '24',
      },
    "122" =>  ## TM40, Wireless Grill-, Meat-, Roasting-Thermometer with 4 Temperature Sensors
              # https://forum.fhem.de/index.php?topic=127938.msg1224516#msg1224516 2022-06-09 @ Prof. Dr. Peter Henning
              # SD_WS_122_T  T: 36 T2: 32 T3: 31 T4: 31  MU;P0=3412;P1=-1029;P2=1043;P3=4706;P4=-2986;P5=549;P6=-1510;P7=-562;D=01212121212121213456575756575756575756565757575656575757575757575657575656575656575757575757575756575756565756565757575757575757565756575757575757575757575757575657565657565757575757575757575757575757575757575756575656565757575621212121212121213456575756;CP=5;R=2;O;
              # SD_WS_122_T  T: 83 T2: 22 T3: 22 T4: 22  MU;P0=11276;P1=-1039;P2=1034;P3=4704;P4=-2990;P5=543;P6=-1537;P7=-559;D=01212121212121213456575756575756575756565757575656575757575757575756565756565657575757575757575757565657565656575757575757575757575656575656565757575757575757565657575656565656575757575757575757575757575757575756565756565656575621212121212121213456575756;CP=5;R=12;O;
      {
        name            => 'TM40',
        comment         => 'Roasting Thermometer with 4 Temperature Sensors',
        changed         => '20220611 new',
        id              => '122',
        one             => [1,-3],           # 520,-1560
        zero            => [1,-1],           # 520,-520
        start           => [9,-6], # 4680,-3120
        clockabs        => 520,
        clockpos        => ['cp'],
        format          => 'twostate',
        preamble        => 'W122#',
        clientmodule    => 'SD_WS',
        modulematch     => '^W122#',
        length_min      => '104',
        length_max      => '108',
      },
    "123" =>  ## Inkbird IBS-P01R Pool Thermometer, Inkbird ITH-20R (not tested)
              # https://forum.fhem.de/index.php/topic,128945.0.html @ xeenon
              # SD_WS_123_T_0655 T: -4.2 Bat%: 90 MN;D=D3910F800301005A0655D6FF14051405264E;N=14;R=22;
              # SD_WS_123_T_0655 T: 22.7 Bat%: 0  MN;D=D3910F80030100000655E30014051405B55C;N=14;R=22;
              # SD_WS_123_T_0655 T: 25   Bat%: 90 MN;D=D3910F800301005A0655FA001405140535F6;N=14;R=22;
              # SD_WS_123_T_7E43 T: 25.4 H: 60 Bat%: 32 MN;D=D3910F00010301207E43FE0014055802772A;N=14;R=232;
      {
        name            => 'Inkbird IBS-P01R ITH-20R',
        comment         => 'IBS-P01R Pool Thermometer',
        changed         => '20220902 new',
        id              => '123',
        N               => [14],
        datarate        => '10000',
        sync            => '2DD4',
        modulation      => '2-FSK',
        cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
        preamble        => 'W123#',
        clientmodule    => 'SD_WS',
        length_min      => '36',     # 18 Byte
        method          => \&main::SIGNALduino_FSK_default,
      },
    "124" => ## Remote control CasaFan FB-FNK Powerboat with 5 buttons for fan
             # https://forum.fhem.de/index.php/topic,53282.msg1258346.html#msg1258346 @ datwusel 2023-01-17
             # FB_FNK_Powerboat_3A9760  light_dimm     MU;P0=-21800;P1=1716;P2=-444;P3=850;P4=416;P5=-2996;P6=648;D=012323242424232423242323242324242423242423232323232324232423242323512323242424232423242323242324242423242423232323232324232423242323512326;CP=4;R=218;
             # FB_FNK_Powerboat_3A9760  light_on_off   MU;P0=-8672;P1=1730;P2=-426;P3=820;P4=432;P5=-2976;D=012323242424232423242323242324242423242423232323232324242323232323512323242424232423242323242324242423242423232323232324242323232323512323242424232423242323242324242423242423;CP=4;R=227;
      {
        name            => 'FB-Powerboat',
        comment         => 'Remote control CasaFan FB-FNK Powerboat',
        changed         => '20230408 new',
        id              => '124',
        one             => [-1,1], # -430,430
        zero            => [-1,2], # -430,860
        start           => [4],    #  1720
        end             => [-7],   # -3010
        clockabs        => 430,
        format          => 'twostate',
        preamble        => 'P124#',
        clientmodule    => 'SD_UT',
        modulematch     => '^P124#.{8}',
        length_min      => '31',
        length_max      => '32',
      },
    "124.1" => ## Remote control CasaFan FB-FNK Powerboat with 5 buttons for fan
             # https://forum.fhem.de/index.php/topic,53282.msg1258346.html#msg1258346 @ datwusel 2023-01-17
             # FB_FNK_Powerboat_3A9760  1_fan_low_speed   MS;P1=1717;P2=-439;P3=861;P4=419;P5=-2992;D=451232324242423242324232324232424242324242323232323242424232324242;CP=4;SP=5;R=229;O;m2;
             # FB_FNK_Powerboat_3A9760  fan_off           MS;P1=1730;P2=-430;P3=849;P4=436;P5=-2974;D=451232324242423242324232324232424242324242323232323242423242324242;CP=4;SP=5;R=226;O;m2;
      {
        name            => 'FB-Powerboat',
        comment         => 'Remote control CasaFan FB-FNK Powerboat',
        changed         => '20230408 new',
        id              => '124.1',
        one             => [1,-1],      # 430,-430
        zero            => [2,-1],      # 860,-430
        sync            => [1,-7,4,-1], # 430,-3010,1720,-430
        clockabs        => 430,
        format          => 'twostate',
        preamble        => 'P124#',
        clientmodule    => 'SD_UT',
        modulematch     => '^P124#.{8}',
        length_min      => '31',
        length_max      => '32',
      },
    "127" =>  ## Remote control with 14 buttons for ceiling fan
               # https://forum.fhem.de/index.php?topic=134121.0 @ Kai-Alfonso 2023-06-29
               # RCnoName127_3603A fan_off  MU;P0=5271;P1=-379;P2=1096;P3=368;P4=-1108;P5=-5997;D=01213434213434212121212121213434342134212121343421343434212521213434213434212121212121213434342134212121343421343434212521213434213434212121212121213434342134212121343421343434212521213434213434212121212121213434342134212121343421343434212;CP=3;R=63;
               # Message is output by SIGNALduino as MU if the last bit is a 0.
      {
        name             => 'RCnoName127',
        comment          => 'Remote control with 14 buttons for ceiling fan',
        changed          => '20230723 new',
        id               => '127',
        one              => [1,-3],  #  370,-1110
        zero             => [3,-1],  # 1110, -370
        start            => [-15],   # -5550 (MU)
        reconstructBit   => '1',
        clockabs         => '370',
        format           => 'twostate',
        preamble         => 'P127#',
        clientmodule     => 'SD_UT',
        modulematch      => '^P127#',
        length_min       => '29',
        length_max       => '30',
      },
    "127.1" =>  ## Remote control with 14 buttons for ceiling fan
                 # https://forum.fhem.de/index.php?topic=134121.0 @ Kai-Alfonso 2023-06-29
                 # RCnoName127_3603A fan_1         MS;P1=-385;P2=1098;P3=372;P4=-1108;P5=-6710;D=352121343421343421212121212121343434213421212121213421343434;CP=3;SP=5;R=79;m2;
                 # RCnoName127_3603A light_on_off  MS;P1=-372;P2=1098;P3=376;P4=-1096;P5=-6712;D=352121343421343421212121212121343434213421342134212134213421;CP=3;SP=5;R=73;m2;
                 # Message is output by SIGNALduino as MS if the last bit is a 1.
      {
        name             => 'RCnoName127',
        comment          => 'Remote control with 14 buttons for ceiling fan',
        changed          => '20230723 new',
        id               => '127',
        one              => [1,-3],  #  370,-1110
        zero             => [3,-1],  # 1110, -370
        sync             => [1,-18], #  370,-6660 (MS)
        clockabs         => '370',
        format           => 'twostate',
        preamble         => 'P127#',
        clientmodule     => 'SD_UT',
        modulematch      => '^P127#',
        length_min       => '29',
        length_max       => '30',
      },
    "128" =>  ## Remote control with 12 buttons for ceiling fan
               # https://forum.fhem.de/index.php?msg=1281573 @ romakrau 2023-07-14
               # RCnoName128_8A7F fan_slower   MU;P0=-420;P1=1207;P2=-1199;P3=424;P4=-10154;D=010101230123010123232323232323232323230123010143230101012301230101232323232323232323232301230101432301010123012301012323232323232323232323012301014323010101230123010123232323232323232323230123010143230101012301230101232323232323232323232301230101;CP=3;R=18;
               # Message is output by SIGNALduino as MU if the last bit is a 0.
      {
        name             => 'RCnoName128',
        comment          => 'Remote control with 12 buttons for ceiling fan',
        changed          => '20230723 new',
        id               => '128',
        one              => [-3,1],  #  -1218,406
        zero             => [-1,3],  #   -406,1218
        start            => [-25,1], # -10150,406 (MU)
        clockabs         => '406',
        format           => 'twostate',
        preamble         => 'P128#',
        clientmodule     => 'SD_UT',
        modulematch      => '^P128#',
        length_min       => '23',
        length_max       => '24',
      },
    "128.1" =>  ## Remote control with 12 buttons for ceiling fan
                 # https://forum.fhem.de/index.php?msg=1281573 @ romakrau 2023-07-14
                 # RCnoName128_8A7F fan_on_off      MS;P2=-424;P3=432;P4=1201;P5=-1197;P6=-10133;D=36353242424532453242453535353535353535353532453535;CP=3;SP=6;R=36;m1;
                 # RCnoName128_8A7F fan_direction   MS;P0=-10144;P4=434;P5=-415;P6=1215;P7=-1181;D=40474565656745674565674747474747474747474745656567;CP=4;SP=0;R=37;m2;
                 # Message is output by SIGNALduino as MS if the last bit is a 1.
      {
        name             => 'RCnoName128',
        comment          => 'Remote control with 12 buttons for ceiling fan',
        changed          => '20230723 new',
        id               => '128',
        one              => [-3,1],  #  -1218,406
        zero             => [-1,3],  #   -406,1218
        sync             => [-25,1], # -10150,406 (MS)
        reconstructBit   => '1',
        clockabs         => '406',
        format           => 'twostate',
        preamble         => 'P128#',
        clientmodule     => 'SD_UT',
        modulematch      => '^P128#',
        length_min       => '23',
        length_max       => '24',
      },
    "129"	=>	## Sainlogic 8in1 und Sainlogic Wifi 7in1 (mit uv und lux), auch von Raddy, Ragova, Nicety Meter, Dema, Cotech
                 # https://forum.fhem.de/index.php?topic=134381.0
                 # T: 19.7 H: 64 Ws: 1.4 Wg: 2 Wd: NNE R: 0  W129#C0E00E141C0000843340FFFBFBBD  MC;LL=-966;LH=989;SL=-485;SH=490;D=002B3F1FF1EBE3FFFF7BCCBF00040442;C=488;L=128;R=83;
                 #
      {
        name            => 'Sainlogic weatherstation',
        comment         => 'also Raddy, Ragova, Nicety Meter, Dema, Cotech',
        changed         => '20230723 new',
        id              => '129',
        clockrange      => [450,550],     # min , max
        format          => 'manchester',
        clientmodule    => 'SD_WS',
        modulematch     => '^W129#',
        preamble        => 'W129#',
        length_min      => '122',
        #length_max      => '32',
        method          => \&main::SIGNALduino_SainlogicWS, # Call to process this message
        polarity        => 'invert',
      },
    "130" =>  ## Remote control CREATE 6601TL for ceiling fan with light
                 # https://forum.fhem.de/index.php?msg=1288203 @ erdnar 2023-09-29
                 # CREATE_6601TL_F53A light_on_off     MS;P1=425;P2=-1142;P3=1187;P4=-395;P5=-12314;D=15121212123412341234341212123412341212121212121234;CP=1;SP=5;R=232;O;m2;
                 # CREATE_6601TL_F53A light_cold_warm  MS;P1=432;P2=-1143;P3=1183;P4=-393;P5=-12300;D=15121212123412341234341212123412341212121212123434;CP=1;SP=5;R=231;O;m2;
                 # CREATE_6601TL_F53A fan_faster       MS;P0=-11884;P1=392;P2=-1179;P3=1180;P4=-391;D=10121212123412341234341212123412341212121212341234;CP=1;SP=0;R=231;O;m2;
      {
        name             => 'CREATE_6601TL',
        comment          => 'Remote control for ceiling fan with light',
        changed          => '20231104 new',
        id               => '130',
        one              => [1,-3],  #
        zero             => [3,-1],  #
        sync             => [1,-30], #
        clockabs         => '400',
        format           => 'twostate',
        preamble         => 'P130#',
        clientmodule     => 'SD_UT',
        modulematch      => '^P130#',
        length_min       => '24',
        length_max       => '24',
      },
    "132"  =>  ## Remote control Halemeier HA-HX2 for Actor HA-RX-M2-1
               # https://github.com/RFD-FHEM/RFFHEM/issues/1207 @ HomeAuto_User 2023-12-11
               # https://forum.fhem.de/index.php?topic=38452.0 (probably identical)
               # remote 1 - off | P132#85EFAC
               # MU;P0=304;P1=-351;P2=633;P3=-692;P4=-12757;D=01230303030301230123030121240301212121230123030303012303030303012124030121212123012303030301230303030301230123030121240301212121230123030303012303030303012301230301212403012121212301230303030123030303030123012303012124030121212123012303030301230303030301;CP=0;R=241;O;
               # MU;P0=-12609;P1=305;P2=-696;P3=-344;P4=653;D=01213434343421342121212134212121212134213421213434012134343434213421212121342121212121342134212134340121343434342134212121213421212121213421342121343401213434343421342121212134212121212134213421213434012134343434213421212121342121212121342134212134340121;CP=1;R=239;O;
               # remote 1 - on  | P132#85EFAA
               # MU;P0=-696;P1=312;P2=-371;P3=637;P4=-12847;D=01012301230123012341012323232301230101010123010101010123012301230123410123232323012301010101230101010101230123012301234101232323230123010101012301010101012301230123012341012323232301230101010123010101010123012301230123410123232323012301010101230101010101;CP=1;R=236;O;
               # MU;P0=-701;P1=304;P2=-366;P3=642;P4=-12781;D=01012301230123012341012323232301230101010123010101010123012301230123410123232323012301010101230101010101230123012301234101232323230123010101012301010101012301230123012341012323232301230101010123010101010123012301230123410123232323012301010101230101010101;CP=1;R=238;O;
               # remote 2 - on  | P132#01EFAA
               # MU;P0=-340;P1=639;P2=-686;P3=304;P4=-12480;D=01230123014301010101010101232323232301230123012301430101010101010123232323012323232323012301230123014301010101010101232323230123232323230123012301230143010101010101012323232301232323232301230123012301430101010101010123232323012323232323012301230123014301;CP=3;R=226;O;
               # MU;P0=-120;P1=642;P2=-343;P3=-684;P4=319;P5=-12492;D=01212121343434342134343434342134213421342154212121212121213434343421343434343421342134213421542121212121212134343434213434343434213421342134215421212121212121343434342134343434342134213421342154212121212121213434343421343434343421342134213421542121212121;CP=4;R=227;O;
               # remote 2 - off  | P132#01EFAC
               # MU;P0=622;P1=-367;P2=-690;P3=323;P4=-12531;D=01010101010101023232323102323232323102310232310101010102323232310232323232310231023231010431010101010101023232323102323232323102310232310104310101010101010232323231023232323231023102323101043101010101010102323232310232323232310231023231010431010101010101;CP=3;R=235;O;
               # MU;P0=307;P1=-685;P2=-350;P3=658;P4=-12510;D=01010102310101010102310231010232340232323232323231010101023101010101023102323232323232323101010102310101010102310231010232340232323232323231010101023101010101023102310102323402323232323232310101010231010101010231023101023234023232323232323101010102310101;CP=0;R=232;O;
      {
        name            => 'HA-HX2',
        comment         => 'Remote control for Halemeier LED actor HA-RX-M2-1',
        changed         => '20231214 new',
        id              => '132',
        one             => [-2,1],
        zero            => [-1,2],
        start           => [-39,1],
        clockabs        => 330,
        format          => 'twostate',
        preamble        => 'P132#',
        clientmodule    => 'SD_UT',
        modulematch     => '^P132#.*',
        length_min      => '24',
        length_max      => '24',
      },    
    "198" =>  ##  VONDOM Handsender von einem RGBW LED Blumentopf
             # https://forum.fhem.de/index.php?topic=129836.0 @Sebastian J
             # u198#91 MU;P0=96;P1=-111;P2=-4341;P3=598;P4=-448;P5=289;P6=-745;D=0101010101010101010101010101010101010101010102345656345656563234565634565656323456563456565632345656345656563234565634565656323456563456565632345656345656563234565634565656323456563456565632345656345656563;CP=5;R=41;
             # u198#97 MU;P0=105;P1=-103;P2=-4319;P3=585;P4=-456;P5=268;P6=-761;D=010101010101010101010101010101010101010101010101010102345656345634343234565634563434323456563456343432345656345634343234565634563434323456563456343432345656345634343234565634563434323456563456343432345656345634343;CP=3;R=43;
      {
        name            => 'VONDOM RGBW LED Blumentopf',
        #comment         => '',
        id              => '198',
        changed         => '20221025 new',
        one             => [2,-1.5],
        zero            => [1,-2.5],
        start           => [-14],
        clockabs        => 300,
        clockpos        => ['zero',0],
        reconstructBit  => '1',
        format          => 'twostate',
        preamble        => 'u198#',
        #clientmodule    => 'SD_UT',
        #modulematch     => '',
        length_min      => '7',
        #length_max      => '',
      },      
    "199" =>  ## universal HT21E, e.g. B.E.G. Alarmanlage
              # https://forum.fhem.de/index.php/topic,127798.0.html
              # P123#93E  MU;P0=30880;P1=-1794;P2=821;P3=-920;P4=1704;P5=-30427;P6=404;P7=-4204;CP=2;R=41;D=0123434123434121212121234521234341234341212121212345212343412343412121212123452123434123434121212121234567;e;
      {
        name            => 'HT21E (BEG)',
        comment         => 'universal, e.g. for B.E.G. Alarmanlage',
        id              => '199',
        developId       => 'y',
        changed         => '20220525 new',
        one             => [-2,1],
        zero            => [-1,2],
        start           => [-35,1],
        clockabs        => 790,
        clockpos        => ['one',1],
        format          => 'twostate',
        preamble        => 'P199#',
        clientmodule    => 'SD_UT',
        #modulematch     => '',
        length_min      => '12',
        length_max      => '12',
      },
		"200"	=>	# Honeywell ActivLink, wireless door bell, PIR Motion sensor
			# https://github.com/klohner/honeywell-wireless-doorbell#the-data-frame
			# MU;P0=-381;P1=100;P2=260;P3=-220;P4=419;P5=-544;CP=1;R=248;D=010101010101010101010101010101023101023452310102310231010101023101010102310232310101010101010231010101010101010101010101010101010231010234523101023102310101010231010101023102323101010101010102310101010101010101010101010101010102310102345231010231023101010102310;e;
			{
				name            => 'Honeywell ActivLink',
				comment         => 'Wireless doorbell and motion sensor (PIR)',
				changed         => '20221112 new',
				id              => '200',
				knownFreqs      => '868.35',
				one             => [2,-1],
				zero            => [1,-2],
				start           => [-3],
				end             => [3],
				clockabs        => 160,
				clockpos        => ['zero',0],
				format          => 'twostate',
				modulation      => '2-FSK',
				preamble        => 'u200#',
				clientmodule    => 'SIGNALduino_un',
				#modulematch     => '',
				length_min      => '48',
				length_max      => '48',
			},
		"200.1"	=>	# Honeywell ActivLink, wireless door bell, PIR Motion sensor
			# https://github.com/klohner/honeywell-wireless-doorbell#the-data-frame
			# MU;P0=-381;P1=100;P2=260;P3=-220;P4=419;P5=-544;CP=1;R=248;D=010101010101010101010101010101023101023452310102310231010101023101010102310232310101010101010231010101010101010101010101010101010231010234523101023102310101010231010101023102323101010101010102310101010101010101010101010101010102310102345231010231023101010102310;e;
			{
				name            => 'Honeywell ActivLink',
				comment         => 'Wireless doorbell and motion sensor (PIR)',
				changed         => '20210420 new',
				id              => '200.1',
				knownFreqs      => '868.35',
				one             => [2.6,-2.2],
				zero            => [1 ,-3.8],
				start           => [-5.4],
				end             => [4.2],
				clockabs        => 100,
				clockpos        => ['zero',0],
				format          => 'twostate',
				modulation      => '2-FSK',
				preamble        => 'u200#',
				clientmodule    => 'SIGNALduino_un',
				#modulematch     => '',
				length_min      => '48',
				length_max      => '48',
			},
		"201"	=>	# WS 1080
			{
				name            => 'WS1080',
				changed         => '20210904 new',
				id              => '201',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^A.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'LaCrosse',
				length_min      => '20',     # 10 Byte
				method        => \&main::SIGNALduino_WS1080,
			},
		"202"	=>	# TX22
			{
				name            => 'TX22',
				changed         => '20210904 new',
				id              => '202',
				knownFreqs      => '868.3',
				N               => [5],
				datarate        => '8842',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^A.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'LaCrosse',
				length_min      => '10',     # 5 Byte
				method        => \&main::SIGNALduino_TX22,
			},
		"203"	=>	# TX38
			{
				name            => 'TX38',
				changed         => '20210904 new',
				id              => '203',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^[C-F].*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				clientmodule    => 'LaCrosse',
				length_min      => '8',      # 4 Byte
				method        => \&main::SIGNALduino_TX38,
			},

		"204"	=>	# WH24 WH65A/B
			{
				name            => 'WH24 WH65A/B',
				changed         => '20210904 new',
				id              => '204',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^24.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W204#',
				clientmodule    => 'SD_WS',
				length_min      => '32',     # 16 Byte
				method        => \&main::SIGNALduino_WH24,
			},
		"205"	=>	# WH25 WH25A WH32B
			{
				name            => 'WH25 WH25A WH32B',
				comment         => 'without bitsum (XOR), WH25A Firmware .../13',
				changed         => '20210904 new',
				id              => '205',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^E.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W205#',
				clientmodule    => 'SD_WS',
				length_min      => '14',     # 7 Byte
				method        => \&main::SIGNALduino_WH25,
			},
		"205.1"	=>	# WH25 WH25A
			{
				name            => 'WH25 WH25A',
				comment         => 'with bitsum (XOR), Firmware .../14',
				changed         => '20220319 new',
				id              => '205.1',
				developId       => 'y',
				knownFreqs      => '868.3',
				N               => [1,6],
				defaultNoN      => '1',		# wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^E.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W205#',
				clientmodule    => 'SD_WS',
				length_min      => '14',     # 7 Byte
				method        => \&main::SIGNALduino_WH25,
			},
		"206"	=>	# W136
			{
				name            => 'W136',
				changed         => '20210904 new',
				id              => '206',
				knownFreqs      => '868.3',
				N               => [10],
				datarate        => '4798',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^....1A.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W206#',
				clientmodule    => 'SD_WS',
				length_min      => '44',     # 22 Byte
				method        => \&main::SIGNALduino_W136,
			},
		"207" =>  ## BRESSER 7-in-1 Weather Center (outdoor sensor)
			# T: 12.7 H: 87 Ws: 0.7 Wg: 0.7 Wd: ESE, rain: 8.4           W207#0C5F1200B2007007000084001270870068000000000000;  MN;D=C26DA6F5B8AA18AADAADAAAA2EAAB8DA2DAAC2AAAAAAAAAAAA000000;N=7;
			# T: 21.7 H: 61 Ws: 0 Wg: 0 Wd: E R: 0, lux: 109280 uv: 6.7  W207#1E0F0970BA000000000000002170611092800670000000;
			## BRESSER PM2.5/10 air quality meter @ elektron-bbs 2023-11-30
			# PM2.5: 629  PM10: 636   MN;D=ACF66068BDCA89BD2AF22AC83AC9CA33333333333393CAAAAA00;N=7;
			# PM2.5:   8  PM10:   9   MN;D=E3626068BDCA89BD2AAADAAA2AAA3AAEEAAF9AAFEA93CAAAAA00;N=7;
			{
				name            => 'Bresser Profi 7in1',
				comment         => 'BRESSER 7-in-1 weather center',
				changed         => '20220101 new',
				id              => '207',
				knownFreqs      => '868.35',
				N               => [7],
				datarate        => '8220',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				#match           => '^9.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W207#',
				clientmodule    => 'SD_WS',
				length_min      => '46',      # 23 Byte
				method          => \&main::SIGNALduino_Bresser_7in1,
			},
		"208" => ## WMBUS S
			#
			{
				name            => 'WMBUS S',
				comment         => 'ab Firmware V 4.2.2',
				changed         => '20220131 new',
				id              => '208',
				knownFreqs      => '868.3',
				N               => [11],
				datarate        => '32730',
				sync            => '7696',
				lqiPos          => -4,
				rssiPos         => -2,
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				#match           => '^[0-9A-F]+',
				preamble        => 'b',
				clientmodule    => 'WMBUS',
				#length_min      => '',
				method          => \&main::SIGNALduino_WMBus,
			},
		"209" => ## WMBUS T
			#
			{
				name            => 'WMBUS T',
				comment         => 'ab Firmware V 4.2.2',
				changed         => '20220131 new',
				id              => '209',
				knownFreqs      => '868.9497 | 434.475',
				N               => [12],
				datarate        => '103149',
				sync            => '543D',
				lqiPos          => -4,
				rssiPos         => -2,
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				match           => '^[0-9A-F]+',
				preamble        => 'b',
				clientmodule    => 'WMBUS',
				#length_min      => '',
				method          => \&main::SIGNALduino_WMBus,
			},
		"210" => ## WMBUS C
			#
			{
				name            => 'WMBUS C',
				changed         => '20220130 new',
				comment         => 'ab Firmware V 4.2.2',
				id              => '210',
				knownFreqs      => '868.9497 | 434.475',
				N               => [12],
				datarate        => '103149',
				sync            => '543D',
				lqiPos          => -4,
				rssiPos         => -2,
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',       # use FIFOs for RX and TX
				match           => '^(X|Y).*',
				preamble        => 'b',
				clientmodule    => 'WMBUS',
				#length_min      => '',
				method          => \&main::SIGNALduino_WMBus,
			},
		"125" => # (alt 211) ecowitt WH31, Ambient Weather WH31E, froggit DP50
			# https://forum.fhem.de/index.php/topic,111653.msg1212517.html#msg1212517
			# T: -1.7 H: 28 channel:1 Bat ok  W125#3024817F1CF565  MN;D=3024817F1CF56500000000000000000000000000;R=18;
			# T: 16.9 H: 69 channel:8 Bat ok  W125#3024F2394535F9  MN;D=3024F2394535F900000000000000000000000000;R=32;
			# T: 15.1 H: 44 channel:1 Bat low W125#30248A272C78A9  MN;D=30248A272C78A900000000000000000000000000;R=24;
			{
				name            => 'WH31 DP50',
				comment         => 'ecowitt WH31, froggit DP50',
				changed         => '20220304 new',
				id              => '125',
				knownFreqs      => '868.35',
				N               => [1,6],
				defaultNoN      => '1',         # wenn 1, dann matchen auch Nachrichten ohne die N Nr
				datarate        => '17257.69',
				sync            => '2DD4',
				modulation      => '2-FSK',
				cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
				match           => '^(30|37).*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
				preamble        => 'W125#',
				clientmodule    => 'SD_WS',
				length_min      => '14',     # 7 Byte
				method          => \&main::SIGNALduino_FSK_default,
				#method        => \&main::SIGNALduino_WH31,
			},
		"212"	=>	## HMS
			# https://forum.fhem.de/index.php/topic,126812.0.html
			{
				name            => 'HMS',
				#comment         => '',
				changed         => '20220322 new',
				id              => '212',
				clockrange      => [495,515],			# min , max
				format          => 'manchester',	    # tristate can't be migrated from bin into hex!
				clientmodule    => 'HMS',
				#modulematch     => '^W58*',
				preamble        => '810e04xx',
				length_min      => '69',
				#length_max      => '52',
				method          => \&main::SIGNALduino_HMS, # Call to process this message
				polarity        => 'invert',
			},
    "126" => # (alt 213) rain gauge ecowitt | Fine Offset | Ambient Weather WH40
             # SD_WS_126_R_011CDF R: 0 MN;D=40011CDF8F00009762;R=61;
             # SD_WS_126_R_013E3C R: 0 MN;D=40013E3C900000105B;R=61;
             #
      {
        name            => 'WH40',
        comment         => 'ecowitt | Fine Offset | Ambient Weather WH40 rain gauge',
        changed         => '20230403 new',
        id              => '126',
        knownFreqs      => '868.35',
        N               => [1,6],
        defaultNoN      => '1',         # wenn 1, dann matchen auch Nachrichten ohne die N Nr
        datarate        => '17257.69',
        sync            => '2DD4',
        modulation      => '2-FSK',
        cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
        match           => '^40.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
        preamble        => 'W126#',
        clientmodule    => 'SD_WS',
        length_min      => '18',     # 9 Byte
        method          => \&main::SIGNALduino_FSK_default,
        #method          => \&main::SIGNALduino_WH40,
      },
    "214" => # ecowitt WS68 Anemometer
             # MN;D=680000c500004b0fffff005a0000d0af;
             # MN;D=680000c500004b2fffff000e00008033;
             # MN;D=680000c501074b0fffff002e0002a663;
             #
      {
        name            => 'WH68',
        comment         => 'ecowitt WS68 Anemometer',
        changed         => '20230408 new',
        id              => '214',
        knownFreqs      => '868.35',
        N               => [1,6],
        defaultNoN      => '1',         # wenn 1, dann matchen auch Nachrichten ohne die N Nr
        datarate        => '17257.69',
        sync            => '2DD4',
        modulation      => '2-FSK',
        cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
        match           => '^68.*',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
        preamble        => 'W214#',
        clientmodule    => 'SD_WS',
        length_min      => '32',     # 16 Byte
        method          => \&main::SIGNALduino_FSK_default,
        #method          => \&main::SIGNALduino_WH68,
      },
    "215" => # MAX
             # https://forum.fhem.de/index.php?topic=135560.0
             # MN;D=0B6E0630163CD912345600102E83;N=15;r;
             # MN;D=0B6E0002123456163CD900002088;N=15;r;
      {
        name            => 'MAX',
        #comment         => '',
        changed         => '20231107 new',
        id              => '215',
        knownFreqs      => '868.3',
        N               => [15],
        datarate        => '9992.60',
        sync            => 'C626',
        lqiPos          => -2,
        rssiPos         => -4,
        modulation      => '2-FSK',
        cc1101FIFOmode  => '1',      # use FIFOs for RX and TX
        #match           => '',   # fuer eine regexp Pruefung am Anfang vor dem method Aufruf
        preamble        => 'Z',
        clientmodule    => 'CUL_MAX',
        length_min      => '28',     # 14 Byte
        method          => \&main::SIGNALduino_MAX,
      },
    "216" => #
             # https://forum.fhem.de/index.php?topic=139142.0
             # https://forum.fhem.de/index.php?topic=139133.0
             # MC;LL=-507;LH=504;SL=-250;SH=246;D=000111AAD6B3916D5AC23A16FCCEE4F8D5B309DC;C=251;L=160;R=243;s30;b1;
             # MC;LL=-511;LH=501;SL=-255;SH=236;D=000442AF5ECA41B16F0C279746EF6675E2CC25E4;C=250;L=158;R=241;s30;b5;
      {
        name            => 'ESA2000',
        comment         => 'ESA2000 und ESA1000 fuer Stromzaehler (analog und digital) und Gas',
        changed         => '20240913 new',
        id              => '216',
        clockrange      => [240,260],     # min , max
        format          => 'manchester',
        clientmodule    => 'ESA2000',
        #modulematch     => '',
        preamble        => 'S',
        length_min      => '152',
        length_max      => '160',
        method          => \&main::SIGNALduino_ESA2000, # Call to process this message
        polarity        => 'invert',
      }
		########################################################################
		#### ### old information from incomplete implemented protocols #### ####

		# ""	=>	## Livolo
							# https://github.com/RFD-FHEM/RFFHEM/issues/29
							# MU;P0=-195;P1=151;P2=475;P3=-333;D=0101010101 02 01010101010101310101310101010101310101 02 01010101010101010101010101010101010101 02 01010101010101010101010101010101010101 02 010101010101013101013101;CP=1;
							#
							# protocol sends 24 to 47 pulses per message.
							# First pulse is the header and is 595 μs long. All subsequent pulses are either 170 μs (short pulse) or 340 μs (long pulse) long.
							# Two subsequent short pulses correspond to bit 0, one long pulse corresponds to bit 1. There is no footer. The message is repeated for about 1 second.
							#
							# Start bit: |             |___|    bit 0: |   |___|    bit 1: |       |___|
			# {
				# name          => 'Livolo',
				# comment       => 'remote control / dimmmer / switch ...',
				# id            => '',
				# knownFreqs    => '',
				# one           => [3],
				# zero          => [1],
				# start         => [5],
				# clockabs      => 110,						#can be 90-140
				# format        => 'twostate',
				# preamble      => 'uXX#',				# prepend to converted message
				# #clientmodule  => '',
				# #modulematch   => '',
				# length_min    => '16',
				# #length_max   => '',						# missing
				# filterfunc    => 'SIGNALduinoAdv_filterSign',
			# },

		########################################################################

);
