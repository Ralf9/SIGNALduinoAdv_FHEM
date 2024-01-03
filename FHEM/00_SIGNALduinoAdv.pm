##############################################
# $Id: 00_SIGNALduinoAdv.pm 3500 2024-01-03 22:00:00Z v3.5.0-Ralf9 $
#
# v3.4.17
# The module is inspired by the FHEMduino project and modified in serval ways for processing the incomming messages
# see http://www.fhemwiki.de/wiki/SIGNALDuino
# It was modified also to provide support for raw message handling which can be send from the SIGNALduino
# The purpos is to use it as addition to the SIGNALduino which runs on an arduno nano or arduino uno.
# It routes Messages serval Modules which are already integrated in FHEM. But there are also modules which comes with it.
# N. Butzek, S. Butzek, 2014-2015
# S.Butzek,Ralf9 2016-2019
# Ralf9 2020-2023

package main;
my $missingModulSIGNALduinoAdv="";

use strict;
use warnings;
use DevIo;
no warnings 'portable';

require "lib/signalduino_protocols.pm";

use Data::Dumper qw(Dumper);
eval "use JSON;1" or $missingModulSIGNALduinoAdv .= "JSON ";
use Scalar::Util qw(looks_like_number);

#use POSIX qw( floor);  # can be removed
#use Math::Round qw();

use constant {
	SDUINO_VERSION            => "v3.5.0-ralf_03.01.24",
	SDUINO_INIT_WAIT_XQ       => 2.5,    # wait disable device
	SDUINO_INIT_WAIT          => 3,
	SDUINO_INIT_MAXRETRY      => 3,
	SDUINO_CMD_TIMEOUT        => 10,
	SDUINO_KEEPALIVE_TIMEOUT  => 60,
	SDUINO_KEEPALIVE_MAXRETRY => 3,
	SDUINO_WRITEQUEUE_NEXT    => 0.3,
	SDUINO_WRITEQUEUE_TIMEOUT => 2,
	SDUINO_recAwNotMatch_Max  => 10,
	SDUINO_parseRespMaxReading => 130,
	
	SDUINO_DISPATCH_VERBOSE     => 5,      # default 5
	SDUINO_MC_DISPATCH_VERBOSE  => 3,      # wenn kleiner 5, z.B. 3 dann wird vor dem dispatch mit loglevel 3 die ID und rmsg ausgegeben
	SDUINO_MC_DISPATCH_LOG_ID   => '12.1', # die o.g. Ausgabe erfolgt nur wenn der Wert mit der ID uebereinstimmt
	SDUINO_PARSE_DEFAULT_LENGHT_MIN => 8,
};

my %ProtocolListSIGNALduino = %SD_Protocols::ProtocolListSIGNALduino;
my $VersionProtocolList = \%SD_Protocols::VersionProtocolList;
my %rfmode = %SD_Protocols::rfmode;
my %rfmodeTesting = %SD_Protocols::rfmodeTesting;

#sub SIGNALduino_Attr(@);
#sub SIGNALduino_HandleWriteQueue($);
#sub SIGNALduino_Parse($$$$@);
#sub SIGNALduino_Read($);
#sub SIGNALduino_Ready($);
#sub SIGNALduino_Write($$$);
#sub SIGNALduino_SimpleWrite(@);

#my $debug=0;

my %gets = (    # Name, Data to send to the SIGNALduino, Regexp for the answer
  "version"  => ["V", 'V\s.*SIGNAL(duino|ESP).*'],
  "freeram"  => ["R", '^[0-9]+'],
  "raw"      => ["", '.*'],
  "uptime"   => ["t", '^[0-9]+' ],
  "cmds"     => ["?", '(.*Use one of[\? 0-9A-Za-z]+[\r\n]*$)|(CSmcmbl=)' ],
  "ping"     => ["P",'^OK$'],
  "config"   => ["CG",'(MS.*MU.*MC.*)|(ccmode=)'],
  "protocolIdToJson"   => ['none','none'],
  "ccconf"   => ["C0DnF", 'C0Dn11.*'],
  "ccreg"    => ["C", '^C.* = .*'],
  "ccpatable" => ["C3E", '^C3E = .*'],
  "cmdBank"  => ["b", '(b=\d.* ccmode=\d.*)|(switch)|(Bank)|(bank)|(radio)|(not valid)'],
  "zAvailableFirmware" => ["none",'none'],
);


my %sets = (
  "raw"       => 'textFieldNL',
  "flash"     => 'textFieldNL',
  "reset"     => 'noArg',
  "close"     => 'noArg',
  "enableMessagetype_3" => 'syncedMS,unsyncedMU,manchesterMC',
  "enableMessagetype_4" => 'syncedMS,syncedMSEQ,unsyncedMU,manchesterMC',
  "disableMessagetype_3" => 'syncedMS,unsyncedMU,manchesterMC',
  "disableMessagetype_4" => 'syncedMS,syncedMSEQ,unsyncedMU,manchesterMC',
  "LaCrossePairForSec" => 'textFieldNL',
  "sendMsg"   => 'textFieldNL',
  "cc1101_freq"    => 'textFieldNL',
  "cc1101_bWidth"  => '58,68,81,102,116,135,162,203,232,270,325,406,464,541,650,812',
  "cc1101_rAmpl"   => '24,27,30,33,36,38,40,42',
  "cc1101_sens"    => '4,8,12,16',
  "cc1101_patable_433" => '-10_dBm,-5_dBm,0_dBm,5_dBm,7_dBm,10_dBm',
  "cc1101_patable_868" => '-10_dBm,-5_dBm,0_dBm,5_dBm,7_dBm,10_dBm',
  "cc1101_reg"     => 'textFieldNL',
  "cc1101_dataRate" => 'textFieldNL',
  "cc1101_deviatn" => 'textFieldNL',
);

my %patable = (
  "433" =>
  {
    "-10_dBm"  => '34',
    "-5_dBm"   => '68',
    "0_dBm"    => '60',
    "5_dBm"    => '84',
    "7_dBm"    => 'C8',
    "10_dBm"   => 'C0',
  },
  "868" =>
  {
    "-10_dBm"  => '27',
    "-5_dBm"   => '67',
    "0_dBm"    => '50',
    "5_dBm"    => '81',
    "7_dBm"    => 'CB',
    "10_dBm"   => 'C2',
  },
);

my @ampllist = (24, 27, 30, 33, 36, 38, 40, 42); # rAmpl(dB)
my @modformat = ("2-FSK","GFSK","-","ASK/OOK","4-FSK","-","-","MSK"); # modulation format
my @SYNC_MODE = ("No preamble/sync","15/16 sync","16/16 sync","30/32 sync", 
                 "No preamble/sync, carrier-sense above threshold", "15/16 + carrier-sense above threshold", "16/16 + carrier-sense above threshold", "30/32 + carrier-sense above threshold");

my %cc1101_register = (		# for get ccreg 99
 	"00" => ['IOCFG2  ', '0D', '29' ],
	"01" => ['IOCFG1  ', '2E' ],
	"02" => ['IOCFG0  ', '2D', '3F' ],
	"03" => ['FIFOTHR ', '07' ],
	"04" => ['SYNC1   ', 'D3' ],
	"05" => ['SYNC0   ', '91' ],
	"06" => ['PKTLEN  ', '3D', '0F' ],
	"07" => ['PKTCTRL1', '04' ],
	"08" => ['PKTCTRL0', '32', '45' ],
	"09" => ['ADDR    ', '00' ],
	"0A" => ['CHANNR  ', '00' ],
	"0B" => ['FSCTRL1 ', '06', '0F' ],
	"0C" => ['FSCTRL0 ', '00' ],
	"0D" => ['FREQ2   ', '10', '1E' ],
	"0E" => ['FREQ1   ', 'B0', 'C4' ],
	"0F" => ['FREQ0   ', '71', 'EC' ],
	"10" => ['MDMCFG4 ', '57', '8C' ],
	"11" => ['MDMCFG3 ', 'C4', '22' ],
	"12" => ['MDMCFG2 ', '30', '02' ],
	"13" => ['MDMCFG1 ', '23', '22' ],
	"14" => ['MDMCFG0 ', 'B9', 'F8' ],
	"15" => ['DEVIATN ', '00', '47' ],
	"16" => ['MCSM2   ', '07', '07' ],
	"17" => ['MCSM1   ', '00', '30' ],
	"18" => ['MCSM0   ', '18', '04' ],
	"19" => ['FOCCFG  ', '14', '36' ],
	"1A" => ['BSCFG   ', '6C' ],
	"1B" => ['AGCCTRL2', '07', '03' ],
	"1C" => ['AGCCTRL1', '00', '40' ],
	"1D" => ['AGCCTRL0', '90', '91' ],
	"1E" => ['WOREVT1 ', '87' ],
	"1F" => ['WOREVT0 ', '6B' ],
	"20" => ['WORCTRL ', 'F8' ],
	"21" => ['FREND1  ', '56' ],
	"22" => ['FREND0  ', '11', '16' ],
	"23" => ['FSCAL3  ', 'E9', 'A9' ],
	"24" => ['FSCAL2  ', '2A', '0A' ],
	"25" => ['FSCAL1  ', '00', '20' ],
	"26" => ['FSCAL0  ', '1F', '0D' ],
	"27" => ['RCCTRL1 ', '41' ],
	"28" => ['RCCTRL0 ', '00' ],
	"29" => ['FSTEST  ' ],
	"2A" => ['PTEST   ' ],
	"2B" => ['AGCTEST ' ],
	"2C" => ['TEST2   ', '88' ],
	"2D" => ['TEST1   ', '31' ],
	"2E" => ['TEST0   ', '0B' ]
);

## Supported Clients per default
my $clientsSIGNALduinoAdv = ":CUL_TCM97001:"
                        ."SD_WS:"
                        ."SD_WS07:"
                        ."SD_WS09:"
                        ."Hideki:"
                        ."LaCrosse:"
                        ."OREGON:"
                        ."CUL_EM:"
                        ."CUL_WS:"
                        ."CUL_TX:"
                        ."SD_AS:"
                        ."IT:"
                        ." :"		# Zeilenumbruch
                        ."FS10:"
                        ."FS20:"
                        ."SOMFY:"
                        ."FLAMINGO:"
                        ."SD_WS_Maverick:"
                        ."KOPP_FC:"
                        ."PCA301:"
                        ."SD_BELL:"	    ## bells
                        ."SD_GT:"
                        ."SD_RSL:"
                        ."SD_UT:"		## universal - more devices with different protocol
                        ."WMBUS:"
                        ."HMS:"
                        ." :"		# Zeilenumbruch
                        ."IFB:"
                        ."CUL_FHTTK:"
                        ."FHT:"
                        ."RFXX10REC:"
                        ."Revolt:"
                        ."Dooya:"
                        ."Fernotron:"
                        ."SD_Keeloq:"
                        ."SD_Rojaflex:"
                        ."Siro:"
                        ."LTECH:"
                        ."CUL_MAX:"
                        ."SD_Tool:"
                        ."SIGNALduino_un:"
                    ;

## default regex match List for dispatching message to logical modules, can be updated during runtime because it is referenced
my %matchListSIGNALduinoAdv = (
      '01:IT'               => '^i......',                    # Intertechno Format
      '02:CUL_TCM97001'     => '^s[A-Fa-f0-9]+',              # Any hex string beginning with s
      '03:SD_RSL'           => '^P1#[A-Fa-f0-9]{8}',
      '04:OREGON'           => '^(3[8-9A-F]|[4-6][0-9A-F]|7[0-8]).*',
      '05:CUL_TX'           => '^TX..........',                       # Need TX to avoid FHTTK
      '06:SD_AS'            => '^P2#[A-Fa-f0-9]{7,8}',                # Arduino based Sensors, should not be default
      '07:Hideki'           => '^P12#75[A-F0-9]+',
      '09:CUL_FHTTK'        => '^T[A-F0-9]{8}',
      '10:SD_WS07'          => '^P7#[A-Fa-f0-9]{6}[AFaf][A-Fa-f0-9]{2,3}',
      '11:SD_WS09'          => '^P9#F[A-Fa-f0-9]+',
      '12:SD_WS'            => '^W\d+x{0,1}#.*',
      '13:RFXX10REC'        => '^(20|29)[A-Fa-f0-9]+',
      '14:Dooya'            => '^P16#[A-Fa-f0-9]+',
      '15:SOMFY'            => '^Ys[0-9A-F]+',
      '16:SD_WS_Maverick'   => '^P47#[A-Fa-f0-9]+',
      '17:SD_UT'            => '^P(?:14|20|22|24|26|29|30|34|46|56|68|69|76|78|81|83|86|90|91|91.1|92|93|95|97|99|104|105|114|118|121|124|127|128|130|132|199)#.*', # universal - more devices with different protocols
      '18:FLAMINGO'         => '^P13\.?1?#[A-Fa-f0-9]+',              # Flamingo Smoke
      '19:CUL_WS'           => '^K[A-Fa-f0-9]{5,}',
      '20:Revolt'           => '^r[A-Fa-f0-9]{22}',
      '21:FS10'             => '^P61#[A-F0-9]+',
      '22:Siro'             => '^P72#[A-Fa-f0-9]+',
      '23:FHT'              => '^81..(04|09|0d)..(0909a001|83098301|c409c401)..',
      '24:FS20'             => '^81..(04|0c)..0101a001',
      '25:CUL_EM'           => '^E0.................',
      '26:Fernotron'        => '^P82#.*',
      '27:SD_BELL'          => '^P(?:15|32|41|42|57|79|96|98|112)#.*',
      '28:SD_Keeloq'        => '^P(?:87|88)#.*',
      '29:SD_GT'            => '^P49#[A-Fa-f0-9]+',
      '30:LaCrosse'         => '^(\\S+\\s+9 |OK\\sWS\\s)',
      '31:KOPP_FC'          => '^kr..................',
      '32:PCA301'           => '^\\S+\\s+24',
      '33:SD_Rojaflex'      => '^P109#[A-Fa-f0-9]+',
      '34:WMBUS'            => '^b.*',
      '35:HMS'              => '^810e04......a001',
      '36:IFB'              => '^J............',
      '37:LTECH'            => '^P31#[A-Fa-f0-9]{26,}',
      '38:CUL_MAX'          => '^Z.*',
      '90:SD_Tool'          => '^pt([0-9]+(\.[0-9])?)(#.*)?',
      'X:SIGNALduino_un'    => '^[u]\d+#.*',
);


sub
SIGNALduinoAdv_Initialize
{
  my ($hash) = @_;

  my $dev = ",1";
  #my $dev = "";
  #if (index(SDUINO_VERSION, "dev") >= 0) {
  #   $dev = ",1";
  #}

# Provider
  $hash->{ReadFn}  = \&SIGNALduinoAdv_Read;
  $hash->{WriteFn} = \&SIGNALduinoAdv_Write;
  $hash->{ReadyFn} = \&SIGNALduinoAdv_Ready;

# Normal devices
  $hash->{DefFn}  		 	= \&SIGNALduinoAdv_Define;
  $hash->{FingerprintFn} 	= \&SIGNALduinoAdv_FingerprintFn;
  $hash->{UndefFn} 		 	= \&SIGNALduinoAdv_Undef;
  $hash->{GetFn}   			= \&SIGNALduinoAdv_Get;
  $hash->{SetFn}   			= \&SIGNALduinoAdv_Set;
  $hash->{AttrFn}  			= \&SIGNALduinoAdv_Attr;
  $hash->{AttrList}			= 
                       "Clients MatchList do_not_notify:1,0 dummy:1"
					  ." hexFile"
                      ." initCommands"
                      ." flashCommand"
  					  ." hardware:ESP32_sduino_devkitV1,ESP8266cc1101,nano328,nano328_optiboot,nanoCC1101,nanoCC1101_optiboot,miniculCC1101,3v3prominiCC1101,promini,radinoCC1101,uno,culV3CC1101,"
					       ."Maple_sduino_USB,Maple_sduino_serial,Maple_sduino_LAN,Maple_cul_USB,Maple_cul_serial,Maple_cul_LAN"
					  ." updateChannelFW:stable,testing,Ralf9"
					  ." debug:0$dev"
					  ." longids"
					  ." minsecs"
					  ." whitelist_IDs"
					  ." blacklist_IDs"
					  ." WS09_WSModel:WH3080,WH1080,CTW600"
					  ." WS09_CRCAUS:0,1,2"
					  ." addvaltrigger"
					  ." rawmsgEvent:1,0"
					  ." cc1101_frequency"
					  ." doubleMsgCheck_IDs"
					  ." parseMUclockCheck:0,1,2"  # wenn > 0 dann ist bei MU Nachrichten der test ob die clock in der Toleranz ist, aktiv
					  ." rfmode_user"
					  ." sendSlowRF_A_IDs"
					  ." suppressDeviceRawmsg:1,0"
					  ." development"
					  ." noMsgVerbose:0,1,2,3,4,5"
					  ." maxMuMsgRepeat"
					  ." userProtocol"
		              ." $readingFnAttributes";

  $hash->{ShutdownFn}		= \&SIGNALduinoAdv_Shutdown;
  $hash->{FW_detailFn}		= \&SIGNALduinoAdv_FW_Detail;
  
  $hash->{msIdList} = ();
  $hash->{muIdList} = ();
  $hash->{mcIdList} = ();
  $hash->{mnIdList} = ();
  
  #ours %attr{};
}

#
# Predeclare Variables from other modules may be loaded later from fhem
#
our $FW_wname;
our $FW_ME;      

#
# Predeclare Variables from other modules may be loaded later from fhem
#
our $FW_CSRF;
our $FW_detail;

sub
SIGNALduinoAdv_FingerprintFn
{
  my ($name, $msg) = @_;

  if (substr($msg,0,2) eq "OK") {
    return;
  }
  # Store only the "relevant" part, as the Signalduino won't compute the checksum
  #$msg = substr($msg, 8) if($msg =~ m/^81/ && length($msg) > 8);
  $name = "" if (!IsDummy($name));
  return ($name, $msg);
}

#####################################
sub
SIGNALduinoAdv_Define
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3) {
    my $msg = "wrong syntax: define <name> SIGNALduinoAdv {none | devicename[\@baudrate] | devicename\@directio | hostname:port}";
    Log3 undef, 2, $msg;
    return $msg;
  }
  
  DevIo_CloseDev($hash);
  my $name = $a[0];

  
  if (!exists &round)
  {
      Log3 $name, 1, "$name: Signalduino can't be activated (sub round not found). Please update Fhem via update command";
	  return;
  }
  
  my $dev = $a[2];
  #Debug "dev: $dev" if ($debug);
  #my $hardware=AttrVal($name,"hardware","nano328");
  #Debug "hardware: $hardware" if ($debug);
 
 
  if($dev eq "none") {
    Log3 $name, 1, "$name: device is none, commands will be echoed only";
    $attr{$name}{dummy} = 1;
    #return undef;
  }
  

  if ($dev ne "none" && $dev =~ m/[a-zA-Z]/ && $dev !~ m/\@/) {    # bei einer IP wird kein \@57600 angehaengt
	$dev .= "\@57600";
  }	
  
  #$hash->{CMDS} = "";
  $hash->{ClientsKeepOrder} = 1;
  $hash->{Clients} = $clientsSIGNALduinoAdv;
  $hash->{MatchList} = \%matchListSIGNALduinoAdv;
  $hash->{DeviceName} = $dev;
  
  my $rfmodelist = "";
  #$rfmodelist .= 'test1,test2,';
  foreach my $rf (sort keys %rfmode) {
     $rfmodelist .= $rf . ",";
  }
  $rfmodelist .= 'custom';
  $hash->{rfmodesets}{rfmode} = $rfmodelist;
  
  $rfmodelist = "";
  foreach my $rf (sort keys %rfmodeTesting) {
     $rfmodelist .= $rf . ",";
  }
  $rfmodelist =~ s/,$//;
  $hash->{rfmodesetsTesting}{rfmodeTesting} = $rfmodelist;
  
  my $ret=undef;
  
  InternalTimer(gettimeofday(), 'SIGNALduinoAdv_IdList',"sduino_IdList:$name",0);       # verzoegern bis alle Attribute eingelesen sind
  
  if($dev ne "none") {
    $ret = DevIo_OpenDev($hash, 0, "SIGNALduinoAdv_DoInit", 'SIGNALduinoAdv_Connect');
  } else {
		$hash->{DevState} = 'initialized';
  		readingsSingleUpdate($hash, "state", "opened", 1);
  }
  
  $hash->{DMSG}="nothing";
  $hash->{LASTDMSG} = "nothing";
  $hash->{LASTDMSGID} = "nothing";
  $hash->{TIME}=time();
  $hash->{versionmodul} = SDUINO_VERSION;
  if (defined($VersionProtocolList->{version})) {
	$hash->{versionprotoL} = $VersionProtocolList->{version};
	Log3 $name, 3, "$name: Protocolhashversion: " . $hash->{versionprotoL};
  }
  
  #Log3 $name, 3, "$name: Firmwareversion: ".$hash->{READINGS}{version}{VAL}  if ($hash->{READINGS}{version}{VAL});

  return $ret;
}

###############################
sub SIGNALduinoAdv_Connect
{
	my ($hash, $err) = @_;

	# damit wird die err-msg nur einmal ausgegeben
	if (!defined($hash->{disConnFlag}) && $err) {
		Log3($hash, 3, "$hash->{NAME}: ${err}");
		$hash->{disConnFlag} = 1;
	}
}

#####################################
sub
SIGNALduinoAdv_Undef
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};

  foreach my $d (sort keys %defs) {
    if(defined($defs{$d}) &&
       defined($defs{$d}{IODev}) &&
       $defs{$d}{IODev} == $hash)
      {
        my $lev = ($reread_active ? 4 : 2);
        Log3 $name, $lev, "$name: deleting port for $d";
        delete $defs{$d}{IODev};
      }
  }

  SIGNALduinoAdv_Shutdown($hash);

  DevIo_CloseDev($hash); 
  RemoveInternalTimer($hash);
  RemoveInternalTimer("HandleWriteQueue:$name");
  RemoveInternalTimer("sduino_IdList:$name");
  return;
}

#####################################
sub
SIGNALduinoAdv_Shutdown
{
  my ($hash) = @_;
  #DevIo_SimpleWrite($hash, "XQ\n",2);
  SIGNALduinoAdv_SimpleWrite($hash, "XQ");  # Switch reception off, it may hang up the SIGNALduino
  return;
}

#####################################
#$hash,$name,"sendmsg","P17;R6#".substr($arg,2)

sub
SIGNALduinoAdv_RemoveLaCrossePair
{
  my $hash = shift;
  delete($hash->{LaCrossePair});
}

sub
SIGNALduinoAdv_Set
{
  my ($hash, @a) = @_;
  
  return "\"set SIGNALduino\" needs at least one parameter" if(@a < 2);

  #Log3 $hash, 3, "SIGNALduino_Set called with params @a";

  my $name = shift @a;
  my $hasCC1101 = 0;
  my $hasFSK = 0;
  my $CC1101Frequency = "433";
  my $mVer = 3;		# 4 = Maple
  if ($hash->{version}) {
	if ($hash->{version} =~ m/cc1101/) {
		$hasCC1101 = 1;
		if (defined($hash->{cc1101_frequency}) && $hash->{cc1101_frequency} >= 800) {
			$CC1101Frequency = 868;
		}
	}
	if ($hash->{version} =~ m/V\s4\./) {	# MapleCul oder MapleSduino
		$mVer = 4;
		$hasFSK = 1;
	}
	elsif ($hash->{version} =~ m/V\s3\.3\.[4-9]/) {
		$hasFSK = 1;
	}
  }
  
  my %my_sets = %sets;
  #Log3 $hash, 3, "SIGNALduino_Set addionals set commands: ".Dumper(%{$hash->{additionalSets}});
  #Log3 $hash, 3, "SIGNALduino_Set addionals rfmode set commands: ".Dumper(%{$hash->{rfmodesets}});
  #Log3 $hash, 3, "SIGNALduino_Set global set commands: ".Dumper(%sets);

  %my_sets = ( %my_sets,  %{$hash->{additionalSets}} ) if ( defined($hash->{additionalSets}) );
  %my_sets = ( %my_sets,  %{$hash->{rfmodesets}} ) if ( defined($hash->{rfmodesets}) );
  %my_sets = ( %my_sets,  %{$hash->{rfmodesetsTesting}} ) if ( defined($hash->{rfmodesetsTesting}) );
  
  #Log3 $hash, 3, "SIGNALduino_Set normal set commands: ".Dumper(%my_sets);
  
  if (!defined($my_sets{$a[0]})) {
    my $arguments = ' ';
    foreach my $arg (sort keys %my_sets) {
      next if ($arg =~ m/cc1101/ && $hasCC1101 == 0);
      next if ($my_sets{$arg} ne "" && $arg ne "flash" && $arg ne "LaCrossePairForSec" && IsDummy($hash->{NAME}));
      next if (($arg eq "rfmode" || $arg eq "rfmodeTesting") && $hasFSK == 0);
      next if ($arg eq "LaCrossePairForSec" && !IsDummy($hash->{NAME}) && $hasFSK == 0);
      if ($arg =~ m/patable/) {
        next if (substr($arg, -3) ne $CC1101Frequency);
      }
      elsif ($arg =~ m/Messagetype/) {
        next if (substr($arg, -1) ne $mVer);
      }
      $arguments.= $arg . ($my_sets{$arg} ? (':' . $my_sets{$arg}) : '') . ' ';
    }
    #Log3 $hash->{NAME}, 3, $hash->{NAME} . ": set $a[0] arg = $arguments";
    return "Unknown argument $a[0], choose one of " . $arguments;
  }

  my $cmd = shift @a;
  my $arg = join(" ", @a);
  
  if ($cmd =~ m/cc1101/ && $hasCC1101 == 0) {
    return "This command is only available with a cc1101 receiver";
  }
  
  return "$name is not active, may firmware is not supported, please flash or reset" if ($cmd ne 'reset' && $cmd ne 'flash' && exists($hash->{DevState}) && $hash->{DevState} ne 'initialized');

  if ($cmd =~ m/^cc1101_/) {
     $cmd = substr($cmd,7);
  }
  
  if($cmd eq "raw") {
    Log3 $name, 4, "set $name $cmd $arg";
    my $newarg;
    if ($arg =~ m/^b(s|d)(s|t|c)[A-Fa-f0-9]+/) {  # send WMBus
       if (substr($arg,2,1) eq 's') {
          $newarg = 'SN;N=11;D=';
       }
       else {
          $newarg = 'SN;N=12;D=';
       }
       $newarg .= $arg . ';';
    }
    else {
       $newarg = $arg;
    }
    #SIGNALduino_SimpleWrite($hash, $newarg);
    SIGNALduinoAdv_AddSendQueue($hash,$newarg);
  } elsif( $cmd eq "flash" ) {
    my @args = split(' ', $arg);
    my $log = "";
    my $hexFile = "";
    my @deviceName = split('@', $hash->{DeviceName});
    my $port = $deviceName[0];
	my $hardware=AttrVal($name,"hardware","");
	my $baudrate=57600;
	if (($hardware =~ m/optiboot/) || $hardware eq "uno") {
		$baudrate=115200;
		$hardware =~ s/_optiboot$//;
	}
    my $defaultHexFile = "./FHEM/firmware/$hash->{TYPE}_$hardware.hex";
    my $logFile = AttrVal("global", "logdir", "./log/") . "$hash->{TYPE}-Flash.log";
    return "Please define your hardware! (attr $name hardware <model of your receiver>) " if ($hardware eq "");
	return "ERROR: argument failed! flash [hexFile|url]" if (!$args[0]);

    #Log3 $hash, 3, "SIGNALduino_Set choosen flash option: $args[0] of available: ".Dumper($my_sets{flash});
    
	if( grep $args[0] eq $_ , split(",",$my_sets{flash}) )
	{
		Log3 $hash, 3, "$name: SIGNALduino_Set flash $args[0] try to fetch github assets for tag $args[0]";

		my $channel=AttrVal($name,"updateChannelFW","stable");
		my $account = "RFD-FHEM";
		if ($channel ne "stable" && $channel ne "testing") {
			$account = $channel;
		}
		my ($tags, undef) = split("__", $args[0]);
		my $ghurl = "https://api.github.com/repos/$account/SIGNALDuino/releases/tags/$tags";
		Log3 $hash, 3, "$name: SIGNALduino_Set flash $tags try to fetch release $ghurl";
		
	    my $http_param = {
                    url        => $ghurl,
                    timeout    => 5,
                    hash       => $hash,                                                                                 # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method     => "GET",                                                                                 # Lesen von Inhalten
                    header     => "User-Agent: perl_fhem\r\nAccept: application/json",  								 # Den Header gemaess abzufragender Daten aendern
                    callback   =>  \&SIGNALduinoAdv_githubParseHttpResponse,                                                # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                    command    => "getReleaseByTag"
                    
                };
   		HttpUtils_NonblockingGet($http_param);                                                                                     # Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
		return;
	} 
    elsif(!$arg || $args[0] !~ m/^(\w|\/|.)+$/) {
      $hexFile = AttrVal($name, "hexFile", "");
      if ($hexFile eq "") {
        $hexFile = $defaultHexFile;
      }
    }
    elsif ($args[0] =~ m/^https?:\/\// ) {
		my $http_param = {
		                    url        => $args[0],
		                    timeout    => 5,
		                    hash       => $hash,                                  # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
		                    method     => "GET",                                  # Lesen von Inhalten
		                    callback   =>  \&SIGNALduinoAdv_ParseHttpResponse,        # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
		                    command    => 'flash',
		                };
		
		HttpUtils_NonblockingGet($http_param);       
		return;  	
    } else {
      $hexFile = $args[0];
    }
	Log3 $name, 3, "$name: filename $hexFile provided, trying to flash";
    return "Usage: set $name flash [filename]\n\nor use the hexFile attribute" if($hexFile !~ m/^(\w|\/|.)+$/);

	# Only for Arduino , not for ESP or MapleMini
	if ($hardware =~ m/(?:nano|mini|radino|uno)/)
	{
		my $flashCommand;
	    if( !defined( $attr{$name}{flashCommand} ) ) {		# check defined flashCommand from user | not, use standard flashCommand | yes, use user flashCommand
				Log3 $name, 5, "$hash->{TYPE} $name: flashCommand is not defined. standard used to flash.";
			if ($hardware eq "radinoCC1101") {																	# radinoCC1101 Port not /dev/ttyUSB0 --> /dev/ttyACM0
				$flashCommand = "avrdude -c avr109 -b [BAUDRATE] -P [PORT] -p atmega32u4 -vv -D -U flash:w:[HEXFILE] 2>[LOGFILE]";
			} else {
				$flashCommand = "avrdude -c arduino -b [BAUDRATE] -P [PORT] -p atmega328p -vv -U flash:w:[HEXFILE] 2>[LOGFILE]";
			}
		} else {
			$flashCommand = $attr{$name}{flashCommand};
			Log3 $name, 3, "$hash->{TYPE} $name: flashCommand is manual defined! $flashCommand";
		}
		
        # check if flashtool (custom or default) exists, abort otherwise
		my $flashTool = (split / /, $flashCommand)[0];
		my $flashToolFound=0;

		for my $path ( split /:/, $ENV{PATH} ) {
		    if ( -f "$path/$flashTool" && -x _ ) {
		    	$flashToolFound=1;
		        last;
		    }
		}

	    Log3 $name, 5, "$name: flashTool $flashTool found = $flashToolFound";
	    return "$flashTool could not be found. Either set PATH properly or provide $flashTool via: sudo apt-get install $flashTool" if($flashToolFound == 0);

	    # strip IP-port in case port is an IP-address
            my $host = $port;
            $host =~ s/:\d+//;

	    $log .= "flashing Arduino $name\n";
	    $log .= "hex file: $hexFile\n";
	    $log .= "port: $port\n";
	    $log .= "host: $host\n";
	    $log .= "log file: $logFile\n";
	
	    if($flashCommand ne "" && !IsDummy($name)) {
	      if (-e $logFile) {
	        unlink $logFile;
	      }
	
	      DevIo_CloseDev($hash);
	      readingsSingleUpdate($hash,'state','FIRMWARE UPDATE running',1);
	      $log .= "$name closed\n";
	
	      my $avrdude = $flashCommand;
	      $avrdude =~ s/\Q[PORT]\E/$port/g;
	      $avrdude =~ s/\Q[HOST]\E/$host/g;
	      $avrdude =~ s/\Q[BAUDRATE]\E/$baudrate/g;
	      $avrdude =~ s/\Q[HEXFILE]\E/$hexFile/g;
	      $avrdude =~ s/\Q[LOGFILE]\E/$logFile/g;
	
	      $log .= "command: $avrdude\n\n";
	      # `$avrdude`;
	      qx($avrdude);
	
	      local $/=undef;
	      if (-e $logFile) {
	        open FILE, $logFile;
	        my $logText = <FILE>;
	        close FILE;
	        if ($logText =~ m/flash verified/) {
	          Log3 $name, 3, "$name: avrdude, Firmware update was successfull";
	          readingsSingleUpdate($hash,'state','FIRMWARE UPDATE successfull',1);
	          FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "FW_okDialog('avrdude, Firmware update was successfull')", '');
	        } else {
	          readingsSingleUpdate($hash,'state','FIRMWARE UPDATE with error',1);
	          Log3 $name, 3, "$name: avrdude, ERROR: avrdude exited with error";
	          FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "FW_okDialog('ERROR: avrdude exited with error, for details see last flashlog.')", '');
	          $log .= 'ERROR: avrdude exited with error';
	        }
	        $log .= "--- AVRDUDE ---------------------------------------------------------------------------------\n";
	        $log .= $logText;
	        $log .= "--- AVRDUDE ---------------------------------------------------------------------------------\n\n";
	      }
	      else {
	        $log .= "WARNING: avrdude created no log file\n\n";
	      }
	    }
	    else {
	      $log .= "\n\nNo flashCommand found. Please define this attribute.\n\n";
	    }
	
	    if (!IsDummy($name)) {
			DevIo_OpenDev($hash, 0, "SIGNALduinoAdv_DoInit", 'SIGNALduinoAdv_Connect');
	    }
	    else {
			Log3 $name, 3, "$name; flashCommand=$flashCommand";
	    }
	    $log .= "$name opened\n";
	    $hash->{helper}{avrdudelogs} = $log;
	    return;
	} else
	{
		FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "FW_okDialog('<u>ERROR:</u><br>Sorry, flashing your $hardware is currently not supported.<br>The file is only downloaded in /opt/fhem/FHEM/firmware.')", '');
		return "Sorry, Flashing your ESP or Maple via Module is currently not supported.";
	}
	
  } elsif ($cmd =~ m/reset/i) {
	delete($hash->{initResetFlag}) if defined($hash->{initResetFlag});
	return SIGNALduinoAdv_ResetDevice($hash);
  } elsif( $cmd eq "close" ) {
	$hash->{DevState} = 'closed';
	return SIGNALduinoAdv_CloseDevice($hash);
  } elsif( $cmd =~ m/Messagetype/ ) {
	my $argm;
	if (substr($cmd,0,1) eq 'd') {	# disableMessagetype
		$argm = 'CD' . substr($arg,-1,1);
	}
	else {	# enableMessagetype
		$argm = 'CE' . substr($arg,-1,1);
	}
	#SIGNALduino_SimpleWrite($hash, $argm);
	SIGNALduinoAdv_AddSendQueue($hash,$argm);
	Log3 $name, 4, "set $name $cmd $arg $argm";;
  } elsif( $cmd eq "freq" ) {
	if ($arg eq "") {
		$arg = AttrVal($name,"cc1101_frequency", 433.92);
	}
	my $f = $arg/26*65536;
	my $f2 = sprintf("%02x", $f / 65536);
	my $f1 = sprintf("%02x", int($f % 65536) / 256);
	my $f0 = sprintf("%02x", $f % 256);
	$arg = sprintf("%.3f", (hex($f2)*65536+hex($f1)*256+hex($f0))/65536*26);
	Log3 $name, 3, "$name: Setting FREQ2..0 (0D,0E,0F) to $f2 $f1 $f0 = $arg MHz";
	SIGNALduinoAdv_AddSendQueue($hash,"W0F$f2");
	SIGNALduinoAdv_AddSendQueue($hash,"W10$f1");
	SIGNALduinoAdv_AddSendQueue($hash,"W11$f0");
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( $cmd eq "bWidth" ) {
	SIGNALduinoAdv_AddSendQueue($hash,"C10");
	$hash->{getcmd}->{cmd} = "bWidth";
	$hash->{getcmd}->{arg} = $arg;
  } elsif( $cmd eq "rAmpl" ) {
	return "a numerical value between 24 and 42 is expected" if($arg !~ m/^\d+$/ || $arg < 24 || $arg > 42);
	my ($v, $w);
	for($v = 0; $v < @ampllist; $v++) {
		last if($ampllist[$v] > $arg);
	}
	$v = sprintf("%02d", $v-1);
	$w = $ampllist[$v];
	Log3 $name, 3, "$name: Setting AGCCTRL2 (1B) to $v / $w dB";
	SIGNALduinoAdv_AddSendQueue($hash,"W1D$v");
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( $cmd eq "sens" ) {
	return "a numerical value between 4 and 16 is expected" if($arg !~ m/^\d+$/ || $arg < 4 || $arg > 16);
	my $w = int($arg/4)*4;
	my $v = sprintf("9%d",$arg/4-1);
	Log3 $name, 3, "$name: Setting AGCCTRL0 (1D) to $v / $w dB";
	SIGNALduinoAdv_AddSendQueue($hash,"W1F$v");
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( substr($cmd,0,7) eq "patable" ) {
	my $paFreq = substr($cmd,8);
	my $pa = "x" . $patable{$paFreq}{$arg};
	Log3 $name, 3, "$name: Setting patable $paFreq $arg $pa";
	SIGNALduinoAdv_AddSendQueue($hash,$pa);
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( $cmd eq "dataRate" ) {
	if ($arg >= 600 and $arg <= 500000) {
		SIGNALduinoAdv_AddSendQueue($hash,"C10");
		$hash->{getcmd}->{cmd} = "dataRate";
		$hash->{getcmd}->{arg} = $arg;
	}
	else {
		return "$name: set datarate $arg out of range (0.6 - 500kBaud)";
	}
  } elsif( $cmd eq "deviatn" ) {
	my $deviatn;
	my $bits;
	my $devlast = 0;
	my $bitlast = 0;
	OUTDEVLOOP:
	for (my $e=0; $e<8; $e++) {
		for (my $m=0; $m<8; $m++) {
			$deviatn = (8+$m)*(2**$e) *26000/(2**17);
			$bits = $m + ($e << 4);
			if ($arg > $deviatn) {
				$devlast = $deviatn;
				$bitlast = $bits;
			}
			else {
				if (($deviatn - $arg) < ($arg - $devlast)) {
					$devlast = $deviatn;
					$bitlast = $bits;
				}
				last OUTDEVLOOP;
			}
		}
	}
	my $hexbits = sprintf("%02x",$bitlast);
	my $devstr =  sprintf("% 5.3f",$devlast);
	Log3 $name, 3, "$name: Setting deviatn (15) to $hexbits = $devstr kHz";
	SIGNALduinoAdv_AddSendQueue($hash,"W17$hexbits");
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( $cmd eq "reg" ) {
	## check for four hex digits
	my @nonHex = grep (!/^[0-9A-Fa-f]{4}$/,@a[0..$#a]) ;
	return "ERROR: wrong parameter value @nonHex, only hexadecimal ​​four digits allowed" if (@nonHex);
	
	## check allowed register position
	#my (@wrongRegisters) = grep { !exists($cc1101_register{substr($_,0,2)}) } @a[0..$#a] ;
	#return "ERROR: unknown register position ".substr($wrongRegisters[0],0,2) if (@wrongRegisters);
	
	Log3 $name, 3, "$name: SetRegisters, cc1101_reg @a[0..$#a]";
	my @tmpSendQueue=();
	foreach my $argcmd (@a[0..$#a]) {
		$argcmd = sprintf("W%02X%s",hex(substr($argcmd,0,2)) + 2,substr($argcmd,2,2));
		SIGNALduinoAdv_AddSendQueue($hash,$argcmd);
	}
	SIGNALduinoAdv_WriteInit($hash);
  } elsif( $cmd eq "LaCrossePairForSec" ) {

    return "Usage: set $name LaCrossePairForSec <seconds_active> [ignore_battery]" if(!$arg || $a[0] !~ m/^\d+$/ || ($a[1] && $a[1] ne "ignore_battery") );
    $hash->{LaCrossePair} = $a[1]?2:1;
    InternalTimer(gettimeofday()+$a[0], "SIGNALduinoAdv_RemoveLaCrossePair", $hash, 0);
  } elsif( $cmd eq "rfmode" || $cmd eq "rfmodeTesting") {
    my $rfcw;
    if ($arg eq "custom") {
        my $carg = AttrVal($name,"rfmode_user",undef);
        if (defined($carg)) {
           $rfcw = $carg;
        }
        else {
           return "ERROR: Attribute rfmode_user not defined";
        }
    }
    elsif ($cmd eq "rfmode") {
        $rfcw = $rfmode{$arg};
    }
    else {
        $rfcw = $rfmodeTesting{$arg};
    }
    Log3 $name, 5, "$name: $cmd msg=$arg $rfcw"; 
    
    $hash->{getcmd}->{cmd} = "rfmode";
    $hash->{getcmd}->{arg} = $arg;
    SIGNALduinoAdv_AddSendQueue($hash,$rfcw);
  } elsif( $cmd eq "sendMsg" ) {
	Log3 $name, 5, "$name: sendmsg msg=$arg";
	
	# Split args in serval variables
	my ($protocol,$data,$repeats,$clock,$frequency,$datalength,$dataishex);
	my $slowrfA = '';
	my $n=0;
	foreach my $s (split "#", $arg) {
	    my $c = substr($s,0,1);
	    if ($n == 0 ) {  #  protocol
			$protocol = substr($s,1);
	    } elsif ($n == 1) { # Data
	        $data = $s;
	        if   ( substr($s,0,2) eq "0x" ) { $dataishex=1; $data=substr($data,2); }
	        else { $dataishex=0; }
	        
	    } else {
	    	    if ($c eq 'R') { $repeats = substr($s,1);  }
	    		elsif ($c eq 'C') { $clock = substr($s,1);   }
	    		elsif ($c eq 'F') { $frequency = substr($s,1);  }
	    		elsif ($c eq 'L') { $datalength = substr($s,1);   }
	    }
	    $n++;
	}
	return "$name: sendmsg, unknown protocol: $protocol" if (!exists($ProtocolListSIGNALduino{$protocol}));

	if (defined($hash->{sendAslowrfID}{$protocol})) {
		$slowrfA = 'A';
	}
	
	$repeats=1 if (!defined($repeats));

	if (exists($ProtocolListSIGNALduino{$protocol}{frequency}) && $hasCC1101 && !defined($frequency)) {
		$frequency = $ProtocolListSIGNALduino{$protocol}{frequency};
	}
	if (defined($frequency) && $hasCC1101) {
		$frequency="F=$frequency;";
	} else {
		$frequency="";
	}
	
	#print ("data = $data \n");
	#print ("protocol = $protocol \n");
    #print ("repeats = $repeats \n");
    
	my %signalHash;
	my %patternHash;
	my $pattern="";
	my $cnt=0;
	
	my $sendData;
	
	if ($protocol == 119) { # Funkbus
		$sendData = SIGNALduinoAdv_PreparingSend_Funkbus($hash, $data);
	}
	## modulation ASK/OOK - MC
	elsif (exists($ProtocolListSIGNALduino{$protocol}{format}) && $ProtocolListSIGNALduino{$protocol}{format} eq 'manchester')
	{
		#$clock = (map { $clock += $_ } @{$ProtocolListSIGNALduino{$protocol}{clockrange}}) /  2 if (!defined($clock));
		
		$clock += $_ for(@{$ProtocolListSIGNALduino{$protocol}{clockrange}});
		$clock = round($clock/2,0);
		if ($protocol == 43) {
			#$data =~ tr/0123456789ABCDEF/FEDCBA9876543210/;
		}
		
		my $intro = "";
		my $outro = "";
		
		$intro = $ProtocolListSIGNALduino{$protocol}{msgIntro} if ($ProtocolListSIGNALduino{$protocol}{msgIntro});
		$outro = $ProtocolListSIGNALduino{$protocol}{msgOutro}.";" if ($ProtocolListSIGNALduino{$protocol}{msgOutro});

		if ($intro ne "" || $outro ne "")
		{
			$intro = "SC$slowrfA;R=$repeats;" . $intro;
			$repeats = 0;
			$slowrfA = '';
		}

		$sendData = $intro . "SM$slowrfA;" . ($repeats > 0 ? "R=$repeats;" : "") . "C=$clock;D=$data;" . $outro . $frequency; #	SM;R=2;C=400;D=AFAFAF;
		Log3 $name, 5, "$name: sendmsg Preparing manchester protocol=$protocol, repeats=$repeats, clock=$clock data=$data";
	
	## Format of RX and TX data = normal, use FIFOs for RX and TX
	} elsif (exists $ProtocolListSIGNALduino{$protocol}{cc1101FIFOmode}) {
		my $ccN = $ProtocolListSIGNALduino{$protocol}{N}[0];
		Log3 $name, 5, "$name: sendmsg Preparing cc1101 FIFO send, protocol=$protocol, repeats=$repeats, N=$ccN, data=$data";
		$sendData = 'SN;' . ($repeats > 0 ? "R=$repeats;" : '') . "N=$ccN;D=$data;" # SN;R=1;N=9;D=08C11484498ABCDE;
	## modulation ASK/OOK - MS MU
	} else {
		if ($protocol == 3 || substr($data,0,2) eq "is") {
			if (substr($data,0,2) eq "is") {
				$data = substr($data,2);   # is am Anfang entfernen
			}
			if ($protocol == 3) {
				$data = SIGNALduinoAdv_ITV1_tristateToBit($data);
			} else {
				$data = SIGNALduinoAdv_ITV1_31_tristateToBit($data);	# $protocolId 3.1
			}
			Log3 $name, 5, "$name: sendmsg IT V1 convertet tristate to bits=$data";
		}
		if (!defined($clock)) {
			$hash->{ITClock} = 250 if (!defined($hash->{ITClock}));   # Todo: Klaeren wo ITClock verwendet wird und ob wir diesen Teil nicht auf Protokoll 3,4 und 17 minimieren
			$clock=$ProtocolListSIGNALduino{$protocol}{clockabs} > 1 ?$ProtocolListSIGNALduino{$protocol}{clockabs}:$hash->{ITClock};
		}
		
		if ($dataishex == 1)	
		{
			# convert hex to bits
	        my $hlen = length($data);
	        my $blen = $hlen * 4;
	        $data = unpack("B$blen", pack("H$hlen", $data));
		}

		Log3 $name, 5, "$name: sendmsg Preparing rawsend command for protocol=$protocol, repeats=$repeats, clock=$clock bits=$data";
		
		foreach my $item (qw(preSync sync start one zero float pause end universal))
		{
		    #print ("item= $item \n");
		    next if (!exists($ProtocolListSIGNALduino{$protocol}{$item}));
		    
			foreach my $p (@{$ProtocolListSIGNALduino{$protocol}{$item}})
			{
			    #print (" p = $p \n");
			    
			    if (!exists($patternHash{$p}))
				{
					$patternHash{$p}=$cnt;
					$pattern.="P".$patternHash{$p}."=". int($p*$clock) .";";
					$cnt++;
				}
		    	$signalHash{$item}.=$patternHash{$p};
			   	#print (" signalHash{$item} = $signalHash{$item} \n");
			}
		}
		my @bits = split("", $data);
	
		my %bitconv = (1=>"one", 0=>"zero", 'D'=> "float", 'F'=> "float", 'P'=> "pause", 'U'=> "universal");
		my $SignalData="D=";
		
		$SignalData.=$signalHash{preSync} if (exists($signalHash{preSync}));
		$SignalData.=$signalHash{sync} if (exists($signalHash{sync}));
		$SignalData.=$signalHash{start} if (exists($signalHash{start}));
		foreach my $bit (@bits)
		{
			next if (!exists($bitconv{$bit}));
			#Log3 $name, 5, "encoding $bit";
			$SignalData.=$signalHash{$bitconv{$bit}}; ## Add the signal to our data string
		}
		$SignalData.=$signalHash{end} if (exists($signalHash{end}));
		$sendData = "SR$slowrfA;R=$repeats;$pattern$SignalData;$frequency";
	}

	
	#SIGNALduino_SimpleWrite($hash, $sendData);
	SIGNALduinoAdv_AddSendQueue($hash,$sendData);
	Log3 $name, 4, "$name/set: sending via SendMsg: $sendData";
  } else {
  	Log3 $name, 5, "$name/set: set $name $cmd $arg";
	#SIGNALduino_SimpleWrite($hash, $arg);
	return "Unknown argument $cmd, choose one of ". ReadingsVal($name,'cmd',' help me');
  }

  return;
}

#####################################
sub
SIGNALduinoAdv_Get
{
  my ($hash, @a) = @_;
  my $type = $hash->{TYPE};
  my $name = $hash->{NAME};
  #return "$name is not active, may firmware is not supported, please flash or reset" if (exists($hash->{DevState}) && $hash->{DevState} ne 'initialized');
  #my $name = $a[0];
  
  Log3 $name, 5, "\"get $type\" needs at least one parameter" if(@a < 2);
  return "\"get $type\" needs at least one parameter" if(@a < 2);
  
  my $isInit = 0;
  my $hasCC1101 = 0;
  if (exists($hash->{DevState}) && $hash->{DevState} eq 'initialized') {
     $isInit = 1;
     if ($hash->{version} && $hash->{version} =~ m/cc1101/) {
        $hasCC1101 = 1;
     }
  }
  
  if(!defined($gets{$a[1]})) {
     my $arguments = ' ';
     foreach my $arg (sort keys %gets) {
        next if ($arg =~ m/^cc/ && $hasCC1101 == 0);
        next if ($arg ne "raw" && $arg ne "protocolIdToJson" && $arg ne "zAvailableFirmware" && IsDummy($name));
        next if ($arg ne "protocolIdToJson" && $arg ne "zAvailableFirmware" && $isInit == 0);
        if ($arg ne "raw" && $arg ne "cmds" && $arg ne "ccreg" && $arg ne "cmdBank" && $arg ne "protocolIdToJson") {
           $arg .= ":noArg";
        }
        $arguments.= $arg . " ";
     }
     #my @cList = map { $_ =~ m/^(file|raw|ccreg)$/ ? $_ : "$_:noArg" } sort keys %gets;
     #Log3 $name, 5, "name: $arguments";
     return "Unknown argument $a[1], choose one of $arguments";
  }
  else {
    return "$name is not active, may firmware is not supported, please flash or reset" if ($isInit == 0 && $a[1] ne "zAvailableFirmware" && $a[1] ne "protocolIdToJson");
  }

  my $arg = (exists($a[2]) ? $a[2] : "");

  return "no command to send, get aborted." if (length($gets{$a[1]}[0]) == 0 && length($arg) == 0);
  
  my ($msg, $err);

  if ($a[1] eq "zAvailableFirmware") {
  	
  	if ($missingModulSIGNALduinoAdv =~ m/JSON/ )
  	{
  		Log3 $name, 1, "$name: get $a[1] failed. Pleas install Perl module JSON. Example: sudo apt-get install libjson-perl";
  		
 		return "$a[1]: \n\nFetching from github is not possible. Please install JSON. Example:<br><code>sudo apt-get install libjson-perl</code>";
  	} 
  	
  	my $channel=AttrVal($name,"updateChannelFW","stable");
  	my $account = "RFD-FHEM";
  	if ($channel ne "stable" && $channel ne "testing") {
  	    $account = $channel;
  	}
	#my $hardware=AttrVal($name,"hardware","nano");
	$hash->{asyncOut}=$hash->{CL};
  	SIGNALduinoAdv_querygithubreleases($hash, $account);
	#return "$a[1]: \n\nFetching $channel firmware versions for $hardware from github\n";
	return;
  }
  elsif ($a[1] eq "protocolIdToJson")
  {
	my $ret;
	my $fieldVal;
	$arg = 0 if ($arg eq "");
	if (exists($ProtocolListSIGNALduino{$arg})) {
		my %idHash = %{$ProtocolListSIGNALduino{$arg}};
		$ret = toJSON(\%idHash);
		Log3 $name, 4, "$name: get protocolIdToJson: $ret";
		$ret .= "\n\n";
		foreach my $field (sort keys %idHash) {
			$fieldVal = $ProtocolListSIGNALduino{$arg}{$field};
			if (ref $fieldVal eq "ARRAY") {
				$fieldVal = "[" . join(",", @$fieldVal) . "]";
			}
			$ret .= sprintf("%-15s => %s", $field, $fieldVal);
			$ret .= "\n";
		}
	}
	else {
		$ret = "ID=$arg not exists!";
	}
	return "$a[1] ID=$arg: \n\n$ret\n";
  }
  
  if (IsDummy($name))
  {
  	if ($arg =~ m/^id([0-9]+(\.[0-9])?)/) {		# wenn bei get raw "id<nr>" am Anfang steht, dann wird "nr" als temporaere whitelist verwendet
		my $id;
		my $pos = index($arg,"#");
		if ($pos != -1) {
			$id = substr($arg,2,$pos-2);
			$arg = substr($arg,$pos+1);
		}
		else {
			$id = substr($arg,2);
			$arg = "";
		}
		SIGNALduinoAdv_IdList("x:$name", $id);
		$hash->{tmpWhiteList} = $id;
	}
	
  	if ($arg =~ /^M[CcSUN];.*/)
  	{
		$arg="\002$arg\003";  	## Add start end end marker if not already there
		Log3 $name, 5, "$name/msg adding start and endmarker to message";
	
	}
	if ($arg =~ /\002M.;.*;\003$/)
	{
		Log3 $name, 4, "$name/msg get raw: $arg";
		return SIGNALduinoAdv_Parse($hash, $hash->{NAME}, uc($arg));
  	}
  	else {
		my $arg2 = "";
		if ($arg =~ m/^version=/) {           # set version
			$arg2 = substr($arg,8);
			$hash->{version} = "V " . $arg2;
		}
		elsif ($arg eq '?') {
			my $ret;
			
			$ret = "dummy get raw\n\n";
			$ret .= "raw message       e.g. MS;P0=-392;P1=...\n";
			$ret .= "dispatch message  e.g. P7#6290DCF37\n";
			$ret .= "version=x.x.x     sets version. e.g. (version=3.2.0) to get old MC messages\n";
			return $ret;
		}
		elsif ($arg ne "") {
			my $ret;
			my @aa = @a;
			shift @aa;
			shift @aa;
			my $dispArg = join(' ', @aa);
			#Log3 $name, 4, "$name/msg get dispatch: $arg";
			Log3 $name, 4, "$name/msg get dispatch: $dispArg";
			$ret = Dispatch($hash, $dispArg, undef);
			if (defined($ret) && $ret ne "") {
				$ret = join(",", @$ret);
				#my $dhash = $defs{$ret};
				#Log3 $name, 4, "$name: " . Dumper($dhash->{READINGS});
				#foreach my $key (keys %{ $dhash->{READINGS} }) {
				#	Log3 $name, 4, "$name: key=$key";
				#}
				#$ret .= "\n" . ReadingsVal($ret, "state", "none");
				return $ret;
			}
			else {
				$ret = "none";
			}
		}
		return "";
  	}
  }
  return "No $a[1] for dummies" if(IsDummy($name));

  Log3 $name, 5, "$name: command for gets: " . $gets{$a[1]}[0] . " " . $arg;

  if ($a[1] eq "raw")
  {
  	# Dirty hack to check and modify direct communication from logical modules with hardware
  	if ($arg =~ /^is.*/ && length($arg) == 34)
  	{
  		# Arctec protocol
  		Log3 $name, 5, "$name: calling set :sendmsg P17;R6#".substr($arg,2);
  		
  		SIGNALduinoAdv_Set($hash,$name,"sendMsg","P17#",substr($arg,2),"#R6");
  	    return "$a[0] $a[1] => $arg";
  	}
  }
  
  #SIGNALduino_SimpleWrite($hash, $gets{$a[1]}[0] . $arg);
  SIGNALduinoAdv_AddSendQueue($hash, $gets{$a[1]}[0] . $arg);
  $hash->{getcmd}->{cmd}=$a[1];
  $hash->{getcmd}->{asyncOut}=$hash->{CL};
  $hash->{getcmd}->{timenow}=time();
  
  return; # We will exit here, and give an output only, if asny output is supported. If this is not supported, only the readings are updated
}

sub SIGNALduinoAdv_parseResponse
{
	my $hash = shift;
	my $cmd = shift;
	my $msg = shift;

	my $name=$hash->{NAME};
	my $retReading = $msg;
	
  	$msg =~ s/[\r\n]//g;

	if($cmd eq "cmds") 
	{       # nice it up
		$msg =~ s/$name cmds =>//g;
		$msg =~ s/.*Use one of//g;
		$retReading = $msg;
 	} 
 	elsif($cmd eq "uptime") 
 	{   # decode it
   		#$msg = hex($msg);              # /125; only for col or coc
    	$msg = sprintf("%d %02d:%02d:%02d", $msg/86400, ($msg%86400)/3600, ($msg%3600)/60, $msg%60);
    	$retReading = $msg;
  	}
  	elsif($cmd eq "ccregAll")
  	{
		$msg = SIGNALduinoAdv_ccregAll($msg);
		$retReading = "";
  	}
  	elsif($cmd eq "readEEPROM64")
  	{
		$msg =~ s/  /\n/g;
		$msg = "\n\n" . $msg;
		$retReading = "";
  	}
  	elsif($cmd eq "ri")
  	{
		$retReading = $msg;
		$msg =~ s/  /\n/g;
		$msg = "\n\n" . $msg;
  	}
  	elsif($cmd eq "ccconf")
  	{
		my $cconfFSK;
		my $modFlag;
		my $freq;
		($msg, $cconfFSK,$freq,$modFlag) = SIGNALduinoAdv_parseCcconf($msg);
		
		$hash->{cc1101_frequency} = $freq;
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, 'cc1101_config', $msg);
		readingsBulkUpdate($hash, 'cc1101_config_ext', $cconfFSK) if ($modFlag);
		readingsEndUpdate($hash, 1);
		
		if ($modFlag) {
			$msg .= "\n\n" . $cconfFSK;
		}
		else {
			readingsDelete($hash, 'cc1101_config_ext');
		}
		$retReading = "";
	}
	elsif($cmd eq "bWidth") {
		my $val = hex(substr($msg,6));
		my $arg = $hash->{getcmd}->{arg};
		my $ob = $val & 0x0f;
		
		my ($bits, $bw) = (0,0);
		OUTERLOOP:
		for (my $e = 0; $e < 4; $e++) {
			for (my $m = 0; $m < 4; $m++) {
				$bits = ($e << 6)+($m << 4);
				$bw  = int(26000/(8 * (4+$m) * (1 << $e))); # KHz
				last OUTERLOOP if($arg >= $bw);
			}
		}

		$ob = sprintf("%02x", $ob+$bits);
		$msg = "Setting MDMCFG4 (10) to $ob = $bw KHz";
		Log3 $name, 3, "$name/msg parseResponse bWidth: Setting MDMCFG4 (10) to $ob = $bw KHz";
		$retReading = $msg;
		delete($hash->{getcmd});
		SIGNALduinoAdv_AddSendQueue($hash,"W12$ob");
		SIGNALduinoAdv_WriteInit($hash);
	}
	elsif($cmd eq "dataRate") {
		my $val = hex(substr($msg,6));
		my $arg = $hash->{getcmd}->{arg};
		my $ob = $val & 0xf0;
		
		my $e = $arg * (2**20) / 26000000;
		$e = log($e) / log(2);
		$e = int($e);
		my $m = ($arg * (2**28) / (26000000 * (2**$e))) - 256;
		my $mr = round($m,0);
		$m = int($m);
		my $datarate0 = ((256+$m)*(2**($e & 15 )))*26000000/(2**28);
		my $m1 = $m + 1;
		my $e1 = $e;
		if ($m1 == 256) {
			$m1 = 0;
			$e1++;
		}
		my $datarate1 = ((256+$m1)*(2**($e1 & 15 )))*26000000/(2**28);
		
		my $datastr;
		if ($mr == $m) {
			$datastr = sprintf("%.2f* (%.2f) Baud",$datarate0, $datarate1);
		}
		else {
			$datastr = sprintf("(%.2f) %.2f* Baud",$datarate0, $datarate1);
			$m = $m1;
			$e = $e1;
		}
		my $mhex = sprintf("%02x",$m);
		$ob = sprintf("%02x", $ob+$e);
		$msg = "Setting MDMCFG4/3 (10 11) to $ob $mhex = $datastr";
		Log3 $name, 3, "$name/msg parseResponse dataRate $arg: $msg";
		$retReading = $msg;
		delete($hash->{getcmd});
		SIGNALduinoAdv_AddSendQueue($hash,"W12$ob");
		SIGNALduinoAdv_AddSendQueue($hash,"W13$mhex");
		SIGNALduinoAdv_WriteInit($hash);
	}
	elsif($cmd eq "rfmode") {
		Log3 $name, 3, "$name/msg parseResponse rfmode: $msg";
		$retReading = $msg;
		$retReading =~ s/CW([A-Fa-f0-9]+.)+//;
		$retReading = $hash->{getcmd}->{arg} . ' => ' . $retReading;
	}
	elsif($cmd eq "ccpatable") {
		my $CC1101Frequency = "433";
		my $freqStr = "433 MHz";
		if (defined($hash->{cc1101_frequency}) && $hash->{cc1101_frequency} >= 800) {
			$CC1101Frequency = 868;
			$freqStr = $hash->{cc1101_frequency} . " MHz";
		}
		my $dBn = substr($msg,9,2);
		$msg = $freqStr . ', ' . $msg;
		Log3 $name, 3, "$name/msg parseResponse patable: $dBn";
		foreach my $dB (keys %{ $patable{$CC1101Frequency} }) {
			if ($dBn eq $patable{$CC1101Frequency}{$dB}) {
				Log3 $name, 5, "$name/msg parseResponse patable: $dB";
				$msg .= " => $dB";
				last;
			}
		}
	#	$msg .=  "\n\n$CC1101Frequency MHz\n\n";
	#	foreach my $dB (keys $patable{$CC1101Frequency})
	#	{
	#		$msg .= "$patable{$CC1101Frequency}{$dB}  $dB\n";
	#	}
	$retReading = $msg;
	}
	elsif($cmd eq "cmdBank") {
		$msg = SIGNALduinoAdv_parseCcBankInfo($hash, $msg);
		$retReading = $msg;
	}
  	return ($msg, $retReading);
}

sub SIGNALduinoAdv_ccregAll
{
		my $msg = shift;
		my $msgtmp = $msg;
		
		$msg =~ s/  /\n/g;
		$msg = "\n\n" . $msg;
		
		$msgtmp =~ s/\s\sccreg/\nccreg/g;
		$msgtmp =~ s/ccreg\s\d0:\s//g;
		
		my @ccreg = split(/\s/,$msgtmp);
		
		$msg.= "\n\n";
		$msg.= "cc1101 reg detail - addr, name, value, (OOK default),[reset]\n";
		
		my $reg_idx = 0;
		foreach my $key (sort keys %cc1101_register) {
			$msg.= "0x".$key." ".$cc1101_register{$key}[0]. " - 0x".$ccreg[$reg_idx];
			if (defined($cc1101_register{$key}[1]) && ($ccreg[$reg_idx] ne $cc1101_register{$key}[1])) {
				$msg.= " (" . $cc1101_register{$key}[1] . ")";
			}
			if (defined($cc1101_register{$key}[2]) && ($ccreg[$reg_idx] ne $cc1101_register{$key}[2])) {
				$msg.= " [" . $cc1101_register{$key}[2] . "]";
			}
			$msg.= "\n";
			$reg_idx++;
		}
		
	return $msg;
}

sub SIGNALduinoAdv_parseCcconf
{
	my $msg = shift;
	my (undef,$str) = split('=', $msg);
	my $var;
	my %r = ( "0D"=>1,"0E"=>1,"0F"=>1,"10"=>1,"11"=>1,"12"=>1,"15"=>1,"1B"=>1,"1D"=>1 );
	my $ccconfFSK="";
	my $modFlag = 0;
	foreach my $a (sort keys %r) {
		$var = substr($str,(hex($a)-13)*2, 2);
		$r{$a} = hex($var);
	}
	my $mod_format = $modformat[($r{"12"}>>4)&7];
	my $deviatnStr = "";
	if ($mod_format =~ m/FSK/) {
		my $deviatn = (8+($r{"15"}&7))*(2**(($r{"15"}>>4)&7)) *26000/(2**17);
		$deviatnStr = sprintf(" DEVIATN:%.3fkHz",$deviatn);
	}
	$ccconfFSK = "Modulation:$mod_format (SYNC_MODE:" . $SYNC_MODE[$r{"12"}&7] . ")" . $deviatnStr;
	if ($mod_format ne $modformat[3]) {
		$mod_format = "";
		$modFlag = 1;
	}
	else {
		$mod_format = ",Modulation:$mod_format";
	}
	my $freq = sprintf("%.3f", 26*(($r{"0D"}*256+$r{"0E"})*256+$r{"0F"})/65536);  #Freq       | Register 0x0D,0x0E,0x0F
	my $ccconf = sprintf("freq:%.3fMHz bWidth:%dKHz rAmpl:%ddB sens:%ddB (DataRate:%.2fBaud%s)",
	$freq,
	26000/(8 * (4+(($r{"10"}>>4)&3)) * (1 << (($r{"10"}>>6)&3))),   #Bw         | Register 0x10
	$ampllist[$r{"1B"}&7],                                          #rAmpl      | Register 0x1B
	4+4*($r{"1D"}&3),                                               #Sens       | Register 0x1D
	((256+$r{"11"})*(2**($r{"10"} & 15 )))*26000000/(2**28),        #DataRate   | Register 0x10,0x11
	$mod_format                                                     #Modulation | Register 0x12
	);

	return ($ccconf,$ccconfFSK,$freq,$modFlag);
}

sub SIGNALduinoAdv_parseCcBankInfo
{
	my $hash = shift;
	my $msg = shift;
	my $ccconf = "";
	my $ccconfFSK = "";
	my $retccconfFSK;
	my $ccRxTxt = "";
	my $modFlag = 0;
	my $freq;
	my %parts;
	
	if ($msg =~ m/Bank__.*  Radio_ /) {
		my @msg_bankinfo_parts = split(/  /,$msg);	# Split message parts by "  " (double space)
		my $i = -1;
		foreach my $bankmsg (@msg_bankinfo_parts)
		{
			$i++;
			if ($bankmsg =~ m/N_____/) {
				last;
			}
		}
		if ($i != -1) {
			#Log3 $hash, 3, "parseCcBankInfo: $msg_bankinfo_parts[$i]";
			my @Nparts = split(/ /,$msg_bankinfo_parts[$i]);
			foreach my $n (@Nparts)
			{
				if (length($n) == 1) {
					if (ord($n) > 57) {
						$n = ord($n) - 48;
					}
					else {
						$n = ' ' . $n;
					}
					#Log3 $hash, 3, "parseCcBankInfo:+$n+";
				}
			}
			$msg_bankinfo_parts[$i] = join ("", @Nparts);
			#Log3 $hash, 3, "parseCcBankInfo: $msg_bankinfo_parts[$i]";
		}
		$msg = join ("\n", @msg_bankinfo_parts);
		#$msg =~ s/  /\n/g;
		$msg = "\n\n" . $msg;
		return $msg;
	}
 if ($msg =~ m/b=.*ccmode=.*ccconf.*/) {
	for my $radio ('a'..'d') {	# delete radio ccconf internals
		delete($hash->{$radio . '_ccconf'});
		delete($hash->{$radio . '_ccconfFSK'});
	}
  my $rmsg = "\n";
  my @msg_radio_parts = split(/  /,$msg);	# Split message parts by "  " (double space)
  #Log3 $hash, 3, "parseCcBankInfo anz: " . scalar(@msg_radio_parts);
  foreach my $radiomsg (@msg_radio_parts)
  {
	%parts = ();
	my @msg_parts = split(/ /,$radiomsg);		# Split message parts by " "
	$freq = 0;
	foreach (@msg_parts)
	{
		my ($m, $mv) = split(/=/,$_);
		if ($m eq "ccconf") {
			($ccconf,$retccconfFSK,$freq,$modFlag) = SIGNALduinoAdv_parseCcconf("=".$mv);
			if (scalar(@msg_radio_parts) == 1) {
				$hash->{cc1101_frequency} = $freq;
			}
		}
		else {
			$parts{$m} = $mv;
		}
	}
	$ccRxTxt = "";
	if (exists($parts{rx})) {
		$ccRxTxt = " rx=0";
	}
	my $ccconftxt = "";
	if (exists($parts{write})) {
		$ccconftxt = 'write ';
	}
	elsif (exists($parts{fn})) {
		$ccconftxt = 'wrReganz=' . $parts{fn} . ' ';
	}
	$ccconf = $ccconftxt . 'b=' . $parts{b} . $ccRxTxt . " $ccconf [boffs=" . $parts{boffs} . ']';
	my $radionr = "";
	my $radiomsg = "";
	if (exists($parts{r})) {
		$radionr = lc($parts{r}) . "_";
		$radiomsg = $parts{r};
		if (substr($parts{boffs},-1) ne '*') {	# ein * am Ende bedeuted, dass dieses Radio selektiert ist
			$radiomsg .= ": ";
		}
		else {
			$radiomsg .= "* ";
			if ($freq > 0) {
				$hash->{cc1101_frequency} = $freq;
			}
		}
	}
	my $radioconf = $radionr . "ccconf";
	$hash->{$radioconf} = $ccconf;
	$ccconfFSK = "ccmode=" . $parts{ccmode};
	if (exists($parts{N})) {
		$ccconfFSK = "N=" . $parts{N} . " " . $ccconfFSK
	}
	$ccconfFSK .= " sync=" . $parts{sync} . " $retccconfFSK";
	
	$radioconf = $radionr . "ccconfFSK";
	if ($modFlag or $parts{ccmode} > 0) {
		$hash->{$radioconf} = $ccconfFSK;
	}
	else {
		delete($hash->{$radioconf});
	}
	$rmsg .= $radiomsg . $ccconf . "\n\n   " . $ccconfFSK . "\n\n";
	
	#Log3 $hash, 4, "parseCcBankInfo:" . Dumper(\%parts);
  }
  return $rmsg;
 }
 
 $msg = "\n\n" . $msg;
 return $msg;
}

#####################################
sub
SIGNALduinoAdv_ResetDevice
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $dev = $hash->{DEF};

  Log3 $name, 3, "$name reset"; 
  DevIo_CloseDev($hash);
  if ($dev =~ m/\@/ && defined($hash->{version}) && substr($hash->{version},0,6) eq 'V 4.1.') {
    my $uploadResetfound=0;
    my $tool_name = "upload-reset";
    for my $path ( split /:/, $ENV{PATH} ) {
      if ( -f "$path/$tool_name" && -x _ ) {
         $uploadResetfound=1;
         last;
      }
    }
    if ($uploadResetfound) { 
      $dev =~ s/\@.*$//;	# ; am Ende entfernen
      my $mapleReset = "upload-reset $dev 750";
      Log3 $name, 3, "$name upload-reset: $mapleReset";
      `$mapleReset`;
    }
    else {
      Log3 $name, 2, "$name reset: upload-reset not found";
    }
  }
  my $ret = DevIo_OpenDev($hash, 0, "SIGNALduinoAdv_DoInit", 'SIGNALduinoAdv_Connect');

  return $ret;
}

#####################################
sub
SIGNALduinoAdv_CloseDevice
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	Log3 $name, 2, "$name closed"; 
	RemoveInternalTimer($hash);
	DevIo_CloseDev($hash);
	readingsSingleUpdate($hash, "state", "closed", 1);
	
	return;
}

#####################################
sub
SIGNALduinoAdv_DoInit
{
	my $hash = shift;
	my $name = $hash->{NAME};
	#my $err;
	#my $msg = undef;

	#my ($ver, $try) = ("", 0);
	#Dirty hack to allow initialisation of DirectIO Device for some debugging and tesing
  	Log3 $name, 1, "$name/define: ".$hash->{DEF};
  
	delete($hash->{disConnFlag}) if defined($hash->{disConnFlag});
	RemoveInternalTimer("HandleWriteQueue:$name");
    @{$hash->{QUEUE}} = ();
    $hash->{sendworking} = 0;
    delete($hash->{recAwNotMatch});
    
    if (($hash->{DEF} !~ m/\@directio/) and ($hash->{DEF} !~ m/none/) )
	{
		Log3 $name, 1, "$name/init: ".$hash->{DEF};
		$hash->{initretry} = 0;
		RemoveInternalTimer($hash);
		
		#SIGNALduino_SimpleWrite($hash, "XQ"); # Disable receiver
		InternalTimer(gettimeofday() + SDUINO_INIT_WAIT_XQ, "SIGNALduinoAdv_SimpleWrite_XQ", $hash, 0);
		
		InternalTimer(gettimeofday() + SDUINO_INIT_WAIT, "SIGNALduinoAdv_StartInit", $hash, 0);
	}
	# Reset the counter
	delete($hash->{XMIT_TIME});
	delete($hash->{NR_CMD_LAST_H});
	return;
}

# Disable receiver
sub SIGNALduinoAdv_SimpleWrite_XQ {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3 $name, 3, "$name/init: disable receiver (XQ)";
	if ($hash->{STATE} eq 'disconnected') {
		RemoveInternalTimer($hash);
		delete($hash->{initretry});
		Log3 $name,3 , "$name/init: disable receiver aborted because of STATE = disconnected!";
		return;
	}
	SIGNALduinoAdv_SimpleWrite($hash, "XQ");
	#DevIo_SimpleWrite($hash, "XQ\n",2);
}


sub SIGNALduinoAdv_StartInit
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{version} = undef;
	
	Log3 $name,3 , "$name/init: get version, retry = " . $hash->{initretry};
	if ($hash->{STATE} eq 'disconnected') {
		RemoveInternalTimer($hash);
		delete($hash->{initretry});
		Log3 $name,3 , "$name/init: get version aborted because of STATE = disconnected!";
		return;
	}
	if ($hash->{initretry} >= SDUINO_INIT_MAXRETRY) {
		$hash->{DevState} = 'INACTIVE';
		# einmaliger reset, wenn danach immer noch 'init retry count reached', dann SIGNALduino_CloseDevice()
		if (!defined($hash->{initResetFlag})) {
			Log3 $name,2 , "$name/init retry count reached. Reset";
			$hash->{initResetFlag} = 1;
			SIGNALduinoAdv_ResetDevice($hash);
		} else {
			Log3 $name,2 , "$name/init retry count reached. Closed";
			SIGNALduinoAdv_CloseDevice($hash);
		}
		return;
	}
	else {
		$hash->{getcmd}->{cmd} = "version";
		SIGNALduinoAdv_SimpleWrite($hash, "V");
		#DevIo_SimpleWrite($hash, "V\n",2);
		$hash->{DevState} = 'waitInit';
		RemoveInternalTimer($hash);
		InternalTimer(gettimeofday() + SDUINO_CMD_TIMEOUT + 30 * $hash->{initretry}, "SIGNALduinoAdv_CheckCmdResp", $hash, 0);
	}
}


####################
sub SIGNALduinoAdv_CheckCmdResp
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $msg = undef;
	my $ver;
	
	if ($hash->{version}) {
	  if ($hash->{DevState} eq 'waitBankInfo') {
	    $ver = "SIGNALduino";
	  }
	  else {
		$ver = $hash->{version};
	  }
		if ($ver !~ m/SIGNAL(duino|ESP)/) {
			$msg = "$name: Not an SIGNALduino device, setting attribute dummy=1 got for V:  $ver";
			Log3 $name, 1, $msg;
			readingsSingleUpdate($hash, "state", "no SIGNALduino found", 1);
			$hash->{DevState} = 'INACTIVE';
			SIGNALduinoAdv_CloseDevice($hash);
		}
		elsif($ver =~ m/^V 3\.1\./) {
			$msg = "$name: Version of your arduino is not compatible, please flash new firmware. (device closed) Got for V:  $ver";
			readingsSingleUpdate($hash, "state", "unsupported firmware found", 1);
			Log3 $name, 1, $msg;
			$hash->{DevState} = 'INACTIVE';
			SIGNALduinoAdv_CloseDevice($hash);
		}
		else {
		  my $initflag = 0;
		  if ($hash->{DevState} ne 'waitBankInfo') {
			readingsSingleUpdate($hash, "state", "opened", 1);
			if ($ver =~ m/cc1101.*\(((b.*)|(R: .*)\))/) {
				if ($ver =~ m/\((b.*)\)/) {
					Log3 $name, 3, "$name/init: firmwareversion with ccBankSupport found -> send b?";
					SIGNALduinoAdv_SimpleWrite($hash, "b?");
				}
				else {
					Log3 $name, 3, "$name/init: firmwareversion with ccBankSupport and multi cc1101 found -> send br";
					SIGNALduinoAdv_SimpleWrite($hash, "br");
				}
				delete($hash->{ccconf});
				delete($hash->{ccconfFSK});
				$hash->{DevState} = 'waitBankInfo';
				$hash->{getcmd}->{cmd} = "cmdBank";
				RemoveInternalTimer($hash);
				InternalTimer(gettimeofday() + SDUINO_CMD_TIMEOUT, "SIGNALduinoAdv_CheckCmdResp", $hash, 0);
			}
			else {	# firmware hat keine EEPROM Baenke oder kein cc1101
				if ($ver =~ m/cc1101/) {
					Log3 $name, 3, "$name/init: firmwareversion without ccBankSupport found";
				}
				else {
					Log3 $name, 3, "$name/init: firmwareversion without cc1101 found";
				}
				for my $radio ('a'..'d') {	# delete radio ccconf internals
					delete($hash->{$radio . '_ccconf'});
					delete($hash->{$radio . '_ccconfFSK'});
				}
				$initflag = 1;
				delete($hash->{getcmd});
			}
		  }
		  else {
			if ($hash->{ccconf}) {
				my $bankinfo = $hash->{ccconf};
				delete($hash->{ccconf});
				if ($bankinfo =~ m/b=.*ccmode=.*ccconf.*/) {
					$initflag = 1;
					Log3 $name, 4, "$name/init: Write ccBankInfo: ($bankinfo) to Internal ccconf";
					my $tmp = SIGNALduinoAdv_parseCcBankInfo($hash,$bankinfo);
					delete($hash->{getcmd});
				}
		    }
		    else {
				Log3 $name, 3, "$name/init Error! get ccBankInfo, no answer";
				delete($hash->{getcmd});
				$initflag = 1;
		    }
		  }
		  if ($initflag) {
			Log3 $name, 2, "$name: initialized. " . SDUINO_VERSION;
			$hash->{DevState} = 'initialized';
			delete($hash->{initResetFlag}) if defined($hash->{initResetFlag});
			SIGNALduinoAdv_SimpleWrite($hash, "XE"); # Enable receiver
			#DevIo_SimpleWrite($hash, "XE\n",2);
			Log3 $name, 3, "$name/init: enable receiver (XE)";
			delete($hash->{initretry});
			# initialize keepalive
			$hash->{keepalive}{ok}    = 0;
			$hash->{keepalive}{retry} = 0;
			InternalTimer(gettimeofday() + SDUINO_KEEPALIVE_TIMEOUT, "SIGNALduinoAdv_KeepAlive", $hash, 0);
		  }
		}
	}
	else {
		delete($hash->{getcmd});
		$hash->{initretry} ++;
		#InternalTimer(gettimeofday()+1, "SIGNALduino_StartInit", $hash, 0);
		SIGNALduinoAdv_StartInit($hash);
	}
}


#####################################
# Check if the 1% limit is reached and trigger notifies
sub
SIGNALduinoAdv_XmitLimitCheck
{
  my ($hash,$fn) = @_;
 
 
  return if ($fn !~ m/^(is|SR).*/);

  my $now = time();


  if(!$hash->{XMIT_TIME}) {
    $hash->{XMIT_TIME}[0] = $now;
    $hash->{NR_CMD_LAST_H} = 1;
    return;
  }

  my $nowM1h = $now-3600;
  my @b = grep { $_ > $nowM1h } @{$hash->{XMIT_TIME}};

  if(@b > 652) {          # Maximum nr of transmissions per hour (unconfirmed). Workaround 163 x 4, da ab firmware V 4.x. bis zu 4 cc1101 moeglich sind

    my $name = $hash->{NAME};
    Log3 $name, 2, "SIGNALduino TRANSMIT LIMIT EXCEEDED";
    DoTrigger($name, "TRANSMIT LIMIT EXCEEDED");

  } else {

    push(@b, $now);

  }
  $hash->{XMIT_TIME} = \@b;
  $hash->{NR_CMD_LAST_H} = int(@b);
}

#####################################
## API to logical modules: Provide as Hash of IO Device, type of function ; command to call ; message to send
sub
SIGNALduinoAdv_Write
{
  my ($hash,$fn,$msg) = @_;
  my $name = $hash->{NAME};

  if ($fn eq "") {
    $fn="RAW" ;
  }
  elsif($fn eq "04" && substr($msg,0,6) eq "010101") {   # FS20
    $fn="sendMsg";
    $msg = substr($msg,6);
    $msg = SIGNALduinoAdv_PreparingSend_FS20_FHT(74, 6, $msg);
  }
  elsif($fn eq "04" && substr($msg,0,6) eq "020183") {   # FHT
    $fn="sendMsg";
    $msg = substr($msg,6,6) . "00" . substr($msg,12); # insert Byte 3 always 0x00
    $msg = SIGNALduinoAdv_PreparingSend_FS20_FHT(73, 12, $msg);
  }
  Log3 $name, 5, "$name/write: sending via Set $fn $msg";
  
  SIGNALduinoAdv_Set($hash,$name,$fn,$msg);
}


sub SIGNALduinoAdv_AddSendQueue
{
  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};
  
  push(@{$hash->{QUEUE}}, $msg);
  
  #Log3 $hash , 5, Dumper($hash->{QUEUE});
  
  Log3 $name, 5,"AddSendQueue: " . $name . ": $msg (" . @{$hash->{QUEUE}} . ")";
  InternalTimer(gettimeofday() + 0.1, "SIGNALduinoAdv_HandleWriteQueue", "HandleWriteQueue:$name") if (@{$hash->{QUEUE}} == 1 && $hash->{sendworking} == 0);
}


sub
SIGNALduinoAdv_SendFromQueue
{
  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};
  
  if($msg ne "") {
    #Log3 $name, 5, "$name SendFromQueue: msg=$msg";
	SIGNALduinoAdv_XmitLimitCheck($hash,$msg);
    #DevIo_SimpleWrite($hash, $msg . "\n", 2);
    $hash->{sendworking} = 1;
    SIGNALduinoAdv_SimpleWrite($hash,$msg);
    if ($msg =~ m/^S(R|C|M|N);/) {
       $hash->{getcmd}->{cmd} = 'sendraw';
       Log3 $name, 4, "$name SendrawFromQueue: msg=$msg"; # zu testen der Queue, kann wenn es funktioniert auskommentiert werden
    } 
    elsif ($msg eq "C99") {
       $hash->{getcmd}->{cmd} = 'ccregAll';
    }
    elsif ($msg eq "ri") {
       $hash->{getcmd}->{cmd} = 'ri';
    }
    elsif ($msg =~ m/^rN[A-Fa-f0-9]{4}/) {
       $hash->{getcmd}->{cmd} = 'readEEPROM64';
    }
  }

  ##############
  # Write the next buffer not earlier than 0.23 seconds
  # else it will be sent too early by the SIGNALduino, resulting in a collision, or may the last command is not finished
  
  if (defined($hash->{getcmd}->{cmd}) && $hash->{getcmd}->{cmd} eq 'sendraw') {
     InternalTimer(gettimeofday() + SDUINO_WRITEQUEUE_TIMEOUT, "SIGNALduinoAdv_HandleWriteQueue", "HandleWriteQueue:$name");
  } else {
     InternalTimer(gettimeofday() + SDUINO_WRITEQUEUE_NEXT, "SIGNALduinoAdv_HandleWriteQueue", "HandleWriteQueue:$name");
  }
}

####################################
sub
SIGNALduinoAdv_HandleWriteQueue
{
  my($param) = @_;
  my(undef,$name) = split(':', $param);
  my $hash = $defs{$name};
  
  #my @arr = @{$hash->{QUEUE}};
  
  $hash->{sendworking} = 0;       # es wurde gesendet
  
  if (defined($hash->{getcmd}->{cmd}) && $hash->{getcmd}->{cmd} eq 'sendraw') {
    Log3 $name, 4, "$name/HandleWriteQueue: sendraw no answer (timeout)";
    delete($hash->{getcmd});
  }
	  
  if(@{$hash->{QUEUE}}) {
    my $msg= shift(@{$hash->{QUEUE}});

    #Log3 $name, 5, "$name/HandleWriteQueue: msg=$msg";
    if($msg eq "") {
      SIGNALduinoAdv_HandleWriteQueue("x:$name");
    } else {
      SIGNALduinoAdv_SendFromQueue($hash, $msg);
    }
  } else {
  	 Log3 $name, 4, "$name/HandleWriteQueue: nothing to send, stopping timer";
  	 RemoveInternalTimer("HandleWriteQueue:$name");
  }
}

#####################################
# called from the global loop, when the select for hash->{FD} reports data
sub
SIGNALduinoAdv_Read
{
  my ($hash) = @_;

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));
  my $name = $hash->{NAME};
  my $debug = AttrVal($name,"debug",0);

  my $SIGNALduinodata = $hash->{PARTIAL};
  Log3 $name, 5, "$name/RAW READ: $SIGNALduinodata/$buf" if ($debug); 
  $SIGNALduinodata .= $buf;

  while($SIGNALduinodata =~ m/\n/) {
    my $rmsg;
    ($rmsg,$SIGNALduinodata) = split("\n", $SIGNALduinodata, 2);
    $rmsg =~ s/\r//;
    
    	if ($rmsg =~ m/^\002(M(s|u);.*;)\003/) {
		$rmsg =~ s/^\002//;                # \002 am Anfang entfernen
		my @msg_parts = split(";",$rmsg);
		my $m0;
		my $mnr0;
		my $m1;
		my $mL;
		my $mH;
		my $part = "";
		my $partD;
		my $dOverfl = 0;
		#my $fFlag = 0;
		
		#Log3 $name, 3, "rmsg=$rmsg";
		$hash->{rmsgRaw} = $rmsg;
		
		foreach my $msgPart (@msg_parts) {
			next if ($msgPart eq "");
			#my $msgHex="";
			#for my $c (split //, $msgPart . ";") {
			#	$msgHex .= sprintf ("%02x", ord($c)) . " ";
			#}
			#Log3 $name, 3, "$name/readhex: $msgHex";
			#if (substr($msgPart,0,1) eq "D" && $fFlag == 0) {
			#	$msgHex = sprintf ("%02x %02x", ord("F"), ord("6")) . " ";
			#	Log3 $name, 3, "$name/readhex: $msgHex F64";
			#	$fFlag == 1;
			#}
			
			$m0 = substr($msgPart,0,1);
			$mnr0 = ord($m0);
			$m1 = substr($msgPart,1);
			if ($m0 eq "M") {
				$part .= "M" . uc($m1) . ";";
			}
			elsif ($mnr0 > 127) {
				$part .= "P" . sprintf("%u", ($mnr0 & 7)) . "=";
				if (length($m1) == 2) {
					$mL = ord(substr($m1,0,1)) & 127;        # Pattern low
					$mH = ord(substr($m1,1,1)) & 127;        # Pattern high
					if (($mnr0 & 0b00100000) != 0) {           # Vorzeichen  0b00100000 = 32
						$part .= "-";
					}
					if ($mnr0 & 0b00010000) {                # Bit 7 von Pattern low
						$mL += 128;
					}
					$part .= ($mH * 256) + $mL;
				}
				$part .= ";";
			}
			elsif (($m0 eq "D" || $m0 eq "d") && length($m1) > 0) {
				my @arrayD = split(//, $m1);
				if ($dOverfl == 0) {
					$part .= "D=";
				}
				else {
					$part =~ s/;$//;	# ; am Ende entfernen
				}
				$dOverfl++;
				$partD = "";
				foreach my $D (@arrayD) {
					$mH = ord($D) >> 4;
					$mL = ord($D) & 7;
					$partD .= "$mH$mL";
				}
				#Log3 $name, 3, "$name/msg READredu1$m0: $partD";
				if ($m0 eq "d") {
					#Log3 $name, 4, "$name/msg ##READredu## $m0=$partD";
					$partD =~ s/.$//;	   # letzte Ziffer entfernen wenn Anzahl der Ziffern ungerade
				}
				$partD =~ s/^8//;	           # 8 am Anfang entfernen
				#Log3 $name, 3, "$name/msg READredu2$m0: $partD";
				$part = $part . $partD . ';';
			}
			elsif (($m0 eq "C" || $m0 eq "S") && length($m1) == 1) {
				$part .= "$m0" . "P=$m1;";
			}
			elsif ($m0 eq "o" || $m0 eq "m") {
				$part .= "$m0$m1;";
			}
			elsif ($m0 eq "F") {
				my $F = hex($m1);
				Log3 $name, AttrVal($name,"noMsgVerbose",4), "$name/msg READredu(o$dOverfl) FIFO=$F";
			}
			elsif ($m1 =~ m/^[0-9A-Z]{1,2}$/) {        # bei 1 oder 2 Hex Ziffern nach Dez wandeln 
				$part .= "$m0=" . hex($m1) . ";";
			}
			elsif ($m0 =~m/[0-9a-zA-Z]/) {
				$part .= "$m0";
				if ($m1 ne "") {
					$part .= "=$m1";
				}
				$part .= ";";
			}
		}
		my $MuOverfl = "";
		if ($dOverfl > 1) {
			$dOverfl--;
			$MuOverfl = "(o$dOverfl)";
		}
		Log3 $name, 4, "$name/msg READredu$MuOverfl: $part";
		$rmsg = "\002$part\003";
	}
	else {
		Log3 $name, 4, "$name/msg READ: $rmsg";
		#if ($rmsg =~ m/L=(69|70|71/72)/) {
		#	Log3 $name, 2, "$name/msg READ: $rmsg";
		#}
	}

	if ( $rmsg && !SIGNALduinoAdv_Parse($hash, $name, $rmsg) && defined($hash->{getcmd}) && defined($hash->{getcmd}->{cmd}))
	{
		my $getcmd = $hash->{getcmd}->{cmd};
		#Log3 $name, 3, "$name/msg READ: getcmd=$getcmd msg=$rmsg";
		my $regexp;
		if (exists($gets{$getcmd}) && $rmsg =~ m/Unsupported command/ && defined($hash->{DevState}) && $hash->{DevState} !~ m/wait/) {
		
		}
		elsif ($getcmd eq 'sendraw') {
			$regexp = '^S(R|C|M|N);';
		}
		elsif ($getcmd eq 'ccregAll') {
			$regexp = '^ccreg 00:';
		}
		elsif ($getcmd eq 'readEEPROM64') {
			$regexp = '^EEPROM [0-9a-zA-Z]{4}: .*EEPROM [0-9a-zA-Z]{4}:';
		}
		elsif ($getcmd eq 'ri') {
			$regexp = 'mac =.*ip =';
		}
		elsif ($getcmd eq 'bWidth' or $getcmd eq 'dataRate') {
			$regexp = '^C.* = .*';
		}
		elsif ($getcmd eq 'rfmode') {
			$regexp = '^CW|ccFactoryReset';
		}
		else {
			if (exists($gets{$getcmd})) {
				$regexp = $gets{$getcmd}[1];
			}
		}
		if(!defined($regexp) || $rmsg =~ m/$regexp/) {
			if ($hash->{recAwNotMatch}) {
				delete($hash->{recAwNotMatch});
			}
			if (defined($hash->{keepalive})) {
				$hash->{keepalive}{ok}    = 1;
				$hash->{keepalive}{retry} = 0;
			}
			Log3 $name, 4, "$name/msg READ: regexp=$regexp cmd=$getcmd msg=$rmsg" if(defined($regexp));
			
			if ($getcmd eq 'version') {
				my $msg_start = index($rmsg, 'V 3.');
				if ($msg_start < 0) {
					$msg_start = index($rmsg, 'V 4.');
				}
				if ($msg_start > 0) {
					$rmsg = substr($rmsg, $msg_start);
					Log3 $name, 4, "$name/read: cut chars at begin. msgstart = $msg_start msg = $rmsg";
				}
				$hash->{version} = $rmsg;
			}
			
			if (defined($hash->{DevState}) && $hash->{DevState} eq 'waitInit' && $getcmd eq 'version') {
				RemoveInternalTimer($hash);
				SIGNALduinoAdv_CheckCmdResp($hash);
			}
			elsif (defined($hash->{DevState}) && $hash->{DevState} eq 'waitBankInfo' && $getcmd eq 'cmdBank' ) {
				#Log3 $name, 3, "$name/msg READcmdbank: regexp=$regexp cmd=$getcmd msg=$rmsg";
				$hash->{ccconf} = $rmsg;
				RemoveInternalTimer($hash);
				SIGNALduinoAdv_CheckCmdResp($hash);
			}
			elsif ($getcmd eq 'sendraw') {
				# zu testen der sendeQueue, kann wenn es funktioniert auf verbose 5
				Log3 $name, 4, "$name/read sendraw answer: $rmsg";
				delete($hash->{getcmd});
				RemoveInternalTimer("HandleWriteQueue:$name");
				SIGNALduinoAdv_HandleWriteQueue("x:$name");
			}
			else {
				my $reading;
				($rmsg, $reading) = SIGNALduinoAdv_parseResponse($hash,$getcmd,$rmsg);
				if (length($reading) > 0) {
					if (length($reading) > SDUINO_parseRespMaxReading) {
						$reading = substr($reading, 0, SDUINO_parseRespMaxReading);
					}
					readingsSingleUpdate($hash, $getcmd, $reading, 0);
					my $ev = $getcmd . ':: ' . $reading;
					DoTrigger($name, $ev, 0);
				}
				if (defined($hash->{getcmd}->{asyncOut})) {
					#Log3 $name, 4, "$name/msg READ: asyncOutput";
					my $ao = asyncOutput( $hash->{getcmd}->{asyncOut}, $getcmd.": " . $rmsg );
				}
				delete($hash->{getcmd});
			}
		} else {
			if ($hash->{recAwNotMatch}) {
				$hash->{recAwNotMatch}++;
			}
			else {
				$hash->{recAwNotMatch} = 1;
			}
			Log3 $name, 4, "$name/msg READ: ". $hash->{recAwNotMatch} .". Received answer ($rmsg) for ". $getcmd." does not match $regexp";
			if ($hash->{recAwNotMatch} > SDUINO_recAwNotMatch_Max) {
				Log3 $name, 4, "$name/msg READ: too much (". SDUINO_recAwNotMatch_Max .")! Received answer ($rmsg) for ". $getcmd." does not match $regexp";
				delete($hash->{recAwNotMatch});
				delete($hash->{getcmd});
			}
		}
	}
  }
  $hash->{PARTIAL} = $SIGNALduinodata;
}



sub SIGNALduinoAdv_KeepAlive {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	return if ($hash->{DevState} eq 'disconnected');
	
	#Log3 $name,4 , "$name/KeepAliveOk: " . $hash->{keepalive}{ok};
	if (!$hash->{keepalive}{ok}) {
		delete($hash->{getcmd});
		if ($hash->{keepalive}{retry} >= SDUINO_KEEPALIVE_MAXRETRY) {
			Log3 $name,3 , "$name/keepalive not ok, retry count reached. Reset";
			$hash->{DevState} = 'INACTIVE';
			SIGNALduinoAdv_ResetDevice($hash);
			return;
		}
		else {
			my $logLevel = 3;
			$hash->{keepalive}{retry} ++;
			if ($hash->{keepalive}{retry} == 1) {
				$logLevel = 4;
			}
			Log3 $name, $logLevel, "$name/KeepAlive not ok, retry = " . $hash->{keepalive}{retry} . " -> get ping";
			$hash->{getcmd}->{cmd} = "ping";
			SIGNALduinoAdv_AddSendQueue($hash, "P");
			#SIGNALduino_SimpleWrite($hash, "P");
		}
	}
	else {
		Log3 $name,4 , "$name/keepalive ok, retry = " . $hash->{keepalive}{retry};
	}
	$hash->{keepalive}{ok} = 0;
	
	InternalTimer(gettimeofday() + SDUINO_KEEPALIVE_TIMEOUT, "SIGNALduinoAdv_KeepAlive", $hash);
}


### Helper Subs >>>


## Parses a HTTP Response for example for flash via http download
sub SIGNALduinoAdv_ParseHttpResponse
{
	
	my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if($err ne "")               											 		# wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 3, "$name: error while requesting ".$param->{url}." - $err";    		# Eintrag fuers Log
    }
    elsif($param->{code} eq "200" && $data ne "")                                                       		# wenn die Abfrage erfolgreich war ($data enthaelt die Ergebnisdaten des HTTP Aufrufes)
    {
    	
        Log3 $name, 3, "url ".$param->{url}." returned: ".length($data)." bytes Data";  # Eintrag fuers Log
		    	
    	if ($param->{command} eq "flash")
    	{
	    	my $filename;
	    	
	    	if ($param->{httpheader} =~ /Content-Disposition: attachment;.?filename=\"?([-+.\w]+)?\"?/)
			{ 
				$filename = $1;
			} else {  # Filename via path if not specifyied via Content-Disposition
	    		($filename = $param->{path}) =~s/.*\///;
			}
			
	    	Log3 $name, 3, "$name: Downloaded $filename firmware from ".$param->{host};
	    	Log3 $name, 5, "$name: Header = ".$param->{httpheader};
	
			
		   	$filename = "FHEM/firmware/" . $filename;
			open(my $file, ">", $filename) or die $!;
			print $file $data;
			close $file;
	
			# Den Flash Befehl mit der soebene heruntergeladenen Datei ausfuehren
			#Log3 $name, 3, "calling set ".$param->{command}." $filename";    		# Eintrag fuers Log

			my $set_return = SIGNALduinoAdv_Set($hash,$name,$param->{command},$filename); # $hash->{SetFn}
			if (defined($set_return))
			{
				Log3 $name ,3, "$name: Error while flashing: $set_return";
			} else {
				Log3 $name ,3, "$name: Firmware update was succesfull";
			}
    	}
    } else {
    	Log3 $name, 3, "$name: undefined error while requesting ".$param->{url}." - $err - code=".$param->{code};    		# Eintrag fuers Log
    }
}

sub SIGNALduinoAdv_splitMsg
{
  my $txt = shift;
  my $delim = shift;
  my @msg_parts = split(/$delim/,$txt);
  
  return @msg_parts;
}
# $value  - $set <= $tolerance
sub SIGNALduinoAdv_inTol
{
	#Debug "sduino abs \($_[0] - $_[1]\) <= $_[2] ";
	return (abs($_[0]-$_[1])<=$_[2]);
}


############################# package main
#=item SIGNALduino_PatternExists()
# This functons, needs reference to $hash, @array of values to search and %patternList where to find the matches.
#
# Will return -1 if pattern is not found or a string, containing the indexes which are in tolerance and have the smallest gap to what we searched
# =cut

# 01232323242423       while ($message =~ /$pstr/g) { $count++ }

sub SIGNALduinoAdv_PatternExists {
  my ($hash,$search,$patternList,$data) = @_;
  #my %patternList=$arg3;
  #Debug 'plist: '.Dumper($patternList) if($debug);
  #Debug 'searchlist: '.Dumper($search) if($debug);

  my $debug = AttrVal($hash->{NAME},'debug',0);
  my $i=0;
  my @indexer;
  my @sumlist;
  my %plist=();

  for my $searchpattern (@{$search})    # z.B. [1, -4]
  {
    next if (exists $plist{$searchpattern});

    # Calculate tolernace for search
    #my $tol=abs(abs($searchpattern)>=2 ?$searchpattern*0.3:$searchpattern*1.5);
    my $tol=abs(abs($searchpattern)>3 ? abs($searchpattern)>16 ? $searchpattern*0.18 : $searchpattern*0.3 : 1);  #tol is minimum 1 or higer, depending on our searched pulselengh

    Debug "tol: looking for ($searchpattern +- $tol)" if($debug);

    my %pattern_gap ; #= {};
    # Find and store the gap of every pattern, which is in tolerance
    %pattern_gap = map { $_ => abs($patternList->{$_}-$searchpattern) } grep { abs($patternList->{$_}-$searchpattern) <= $tol} (keys %$patternList);
    if (scalar keys %pattern_gap > 0)
    {
      Debug "index => gap in tol (+- $tol) of pulse ($searchpattern) : ".Dumper(\%pattern_gap) if($debug);
      # Extract fist pattern, which is nearst to our searched value
      my @closestidx = (sort {$pattern_gap{$a} <=> $pattern_gap{$b}} keys %pattern_gap);

      $plist{$searchpattern} = 1;
      push @indexer, $searchpattern; 
      push @sumlist, [@closestidx];  
    } else {
      # search is not found, return -1
      return -1;
    }
    $i++;
  }

  sub cartesian_product {
    use List::Util qw(reduce);
    reduce {
      [ map {
        my $item = $_;
        map [ @$_, $item ], @$a
      } @$b ]
    } [[]], @_
  }
  my @res = cartesian_product @sumlist;
  Debug qq[sumlists is: ].Dumper @sumlist if($debug);
  Debug qq[res is: ].Dumper $res[0] if($debug);
  Debug qq[indexer is: ].Dumper \@indexer if($debug);

  OUTERLOOP:
  for my $i (0..$#{$res[0]})
  {

    ## Check if we have same patternindex for different values and skip this invalid ones
    my %count;  
    for (@{$res[0][$i]}) 
    { 
      $count{$_}++; 
      next OUTERLOOP if ($count{$_} > 1)
    };
    
    # Create a mapping table to exchange the values later on
    for (my $x=0;$x <= $#indexer;$x++)
    {
      $plist{$indexer[$x]}  = $res[0][$i][$x]; 
    }
    Debug qq[plist is for this check ].Dumper(\%plist) if($debug);

    # Create our searchstring with our mapping table
    my @patternVariant= @{$search};
    for my $v (@patternVariant)
    {
      #Debug qq[value before is: $v ] if($debug);
      $v = $plist{$v};
      #Debug qq[after: $v ] if($debug);

    }
    Debug qq[patternVariant is ].Dumper(\@patternVariant) if($debug);
    my $search_pattern = join '', @patternVariant;

    (index ($$data, $search_pattern) > -1) ? return $search_pattern : next;
    
  }
  return -1;  

}

#SIGNALduino_MatchSignalPattern{$hash,@array, %hash, @array, $scalar}; not used >v3.1.3
sub SIGNALduinoAdv_MatchSignalPattern($\@\%\@$){

	my ( $hash, $signalpattern,  $patternList,  $data_array, $idx) = @_;
    my $name = $hash->{NAME};
	#print Dumper($patternList);		
	#print Dumper($idx);		
	#Debug Dumper($signalpattern) if ($debug);		
	my $tol="0.2";   # Tolerance factor
	my $found=0;
	my $debug = AttrVal($hash->{NAME},"debug",0);
	
	foreach ( @{$signalpattern} )
	{
			#Debug " $idx check: ".$patternList->{$data_array->[$idx]}." == ".$_;		
			Debug "$name: idx: $idx check: abs(". $patternList->{$data_array->[$idx]}." - ".$_.") > ". ceil(abs($patternList->{$data_array->[$idx]}*$tol)) if ($debug);		
			  
			#print "\n";;
			#if ($patternList->{$data_array->[$idx]} ne $_ ) 
			### Nachkommastelle von ceil!!!
			if (!defined( $patternList->{$data_array->[$idx]})){
				Debug "$name: Error index ($idx) does not exist!!" if ($debug);

				return -1;
			}
			if (abs($patternList->{$data_array->[$idx]} - $_)  > ceil(abs($patternList->{$data_array->[$idx]}*$tol)))
			{
				return -1;		## Pattern does not match, return -1 = not matched
			}
			$found=1;
			$idx++;
	}
	if ($found)
	{
		return $idx;			## Return new Index Position
	}
	
}




sub SIGNALduinoAdv_b2h {
    my $num   = shift;
    my $WIDTH = 4;
    my $index = length($num) - $WIDTH;
    my $hex = '';
    do {
        my $width = $WIDTH;
        if ($index < 0) {
            $width += $index;
            $index = 0;
        }
        my $cut_string = substr($num, $index, $width);
        $hex = sprintf('%X', oct("0b$cut_string")) . $hex;
        $index -= $WIDTH;
    } while ($index > (-1 * $WIDTH));
    return $hex;
}

sub SIGNALduinoAdv_Split_Message
{
	my $rmsg = shift;
	my $name = shift;
	my %patternList;
	my $clockidx;
	my $syncidx;
	my $rawData;
	my $clockabs;
	my $mcbitnum;
	my $nativenr;
	my $rssi;
	
	my @msg_parts = SIGNALduinoAdv_splitMsg($rmsg,';');			## Split message parts by ";"
	my %ret;
	my $debug = AttrVal($name,"debug",0);
	
	foreach (@msg_parts)
	{
		#Debug "$name: checking msg part:( $_ )" if ($debug);

		#if ($_ =~ m/^MS/ or $_ =~ m/^MC/ or $_ =~ m/^Mc/ or $_ =~ m/^MU/) 		#### Synced Message start
		if ($_ =~ m/^M./)
		{
			$ret{messagetype} = $_;
		}
		elsif ($_ =~ m/^P\d=-?\d{2,}/ or $_ =~ m/^[SL][LH]=-?\d{2,}/) 		#### Extract Pattern List from array
		{
		   $_ =~ s/^P+//;  
		   $_ =~ s/^P\d//;  
		   my @pattern = split(/=/,$_);
		   
		   $patternList{$pattern[0]} = $pattern[1];
		   Debug "$name: extracted  pattern @pattern \n" if ($debug);
		}
		elsif($_ =~ m/D=\d+/ or $_ =~ m/^D=[A-F0-9XY][A-F0-9]+/) 		#### Message from array
		{
			$_ =~ s/D=//;  
			$rawData = $_ ;
			Debug "$name: extracted  data $rawData\n" if ($debug);
			$ret{rawData} = $rawData;
		}
		elsif($_ =~ m/^SP=\d{1}/) 		#### Sync Pulse Index
		{
			(undef, $syncidx) = split(/=/,$_);
			Debug "$name: extracted  syncidx $syncidx\n" if ($debug);
			#return undef if (!defined($patternList{$syncidx}));
			$ret{syncidx} = $syncidx;

		}
		elsif($_ =~ m/^CP=\d{1}/) 		#### Clock Pulse Index
		{
			(undef, $clockidx) = split(/=/,$_);
			Debug "$name: extracted  clockidx $clockidx\n" if ($debug);
			#return undef if (!defined($patternList{$clockidx}));
			$ret{clockidx} = $clockidx;
		}
		elsif($_ =~ m/^L=\d/) 		#### MC bit length
		{
			(undef, $mcbitnum) = split(/=/,$_);
			Debug "$name: extracted  number of $mcbitnum bits\n" if ($debug);
			$ret{mcbitnum} = $mcbitnum;
		}
		elsif($_ =~ m/^N=\d{1}/)	### xFSK Native Nr
		{
			(undef, $nativenr) = split(/=/,$_);
			Debug "$name: extracted xFSK Native Nr $nativenr \n" if ($debug);
			$ret{N} = $nativenr;
		}
		elsif($_ =~ m/^C=\d+/) 		#### Message from array
		{
			$_ =~ s/C=//;  
			$clockabs = $_ ;
			Debug "$name: extracted absolute clock $clockabs \n" if ($debug);
			$ret{clockabs} = $clockabs;
		}
		elsif($_ =~ m/^R=\d+/)		### RSSI ###
		{
			$_ =~ s/R=//;
			$rssi = $_ ;
			Debug "$name: extracted RSSI $rssi \n" if ($debug);
			$ret{rssi} = $rssi;
		}
		elsif($_ =~ m/^r/)		### append RSSI ###
		{
			$ret{appendrssi} = 1;
		}
		else {
			Debug "$name: unknown Message part $_" if ($debug);;
		}
		#print "$_\n";
	}
	$ret{pattern} = {%patternList}; 
	return %ret;
}


# Function which dispatches a message if needed.
sub SIGNALdunoAdv_Dispatch
{
	my ($hash, $rmsg, $dmsg, $rssi, $id, $nrEqualDmsg) = @_;
	my $name = $hash->{NAME};
	
	if (!defined($dmsg))
	{
		Log3 $name, 5, "$name Dispatch: dmsg is undef. Skipping dispatch call";
		return;
	}
	
	#Log3 $name, 5, "$name: Dispatch DMSG: $dmsg";
	
	if (IsDummy($name) && defined($hash->{rawListNr})) {	# wenn es das Internal rawListNr gibt, dann wird die Nr per dispatch an das Modul SIGNALduino_TOOL uebergeben
		$rssi = "" if (!defined($rssi));
		$dmsg = lc($dmsg) if ($id eq '74');
		if (substr($rmsg,0,2) ne 'MC') {
			$nrEqualDmsg = "";
		}
		$dmsg = "pt$id#" . $hash->{rawListNr} . "#" . $nrEqualDmsg . "#" . $dmsg;
		Log3 $name, 4, "$name Dispatch: $dmsg, $rssi dispatch";
		Dispatch($hash, $dmsg, undef);  ## Dispatch zum Modul SIGNALduino_TOOL
		return;
	}
	
#	if ($id == 0.4) {
#	   	my $rawmsglist;
#   	    my @lines;
#   	    if (defined($hash->{rawmsgList}))
#   	    {
#   	    	$rawmsglist=$hash->{rawmsgList};
#			@lines = split (' ', $rawmsglist);   # or whatever
#   	    }
#   	    push(@lines,"$dmsg#$rmsg\n");
#		shift(@lines)if (scalar @lines >10);
#		$rawmsglist = join(' ',@lines);
#
#		$hash->{rawmsgList}=$rawmsglist;
#	}
	
	my $DMSGgleich = 1;
	if ($dmsg eq $hash->{LASTDMSG}) {
		Log3 $name, SDUINO_DISPATCH_VERBOSE, "$name Dispatch: $dmsg, test gleich";
	} else {
		if (defined($hash->{DoubleMsgIDs}{$id})) {
			if ($nrEqualDmsg < 2) {	# keine MU-Nachricht oder keine doppelte MU-Nachricht
				$DMSGgleich = 0;
				Log3 $name, SDUINO_DISPATCH_VERBOSE, "$name Dispatch: $dmsg, test ungleich";
			}
			else {
				Log3 $name, SDUINO_DISPATCH_VERBOSE, "$name Dispatch: $dmsg, test gleich ($nrEqualDmsg)";
			}
		}
		else {
			Log3 $name, SDUINO_DISPATCH_VERBOSE, "$name Dispatch: $dmsg, test ungleich: disabled";
		}
		$hash->{LASTDMSG} = $dmsg;
		$hash->{LASTDMSGID} = $id;
	}

   if ($DMSGgleich) {
	#Dispatch if dispatchequals is provided in protocol definition or only if $dmsg is different from last $dmsg, or if 2 seconds are between transmits
	if ( (SIGNALduinoAdv_getProtoProp($id,'dispatchequals',0) eq 'true') || ($hash->{DMSG} ne $dmsg) || ($hash->{TIME}+2 < time() ) )   { 
		$hash->{MSGCNT}++;
		$hash->{TIME} = time();
		$hash->{DMSG} = $dmsg;
		$hash->{EQMSGCNT} = 0;
		#my $event = 0;
		if (substr(ucfirst($dmsg),0,1) eq 'U') { # u oder U
			#$event = 1;
			DoTrigger($name, "DMSG " . $dmsg);
			return if (substr($dmsg,0,1) eq 'U') # Fuer $dmsg die mit U anfangen ist kein Dispatch notwendig, da es dafuer kein Modul gibt klein u wird dagegen dispatcht
		}
		#readingsSingleUpdate($hash, "state", $hash->{READINGS}{state}{VAL}, $event);
		
		if (defined($ProtocolListSIGNALduino{$id}{developId}) && $ProtocolListSIGNALduino{$id}{developId} eq "m") {
			my $IDsNoDispatch = "," . InternalVal($name,"IDsNoDispatch","") . ",";
			if ($IDsNoDispatch ne ",," && index($IDsNoDispatch, ",$id,") >= 0) {	# kein dispatch wenn die Id im Internal IDsNoDispatch steht
				Log3 $name, 3, "$name: ID=$id skiped dispatch (developId=m). $IDsNoDispatch To use, please add $id to the attr whitelist_IDs";
				return;
			}
		}
		
		$hash->{RAWMSG} = $rmsg;
		my %addvals = (
			DMSG => $dmsg,
			Protocol_ID => $id
		);
		if (AttrVal($name,"suppressDeviceRawmsg",0) == 0) {
			$addvals{RAWMSG} = $rmsg;
		}
		$addvals{DMSGequal} = $nrEqualDmsg if ($nrEqualDmsg > 1);
		if(defined($rssi)) {
			$hash->{RSSI} = $rssi;
			$addvals{RSSI} = $rssi;
			$rssi .= " dB,"
		}
		else {
			$rssi = "";
		}
		
		$dmsg = lc($dmsg) if ($id eq '74' || $id eq '74.1');
		Log3 $name, 4, "$name Dispatch: $dmsg, $rssi dispatch";
		Dispatch($hash, $dmsg, \%addvals);  ## Dispatch to other Modules 
		
	}	else {
		$hash->{EQMSGCNT}++;
		Log3 $name, 4, "$name Dispatch: $dmsg, Dropped (" . $hash->{EQMSGCNT} . ") due to short time and equal msg";
	}
   }
}


# calculated RSSI and RSSI value and RSSI string (-77,' RSSI = -77')
sub SIGNALduinoAdv_calcRSSI {
  my $rssi = shift;
  my $rssiStr = '';
  $rssi = ($rssi>=128 ? (($rssi-256)/2-74) : ($rssi/2-74));
  $rssiStr = " RSSI = $rssi";
  return ($rssi,$rssiStr);
}


sub
SIGNALduinoAdv_Parse_MS
{
	my ($hash, $name, $rmsg,%msg_parts) = @_;

	my $protocolid;
	my $syncidx=$msg_parts{syncidx};			
	my $clockidx=$msg_parts{clockidx};				
	my $rssi=$msg_parts{rssi};
	my $protocol=undef;
	my $rawData=$msg_parts{rawData};
	my %patternList;
	my $rssiStr= '';
	
	if (defined($rssi)) {
		($rssi,$rssiStr) = SIGNALduinoAdv_calcRSSI($rssi);
	}
	
    #$patternList{$_} = $msg_parts{rawData}{$_] for keys %msg_parts{rawData};

	#$patternList = \%msg_parts{pattern};

	#Debug "Message splitted:";
	#Debug Dumper(\@msg_parts);

	my $debug = AttrVal($hash->{NAME},"debug",0);
	my $dummy = IsDummy($hash->{NAME});
	
	if (defined($clockidx) and defined($syncidx))
	{
		## Make a lookup table for our pattern index ids
		#Debug "List of pattern:";
		my $clockabs= $msg_parts{pattern}{$msg_parts{clockidx}};
		return if ($clockabs == 0); 
		$patternList{$_} = round($msg_parts{pattern}{$_}/$clockabs,1) for keys %{$msg_parts{pattern}};
		
 		#Debug Dumper(\%patternList);		

		#### Convert rawData in Message
		my $signal_length = length($rawData);        # Length of data array

		## Iterate over the data_array and find zero, one, float and sync bits with the signalpattern
		## Find matching protocols
		my $message_dispatched=0;
		foreach my $id (@{$hash->{msIdList}}) {
			
			my $valid=1;
			Debug "Testing against Protocol id $id -> $ProtocolListSIGNALduino{$id}{name}"  if ($debug);

			# Check Clock if is it in range
			if ($ProtocolListSIGNALduino{$id}{clockabs} > 0) {
				if (!SIGNALduinoAdv_inTol($ProtocolListSIGNALduino{$id}{clockabs},$clockabs,$clockabs*0.30)) {
					Log3 $name, 5, "$name: MS ID=$id protocClock=$ProtocolListSIGNALduino{$id}{clockabs}, msgClock=$clockabs is not in tol=" . $clockabs*0.30 if ($debug || $dummy);  
					next;
				} elsif ($debug) {
					Debug "protocClock=$ProtocolListSIGNALduino{$id}{clockabs}, msgClock=$clockabs is in tol=" . $clockabs*0.30;
				}
			}
			
			#Debug Dumper(@{$ProtocolListSIGNALduino{$id}{sync}});
			Debug "Searching in patternList: ".Dumper(\%patternList) if($debug);
			Debug "searching sync: @{$ProtocolListSIGNALduino{$id}{sync}}[0] @{$ProtocolListSIGNALduino{$id}{sync}}[1]" if($debug); # z.B. [1, -18] 
			#$valid = $valid && SIGNALduino_inTol($patternList{$clockidx}, @{$ProtocolListSIGNALduino{$id}{sync}}[0], 3); #sync in tolerance
			#$valid = $valid && SIGNALduino_inTol($patternList{$syncidx}, @{$ProtocolListSIGNALduino{$id}{sync}}[1], 3); #sync in tolerance
			
			my $pstr;
			my %patternLookupHash=();
			my %endPatternLookupHash=();
			
			## sync
			if (($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{sync}},\%patternList,\$rawData)) eq -1) {
				Debug "sync not found" if ($debug);
				next;
			}
			Debug "Found matched sync with indexes: ($pstr)" if ($debug);
			$patternLookupHash{$pstr}=""; ## Append Sync to our lookuptable
			
			my $message_start = index($rawData,$pstr)+length($pstr);
			my $signal_width= @{$ProtocolListSIGNALduino{$id}{one}};
			my $bit_length = ($signal_length-$message_start) / $signal_width;
			Debug "expecting $bit_length bits in signal" if ($debug);
			
			#Check calculated min length
			if (exists($ProtocolListSIGNALduino{$id}{length_min}) && $ProtocolListSIGNALduino{$id}{length_min} > $bit_length) {
				Debug "bit_length=$bit_length to short" if ($debug);
				Log3 $name, 5, "$name: MS ID=$id length_min=$ProtocolListSIGNALduino{$id}{length_min}, bit_length=$bit_length to short" if ($dummy);
				next;
			}
			
			## one
			if (($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{one}},\%patternList,\$rawData)) eq -1) {
				Debug "one pattern not found" if ($debug);
				next;
			}
			Debug "Found matched one with indexes: ($pstr)" if ($debug);
			$patternLookupHash{$pstr}="1";		## Append One to our lookuptable
			if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
				chop($pstr);
				$endPatternLookupHash{$pstr}="1";
			}
			
			## zero
			if (($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{zero}},\%patternList,\$rawData)) eq -1) {
				Debug "zero pattern not found" if ($debug);
				next;
			}
			Debug "Found matched zero with indexes: ($pstr)" if ($debug);
			$patternLookupHash{$pstr}="0";		## Append Zero to our lookuptable
			if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
				chop($pstr);
				$endPatternLookupHash{$pstr}="0";
			}
			
			## float
			if (defined($ProtocolListSIGNALduino{$id}{float}) && ($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{float}},\%patternList,\$rawData)) >=0) {
				Debug "Found matched float with indexes: ($pstr)" if ($debug);
				$patternLookupHash{$pstr}="F";	## Append Float to our lookuptable
				if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
					chop($pstr);
					$endPatternLookupHash{$pstr}="F";
				}
			}

			#Debug "Pattern Lookup Table".Dumper(%patternLookupHash);
		
			#Anything seems to be valid, we can start decoding this.			

			Log3 $name, 4, "$name: Matched MS Protocol id $id -> $ProtocolListSIGNALduino{$id}{name}, bitLen=$bit_length";
			
			my @bit_msg;							# array to store decoded signal bits

			Log3 $name, 5, "$name: Starting demodulation at Position $message_start";
			
			for (my $i=$message_start;$i<length($rawData);$i+=$signal_width)
			{
				my $sigStr= substr($rawData,$i,$signal_width);
				#Log3 $name, 5, "demodulating $sig_str";
				#Debug $patternLookupHash{substr($rawData,$i,$signal_width)}; ## Get $signal_width number of chars from raw data string
				if (exists $patternLookupHash{$sigStr}) { ## Add the bits to our bit array
					push(@bit_msg,$patternLookupHash{$sigStr}) if ($patternLookupHash{$sigStr} ne '');
				} elsif (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
					if (length($sigStr) == $signal_width) {			# ist $sigStr zu lang?
						chop($sigStr);
					}
					if (exists($endPatternLookupHash{$sigStr})) {
						push(@bit_msg,$endPatternLookupHash{$sigStr});
						Log3 $name, 4, "$name: last part pair=$sigStr reconstructed, last bit=$endPatternLookupHash{$sigStr}, bitLen=" . scalar @bit_msg;
					}
					else {
						Log3 $name, 5, "$name: can't reconstruct last part pair=$sigStr, bitLen=" . scalar @bit_msg;
					}
					last;
				} else {
					Log3 $name, 5, "$name: Found wrong signalpattern $sigStr, catched ".scalar @bit_msg." bits, aborting demodulation";
					last;
				}
			}
			
			Debug "$name: decoded message raw (@bit_msg), ".@bit_msg." bits\n" if ($debug);
			
			#Check converted message against lengths
			my ($rcode, $rtxt) = SIGNALduinoAdv_TestLength(undef,$id,scalar @bit_msg,"");
			if (!$rcode)
			{
			  Log3 $name, 5, "$name: decoded $rtxt" if ($debug || $dummy);
			  next;
			}
			
			my $padwith = defined($ProtocolListSIGNALduino{$id}{paddingbits}) ? $ProtocolListSIGNALduino{$id}{paddingbits} : 4;
			my $i=0;
			while (scalar @bit_msg % $padwith > 0)  ## will pad up full nibbles per default or full byte if specified in protocol
			{
				push(@bit_msg,0);
				$i++;
			}
			Debug "$name padded $i bits to bit_msg array" if ($debug);
			
			if ($i == 0) {
				Log3 $name, 5, "$name: dispatching bits: @bit_msg";
			} else {
				Log3 $name, 5, "$name: dispatching bits: @bit_msg with $i Paddingbits 0";
			}
			
			if (exists($ProtocolListSIGNALduino{$id}{postDemodulation})) {
				my @retvalue;
				($rcode,@retvalue) = SIGNALduinoAdv_callsub('postDemodulation',$ProtocolListSIGNALduino{$id}{postDemodulation},$name,@bit_msg);
				next if ($rcode < 1 );
				#Log3 $name, 5, "$name: postdemodulation value @retvalue";
				@bit_msg = @retvalue;
				undef(@retvalue); undef($rcode);
			}
			
			#my $dmsg = sprintf "%02x", oct "0b" . join "", @bit_msg;			## Array -> String -> bin -> hex
			my $dmsg = SIGNALduinoAdv_b2h(join "", @bit_msg);
			my $postamble = $ProtocolListSIGNALduino{$id}{postamble};
			#if (defined($rawRssi)) {
				#if (defined($ProtocolListSIGNALduino{$id}{preamble}) && $ProtocolListSIGNALduino{$id}{preamble} eq "s") {
				#	$postamble = sprintf("%02X", $rawRssi);
				#} elsif ($id eq "7") {
				#        $postamble = "#R" . sprintf("%02X", $rawRssi);
				#}
			#}
			$dmsg = "$dmsg".$postamble if (defined($postamble));
			$dmsg = "$ProtocolListSIGNALduino{$id}{preamble}"."$dmsg" if (defined($ProtocolListSIGNALduino{$id}{preamble}));
			
			Log3 $name, 4, "$name: Decoded MS Protocol id $id dmsg $dmsg length " . scalar @bit_msg . $rssiStr;
			
			#my ($rcode,@retvalue) = SIGNALduino_callsub('preDispatchfunc',$ProtocolListSIGNALduino{$id}{preDispatchfunc},$name,$dmsg);
			#next if (!$rcode);
			#$dmsg = @retvalue;
			#undef(@retvalue); undef($rcode);
			
			my $modulematch = undef;
			if (defined($ProtocolListSIGNALduino{$id}{modulematch})) {
				$modulematch = $ProtocolListSIGNALduino{$id}{modulematch};
			}
			if (!defined($modulematch) || $dmsg =~ m/$modulematch/) {
				Debug "$name: dispatching now msg: $dmsg" if ($debug);
				#if (defined($ProtocolListSIGNALduino{$id}{developId}) && substr($ProtocolListSIGNALduino{$id}{developId},0,1) eq "m") {
				#	my $devid = "m$id";
				#	my $develop = lc(AttrVal($name,"development",""));
				#	if ($develop !~ m/$devid/) {		# kein dispatch wenn die Id nicht im Attribut development steht
				#		Log3 $name, 3, "$name: ID=$devid skiped dispatch (developId=m). To use, please add m$id to the attr development";
				#		next;
				#	}
				#}
				SIGNALdunoAdv_Dispatch($hash,$rmsg,$dmsg,$rssi,$id,0);
				$message_dispatched=1;
			}
		}
		
		return 0 if (!$message_dispatched);
		
		return 1;
		

	} else {
		Log3 $name, 3, "$name ParseMS Error! clockidx or syncidx isn't valid: $rmsg";
		return 0
	}
}


## //Todo: check list as reference
sub SIGNALduinoAdv_padbits(\@$)
{
	my $i=@{$_[0]} % $_[1];
	while (@{$_[0]} % $_[1] > 0)  ## will pad up full nibbles per default or full byte if specified in protocol
	{
		push(@{$_[0]},'0');
	}
	return " padded $i bits to bit_msg array";
}

# - - - - - - - - - - - -
#=item SIGNALduinoAdv_getProtoProp()
#This functons, will return a value from the Protocolist and check if it is defined optional you can specify a optional default value that will be reurned
# 
# returns "" if the var is not defined
# =cut
#  $id, $propertyname,

sub SIGNALduinoAdv_getProtoProp
{
	my ($id,$propNameLst,$default) = @_;
	
	#my $id = shift;
	#my $propNameLst = shift;
	return $ProtocolListSIGNALduino{$id}{$propNameLst} if defined($ProtocolListSIGNALduino{$id}{$propNameLst});
	return $default; # Will return undef if $default is not provided
	#return undef;
}


sub SIGNALduinoAdv_Parse_MU_Dispatch
{
	my ($hash,$rmsg,$dmsg,$rssi,$id,$nrEqualDmsg) = @_;
	my $modulematch;
	
	if (defined($ProtocolListSIGNALduino{$id}{modulematch})) {
		$modulematch = $ProtocolListSIGNALduino{$id}{modulematch};
	}
	if (!defined($modulematch) || $dmsg =~ m/$modulematch/) {
		SIGNALdunoAdv_Dispatch($hash,$rmsg,$dmsg,$rssi,$id,$nrEqualDmsg);
		return 1;
	}
	return 0;
}


sub SIGNALduinoAdv_Parse_MU
{
	my ($hash, $name, $rmsg,%msg_parts) = @_;

	my $protocolid;
	my $clockidx=$msg_parts{clockidx};
	my $rssi=$msg_parts{rssi};
	my $rawData;
	my %patternListRaw;
	my $message_dispatched=0;
	my $debug = AttrVal($name,"debug",0);
	my $maxRepeat = AttrVal($name,"maxMuMsgRepeat", 4);
	my $parseMUclockCheck = AttrVal($name,"parseMUclockCheck",0);
	my $dummy = IsDummy($name);
	my $rssiStr= '';
	
	if (defined($rssi)) {
		($rssi,$rssiStr) = SIGNALduinoAdv_calcRSSI($rssi);
	}
	
    Debug "$name: processing unsynced message\n" if ($debug);

	my $clockabs = 1;  #Clock will be fetched from Protocol if possible
	#$patternListRaw{$_} = floor($msg_parts{pattern}{$_}/$clockabs) for keys $msg_parts{pattern};
	$patternListRaw{$_} = $msg_parts{pattern}{$_} for keys %{$msg_parts{pattern}};

	
	if (defined($clockidx))
	{
		
		## Make a lookup table for our pattern index ids
		#Debug "List of pattern:"; 		#Debug Dumper(\%patternList);		

		## Find matching protocols
		foreach my $id (@{$hash->{muIdList}}) {
			
			#my $valid=1;
			$clockabs= $ProtocolListSIGNALduino{$id}{clockabs};
			my %patternList;
			$rawData=$msg_parts{rawData};
			if (exists($ProtocolListSIGNALduino{$id}{filterfunc}))
			{
				my $method = $ProtocolListSIGNALduino{$id}{filterfunc};
		   		if (!exists &$method)
				{
					Log3 $name, 5, "$name: Error: Unknown filterfunc, please check the definition";
					next;
				} else {					
					Log3 $name, 5, "$name: for MU Protocol id $id, applying filterfunc" if ($debug);

					(my $count_changes,$rawData,my %patternListRaw_tmp) = $method->($name,$id,$rawData,%patternListRaw);

					%patternList = map { $_ => round($patternListRaw_tmp{$_}/$clockabs,1) } keys %patternListRaw_tmp; 
				}
			} else {
				%patternList = map { $_ => round($patternListRaw{$_}/$clockabs,1) } keys %patternListRaw; 
			}
			
			my $msgclock;
			my $clocksource = "";
			my $clockMsg = "";
			if (defined($ProtocolListSIGNALduino{$id}{clockpos}) && defined($ProtocolListSIGNALduino{$id}{clockpos}[0]))
			{
				$clocksource = $ProtocolListSIGNALduino{$id}{clockpos}[0];
				if ($clocksource ne "one" && $clocksource ne "zero") {	# wenn clocksource nicht one oder zero ist, dann wird CP= aus der Nachricht verwendet
					$msgclock = $msg_parts{pattern}{$clockidx};
					if (!SIGNALduinoAdv_inTol($clockabs,$msgclock,$msgclock*0.30)) {
						Log3 $name, 5, "$name: clock for MU Protocol id $id, clockId=$clockabs, clockmsg=$msgclock (cp) is not in tol=" . $msgclock*0.30 if ($dummy||$debug);
						next if ($parseMUclockCheck > 0);
					} else {
						$clockMsg = ", msgClock=$msgclock (cp) is in tol" if ($dummy||$debug||$parseMUclockCheck==2);
					}
				}
			}
			
			#Debug Dumper(\%patternList);	
					
			Debug "Testing against Protocol id $id -> $ProtocolListSIGNALduino{$id}{name}"  if ($debug);

			Debug "Searching in patternList: ".Dumper(\%patternList) if($debug);

			my @msgStartLst;
			my @pstrAr = ('','','');
			my $startStr=""; # Default match if there is no start pattern available
			my $message_start=0 ;
			my $startLogStr="";
			
			if (defined($ProtocolListSIGNALduino{$id}{starti}))
			{
				if (defined($ProtocolListSIGNALduino{$id}{start2}) && scalar @{$ProtocolListSIGNALduino{$id}{start2}} >0)
				{
					if (($pstrAr[2]=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{start2}},\%patternList,\$rawData)) eq -1) {
						Log3 $name, 5, "$name: start2 pattern(starti) for MU Protocol id $id not found, aborting" if ($dummy);
						next;
					}
				}
				if (($pstrAr[1]=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{one}},\%patternList,\$rawData)) eq -1)
				{
					Log3 $name, 5, "$name: one pattern(starti) for MU Protocol id $id not found, aborting" if ($dummy);
					next;
				}
				if (defined($ProtocolListSIGNALduino{$id}{zero}) && scalar @{$ProtocolListSIGNALduino{$id}{zero}} >0)
				{
					if  (($pstrAr[0]=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{zero}},\%patternList,\$rawData)) eq -1) {
						Log3 $name, 5, "$name: zero pattern(starti) for MU Protocol id $id not found, aborting" if ($dummy);
						next;
					}
				}
				foreach my $startStrIdx (@{$ProtocolListSIGNALduino{$id}{starti}}) {
					$startStr .= $pstrAr[$startStrIdx];
				}
				Log3 $name, 5, "$name: startStr(starti) $startStr for MU Protocol id $id" if ($dummy || $debug);
				#Debug "startStr(starti) id=$id is: $startStr" if ($debug);
			}
			elsif (defined($ProtocolListSIGNALduino{$id}{start}))	# wenn start definiert ist, dann startStr ermitteln und in rawData suchen und in der rawData alles bis zum startStr abschneiden
			{
				@msgStartLst = $ProtocolListSIGNALduino{$id}{start};
				Debug "msgStartLst: ".Dumper(@msgStartLst)  if ($debug);
				
				if ( ($startStr=SIGNALduinoAdv_PatternExists($hash,@msgStartLst,\%patternList,\$rawData)) eq -1)
				{
					Log3 $name, 5, "$name: start pattern for MU Protocol id $id -> $ProtocolListSIGNALduino{$id}{name} not found, aborting" if ($dummy);
					next;
				}
				Debug "startStr is: $startStr" if ($debug);
			}
			
			if ($startStr ne '') {
				$message_start = index($rawData, $startStr);
				if ($message_start >= 0) {
					$rawData = substr($rawData, $message_start);
					$startLogStr = "StartStr: $startStr cut Pos $message_start" . "; ";
					Debug "rawData = $rawData" if ($debug);
					Debug "startStr $startStr found. Message starts at $message_start" if ($debug);
				} else {
					Debug "startStr $startStr not found." if ($debug);
					next;
				}
			}
			
			my %patternLookupHash=();
			my %endPatternLookupHash=();
			my $pstr="";
			my $zeroRegex ="";
			my $oneRegex ="";
			my $floatRegex ="";
			my $protocListClock;
			
			if ($pstrAr[1] ne '') {
				$pstr = $pstrAr[1];
			}
			elsif (($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{one}},\%patternList,\$rawData)) eq -1) {
				Log3 $name, 5, "$name: one pattern for MU Protocol id $id not found, aborting" if ($dummy);
				next;
			}
			Debug "Found matched one" if ($debug);
			if ($clocksource eq "one")		# clocksource one, dann die clock aus one holen
			{
				$msgclock = $msg_parts{pattern}{substr($pstr, $ProtocolListSIGNALduino{$id}{clockpos}[1], 1)};
				$protocListClock = $clockabs * $ProtocolListSIGNALduino{$id}{one}[$ProtocolListSIGNALduino{$id}{clockpos}[1]];
				if (!SIGNALduinoAdv_inTol($protocListClock,$msgclock,$msgclock*0.30)) {
					Log3 $name, 5, "$name: clock for MU Protocol id $id, protocClock=$protocListClock, msgClock=$msgclock (one) is not in tol=" . $msgclock*0.30 if ($dummy||$debug);
					next if ($parseMUclockCheck > 0);
				} else {
					$clockMsg = ", msgClock=$msgclock (one) is in tol" if ($dummy||$debug||$parseMUclockCheck==2);
				}
			}
			$oneRegex=$pstr;
			$patternLookupHash{$pstr}="1";		## Append one to our lookuptable
			Debug "added $pstr " if ($debug);
			if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
				chop($pstr);
				$endPatternLookupHash{$pstr} = "1";
			}
			
			$pstr = '';
			if ($pstrAr[1] ne '') {  # wenn es ein one pstr gibt, dann wurden one und zero bereits ermittelt
				if ($pstrAr[0] ne '') {
					$pstr = $pstrAr[0];
				}
			}
			elsif (defined($ProtocolListSIGNALduino{$id}{zero}) && scalar @{$ProtocolListSIGNALduino{$id}{zero}} >0)
			{
				if  (($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{zero}},\%patternList,\$rawData)) eq -1)
				{
					Log3 $name, 5, "$name: zero pattern for MU Protocol id $id not found, aborting" if ($dummy);
					next;
				}
			}
			if ($pstr ne '') {
				Debug "Found matched zero" if ($debug);
				if ($clocksource eq "zero")		# clocksource zero, dann die clock aus zero holen
				{
					$msgclock = $msg_parts{pattern}{substr($pstr, $ProtocolListSIGNALduino{$id}{clockpos}[1], 1)};
					$protocListClock = $clockabs * $ProtocolListSIGNALduino{$id}{zero}[$ProtocolListSIGNALduino{$id}{clockpos}[1]];
					if (!SIGNALduinoAdv_inTol($protocListClock,$msgclock,$msgclock*0.30)) {
						Log3 $name, 5, "$name: clock for MU Protocol id $id, protocClock=$protocListClock, msgClock=$msgclock (zero) is not in tol=" . $msgclock*0.30 if ($dummy||$debug);
						next if ($parseMUclockCheck > 0);
					} else {
						$clockMsg = ", msgClock=$msgclock (zero) is in tol" if ($dummy||$debug||$parseMUclockCheck==2);
					}
				}
				$zeroRegex='|' . $pstr;
				$patternLookupHash{$pstr}="0";		## Append zero to our lookuptable
				Debug "added $pstr " if ($debug);
				if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
					chop($pstr);
					$endPatternLookupHash{$pstr} = "0";
				}
			}

			if (defined($ProtocolListSIGNALduino{$id}{float}) && ($pstr=SIGNALduinoAdv_PatternExists($hash,\@{$ProtocolListSIGNALduino{$id}{float}},\%patternList,\$rawData)) >=0)
			{
				Debug "Found matched float" if ($debug);
				$floatRegex='|' . $pstr;
				$patternLookupHash{$pstr}="F";		## Append float to our lookuptable
				Debug "added $pstr " if ($debug);
				if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
					chop($pstr);
					$endPatternLookupHash{$pstr} = "F";
				}
			}
			
			#Debug "Pattern Lookup Table".Dumper(%patternLookupHash);
			Log3 $name, 4, "$name: Fingerprint for MU Protocol id $id -> $ProtocolListSIGNALduino{$id}{name} matches, trying to demodulate$clockMsg";
			
			my $signal_width= @{$ProtocolListSIGNALduino{$id}{one}};
			my $length_min;
			if (defined($ProtocolListSIGNALduino{$id}{length_min})) {
				$length_min = $ProtocolListSIGNALduino{$id}{length_min};
			} else {
				$length_min = SDUINO_PARSE_DEFAULT_LENGHT_MIN;
			}
			my $length_max = 0;
			$length_max = $ProtocolListSIGNALduino{$id}{length_max} if (defined($ProtocolListSIGNALduino{$id}{length_max}));
			
			my $signalRegex = "(?:" . $oneRegex . $zeroRegex . $floatRegex . "){$length_min,}";
			
			if (exists($ProtocolListSIGNALduino{$id}{reconstructBit})) {
				#$signalRegex .= "(?:" . $oneRegex . $partZero . $partFloat . ")?";
				$signalRegex .= "(?:" . join("|",keys %endPatternLookupHash) . ")?";
			}
			my $regex="(?:$startStr)($signalRegex)";
			
			Debug "Regex is: $regex" if ($debug);
			
			my $repeat=0;
			my $repeatStr="";
			my $length_str;
			my $bit_msg_length;
			my $nrRestart = 0;
			my $dmsg = "";
			my $lastDmsg = "";
			my $nrEqualDmsg = 1;
			my $ret;
			
			while ( $rawData =~ m/$regex/g) {
				#Log3 $name, 5, "$name: regex=$regex part=$1";
				my @pairs = unpack "(a$signal_width)*", $1;
				$message_start = $-[0];
				$bit_msg_length = scalar @pairs;
				
				if ($length_max > 0 && $bit_msg_length > $length_max) {		# ist die Nachricht zu lang?
					$length_str = " (length $bit_msg_length to long)";
				} else {
					$length_str = "";
				}
				
				if ($nrRestart == 0) {
					Log3 $name, 5, "$name: Starting demodulation ($startLogStr" . "Signal: $signalRegex Pos $message_start) length_min_max (".$length_min."..".$length_max.") length=".$bit_msg_length;
					Log3 $name, 5, "$name: skip demodulation (length $bit_msg_length is to long)" if ($length_str ne "");
				} else {
					Log3 $name, 5, "$name: $nrRestart.restarting demodulation$length_str at Pos $message_start regex ($regex)";
				}
				
				$nrRestart++;
				next if ($length_str ne "");	# Nachricht ist zu lang
				
				
				#Anything seems to be valid, we can start decoding this.			
				
				my @bit_msg=();			# array to store decoded signal bits
				
				foreach my $sigStr (@pairs)
				{
					if (exists $patternLookupHash{$sigStr}) {
						push(@bit_msg,$patternLookupHash{$sigStr})  ## Add the bits to our bit array
					}
					elsif (exists($ProtocolListSIGNALduino{$id}{reconstructBit}) && exists($endPatternLookupHash{$sigStr})) {
						my $lastbit = $endPatternLookupHash{$sigStr};
						push(@bit_msg,$lastbit);
						Log3 $name, 4, "$name: last part pair=$sigStr reconstructed, bit=$lastbit";
					}
				}
				
					Debug "$name: demodulated message raw (@bit_msg), ".@bit_msg." bits\n" if ($debug);
					
					if (exists($ProtocolListSIGNALduino{$id}{postDemodulation})) {
						my ($rcode,@retvalue) = SIGNALduinoAdv_callsub('postDemodulation',$ProtocolListSIGNALduino{$id}{postDemodulation},$name,@bit_msg);
						next if ($rcode < 1 );
						@bit_msg = @retvalue;
						Log3 $name, 5, "$name: postdemodulation value @retvalue" if ($debug);
						undef(@retvalue); undef($rcode);
					}
					
					my $bit_msg_length = scalar @bit_msg;
					
					if (defined($ProtocolListSIGNALduino{$id}{dispatchBin})) {
						$dmsg = join ("", @bit_msg);
						Log3 $name, 5, "$name: dispatching bits: $dmsg";
					} else {
						my $anzPadding = 0;
						my $padwith = defined($ProtocolListSIGNALduino{$id}{paddingbits}) ? $ProtocolListSIGNALduino{$id}{paddingbits} : 4;
						while (scalar @bit_msg % $padwith > 0)  ## will pad up full nibbles per default or full byte if specified in protocol
						{
							push(@bit_msg,'0');
							$anzPadding++;
							Debug "$name: padding 0 bit to bit_msg array" if ($debug);
						}
						$dmsg = join ("", @bit_msg);
						if ($anzPadding == 0) {
							Log3 $name, 5, "$name: dispatching bits: $dmsg";
						} else {
							Log3 $name, 5, "$name: dispatching bits: $dmsg with anzPadding=$anzPadding";
						}
						$dmsg = SIGNALduinoAdv_b2h($dmsg);
					}
					@bit_msg=(); # clear bit_msg array
					
					$dmsg =~ s/^0+//	 if (defined($ProtocolListSIGNALduino{$id}{remove_zero})); 
					$dmsg = "$dmsg"."$ProtocolListSIGNALduino{$id}{postamble}" if (defined($ProtocolListSIGNALduino{$id}{postamble}));
					$dmsg = "$ProtocolListSIGNALduino{$id}{preamble}"."$dmsg" if (defined($ProtocolListSIGNALduino{$id}{preamble}));
					
					Log3 $name, 4, "$name: decoded matched MU Protocol id $id dmsg $dmsg length $bit_msg_length" . $repeatStr . $rssiStr;
					
					if (SIGNALduinoAdv_getProtoProp($id,'dispatchequals',0) eq 'true' || defined($hash->{rawListNr})) {
						$lastDmsg = $dmsg;
						$dmsg = 'eq';
					}
					
					if ($dmsg eq $lastDmsg) {
						$nrEqualDmsg++
					}
					else {
						if ($lastDmsg ne "") {
							Log3 $name, 4, "$name: equalDMS $lastDmsg ($nrEqualDmsg)";
							$ret = SIGNALduinoAdv_Parse_MU_Dispatch($hash,$rmsg,$lastDmsg,$rssi,$id,$nrEqualDmsg);
							$message_dispatched = 1 if $ret;
						}
						$lastDmsg = $dmsg if ($dmsg ne 'eq');
						$nrEqualDmsg = 1;
					}
					
					$repeat++;
					$repeatStr = " repeat $repeat";
					last if ($repeat > $maxRepeat);	# Abbruch, wenn die max repeat anzahl erreicht ist
			}
			if ($dmsg eq $lastDmsg && $lastDmsg ne "") {
				Log3 $name, 4, "$name: equalDMS $dmsg ($nrEqualDmsg)";
				$ret = SIGNALduinoAdv_Parse_MU_Dispatch($hash,$rmsg,$dmsg,$rssi,$id,$nrEqualDmsg);
				$message_dispatched = 1 if $ret;
			}
			Log3 $name, 5, "$name: regex ($regex) did not match, aborting" if ($nrRestart == 0);
		}
		return 0 if (!$message_dispatched);
		
		return 1;
	} else {
		Log3 $name, 3, "$name ParseMU Error! clockidx isn't valid: $rmsg";
		return 0
	}
}


sub
SIGNALduinoAdv_Parse_MC
{

	my ($hash, $name, $rmsg,%msg_parts) = @_;
	my $clock=$msg_parts{clockabs};	     ## absolute clock
	my $rawData=$msg_parts{rawData};
	my $rssi=$msg_parts{rssi};
	my $mcbitnum=$msg_parts{mcbitnum};
	my $messagetype=$msg_parts{messagetype};
	my $bitData;
	my $dmsg;
	my $message_dispatched=0;
	my $debug = AttrVal($name,"debug",0);
	my $rssiStr= '';
	
	if (defined($rssi)) {
		($rssi,$rssiStr) = SIGNALduinoAdv_calcRSSI($rssi);
	}
	
	if (!$clock) {
		Log3 $name, 3, "$name ParseMC Error! clock isn't num: $rmsg";
		return;
	}
	if (!$mcbitnum) {
		Log3 $name, 3, "$name ParseMC Error! mcbitnum isn't num: $rmsg";
		return;
	}
	
	#my $protocol=undef;
	#my %patternListRaw = %msg_parts{patternList};
	
	Debug "$name: processing manchester message len:".length($rawData) if ($debug);
	
	my $hlen = length($rawData);
	my $blen;
	#if (defined($mcbitnum)) {
	#	$blen = $mcbitnum;
	#} else {
		$blen = $hlen * 4;
	#}
	
	my $rawDataInverted;
	($rawDataInverted = $rawData) =~ tr/0123456789ABCDEF/FEDCBA9876543210/;   # Some Manchester Data is inverted
	
	foreach my $id (@{$hash->{mcIdList}}) {

		#next if ($blen < $ProtocolListSIGNALduino{$id}{length_min} || $blen > $ProtocolListSIGNALduino{$id}{length_max});
		#if ( $clock >$ProtocolListSIGNALduino{$id}{clockrange}[0] and $clock <$ProtocolListSIGNALduino{$id}{clockrange}[1]);
		if ( $clock >$ProtocolListSIGNALduino{$id}{clockrange}[0] and $clock <$ProtocolListSIGNALduino{$id}{clockrange}[1] and length($rawData)*4 >= $ProtocolListSIGNALduino{$id}{length_min} )
		{
			Debug "clock and min length matched"  if ($debug);
			
			Log3 $name, 4, "$name: Found manchester Protocol id $id clock $clock" . "$rssiStr -> $ProtocolListSIGNALduino{$id}{name}";
			
			my $polarityInvert = 0;
			if (exists($ProtocolListSIGNALduino{$id}{polarity}) && ($ProtocolListSIGNALduino{$id}{polarity} eq 'invert'))
			{
				$polarityInvert = 1;
			}
			if ($messagetype eq 'Mc' || (defined($hash->{version}) && substr($hash->{version},0,6) eq 'V 3.2.'))
			{
				$polarityInvert = $polarityInvert ^ 1;
			}
			if ($polarityInvert == 1)
			{
		   		$bitData= unpack("B$blen", pack("H$hlen", $rawDataInverted)); 
			} else {
		   		$bitData= unpack("B$blen", pack("H$hlen", $rawData)); 
			}
			Debug "$name: extracted data $bitData (bin)\n" if ($debug); ## Convert Message from hex to bits
		   	Log3 $name, 5, "$name: extracted data $bitData (bin)";
			
			if (!exists $ProtocolListSIGNALduino{$id}{method}) {
				Log3 $name, 3, "$name ParseMC: Error ID=$id, no method defined, it must be defined in the protocol hash!";
				next;
			}
			
			my $method = $ProtocolListSIGNALduino{$id}{method};
		    if (!defined &$method)
			{
				Log3 $name, 3, "$name ParseMC: Error ID=$id, Unknown method. Please check it!";
			} else {
				$mcbitnum = length($bitData) if ($mcbitnum > length($bitData));
				my ($rcode,$res) = $method->($name,$bitData,$id,$mcbitnum);
				if ($rcode != -1) {
					$dmsg = $res;
					$dmsg=$ProtocolListSIGNALduino{$id}{preamble}.$dmsg if (defined($ProtocolListSIGNALduino{$id}{preamble})); 
					my $modulematch;
					if (defined($ProtocolListSIGNALduino{$id}{modulematch})) {
		                $modulematch = $ProtocolListSIGNALduino{$id}{modulematch};
					}
					if (!defined($modulematch) || $dmsg =~ m/$modulematch/) {
						#if (defined($ProtocolListSIGNALduino{$id}{developId}) && substr($ProtocolListSIGNALduino{$id}{developId},0,1) eq "m") {
						#	my $devid = "m$id";
						#	my $develop = lc(AttrVal($name,"development",""));
						#	if ($develop !~ m/$devid/) {		# kein dispatch wenn die Id nicht im Attribut development steht
						#		Log3 $name, 3, "$name: ID=$devid skiped dispatch (developId=m). To use, please add m$id to the attr development";
						#		next;
						#	}
						#}
						if (SDUINO_MC_DISPATCH_VERBOSE < 5 && (SDUINO_MC_DISPATCH_LOG_ID eq '' || SDUINO_MC_DISPATCH_LOG_ID eq $id))
						{
							Log3 $name, SDUINO_MC_DISPATCH_VERBOSE, "$name $id, $rmsg $rssiStr";
						}
						my $nrEqualDmsg = 0;
						if ($rcode > 1) {
							$nrEqualDmsg = $rcode;
						}
						SIGNALdunoAdv_Dispatch($hash,$rmsg,$dmsg,$rssi,$id,$nrEqualDmsg);
						$message_dispatched=1;
					}
				} else {
					$res="undef" if (!defined($res));
					Log3 $name, 5, "$name: protocol does not match return from method: ($res)" ; 
				}
			}
		}
			
	}
	return 0 if (!$message_dispatched);
	return 1;
}

sub SIGNALduinoAdv_Parse_MN
{
	my ($hash, $name, $rmsg,%msg_parts) = @_;
	my $rawData=$msg_parts{rawData};
	my $rssi=$msg_parts{rssi};
	my $N=$msg_parts{N};
	my $dmsg;
	my $debug = AttrVal($name,"debug",0);
	my $rssi_for;
	my $rssiStr= '';
	
	if (defined($msg_parts{appendrssi})) {
		$rssi = hex(substr($rawData,-4,2));
	}
	if (defined($rssi)) {
		($rssi,$rssiStr) = SIGNALduinoAdv_calcRSSI($rssi);
	}
	my $hlen = length($rawData);
	my $match;
	my $modulation;
	foreach my $id (@{$hash->{mnIdList}}) {
		$modulation = SIGNALduinoAdv_getProtoProp($id,"modulation","xFSK");
		$match = SIGNALduinoAdv_getProtoProp($id,"match","");
		
		if (!defined($N)) {		# die empfangenen FSK Nachrichten enthalten keine N Nr
			next if (SIGNALduinoAdv_getProtoProp($id,"defaultNoN","") ne "1" && scalar(@{$hash->{mnIdList}}) > 1);  # Abbruch
		}
		else {
			#next if ($N ne SIGNALduino_getProtoProp($id,"N",""));	# Abbruch wenn N Nr nicht uebereinstimmt
			my $nFlag = 0;
			foreach my $p (@{$ProtocolListSIGNALduino{$id}{N}}) {
				if ($N == $p) {
					$nFlag = 1;
				}
				#Log3 $name, 4, "$name Parse_MN: ID=$id N=$N Np=$p";
			}
			next if $nFlag == 0;
		}
		if ($match eq "" || $rawData =~ m/$match/) {
			if (!defined($rssi) && defined($ProtocolListSIGNALduino{$id}{rssiPos})) {
				($rssi_for,$rssiStr) = SIGNALduinoAdv_calcRSSI(hex(substr($rawData, $ProtocolListSIGNALduino{$id}{rssiPos}, 2)));
				if (defined($ProtocolListSIGNALduino{$id}{lqiPos})) {
					$rssiStr .= ' LQI = ' . hex(substr($rawData, $ProtocolListSIGNALduino{$id}{lqiPos}, 2));
				}
			}
			else {
				$rssi_for = $rssi;
			}
			Log3 $name, 4, "$name Parse_MN: Found $modulation Protocol id $id length $hlen" . "$rssiStr -> $ProtocolListSIGNALduino{$id}{name}";
		}
		else {
			next;
		}
		
		if (defined(($ProtocolListSIGNALduino{$id}{length_min})) && $hlen < $ProtocolListSIGNALduino{$id}{length_min}) {
			Log3 $name, 4, "$name ParseMN: Error! ID=$id msg=$rawData ($hlen) too short, min=" . $ProtocolListSIGNALduino{$id}{length_min};
			next;
		}
		
		if (!exists $ProtocolListSIGNALduino{$id}{method}) {
			Log3 $name, 3, "$name ParseMN: Error! ID=$id, no method defined, it must be defined in the protocol hash!";
			next;
		}
		my $method = $ProtocolListSIGNALduino{$id}{method};
		if (!defined &$method)
		{
			Log3 $name, 3, "$name ParseMN: Error! ID=$id, Unknown method. Please check it!";
		} else {
			my ($rcode,$res) = $method->($name,$rawData,$id);
			if ($rcode != -1) {
				$dmsg = $res;
				$dmsg = "$ProtocolListSIGNALduino{$id}{preamble}"."$dmsg" if (defined($ProtocolListSIGNALduino{$id}{preamble}));
				Log3 $name, 4, "$name ParseMN: ID=$id dmsg=$dmsg";
				SIGNALdunoAdv_Dispatch($hash,$rmsg,$dmsg,$rssi_for,$id,0);
			}
			else {
				Log3 $name, 4, "$name ParseMN: method error! $res";
			}
		}
	}
	return 1;
}

sub
SIGNALduinoAdv_Parse
{
  my ($hash, $name, $rmsg) = @_;

	#print Dumper(\%ProtocolListSIGNALduino);
	
    	
	if (!($rmsg=~ s/^\002(M.;.*;)\003/$1/)) 			# Check if a Data Message arrived and if it's complete  (start & end control char are received)
	{							# cut off start end end character from message for further processing they are not needed
		my $noMsgVerbose = AttrVal($name,"noMsgVerbose",5);
		if ($rmsg ne "OK" || $noMsgVerbose == 5) {
			Log3 $name, $noMsgVerbose, "$name/noMsg Parse: $rmsg";
		}
		else {
			Log3 $name, $noMsgVerbose+1, "$name/noMsg Parse: $rmsg";
		}
		return;
	}

	if (defined($hash->{keepalive})) {
		$hash->{keepalive}{ok}    = 1;
		$hash->{keepalive}{retry} = 0;
	}
	
	my $debug = AttrVal($name,"debug",0);
	
	
	Debug "$name: incoming message: ($rmsg)\n" if ($debug);
	
	if (AttrVal($name, "rawmsgEvent", 0)) {
		DoTrigger($name, "RAWMSG " . $rmsg);
	}
	
	my %signal_parts=SIGNALduinoAdv_Split_Message($rmsg,$name);   ## Split message and save anything in an hash %signal_parts
	#Debug "raw data ". $signal_parts{rawData};
	
	
	my $dispatched;

	# Message synced type   -> MS
	if (@{$hash->{msIdList}} && $rmsg=~ m/^MS;(P\d=-?\d+;){3,8}D=\d+;CP=\d;SP=\d;/) 
	{
		$dispatched= SIGNALduinoAdv_Parse_MS($hash, $name, $rmsg,%signal_parts);
	}
	# Message unsynced type   -> MU
  	elsif (@{$hash->{muIdList}} && $rmsg=~ m/^MU;(P\d=-?\d+;){3,8}((CP|R)=\d+;){0,2}D=\d+;/)
	{
		$dispatched=  SIGNALduinoAdv_Parse_MU($hash, $name, $rmsg,%signal_parts);
	}
	# Manchester encoded Data   -> MC
  	elsif (@{$hash->{mcIdList}} && $rmsg=~ m/^M[cC];.*;/) 
	{
		$dispatched=  SIGNALduinoAdv_Parse_MC($hash, $name, $rmsg,%signal_parts);
	}
	elsif (@{$hash->{mnIdList}} && $rmsg=~ m/^MN;.*;/) 
	{
		$dispatched=  SIGNALduinoAdv_Parse_MN($hash, $name, $rmsg,%signal_parts);
	}
	else {
		Debug "$name: unknown Messageformat, aborting\n" if ($debug);
		return;
	}
	
	delete($hash->{rawListNr}) if (defined($hash->{rawListNr}));
	
	if ( AttrVal($hash->{NAME},"verbose","0") > 4 && !$dispatched && !IsDummy($name))	# bei verbose 5 wird die $rmsg in $hash->{unknownmessages} hinzugefuegt
	{
   	    my $notdisplist;
   	    my @lines;
   	    if (defined($hash->{unknownmessages}))
   	    {
   	    	$notdisplist=$hash->{unknownmessages};	      				
			@lines = split ('#', $notdisplist);   # or whatever
   	    }
		push(@lines,FmtDateTime(time())."-".$rmsg);
		shift(@lines)if (scalar @lines >25);
		$notdisplist = join('#',@lines);

		$hash->{unknownmessages}=$notdisplist;
		return;
		#Todo  compare Sync/Clock fact and length of D= if equal, then it's the same protocol!
	}


}


#####################################
sub
SIGNALduinoAdv_Ready
{
  my ($hash) = @_;

  if ($hash->{STATE} eq 'disconnected') {
    $hash->{DevState} = 'disconnected';
    return DevIo_OpenDev($hash, 1, "SIGNALduinoAdv_DoInit", 'SIGNALduinoAdv_Connect')
  }
  
  # This is relevant for windows/USB only
  my $po = $hash->{USBDev};
  my ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags);
  if($po) {
    ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $po->status;
  }
  return ($InBytes && $InBytes>0);
}


sub
SIGNALduinoAdv_WriteInit
{
  my ($hash) = @_;
  
  # todo: ist dies so ausreichend, damit die Aenderungen uebernommen werden?
  SIGNALduinoAdv_AddSendQueue($hash,"WS36");   # SIDLE, Exit RX / TX, turn off frequency synthesizer 
  SIGNALduinoAdv_AddSendQueue($hash,"WS34");   # SRX, Enable RX. Perform calibration first if coming from IDLE and MCSM0.FS_AUTOCAL=1.
}

########################
sub
SIGNALduinoAdv_SimpleWrite
{
  my ($hash, $msg, $nonl) = @_;
  return if(!$hash);
  if($hash->{TYPE} eq "SIGNALduino_RFR") {
    # Prefix $msg with RRBBU and return the corresponding SIGNALduino hash.
    ($hash, $msg) = SIGNALduino_RFR_AddPrefix($hash, $msg); 
  }

  my $name = $hash->{NAME};
  Log3 $name, 5, "$name SW: $msg";

  $msg .= "\n" unless($nonl);

  $hash->{USBDev}->write($msg)    if($hash->{USBDev});
  syswrite($hash->{TCPDev}, $msg) if($hash->{TCPDev});
  syswrite($hash->{DIODev}, $msg) if($hash->{DIODev});

  # Some linux installations are broken with 0.001, T01 returns no answer
  select(undef, undef, undef, 0.01);
}

sub
SIGNALduinoAdv_Attr
{
	my ($cmd,$name,$aName,$aVal) = @_;
	my $hash = $defs{$name};
	my $debug = AttrVal($name,"debug",0);
	
	$aVal= "" if (!defined($aVal));
	Log3 $name, 4, "$name: Calling Getting Attr sub with args: $cmd $aName = $aVal";
		
	if( $aName eq "Clients" ) {		## Change clientList
		$hash->{Clients} = $aVal;
		$hash->{Clients} = $clientsSIGNALduinoAdv if( !$hash->{Clients}) ;				## Set defaults
		return "Setting defaults";
	} elsif( $aName eq "MatchList" ) {	## Change matchList
		my $match_list;
		if( $cmd eq "set" ) {
			$match_list = eval $aVal;
			if( $@ ) {
				Log3 $name, 2, $name .": $aVal: ". $@;
			}
		}
		
		if( ref($match_list) eq 'HASH' ) {
		  $hash->{MatchList} = $match_list;
		} else {
		  $hash->{MatchList} = \%matchListSIGNALduinoAdv;								## Set defaults
		  Log3 $name, 2, $name .": $aVal: not a HASH using defaults" if( $aVal );
		}
	}
	elsif ($aName eq "userProtocol")
	{
		if ($aVal !~ m/^\[.*\]$/) {
			$aVal = "[" . $aVal . "]";
		}
		
		if ($aVal =~ m/^\[\{.*\}\]$/) {
			my $id;
			if ($aVal !~ m/^\[.*\]$/) {
				$aVal = "[" . $aVal . "]";
			}
			my @decoded = eval { @{decode_json($aVal)} };
			if ($@) {
				Log3 $name, 3, "$name Attr: userProtocol $@ can't decode JSON";
			}
			#Log3 $name, 3, "$name Attr: userProtocol Dumper" . Dumper(@decoded);	# nur zum Test
			for my $nr (0 .. $#decoded) {
				$id = $decoded[$nr]->{id};
				$ProtocolListSIGNALduino{$id} = $decoded[$nr];
				foreach my $field (keys %{$decoded[$nr]}) {
					Log3 $name, 4, "$name Attr: userProtocol[$nr] Field=$field : " . $decoded[$nr]->{$field};	# nur zum Test
					$ProtocolListSIGNALduino{$id}{$field} = $decoded[$nr]->{$field};
				}
			}
		}
		else {
			Log3 $name, 3, "$name Attr: userProtocol syntax error";
		}
	}
	elsif ($aName eq "verbose")
	{
		Log3 $name, 3, "$name: setting Verbose to: " . $aVal;
		$hash->{unknownmessages}="" if $aVal <4;
		
	}
	elsif ($aName eq "debug")
	{
		$debug = $aVal;
		Log3 $name, 3, "$name: setting debug to: " . $debug;
	}
	elsif ($aName eq "whitelist_IDs")
	{
		Log3 $name, 3, "$name Attr: whitelist_IDs: $aVal";
		if ($init_done) {		# beim fhem Start wird das SIGNALduino_IdList nicht aufgerufen, da es beim define aufgerufen wird
			SIGNALduinoAdv_IdList("x:$name",$aVal);
		}
	}
	elsif ($aName eq "blacklist_IDs")
	{
		Log3 $name, 3, "$name Attr: blacklist_IDs: $aVal";
		if ($init_done) {		# beim fhem Start wird das SIGNALduino_IdList nicht aufgerufen, da es beim define aufgerufen wird
			SIGNALduinoAdv_IdList("x:$name",undef,$aVal);
		}
	}
	elsif ($aName eq "development")
	{
		Log3 $name, 3, "$name Attr: development: $aVal";
		if ($init_done) {		# beim fhem Start wird das SIGNALduino_IdList nicht aufgerufen, da es beim define aufgerufen wird
			SIGNALduinoAdv_IdList("x:$name",undef,undef,$aVal);
		}
	}
	elsif ($aName eq "doubleMsgCheck_IDs")
	{
		if (defined($aVal)) {
			if (length($aVal)>0) {
				if (substr($aVal,0 ,1) eq '#') {
					Log3 $name, 3, "$name Attr: doubleMsgCheck_IDs disabled: $aVal";
					delete $hash->{DoubleMsgIDs};
				}
				else {
					Log3 $name, 3, "$name Attr: doubleMsgCheck_IDs enabled: $aVal";
					my %DoubleMsgiD = map { $_ => 1 } split(",", $aVal);
					$hash->{DoubleMsgIDs} = \%DoubleMsgiD;
					#print Dumper $hash->{DoubleMsgIDs};
				}
			}
			else {
				Log3 $name, 3, "$name delete Attr: doubleMsgCheck_IDs";
				delete $hash->{DoubleMsgIDs};
			}
		}
	}
	elsif ($aName eq "sendSlowRF_A_IDs")
	{
		if (defined($aVal)) {
			if (length($aVal)>0) {
				Log3 $name, 3, "$name Attr: sendSlowRF_A_IDs enabled: $aVal";
				my %sendAslowrfID = map { $_ => 1 } split(",", $aVal);
				$hash->{sendAslowrfID} = \%sendAslowrfID;
				#print Dumper $hash->{sendAslowrfID};
			}
			else {
				Log3 $name, 3, "$name delete Attr: sendSlowRF_A_IDs";
				delete $hash->{sendAslowrfID};
			}
		}
	}
	elsif ($aName eq "cc1101_frequency")
	{
		if ($aVal eq "" || $aVal < 800) {
			Log3 $name, 3, "$name: delete cc1101_frequeny";
			delete ($hash->{cc1101_frequency}) if (defined($hash->{cc1101_frequency}));
		} else {
			Log3 $name, 3, "$name: setting cc1101_frequency to 868";
			$hash->{cc1101_frequency} = 868;
		}
	}

	elsif ($aName eq "hardware")	# to set flashCommand if hardware def or change
	{
		# to delete flashCommand if hardware delete
		if ($cmd eq "del") {
			if (exists $attr{$name}{flashCommand}) { delete $attr{$name}{flashCommand};}
		}
	}
	elsif ($aName eq "rfmode_user")
	{
		if ($cmd eq "set") {
			if ($aVal !~ m/^CW[A-Fa-f0-9]{4}(,[A-Fa-f0-9]{4})*$/) {
				return "$name Attr: rfmode_user syntax error";
			}
		}
	}
  	return;
}


sub SIGNALduinoAdv_FW_Detail {
  my ($FW_wname, $name, $room, $pageHash) = @_;
  
  my $hash = $defs{$name};
  
  #my @dspec=devspec2array("DEF=.*fakelog");
  #my $lfn = $dspec[0];
  my $fn=$defs{$name}->{TYPE}."-Flash.log";
  
  my $ret = "<div class='makeTable wide'><span>Information menu</span>
<table class='block wide' id='SIGNALduinoInfoMenue' nm='$hash->{NAME}' class='block wide'>
<tr class='even'>";

  if (-s AttrVal("global", "logdir", "./log/") .$fn)
  {
	  $ret.="<td><a href='#showLastFlashlog' id='showLastFlashlog'>Last Flashlog</a></td>";
	  #$ret .= "<a href=\"$flashlogurl\">Last Flashlog<\/a>";
  }

  $ret.="<td><a href='#showProtocolList' id='showProtocolList'>Display protocollist</a></td>";
  $ret.="<td><a href='#SD_dispChanges' id='SD_dispChanges'>Display protocollist changes since days</a>";
  $ret.="<INPUT type=\"text\" name=\"dispChanges\" id=\"SD_dispChangesDays\" value=\"200\" maxlength=\"3\" size=\"3\">";
  #$ret.="<INPUT type=\"checkbox\" id=\"SD_ID_dispChanges\" name=\"SD_dispChanges\" /><label for=\"SD_dispChanges\">display changed in comment)</label>";
  $ret.= "</td>";
  $ret.= '</tr></table></div>
  
<script>
$( "#showLastFlashlog" ).click(function(e) {
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduinoAdv_FW_getLastFlashlog("'.$FW_detail.'")}&XHR=1\', function(data){SD_dispLastFlashlog(data)});
});

$( "#showProtocolList" ).click(function(e) {
	var dispChanged = -1;
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduinoAdv_FW_getProtocolList("'.$FW_detail.'","\'+dispChanged+\'")}&XHR=1\', function(data){SD_plistWindow(data)});
});

$( "#SD_dispChanges" ).click(function(e) {
	var dispChanged = document.getElementById("SD_dispChangesDays").value;
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduinoAdv_FW_getProtocolList("'.$FW_detail.'","\'+dispChanged+\'")}&XHR=1\', function(data){SD_dispChanges(data)});
});

function SD_dispLastFlashlog(txt)
{
  var div = $("<div id=\"SD_LastFlashlog\">");
  $(div).html(txt);
  $("body").append(div);
  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "last Flashlog",
    buttons: [
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();
      }}]
  });
}

function SD_plistWindow(txt)
{
  var div = $("<div id=\"SD_protocolDialog\">");
  $(div).html(txt);
  $("body").append(div);
  var oldPos = $("body").scrollTop();
  var element = document.getElementById("SD_protoCaption");
  var caption = element.innerHTML;
  var btxtStable = "";
  var btxtBlack = "";
  if ($("#SD_protoCaption").text().substr(0,1) != "d") {
    btxtStable = "stable";
  }
  if ($("#SD_protoCaption").text().substr(-1) == ".") {
    btxtBlack = " except blacklist";
  }
  
  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "Protocollist Overview",
    buttons: [
      {text:"select all " + btxtStable + btxtBlack, click:function(){
		  $("#SD_protocolDialog table td input:checkbox").prop(\'checked\', true);
		  
		  $("input[name=SDnotCheck]").each( function () {
			  $(this).prop(\'checked\',false);
		  });
      }},
      {text:"deselect all", click:function(e){
           $("#SD_protocolDialog table td input:checkbox").prop(\'checked\', false);
      }},
      {text:"save to whitelist and close", click:function(){
      	var allVals = [];
 		  $("#SD_protocolDialog table td input:checkbox:checked").each(function() {
	    	  allVals.push($(this).val());
		  })

          FW_cmd(FW_root+ \'?XHR=1&cmd={SIGNALduinoAdv_FW_saveWhitelist("'.$name.'","\'+String(allVals)+\'")}\');
          $(this).dialog("close");
          $(div).remove();
          location.reload();
      }},
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();
        location.reload();
      }}]
  });
}

function SD_dispChanges(txt)
{
  var div = $("<div id=\"SD_protocolDialog\">");
  $(div).html(txt);
  $("body").append(div);
  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "Display Protocollist changed",
    buttons: [
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();
        location.reload();
      }}]
  });
}


</script>';
  return $ret;
}

sub SIGNALduinoAdv_FW_saveWhitelist
{
	my $name = shift;
	my $wl_attr = shift;
	
	if (!IsDevice($name)) {
		Log3 undef, 3, "SIGNALduino_FW_saveWhitelist: $name is not a valid definition, operation aborted.";
		return;
	}
	
	if ($wl_attr eq "") {	# da ein Attribut nicht leer sein kann, kommt ein Komma rein
		$wl_attr = ',';
	}
	elsif ($wl_attr !~ /\d+(?:,\d.?\d?)*$/ ) {
		Log3 $name, 3, "$name Whitelist save: attr whitelist_IDs can not be updated";
		return;
	}
	else {
		$wl_attr =~ s/,$//;			# Komma am Ende entfernen
	}
	#$attr{$name}{whitelist_IDs} = $wl_attr;
	Log3 $name, 3, "$name Whitelist save: $wl_attr";
	CommandAttr(undef,"$name whitelist_IDs $wl_attr");
	#SIGNALduino_IdList("x:$name", $wl_attr);
}

sub SIGNALduinoAdv_IdList
{
	my ($param, $aVal, $blacklist, $develop0) = @_;
	my (undef,$name) = split(':', $param);
	my $hash = $defs{$name};

	my @idList = ();
	my @msIdList = ();
	my @muIdList = ();
	my @mcIdList = ();
	my @mnIdList = ();
	my @skippedDevId = ();
	my @skippedBlackId = ();
	my @devModulId = ();
	#my %WhitelistIDs;
	my %BlacklistIDs;
	my $clientmodule;
	my %clients;
	my $wflag = 0;		# whitelist flag, 0=disabled
	
	delete ($hash->{IDsNoDispatch}) if (defined($hash->{IDsNoDispatch}));
	delete ($hash->{tmpWhiteList}) if (defined($hash->{tmpWhiteList}));

	if (!defined($aVal)) {
		$aVal = AttrVal($name,"whitelist_IDs","");
	}
	
	my ($develop,$devFlag) = SIGNALduinoAdv_getAttrDevelopment($name, $develop0);	# $devFlag = 1 -> alle developIDs y aktivieren
	Log3 $name, 3, "$name IDlist development version active: development attribute = $develop" if ($devFlag == 1);
	
	if ($aVal eq "" || substr($aVal,0 ,1) eq '#') {		# whitelist nicht aktiv
		if ($devFlag == 1) {
			Log3 $name, 3, "$name IDlist attr whitelist disabled (all IDs active, except blacklisted): $aVal";
		}
		else {
			Log3 $name, 3, "$name IDlist attr whitelist disabled (all IDs active, except blacklisted and instable IDs): $aVal";
		}
		
		if (!defined($blacklist)) {
			$blacklist = AttrVal($name,"blacklist_IDs","");
		}
		if (length($blacklist) > 0) {							# Blacklist in Hash wandeln
			Log3 $name, 4, "$name IDlist: attr blacklistIds=$blacklist";
			%BlacklistIDs = map { $_ => 1 } split(",", $blacklist);
			#my $w = join ', ' => map "$_" => keys %BlacklistIDs;
			#Log3 $name, 3, "$name IdList, Attr blacklist $w";
		}
		@idList = keys %ProtocolListSIGNALduino;
	}
	else {		# whitelist aktiv
		#%WhitelistIDs = map { $_ => 1 } split(",", $aVal);			# whitelist in Hash wandeln
		#my $w = join ',' => map "$_" => keys %WhitelistIDs;
		
		@idList = split(",", $aVal);
		
		Log3 $name, 3, "$name IDlist attr whitelist active: @idList";
		$wflag = 1;
	}
	
	@idList = sort {$a <=> $b} @idList;
	Log3 $name, 5, "$name IDlist sort: @idList";
	
	#foreach $id (keys %ProtocolListSIGNALduino)
	foreach my $id (@idList)
	{
		#if ($wflag == 1)				# whitelist aktive
		#{
		#	next if (!exists($WhitelistIDs{$id}))		# Id wurde in der whitelist nicht gefunden
		#}
		if ($wflag == 0) {						# whitelist not aktice
			if (exists($BlacklistIDs{$id})) {
				#Log3 $name, 3, "$name IdList, skip Blacklist ID $id";
				push (@skippedBlackId, $id);
				next;
			}
		
			# wenn es keine developId gibt, dann die folgenden Abfragen ueberspringen
			if (exists($ProtocolListSIGNALduino{$id}{developId}))
			{
				if ($ProtocolListSIGNALduino{$id}{developId} eq "m") {
					if ($develop !~ m/m$id/) {  # ist nur zur Abwaertskompatibilitaet und kann in einer der naechsten Versionen entfernt werden
						push (@devModulId, $id);
						if ($devFlag == 0 && $develop ne "m" && $develop !~ m/m\,/) {
							push (@skippedDevId, $id);
							next;
						}
					}
				}
				elsif ($ProtocolListSIGNALduino{$id}{developId} eq "p") {
					if (exists($ProtocolListSIGNALduino{$id}{deleted})) {
						Log3 $name, 4, "$name: IDlist ID=$id skipped, Id is deleted";
					}
					else {
						Log3 $name, 3, "$name: IDlist ID=$id skipped (developId=p), caution, protocol can cause crashes, use only if advised to do";
					}
					next;
				}
				elsif ($devFlag == 0 && $ProtocolListSIGNALduino{$id}{developId} eq "y" && $develop !~ m/y$id/) {
					#Log3 $name, 3, "$name: IdList ID=$id skipped (developId=y)";
					push (@skippedDevId, $id);
					next;
				}
			}
		}
		else { # whitelist aktive
		    $clientmodule = SIGNALduinoAdv_getProtoProp($id,'clientmodule','');
			$clients{$clientmodule} = defined if ($clientmodule ne '');
		}
		
		if (exists ($ProtocolListSIGNALduino{$id}{format}) && $ProtocolListSIGNALduino{$id}{format} eq "manchester")
		{
			push (@mcIdList, $id);
		}
		elsif (exists $ProtocolListSIGNALduino{$id}{cc1101FIFOmode})
		{
			push (@mnIdList, $id);
		}
		elsif (exists $ProtocolListSIGNALduino{$id}{sync})
		{
			push (@msIdList, $id);
		}
		elsif (exists ($ProtocolListSIGNALduino{$id}{clockabs}))
		{
			push (@muIdList, $id);
		}
	}

	#@msIdList = sort {$a <=> $b} @msIdList;
	#@muIdList = sort {$a <=> $b} @muIdList;
	#@mcIdList = sort {$a <=> $b} @mcIdList;
	#@skippedDevId = sort {$a <=> $b} @skippedDevId;
	#@skippedBlackId = sort {$a <=> $b} @skippedBlackId;
	#@devModulId = sort {$a <=> $b} @devModulId;

	Log3 $name, 3, "$name: IDlist MS @msIdList";
	Log3 $name, 3, "$name: IDlist MU @muIdList";
	Log3 $name, 3, "$name: IDlist MC @mcIdList";
	Log3 $name, 3, "$name: IDlist MN @mnIdList";
	Log3 $name, 3, "$name: IDlist blacklistId skipped = @skippedBlackId" if (scalar @skippedBlackId > 0);
	Log3 $name, 3, "$name: IDlist development skipped = @skippedDevId" if (scalar @skippedDevId > 0);
	
	if ($wflag == 1) {            # bei aktiver whitelist werden nur die Clientmodule der IDs in der whitelist in die $hash->{Clients} kopiert
		my $num_clients = keys %clients;
		Log3 $name, 4, "$name: IDlist num = $num_clients clients = " . join ',' => map "$_" => keys %clients;
		if ($num_clients > 0 && $num_clients < 30) {
			my @clientList = split(":", $clientsSIGNALduinoAdv);
			Log3 $name, 5, "$name: IDlist num = " . scalar(@clientList) . " clientlist=@clientList";
			my $clientsNew = ':';
			if (IsDummy($name)) {
				$clientsNew = ':SD_Tool:';
			}
			my $i = 0;
			foreach my $m (@clientList) {
				if (exists($clients{$m})) {
					$clientsNew .= $m . ':';
					$i++;
					if ($i == 11) {
						$clientsNew .= ' :'; # Zeilenumbruch
						$i = 0;
					}
				}
			}
			$hash->{Clients} = $clientsNew;
			delete $hash->{'.clientArray'};
			Log3 $name, 3, "$name: IDlist clientListNew = $clientsNew";
		}
		else {
			$hash->{Clients} = $clientsSIGNALduinoAdv;
			delete $hash->{'.clientArray'};
		}
	}
	else {  # whitelist nicht aktiv
		$hash->{Clients} = $clientsSIGNALduinoAdv;
		delete $hash->{'.clientArray'};
	}
	
	if (scalar @devModulId > 0)
	{
		Log3 $name, 3, "$name: IDlist development protocol is active (to activate dispatch to not finshed logical module, enable desired protocol via whitelistIDs) = @devModulId";
		$hash->{IDsNoDispatch} = join("," , @devModulId);
	}
	
	$hash->{msIdList} = \@msIdList;
	$hash->{muIdList} = \@muIdList;
	$hash->{mcIdList} = \@mcIdList;
	$hash->{mnIdList} = \@mnIdList;
}

sub SIGNALduinoAdv_getAttrDevelopment
{
	my $name = shift;
	my $develop = shift;
	my $devFlag = 0;
	#if (index(SDUINO_VERSION, "dev") >= 0) {  	# development version
		$develop = AttrVal($name,"development", 0) if (!defined($develop));
		$devFlag = 1 if ($develop eq "1" || (substr($develop,0,1) eq "y" && $develop !~ m/^y\d/));	# Entwicklerversion, y ist nur zur Abwaertskompatibilitaet und kann in einer der naechsten Versionen entfernt werden
	#}
	#else {
	#	$develop = "0";
	#	Log3 $name, 3, "$name IdList: ### Attribute development is in this version ignored ###";
	#}
	return ($develop,$devFlag);
}


sub SIGNALduinoAdv_callsub
{
	my $funcname =shift;
	my $method = shift;
	my $name = shift;
	my @args = @_;
	
	if ( defined $method && defined &$method )
	{
		#my $subname = @{[eval {&$method}, $@ =~ /.*/]};
		Log3 $name, 5, "$name: applying $funcname , value before : @args"; # method $subname";
		
		my ($rcode, @returnvalues) = $method->($name, @args) ;	
			
		if (@returnvalues && defined($returnvalues[0])) {
			Log3 $name, 5, "$name: rcode=$rcode, modified after $funcname: @returnvalues";
		} else {
	   		Log3 $name, 5, "$name: rcode=$rcode, after calling $funcname";
	    } 
	    return ($rcode, @returnvalues);
	} elsif (defined $method ) {
		Log3 $name, 5, "$name: Error: Unknown method $funcname, please check definition";
		return (0,undef);
	}	
	return (1,@args);			
}


# calculates the hex (in bits) and adds it at the beginning of the message
# input = @list
# output = @list
sub SIGNALduinoAdv_postDemo_lengtnPrefix
{
	my ($name, @bit_msg) = @_;
	
	my $msg = join("",@bit_msg);	

	#$msg = unpack("B8", pack("N", length($msg))).$msg;
	$msg=sprintf('%08b', length($msg)).$msg;
	
	return (1,split("",$msg));
}


sub SIGNALduinoAdv_PreparingSend_FS20_FHT {
	my ($id, $sum, $msg) = @_;
	my $temp = 0;
	my $newmsg = "P$id#0000000000001";	  # 12 Bit Praeambel, 1 bit
	
	for (my $i=0; $i<length($msg); $i+=2) {
		$temp = hex(substr($msg, $i, 2));
		$sum += $temp;
		$newmsg .= SIGNALduinoAdv_dec2binppari($temp);
	}
	
	$newmsg .= SIGNALduinoAdv_dec2binppari($sum & 0xFF);   # Checksum		
	my $repeats = $id - 71;			# FS20(74)=3, FHT(73)=2
	$newmsg .= "0P#R" . $repeats;		# EOT, Pause, 3 Repeats    
	
	return $newmsg;
}

sub SIGNALduinoAdv_dec2binppari {      # dec to bin . parity
	my $num = shift;
	my $parity = 0;
	my $nbin = sprintf("%08b",$num);
	foreach my $c (split //, $nbin) {
		$parity ^= $c;
	}
	my $result = $nbin . $parity;		# bin(num) . paritybit
	return $result;
}


sub SIGNALduino_postDemo_bit2Arctec
{
	my ($name, @bit_msg) = @_;
	my $msg = join("",@bit_msg);	
	# Convert 0 -> 01   1 -> 10   F -> 00  to be compatible with IT Module
	$msg =~ s/0/z/g;
	$msg =~ s/1/10/g;
	$msg =~ s/z/01/g;
	$msg =~ s/F/00/g;
	return (1,split("",$msg)); 
}

sub SIGNALduino_postDemo_bit2itv1
{
	my ($name, @bit_msg) = @_;
	my $msg = join("",@bit_msg);	

	$msg =~ s/0F/01/g;		# Convert 0F -> 01 (F) to be compatible with CUL
	#$msg =~ s/0F/11/g;		# Convert 0F -> 11 (1) float
	if (index($msg,'F') == -1) {
		return (1,split("",$msg));
	} else {
		return (0,0);
	}
}


sub SIGNALduinoAdv_ITV1_tristateToBit
{
	my ($msg) = @_;
	# Convert 0 -> 00   1 -> 11 F => 01 to be compatible with IT Module
	$msg =~ s/0/00/g;
	$msg =~ s/1/11/g;
	$msg =~ s/F/01/g;
	$msg =~ s/D/10/g;
		
	return (1,$msg);
}

sub SIGNALduinoAdv_ITV1_31_tristateToBit	# ID 3.1
{
	my ($msg) = @_;
	# Convert 0 -> 00   1 -> 0D F => 01 to be compatible with IT Module
	$msg =~ s/0/00/g;
	$msg =~ s/1/0D/g;
	$msg =~ s/F/01/g;
		
	return (1,$msg);
}

sub SIGNALduino_postDemo_HE800
{
	my ($name, @bit_msg) = @_;
	my $protolength = scalar @bit_msg;
	
	if ($protolength != 28 && $protolength < 40) {
		for (my $i=0; $i<(40-$protolength); $i++) {
			push(@bit_msg, 0);
		}
	}
	return (1,@bit_msg);
}

sub SIGNALduino_postDemo_HE_EU
{
	my ($name, @bit_msg) = @_;
	my $protolength = scalar @bit_msg;
	
	if ($protolength != 60 && $protolength < 72) {
		for (my $i=0; $i<(72-$protolength); $i++) {
			push(@bit_msg, 0);
		}
	}
	return (1,@bit_msg);
}

sub SIGNALduino_postDemo_EM {
	my ($name, @bit_msg) = @_;
	my $msg = join("",@bit_msg);
	my $msg_start = index($msg, "0000000001");				# find start
	$msg = substr($msg,$msg_start + 10);						# delete preamble + 1 bit
	my $new_msg = "";
	my $crcbyte;
	my $msgcrc = 0;

	if ($msg_start > 0 && length $msg == 89) {
		for (my $count = 0; $count < length ($msg) ; $count +=9) {
			$crcbyte = substr($msg,$count,8);
			if ($count < (length($msg) - 10)) {
				$new_msg.= join "", reverse @bit_msg[$msg_start + 10 + $count.. $msg_start + 17 + $count];
				$msgcrc = $msgcrc ^ oct( "0b$crcbyte" );
			}
		}
	
		if ($msgcrc == oct( "0b$crcbyte" )) {
			Log3 $name, 4, "$name: EM Protocol - CRC OK";
			return (1,split("",$new_msg));
		} else {
			Log3 $name, 3, "$name: EM Protocol - CRC ERROR";
			return 0, undef;
		}
	}
	
	Log3 $name, 3, "$name: EM Protocol - Start not found or length msg (".length $msg.") not correct";
	return 0, undef;
}

sub SIGNALduino_postDemo_FS20 {
	my ($name, @bit_msg) = @_;
	my $datastart = 0;
   my $protolength = scalar @bit_msg;
	my $sum = 6;
	my $b = 0;
	my $i = 0;
   for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
      last if $bit_msg[$datastart] eq "1";
   }
   if ($datastart == $protolength) {                                 # all bits are 0
		Log3 $name, 4, "$name: FS20 - ERROR message all bit are zeros";
		return 0, undef;
   }
   splice(@bit_msg, 0, $datastart + 1);                             	# delete preamble + 1 bit
   $protolength = scalar @bit_msg;
   Log3 $name, 5, "$name: FS20 - pos=$datastart length=$protolength";
   if ($protolength == 46 || $protolength == 55) {			# If it 1 bit too long, then it will be removed (EOT-Bit)
      pop(@bit_msg);
      $protolength--;
   }
   if ($protolength == 45 || $protolength == 54) {          ### FS20 length 45 or 54
      for(my $b = 0; $b < $protolength - 9; $b += 9) {	                  # build sum over first 4 or 5 bytes
         $sum += oct( "0b".(join "", @bit_msg[$b .. $b + 7]));
      }
      my $checksum = oct( "0b".(join "", @bit_msg[$protolength - 9 .. $protolength - 2]));   # Checksum Byte 5 or 6
      if ((($sum + 6) & 0xFF) == $checksum) {			# Message from FHT80 roothermostat
         Log3 $name, 5, "$name: FS20 - Detection aborted, checksum matches FHT code";
         return 0, undef;
      }
      if (($sum & 0xFF) == $checksum) {				            ## FH20 remote control
			for(my $b = 0; $b < $protolength; $b += 9) {	            # check parity over 5 or 6 bytes
				my $parity = 0;					                                 # Parity even
				for(my $i = $b; $i < $b + 9; $i++) {			                  # Parity over 1 byte + 1 bit
					$parity += $bit_msg[$i];
				}
				if ($parity % 2 != 0) {
					Log3 $name, 4, "$name: FS20 ERROR - Parity not even";
					return 0, undef;
				}
			}																						# parity ok
			for(my $b = $protolength - 1; $b > 0; $b -= 9) {	               # delete 5 or 6 parity bits
				splice(@bit_msg, $b, 1);
			}
         if ($protolength == 45) {                       		### FS20 length 45
            splice(@bit_msg, 32, 8);                                       # delete checksum
            splice(@bit_msg, 24, 0, (0,0,0,0,0,0,0,0));                    # insert Byte 3
         } else {                                              ### FS20 length 54
            splice(@bit_msg, 40, 8);                                       # delete checksum
         }
			my $dmsg = SIGNALduinoAdv_b2h(join "", @bit_msg);
			Log3 $name, 4, "$name: FS20 - remote control post demodulation $dmsg length $protolength";
			return (1, @bit_msg);											## FHT80TF ok
      }
      else {
         Log3 $name, 4, "$name: FS20 ERROR - wrong checksum";
      }
   }
   else {
      Log3 $name, 5, "$name: FS20 ERROR - wrong length=$protolength (must be 45 or 54)";
   }
   return 0, undef;
}

sub SIGNALduino_postDemo_FHT80 {
	my ($name, @bit_msg) = @_;
	my $datastart = 0;
   my $protolength = scalar @bit_msg;
	my $sum = 12;
	my $b = 0;
	my $i = 0;
   for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
      last if $bit_msg[$datastart] eq "1";
   }
   if ($datastart == $protolength) {                                 # all bits are 0
		Log3 $name, 4, "$name: FHT80 - ERROR message all bit are zeros";
		return 0, undef;
   }
   splice(@bit_msg, 0, $datastart + 1);                             	# delete preamble + 1 bit
   $protolength = scalar @bit_msg;
   Log3 $name, 5, "$name: FHT80 - pos=$datastart length=$protolength";
   if ($protolength == 55) {						# If it 1 bit too long, then it will be removed (EOT-Bit)
      pop(@bit_msg);
      $protolength--;
   }
   if ($protolength == 54) {                       		### FHT80 fixed length
      for($b = 0; $b < 45; $b += 9) {	                             # build sum over first 5 bytes
         $sum += oct( "0b".(join "", @bit_msg[$b .. $b + 7]));
      }
      my $checksum = oct( "0b".(join "", @bit_msg[45 .. 52]));          # Checksum Byte 6
      if ((($sum - 6) & 0xFF) == $checksum) {		## Message from FS20 remote control
         Log3 $name, 5, "$name: FHT80 - Detection aborted, checksum matches FS20 code";
         return 0, undef;
      }
      if (($sum & 0xFF) == $checksum) {								## FHT80 Raumthermostat
         for($b = 0; $b < 54; $b += 9) {	                              # check parity over 6 byte
            my $parity = 0;					                              # Parity even
            for($i = $b; $i < $b + 9; $i++) {			                  # Parity over 1 byte + 1 bit
               $parity += $bit_msg[$i];
            }
            if ($parity % 2 != 0) {
               Log3 $name, 4, "$name: FHT80 ERROR - Parity not even";
               return 0, undef;
            }
         }																					# parity ok
         for($b = 53; $b > 0; $b -= 9) {	                              # delete 6 parity bits
            splice(@bit_msg, $b, 1);
         }
         if ($bit_msg[26] != 1) {                                       # Bit 5 Byte 3 must 1
            Log3 $name, 4, "$name: FHT80 ERROR - byte 3 bit 5 not 1";
            return 0, undef;
         }
         splice(@bit_msg, 40, 8);                                       # delete checksum
         splice(@bit_msg, 24, 0, (0,0,0,0,0,0,0,0));# insert Byte 3
         my $dmsg = SIGNALduinoAdv_b2h(join "", @bit_msg);
         Log3 $name, 4, "$name: FHT80 - roomthermostat post demodulation $dmsg";
         return (1, @bit_msg);											## FHT80 ok
      }
      else {
         Log3 $name, 4, "$name: FHT80 ERROR - wrong checksum";
      }
   }
   else {
      Log3 $name, 5, "$name: FHT80 ERROR - wrong length=$protolength (must be 54)";
   }
   return 0, undef;
}

sub SIGNALduino_postDemo_FHT80TF {
	my ($name, @bit_msg) = @_;
	my $datastart = 0;
   my $protolength = scalar @bit_msg;
	my $sum = 12;			
	my $b = 0;
   if ($protolength < 46) {                                        	# min 5 bytes + 6 bits
		Log3 $name, 4, "$name: FHT80TF - ERROR lenght of message < 46";
		return 0, undef;
   }
   for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
      last if $bit_msg[$datastart] eq "1";
   }
   if ($datastart == $protolength) {                                 # all bits are 0
		Log3 $name, 4, "$name: FHT80TF - ERROR message all bit are zeros";
		return 0, undef;
   }
   splice(@bit_msg, 0, $datastart + 1);                             	# delete preamble + 1 bit
   $protolength = scalar @bit_msg;
   if ($protolength == 45) {                       		      ### FHT80TF fixed length
      for(my $b = 0; $b < 36; $b += 9) {	                             # build sum over first 4 bytes
         $sum += oct( "0b".(join "", @bit_msg[$b .. $b + 7]));
      }
      my $checksum = oct( "0b".(join "", @bit_msg[36 .. 43]));          # Checksum Byte 5
      if (($sum & 0xFF) == $checksum) {									## FHT80TF Tuer-/Fensterkontakt
			for(my $b = 0; $b < 45; $b += 9) {	                           # check parity over 5 byte
				my $parity = 0;					                              # Parity even
				for(my $i = $b; $i < $b + 9; $i++) {			               # Parity over 1 byte + 1 bit
					$parity += $bit_msg[$i];
				}
				if ($parity % 2 != 0) {
					Log3 $name, 4, "$name: FHT80TF ERROR - Parity not even";
					return 0, undef;
				}
			}																					# parity ok
			for(my $b = 44; $b > 0; $b -= 9) {	                           # delete 5 parity bits
				splice(@bit_msg, $b, 1);
			}
         if ($bit_msg[26] != 0) {                                       # Bit 5 Byte 3 must 0
            Log3 $name, 4, "$name: FHT80TF ERROR - byte 3 bit 5 not 0";
            return 0, undef;
         }
			splice(@bit_msg, 32, 8);                                       # delete checksum
				my $dmsg = SIGNALduinoAdv_b2h(join "", @bit_msg);
				Log3 $name, 4, "$name: FHT80TF - door/window switch post demodulation $dmsg";
			return (1, @bit_msg);											## FHT80TF ok
      } 
   } 
   return 0, undef;
}

sub SIGNALduino_postDemo_WS7035 {
	my ($name, @bit_msg) = @_;
	my $msg = join("",@bit_msg);
	my $parity = 0;					# Parity even
	my $sum = 0;						# checksum

	Log3 $name, 4, "$name: WS7035 $msg";
	if (substr($msg,0,8) ne "10100000") {		# check ident
		Log3 $name, 4, "$name: WS7035 ERROR - Ident not 1010 0000";
		return 0, undef;
	} else {
		for(my $i = 15; $i < 28; $i++) {			# Parity over bit 15 and 12 bit temperature
	      $parity += substr($msg, $i, 1);
		}
		if ($parity % 2 != 0) {
			Log3 $name, 4, "$name: WS7035 ERROR - Parity not even";
			return 0, undef;
		} else {
			for(my $i = 0; $i < 39; $i += 4) {			# Sum over nibble 0 - 9
				$sum += oct("0b".substr($msg,$i,4));
			}
			if (($sum &= 0x0F) != oct("0b".substr($msg,40,4))) {
				Log3 $name, 4, "$name: WS7035 ERROR - Checksum";
				return 0, undef;
			} else {
				Log3 $name, 4, "$name: WS7035 " . substr($msg,0,4) ." ". substr($msg,4,4) ." ". substr($msg,8,4) ." ". substr($msg,12,4) ." ". substr($msg,16,4) ." ". substr($msg,20,4) ." ". substr($msg,24,4) ." ". substr($msg,28,4) ." ". substr($msg,32,4) ." ". substr($msg,36,4) ." ". substr($msg,40) ." Checksum ok";
				substr($msg, 27, 4, '');			# delete nibble 8
				return (1,split("",$msg));
			}
		}
	}
}

sub SIGNALduino_postDemo_WS2000 {
	my ($name, @bit_msg) = @_;
	my $debug = AttrVal($name,"debug",0);
	my @new_bit_msg = "";
	my $protolength = scalar @bit_msg;
	my @datalenghtws = (35,50,35,50,70,40,40,85);
	my $datastart = 0;
	my $datalength = 0;
	my $datalength1 = 0;
	my $index = 0;
	my $data = 0;
	my $dataindex = 0;
	my $error = 0;
	my $check = 0;
	my $sum = 5;
	my $typ = 0;
	my $adr = 0;
	my @sensors = (
		"Thermo",
		"Thermo/Hygro",
		"Rain",
		"Wind",
		"Thermo/Hygro/Baro",
		"Brightness",
		"Pyrano",
		"Kombi"
		);

	for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
		last if $bit_msg[$datastart] eq "1";
	}
	if ($datastart == $protolength) {                                 # all bits are 0
		Log3 $name, 4, "$name: WS2000 - ERROR message all bit are zeros";
		return 0, undef;
	}
	$datalength = $protolength - $datastart;
	$datalength1 = $datalength - ($datalength % 5);  		# modulo 5
	Log3 $name, 5, "$name: WS2000 protolength: $protolength, datastart: $datastart, datalength $datalength";
	$typ = oct( "0b".(join "", reverse @bit_msg[$datastart + 1.. $datastart + 4]));		# Sensortyp
	if ($typ > 7) {
		Log3 $name, 4, "$name: WS2000 Sensortyp $typ - ERROR typ to big";
		return 0, undef;
	}
	if ($typ == 1 && ($datalength == 45 || $datalength == 46)) {$datalength1 += 5;}		# Typ 1 ohne Summe
	if ($datalenghtws[$typ] != $datalength1) {												# check lenght of message
		Log3 $name, 4, "$name: WS2000 Sensortyp $typ - ERROR lenght of message $datalength1 ($datalenghtws[$typ])";
		return 0, undef;
	} elsif ($datastart > 10) {									# max 10 Bit preamble
		Log3 $name, 4, "$name: WS2000 ERROR preamble > 10 ($datastart)";
		return 0, undef;
	} else {
		do {
			$error += !$bit_msg[$index + $datastart];			# jedes 5. Bit muss 1 sein
			$dataindex = $index + $datastart + 1;
			my $rest = $protolength - $dataindex;   # prevents perl warning WS2000
			if ($rest < 4) {
				Log3 $name, 4, "$name: WS2000 Sensortyp $typ - ERROR rest of message < 4 ($rest)";
				return (0, undef);
			}
			$data = oct( "0b".(join "", reverse @bit_msg[$dataindex .. $dataindex + 3]));
			if ($index == 5) {$adr = ($data & 0x07)}			# Sensoradresse
			if ($datalength == 45 || $datalength == 46) { 	# Typ 1 ohne Summe
				if ($index <= $datalength - 5) {
					$check = $check ^ $data;		# Check - Typ XOR Adresse XOR  bis XOR Check muss 0 ergeben
				}
			} else {
				if ($index <= $datalength - 10) {
					$check = $check ^ $data;		# Check - Typ XOR Adresse XOR  bis XOR Check muss 0 ergeben
					$sum += $data;
				}
			}
			$index += 5;
		} until ($index >= $datalength -1 );
	}
	if ($error != 0) {
		Log3 $name, 4, "$name: WS2000 Sensortyp $typ Adr $adr - ERROR examination bit";
		return (0, undef);
	} elsif ($check != 0) {
		Log3 $name, 4, "$name: WS2000 Sensortyp $typ Adr $adr - ERROR check XOR";
		return (0, undef);
	} else {
		if ($datalength < 45 || $datalength > 46) { 			# Summe pruefen, ausser Typ 1 ohne Summe
			$data = oct( "0b".(join "", reverse @bit_msg[$dataindex .. $dataindex + 3]));
			if ($data != ($sum & 0x0F)) {
				Log3 $name, 4, "$name: WS2000 Sensortyp $typ Adr $adr - ERROR sum";
				return (0, undef);
			}
		}
		Log3 $name, 4, "$name: WS2000 Sensortyp $typ Adr $adr - $sensors[$typ]";
		$datastart += 1;																							# [x] - 14_CUL_WS
		@new_bit_msg[4 .. 7] = reverse @bit_msg[$datastart .. $datastart+3];						# [2]  Sensortyp
		@new_bit_msg[0 .. 3] = reverse @bit_msg[$datastart+5 .. $datastart+8];					# [1]  Sensoradresse
		@new_bit_msg[12 .. 15] = reverse @bit_msg[$datastart+10 .. $datastart+13];				# [4]  T 0.1, R LSN, Wi 0.1, B   1, Py   1
		@new_bit_msg[8 .. 11] = reverse @bit_msg[$datastart+15 .. $datastart+18];				# [3]  T   1, R MID, Wi   1, B  10, Py  10
		if ($typ == 0 || $typ == 2) {		# Thermo (AS3), Rain (S2000R, WS7000-16)
			@new_bit_msg[16 .. 19] = reverse @bit_msg[$datastart+20 .. $datastart+23];			# [5]  T  10, R MSN
		} else {
			@new_bit_msg[20 .. 23] = reverse @bit_msg[$datastart+20 .. $datastart+23];			# [6]  T  10, 			Wi  10, B 100, Py 100
			@new_bit_msg[16 .. 19] = reverse @bit_msg[$datastart+25 .. $datastart+28];			# [5]  H 0.1, 			Wr   1, B Fak, Py Fak
			if ($typ == 1 || $typ == 3 || $typ == 4 || $typ == 7) {	# Thermo/Hygro, Wind, Thermo/Hygro/Baro, Kombi
				@new_bit_msg[28 .. 31] = reverse @bit_msg[$datastart+30 .. $datastart+33];		# [8]  H   1,			Wr  10
				@new_bit_msg[24 .. 27] = reverse @bit_msg[$datastart+35 .. $datastart+38];		# [7]  H  10,			Wr 100
				if ($typ == 4) {	# Thermo/Hygro/Baro (S2001I, S2001ID)
					@new_bit_msg[36 .. 39] = reverse @bit_msg[$datastart+40 .. $datastart+43];	# [10] P    1
					@new_bit_msg[32 .. 35] = reverse @bit_msg[$datastart+45 .. $datastart+48];	# [9]  P   10
					@new_bit_msg[44 .. 47] = reverse @bit_msg[$datastart+50 .. $datastart+53];	# [12] P  100
					@new_bit_msg[40 .. 43] = reverse @bit_msg[$datastart+55 .. $datastart+58];	# [11] P Null
				}
			}
		}
		return (1, @new_bit_msg);
	}

}


sub SIGNALduino_postDemo_WS7053 {
	my ($name, @bit_msg) = @_;
	my $msg = join("",@bit_msg);
	my $parity = 0;	                       # Parity even
	Log3 $name, 4, "$name: WS7053 - MSG = $msg";
	my $msg_start = index($msg, "10100000");
	if ($msg_start > 0) {                  # start not correct
		$msg = substr($msg, $msg_start);
		$msg .= "0";
		Log3 $name, 5, "$name: WS7053 - cut $msg_start char(s) at begin";
	}
	if ($msg_start < 0) {                  # start not found
		Log3 $name, 3, "$name: WS7053 ERROR - Ident 10100000 not found";
		return 0, undef;
	} else {
		if (length($msg) < 32) {             # msg too short
			Log3 $name, 3, "$name: WS7053 ERROR - msg too short, length " . length($msg);
		return 0, undef;
		} else {
			for(my $i = 15; $i < 28; $i++) {   # Parity over bit 15 and 12 bit temperature
				$parity += substr($msg, $i, 1);
			}
			if ($parity % 2 != 0) {
				Log3 $name, 3, "$name: WS7053 ERROR - Parity not even";
				return 0, undef;
			} else {
				Log3 $name, 5, "$name: WS7053 before: " . substr($msg,0,4) ." ". substr($msg,4,4) ." ". substr($msg,8,4) ." ". substr($msg,12,4) ." ". substr($msg,16,4) ." ". substr($msg,20,4) ." ". substr($msg,24,4) ." ". substr($msg,28,4);
				# Format from 7053:  Bit 0-7 Ident, Bit 8-15 Rolling Code/Parity, Bit 16-27 Temperature (12.3), Bit 28-31 Zero
				my $new_msg = substr($msg,0,28) . substr($msg,16,8) . substr($msg,28,4);
				# Format for CUL_TX: Bit 0-7 Ident, Bit 8-15 Rolling Code/Parity, Bit 16-27 Temperature (12.3), Bit 28 - 35 Temperature (12), Bit 36-39 Zero
				Log3 $name, 5, "$name: WS7053 after:  " . substr($new_msg,0,4) ." ". substr($new_msg,4,4) ." ". substr($new_msg,8,4) ." ". substr($new_msg,12,4) ." ". substr($new_msg,16,4) ." ". substr($new_msg,20,4) ." ". substr($new_msg,24,4) ." ". substr($new_msg,28,4) ." ". substr($new_msg,32,4) ." ". substr($new_msg,36,4);
				return (1,split("",$new_msg));
			}
		}
	}
}

sub SIGNALduino_postDemo_Revolt {
	my ($name, @bit_msg) = @_;
	
	my $protolength = scalar @bit_msg;
	my $sum = 0;
	my $checksum = oct( '0b' . ( join "", @bit_msg[ 88 .. 95 ] ) );
	for ( my $b = 0 ; $b < 88 ; $b += 8 )
	{	# build sum over first 11 bytes
		$sum += oct( '0b' . ( join "", @bit_msg[ $b .. $b + 7 ] ) );
	}
	$sum &= 0xFF;
	
	if ($sum != $checksum) {
		my $dmsg = SIGNALduinoAdv_b2h(join "", @bit_msg[ 0 .. 95 ] );
		Log3 $name, 4, "$name: postDemo_Revolt, ERROR checksum mismatch, $sum != $checksum in msg $dmsg";
		return 0, undef;
	}
	
	my @new_bitmsg = splice @bit_msg, 0,88;
	return 1,@new_bitmsg;
}


# manchester method

sub SIGNALduino_MCTFA
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	
	my $preamble_pos;
	my $message_end;
	my $message_length;
		
	#if ($bitData =~ m/^.?(1){16,24}0101/)  {  
	if ($bitData =~ m/(1{9}101)/ )
	{ 
		$preamble_pos=$+[1];
		Log3 $name, 4, "$name: TFA 30.3208.0 preamble_pos = $preamble_pos";
		return (-1," sync not found") if ($preamble_pos <=0);
		my @messages;
		
		my $i=1;
		my $retmsg = "";
		do 
		{
			$message_end = index($bitData,"1111111111101",$preamble_pos); 
			if ($message_end < $preamble_pos)
			{
				$message_end=$mcbitnum;		# length($bitData);
			} 
			$message_length = ($message_end - $preamble_pos);			
			
			my $part_str=substr($bitData,$preamble_pos,$message_length);
			#$part_str = substr($part_str,0,52) if (length($part_str)) > 52;

			Log3 $name, 4, "$name: TFA message start($i)=$preamble_pos end=$message_end with length=$message_length";
			Log3 $name, 5, "$name: TFA message part($i)=$part_str";
			
			my ($rcode, $rtxt) = SIGNALduinoAdv_TestLength($name, $id, $message_length, "TFA message part($i)");
			if ($rcode) {
				my $hex=SIGNALduinoAdv_b2h($part_str);
				push (@messages,$hex);
				Log3 $name, 4, "$name: TFA message part($i)=$hex";
			}
			else {
				$retmsg = ", " . $rtxt;
			}
			
			$preamble_pos=index($bitData,"1101",$message_end)+4;
			$i++;
		}  while ($message_end < $mcbitnum && $i < 10);
		
		my %seen;
		my @dupmessages = map { 1==$seen{$_}++ ? $_ : () } @messages;
	
		return (-1,"loop error, please report this data $bitData") if ($i==10);
		if (scalar(@dupmessages) > 0 ) {
			Log3 $name, 4, "$name: repeated hex ".$dupmessages[0]." found ".$seen{$dupmessages[0]}." times";
			return  ($seen{$dupmessages[0]},$dupmessages[0]);
		} else {  
			return (-1," no duplicate found$retmsg");
		}
	}
	return (-1,undef);
	
}


sub SIGNALduino_OSV2
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	
	my $preamble_pos;
	my $message_end;
	my $message_length;
	my $msg_start;
	
	#$bitData =~ tr/10/01/;
       #if ($bitData =~ m/^.?(01){12,17}.?10011001/) 
	if ($bitData =~ m/^.?(01){8,17}.?10011001/) 
	{  # Valid OSV2 detected!	
		#$preamble_pos=index($bitData,"10011001",24);
		$preamble_pos=$+[1];
		
		Log3 $name, 4, "$name: OSV2 protocol detected: preamble_pos = $preamble_pos";
		return (-1,"sync not found") if ($preamble_pos <=18);
		
		$message_end=$-[1] if ($bitData =~ m/^.{44,}(01){16,17}.?10011001/); #Todo regex .{44,} 44 should be calculated from $preamble_pos+ min message lengh (44)
		if (!defined($message_end) || $message_end < $preamble_pos) {
			$message_end = length($bitData);
		} else {
			$message_end += 16;
			Log3 $name, 4, "$name: OSV2 message end pattern found at pos $message_end  lengthBitData=".length($bitData);
		}
		$message_length = ($message_end - $preamble_pos)/2;

		return (-1," message is to short") if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $message_length < $ProtocolListSIGNALduino{$id}{length_min} );
		return (-1," message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $message_length > $ProtocolListSIGNALduino{$id}{length_max} );
		
		my $idx=0;
		my $osv2bits="";
		my $osv2hex ="";
		
		for ($idx=$preamble_pos;$idx<$message_end;$idx=$idx+16)
		{
			if ($message_end-$idx < 8 )
			{
			  last;
			}
			
			my $osv2byte=substr($bitData,$idx,16);

			my $rvosv2byte="";
			
			for (my $p=0;$p<length($osv2byte);$p=$p+2)
			{
				$rvosv2byte = substr($osv2byte,$p,1).$rvosv2byte;
			}
			$rvosv2byte =~ tr/10/01/;
			
			if (length($rvosv2byte) == 8) {
				$osv2hex=$osv2hex.sprintf('%02X', oct("0b$rvosv2byte"))  ;
			} else {
				$osv2hex=$osv2hex.sprintf('%X', oct("0b$rvosv2byte"))  ;
			}
			$osv2bits = $osv2bits.$rvosv2byte;
		}
		$osv2hex = sprintf("%02X", length($osv2hex)*4).$osv2hex;
		Log3 $name, 4, "$name: OSV2 protocol converted to hex: ($osv2hex) with length (".(length($osv2hex)*4).") bits";
		#$found=1;
		#$dmsg=$osv2hex;
		return (1,$osv2hex);
	}
	elsif ($bitData =~ m/1{12,24}(0101)/g) {  # min Preamble 12 x 1, Valid OSV3 detected!	
		$preamble_pos = $-[1];
		$msg_start = $preamble_pos + 4;
		if ($bitData =~ m/\G.+?(1{24})(0101)/) {		#  preamble + sync der zweiten Nachricht
			$message_end = $-[1];
			Log3 $name, 4, "$name: OSV3 protocol with two messages detected: length of second message = " . ($mcbitnum - $message_end - 28);
		}
		else {		# es wurde keine zweite Nachricht gefunden
			$message_end = $mcbitnum;
		}
		$message_length = $message_end - $msg_start;
		#Log3 $name, 4, "$name: OSV3: bitdata=$bitData";
		Log3 $name, 4, "$name: OSV3 protocol detected: msg_start = $msg_start, message_length = $message_length";
		return (-1," message with length ($message_length) is to short") if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $message_length < $ProtocolListSIGNALduino{$id}{length_min} );
		
		my $idx=0;
		#my $osv3bits="";
		my $osv3hex ="";
		
		for ($idx=$msg_start; $idx<$message_end; $idx=$idx+4)
		{
			last if (length($bitData)-$idx  < 4 );
			
			my $osv3nibble=substr($bitData,$idx,4);

			my $rvosv3nibble="";
			
			for (my $p=0;$p<length($osv3nibble);$p++)
			{
				$rvosv3nibble = substr($osv3nibble,$p,1).$rvosv3nibble;
			}
			$osv3hex=$osv3hex.sprintf('%X', oct("0b$rvosv3nibble"));
			#$osv3bits = $osv3bits.$rvosv3nibble;
		}
		Log3 $name, 4, "$name: OSV3 protocol =                     $osv3hex";
		my $korr = 10;
		# Check if nibble 1 is A
		if (substr($osv3hex,1,1) ne 'A')
		{
			my $n1=substr($osv3hex,1,1);
			$korr = hex(substr($osv3hex,3,1));
			substr($osv3hex,1,1,'A');  # nibble 1 = A
			substr($osv3hex,3,1,$n1); # nibble 3 = nibble1
		}
		# Korrektur nibble
		my $insKorr = sprintf('%X', $korr);
		# Check for ending 00
		if (substr($osv3hex,-2,2) eq '00')
		{
			#substr($osv3hex,1,-2);  # remove 00 at end
			$osv3hex = substr($osv3hex, 0, length($osv3hex)-2);
		}
		my $osv3len = length($osv3hex);
		$osv3hex .= '0';
		my $turn0 = substr($osv3hex,5, $osv3len-4);
		my $turn = '';
		for ($idx=0; $idx<$osv3len-5; $idx=$idx+2) {
			$turn = $turn . substr($turn0,$idx+1,1) . substr($turn0,$idx,1);
		}
		$osv3hex = substr($osv3hex,0,5) . $insKorr . $turn;
		$osv3hex = substr($osv3hex,0,$osv3len+1);
		$osv3hex = sprintf("%02X", length($osv3hex)*4).$osv3hex;
		Log3 $name, 4, "$name: OSV3 protocol converted to hex: ($osv3hex) with length (".((length($osv3hex)-2)*4).") bits";
		#$found=1;
		#$dmsg=$osv2hex;
		return (1,$osv3hex);
		
	}
	return (-1,undef);
}

sub SIGNALduino_OSV1 {
	my ($name,$bitData,$id,$mcbitnum) = @_;
	return (-1," message is to short") if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $mcbitnum < $ProtocolListSIGNALduino{$id}{length_min} );
	return (-1," message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $mcbitnum > $ProtocolListSIGNALduino{$id}{length_max} );
	my $calcsum = oct( "0b" . reverse substr($bitData,0,8));
	$calcsum += oct( "0b" . reverse substr($bitData,8,8));
	$calcsum += oct( "0b" . reverse substr($bitData,16,8));
	$calcsum = ($calcsum & 0xFF) + ($calcsum >> 8);
	my $checksum = oct( "0b" . reverse substr($bitData,24,8));
	
	if ($calcsum != $checksum) {	# Checksum
		return (-1,"OSV1 - ERROR checksum not equal: $calcsum != $checksum");
	} 
	#if (substr($bitData,20,1) == 0) {
	#	$bitData =~ tr/01/10/; # invert message and check if it is possible to deocde now
	#} 
	
	Log3 $name, 4, "$name: OSV1 input data: $bitData";
	my $newBitData = '00001010';                       # Byte 0:   Id1 = 0x0A
    $newBitData .= '01001101';                         # Byte 1:   Id2 = 0x4D
	my $channel = substr($bitData,6,2);						# Byte 2 h: Channel
	if ($channel eq '00') {										# in 0 LSB first
		$newBitData .= '0001';									# out 1 MSB first
	} elsif ($channel eq '10') {								# in 4 LSB first
		$newBitData .= '0010';									# out 2 MSB first
	} elsif ($channel eq '01') {								# in 4 LSB first
		$newBitData .= '0011';									# out 3 MSB first
	} else {															# in 8 LSB first
		return (-1,"$name: OSV1 - ERROR channel not valid: $channel");
    }
    $newBitData .= '0000';                             # Byte 2 l: ????
    $newBitData .= '0000';                             # Byte 3 h: address
    $newBitData .= reverse substr($bitData,0,4);       # Byte 3 l: address (Rolling Code)
    $newBitData .= reverse substr($bitData,8,4);       # Byte 4 h: T 0,1
    $newBitData .= '0' . substr($bitData,23,1) . '00'; # Byte 4 l: Bit 2 - Batterie 0=ok, 1=low (< 2,5 Volt)
    $newBitData .= reverse substr($bitData,16,4);      # Byte 5 h: T 10
    $newBitData .= reverse substr($bitData,12,4);      # Byte 5 l: T 1
    $newBitData .= '0000';                             # Byte 6 h: immer 0000
    $newBitData .= substr($bitData,21,1) . '000';      # Byte 6 l: Bit 3 - Temperatur 0=pos | 1=neg, Rest 0
    $newBitData .= '00000000';                         # Byte 7: immer 0000 0000
    # calculate new checksum over first 16 nibbles
    $checksum = 0;       
    for (my $i = 0; $i < 64; $i = $i + 4) {
       $checksum += oct( "0b" . substr($newBitData, $i, 4));
    }
    $checksum = ($checksum - 0xa) & 0xff;
    $newBitData .= sprintf("%08b",$checksum);          # Byte 8:   new Checksum 
    $newBitData .= '00000000';                         # Byte 9:   immer 0000 0000
    my $osv1hex = '50' . SIGNALduinoAdv_b2h($newBitData); # output with length before
    Log3 $name, 4, "$name: OSV1 protocol id $id translated to RFXSensor format";
    Log3 $name, 4, "$name: converted to hex: $osv1hex";
    return (1,$osv1hex);
   
}

sub	SIGNALduino_AS
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	my $debug = AttrVal($name,"debug",0);
	
	if(index($bitData,"1100",16) >= 0) # $rawData =~ m/^A{2,3}/)
	{  # Valid AS detected!	
		my $message_start = index($bitData,"1100",16);
		Debug "$name: AS protocol detected \n" if ($debug);
		
		my $message_end=index($bitData,"1100",$message_start+16);
		$message_end = length($bitData) if ($message_end == -1);
		my $message_length = $message_end - $message_start;
		
		return (-1," message is to short") if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $message_length < $ProtocolListSIGNALduino{$id}{length_min} );
		return (-1," message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $message_length > $ProtocolListSIGNALduino{$id}{length_max} );
		
		
		my $msgbits =substr($bitData,$message_start);
		
		my $ashex=sprintf('%02X', oct("0b$msgbits"));
		Log3 $name, 5, "$name: AS protocol converted to hex: ($ashex) with length ($message_length) bits \n";

		return (1,$bitData);
	}
	return (-1,undef);
}

sub	SIGNALduino_Hideki
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	my $debug = AttrVal($name,"debug",0);
	
	if ($mcbitnum == 89) {
		my $bit0 = substr($bitData,0,1);
		$bit0 = $bit0 ^ 1;
		$bitData = $bit0 . $bitData;
		Log3 $name, 4, "$name hideki: L=$mcbitnum add bit $bit0 at begin $bitData";
	}
    Debug "$name: search in $bitData \n" if ($debug);
	my $message_start = index($bitData,"10101110");
	if ($message_start >= 0 )   # 0x75 but in reverse order
	{
		#Log3 $name, 3, "$name: receive hideki protocol inverted";
		#Log3 $name, 3, "$name: msgstart: $message_start data=$bitData";
		Debug "$name: Hideki protocol detected \n" if ($debug);

		# Todo: Mindest Laenge fuer startpunkt vorspringen 
		# Todo: Wiederholung auch an das Modul weitergeben, damit es dort geprueft werden kann
		my $message_end = index($bitData,"10101110",$message_start+71); # pruefen auf ein zweites 0x75,  mindestens 72 bit nach 1. 0x75, da der Regensensor minimum 8 Byte besitzt je byte haben wir 9 bit
        $message_end = length($bitData) if ($message_end == -1);
        my $message_length = $message_end - $message_start;
		
		return (-1,"message is to short") if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $message_length < $ProtocolListSIGNALduino{$id}{length_min} );
		return (-1,"message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $message_length > $ProtocolListSIGNALduino{$id}{length_max} );

		
		my $hidekihex = "";
		my $idx;
		
		for ($idx=$message_start; $idx<$message_end; $idx=$idx+9)
		{
			my $byte = "";
			$byte= substr($bitData,$idx,8); ## Ignore every 9th bit
			Debug "$name: byte in order $byte " if ($debug);
			$byte = scalar reverse $byte;
			Debug "$name: byte reversed $byte , as hex: ".sprintf('%X', oct("0b$byte"))."\n" if ($debug);

			$hidekihex=$hidekihex.sprintf('%02X', oct("0b$byte"));
		}
		Log3 $name, 4, "$name: hideki protocol converted to hex: $hidekihex with " .$message_length ." bits, messagestart $message_start";

		return  (1,$hidekihex); ## Return only the original bits, include length
	}
	return (-1,"Start pattern (10101110) not found");
}


sub SIGNALduino_Maverick
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	my $debug = AttrVal($name,"debug",0);


	if ($bitData =~ m/^.*(101010101001100110010101).*/) 
	{  # Valid Maverick header detected	
		my $header_pos=$+[1];
		
		Log3 $name, 4, "$name: Maverick protocol detected: header_pos = $header_pos";

		my $hex=SIGNALduinoAdv_b2h(substr($bitData,$header_pos,26*4));
	
		return  (1,$hex); ## Return the bits unchanged in hex
	} else {
		return (-1,"header not found");
	}	
}

sub SIGNALduino_OSPIR
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	my $debug = AttrVal($name,"debug",0);

	return (-1," message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $mcbitnum > $ProtocolListSIGNALduino{$id}{length_max} );
	if ($bitData =~ m/^.*(1{14}|0{14}).*/) 
	{  # Valid Oregon PIR detected	
		my $header_pos=$+[1];
		
		Log3 $name, 4, "$name: Oregon PIR protocol detected: header_pos = $header_pos";

		my $hex=SIGNALduinoAdv_b2h($bitData);
	
		return  (1,$hex); ## Return the bits unchanged in hex
	} else {
		return (-1,"header not found");
	}	
}

sub SIGNALduino_GROTHE
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	#my $debug = AttrVal($name,"debug",0);

	my $bitLength;
	$bitData = substr($bitData, 0, $mcbitnum);
	my $preamble = "01000111";
	my $pos = index($bitData, $preamble);
	if ($pos < 0 || $pos > 5) {
		return (-1,"Start pattern ($preamble) not found");
	} else {
		if ($pos == 1) {		# eine Null am Anfang zuviel
			$bitData =~ s/^0//;		# eine Null am Anfang entfernen
		}
		$bitLength = length($bitData);
		my ($rcode, $rtxt) = SIGNALduinoAdv_TestLength($name, $id, $bitLength, "GROTHE ID=$id");
		if (!$rcode) {
			return (-1," $rtxt");
		}
	}

	my $hex=SIGNALduinoAdv_b2h($bitData);

	Log3 $name, 4, "$name: GROTHE protocol Id=$id detected. $bitData ($bitLength)";	
	return  (1,$hex); ## Return the bits unchanged in hex
}

sub SIGNALduino_SainlogicWS
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	#my $debug = AttrVal($name,"debug",0);

	my $bitLength;
	$bitData = substr($bitData, 0, $mcbitnum);
	my $preamble = "1111010100";
	my $pos = index($bitData, $preamble);
	if ($pos < 0 || $pos > 7) {
		return (-1,"Start pattern ($preamble) not found. Pos=$pos");
	} else {
		$bitData = substr($bitData,$pos+10);
		$bitLength = length($bitData);
		if ($bitLength < 112) {
			return (-1,"message ist too short. length_min=112, length=$bitLength");
		}
		if ($bitLength > 112) {
			$bitData = substr($bitData,0,112);
		}
	}
	my $hex=SIGNALduinoAdv_b2h($bitData);

	Log3 $name, 4, "$name: SainlogicWS protocol Id=$id detected. $bitData ($bitLength)";	
	return  (1,$hex); ## Return the bits unchanged in hex
}

sub SIGNALduino_HMS
{
	my ($name,$bitData,$id,$mcbitnum) = @_;

	my $binData;
	my $data;
	my $pdata;
	my $hex;
	my $xorsum = 0;
	my $parity;
	my $p;
	my $errtxt = '';
	my $i = 0;

	if ($mcbitnum == 70) {
		$bitData = substr($bitData, 1);
		Log3 $name, 4, "$name: HMS $bitData, remove one bit at begin";
	}
	for (my $n=0; $n<=6; $n++) {
		if (substr($bitData, $i+9, 1) eq '1' && $n < 6) {
			$errtxt = 'a fixed 0-bit is 1';
			last;
		}
		$binData = reverse substr($bitData, $i, 8);
		$data = oct("0b$binData");
		$hex .= sprintf('%02x', $data);
		$pdata = $data;
		$p = 0;
		while ($pdata) {       # parity
			$p^=($pdata & 1);
			$pdata>>=1;
		}
		$parity = substr($bitData, $i+8, 1);
		if ($p != $parity) {
			$errtxt = 'wrong parity pos='.($i+8);
			last;
		}
		$i += 10;
		if ($n < 6) {
			$xorsum ^= $data;
			#Log3 $name, 4, "$name: HMS $binData $p $parity";
		}
		else {
			#Log3 $name, 4, "$name: HMS $binData $p $parity $xorsum $data";
			if ($xorsum != $data) {
				$errtxt = 'wrong xorsum';
				last;
			}
		}
	}
	if ($errtxt eq '') {
		Log3 $name, 4, "$name: HMS $hex parity ok, xorsum ok";
		# Reformat for 12_HMS.pm
		my $type = hex(substr($hex,5,1));
		my $stat = $type > 1 ? hex(substr($hex,6,2)) : hex(substr($hex,4,2));
		my $prf  = $type > 1 ? "02" : "05";
		my $bat  = $type > 1 ? hex(substr($hex,4,1))+1 : 1;
		my $HA = substr($hex,0,4);
		my $values = $type > 1 ?  "000000" : substr($hex,6,6);
			$hex = sprintf("%s%x%xa001%s0000%02x%s",
			$prf, $bat, $type,
			$HA,                 # House-Code
			$stat,
			$values);            # Values
		return  (1,$hex);
	}
	else {
		return  (-1, $errtxt);
	}
}

# Funkbus
sub SIGNALduino_Funkbus_calcChecksum
{
	my $s_bitmsg = shift;

	my $bin;
	my $data;
	my $xor = 0;
	my $chk = 0;
	my $p = 0;  # parity
	my $hex = '';
	for (my $i=0; $i<6;$i++) {  # checksum
		$bin = substr($s_bitmsg, $i*8,8);
		$data = oct("b".$bin);
		$hex .= sprintf('%02X', $data);
		if ($i<5) {
			$xor ^= $data;
		}
		else {
			$chk = $data & 0x0f;
			$xor ^= $data & 0xe0;
			$data &= 0xf0;
		}
		while ($data) {       # parity
			$p^=($data & 1);
			$data>>=1;
		}
	}

	my $xor_nibble = (($xor&0xf0) >> 4) ^ ($xor&0x0F);
	my $result = 0;
	if ($xor_nibble & 0x8) {
		$result ^= 0xC;
	}
	if ($xor_nibble & 0x4) {
		$result ^= 0x2;
	}
	if ($xor_nibble & 0x2) {
		$result ^= 0x8;
	}
	if ($xor_nibble & 0x01) {
		$result ^= 0x3;
	}
	return ($result, $chk, $p, $hex);
}

sub SIGNALduino_convert_to_diffManchester
{
	my ($bitData ,$state) = @_;

	# 2 - SL short low
	# 3 - SH short high
	# 4 - LL long low
	# 5 - LH long high
	my $res = '';
	for (my $n=0; $n<length($bitData); $n++) {
		if (substr($bitData, $n, 1) eq '1') {
			if ($state == 0) {
				$res .= '23';
			}
			else {
				$res .= '32';
			}
		}
		else {
			if ($state == 0) {
				$res .= '4';
				$state = 1;
			}
			else {
				$res .= '5';
				$state = 0;
			}
		}
	}
	if ($state == 1) {
		$res .= '3';
	}
	
	return $res;
}

sub SIGNALduino_PreparingSend_Funkbus
{
	my ($hash,$msg) = @_;
	
	my @hexrev = ('0','8','4','C','2','A','6','E','1','9','5','D','3','B','7','F');
	my %gr = ('A' => '00', 'B' => '10', 'C' => '01', 'L' => '11');
	my %action = ('S' => '00', 'U' => '10', 'D' => '01', 'L' => '11');
	my $bitData;
	my $bitData0;
	my $hex;
	my $typ = '';
	my $id = '';
	my $state;
	my $dataBits13;
	my $bits;
	my $sendmsg;
	my $pattern = 'P0=3600;P2=-500;P3=500;P4=-1000;P5=1000;D=0';
	
	if ($msg !~ /^[0-9A-F]{7}[ABCL][1-8][SUDL]./) {
		Log3 $hash, 3, "Funkbus sendmsg error";
		return "Funkbus: sendmsg error";
	}
	
	for (my $n=0; $n<7; $n++) {
		$hex = $hexrev[hex(substr($msg,$n,1))];
		if ($n < 2) {
			$typ .= $hex;
		}
		elsif ($n < 6) {
			$id .= $hex;
		}
		else {
			$state = $hex;
		}
	}
	$id = reverse $id;
	$bitData0 = unpack("B28", pack("H7", $typ.$id.$state));
	
	# 0123 4567 8901 2345
	# uuuu uccc ggua arlp
	#
	# u: unknown
	# c: button on the remote (0-7)
	# g: group (A-C)
	# a: action
	# rl: repeat, longpress
	# p: parity
	$dataBits13 = '00000' . reverse(sprintf('%03b', substr($msg,8,1)-1)) . $gr{substr($msg,7,1)} . '0' . $action{substr($msg,9,1)};
	$bitData0 .= $dataBits13;
	my $d = substr($msg,10,1);
	
	my ($result, undef, $p, undef) = SIGNALduino_Funkbus_calcChecksum($bitData0 . '0000000');
	$bitData = $bitData0 . '00' . $p . sprintf('%04b', $result) . '1';
	my $res = SIGNALduino_convert_to_diffManchester($bitData, 0);
	$sendmsg = 'SR;R=1;' . $pattern . $res . ';';
	
	Log3 $hash, 3, "Funkbus sendmsg0: $bitData typ=$typ id=$id state=$state p=$p result=$result bits=$dataBits13 $d res=$res";
	
	($result, undef, $p, undef) = SIGNALduino_Funkbus_calcChecksum($bitData0 . '1000000');
	$bitData = $bitData0 . '10' . $p . sprintf('%04b', $result) . '1';
	$res = SIGNALduino_convert_to_diffManchester($bitData, 0);
	$sendmsg .= 'SR;R=3;' . $pattern . $res . ';';
	
	Log3 $hash, 3, "Funkbus sendmsg1: $bitData typ=$typ id=$id state=$state p=$p result=$result bits=$dataBits13 $d res=$res";
	Log3 $hash, 3, "Funkbus sendmsg: sendmsg=$sendmsg";
	
	return $sendmsg;
}

sub SIGNALduino_Funkbus
{
	my ($name,$bitData,$id,$mcbitnum) = @_;
	
	return (-1,'message is to long') if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $mcbitnum > $ProtocolListSIGNALduino{$id}{length_max} );
	return (-1,'message is to short') if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $mcbitnum < $ProtocolListSIGNALduino{$id}{length_min} );
	
	$bitData = substr($bitData,0,$mcbitnum);
	$bitData =~ s/1/zo/g; # 0 durch zo (01) ersetzen
	$bitData =~ s/0/oz/g; # 1 durch oz (10) ersetzen
	Log3 $name, 5, "$name Funkbus: raw=$bitData";
	
	my @bitmsg;
	if ($id ne '119') {
		push (@bitmsg,0);
	}
	my $i = 1;
	my $len = $mcbitnum * 2;
	while ($i < $len) {  # nach Differential Manchester wandeln
		if (substr($bitData,$i,1) eq substr($bitData,$i+1,1)) {
			push (@bitmsg,0);
		}
		else {
			push (@bitmsg,1);
		}
		$i += 2;
	}
	my $s_bitmsg = join "", @bitmsg;
	
	if ($id eq '119') {
		my $pos = index($s_bitmsg,'01100');
		if ($pos >= 0 && $pos < 5) {
			$s_bitmsg = '001' . substr($s_bitmsg,$pos);
			return (-1,'wrong bits at begin') if (length($s_bitmsg) < 48);
		}
		else {
			return (-1,'wrong bits at begin');
		}
	}
	
	my ($result, $chk, $p, $hex) = SIGNALduino_Funkbus_calcChecksum($s_bitmsg);

	Log3 $name, 4, "$name Funkbus: len=" . length($s_bitmsg) . " bit49=" . substr($s_bitmsg,48,1) . " parity=$p res=$result chk=$chk msg=$s_bitmsg hex=$hex";
	if ($p == 1) {
		return (-1,'parity error');
	}
	if ($result != $chk) {
		return (-1,'checksum error');
	}
	
	return  (1,$hex);
}


sub SIGNALduino_MCRAW
{
	my ($name,$bitData,$id,$mcbitnum) = @_;

	return (-1," message is to long") if (defined($ProtocolListSIGNALduino{$id}{length_max}) && $mcbitnum > $ProtocolListSIGNALduino{$id}{length_max} );
	
	my $hex=SIGNALduinoAdv_b2h($bitData);
	return  (1,$hex); ## Return the bits unchanged in hex
}


sub SIGNALduino_SomfyRTS
{
	my ($name, $bitData,$id,$mcbitnum) = @_;
	
	my $flag = 0;
	if (defined($mcbitnum)) {
		Log3 $name, 4, "$name: Somfy bitdata: $bitData ($mcbitnum)";
		if ($id eq '43.1') {
			if ($mcbitnum == 57 || ($mcbitnum == 81 && substr($bitData,0,1) eq '0'))  {
				$bitData = substr($bitData, 1, $mcbitnum - 1);
				Log3 $name, 4, "$name: Somfy bitdata: _$bitData (" . length($bitData) . "). Bit am Anfang entfernt";
			} elsif ($mcbitnum > 80) {
				$bitData = substr($bitData, 0, 80); # Bits am Ende entfernen
			}
			my $encData = SIGNALduinoAdv_b2h($bitData);

			#Log3 $name, 4, "$name: Somfy RTS protocol enc: $encData";
			return (1, $encData);
		}
		
		if ($mcbitnum <= 60) {
			if (substr($bitData, 0, 4) eq '1010') {
				$flag = 1;	# ok
			}
			elsif (($mcbitnum == 56 || $mcbitnum == 57) && substr($bitData, 0, 5) eq '01010') {
				$bitData = substr($bitData, 1, $mcbitnum - 1);
				if ($mcbitnum == 56) {
					$bitData .= '0';
				}
				Log3 $name, 4, "$name: Somfy bitdata: _$bitData (" . length($bitData) . "). Bit am Anfang entfernt";
				$flag = 1;	# ok
			}
			elsif ($mcbitnum >= 52 && $mcbitnum <= 55) {
				$bitData = substr($bitData, $mcbitnum - 52, 52);
				$bitData = '1010' . $bitData;
				Log3 $name, 4, "$name: Somfy bitdata: _$bitData (" . length($bitData) . "). 1010 am Anfang zugefuegt";
				$flag = 1;	# ok
			}
		}
		else {	# 80 Bit Nachrichten
			if (substr($bitData, 0, 4) eq '1010' || substr($bitData, 0, 4) eq '1000') {
				$flag = 1;	# ok
			}
			elsif (($mcbitnum == 80 || $mcbitnum == 81) && (substr($bitData, 0, 5) eq '01010' || substr($bitData, 0, 5) eq '01000')) {
				$bitData = substr($bitData, 1, $mcbitnum - 1);
				if ($mcbitnum == 80) {
					$bitData .= '0';
				}
				Log3 $name, 4, "$name: Somfy bitdata: _$bitData (" . length($bitData) . "). Bit am Anfang entfernt";
				$flag = 1;	# ok
			}
			elsif ($mcbitnum == 78 || $mcbitnum == 79) {
				$bitData = substr($bitData, $mcbitnum - 78, 78);
				$bitData = '10' . $bitData;
				Log3 $name, 4, "$name: Somfy bitdata: _$bitData (" . length($bitData) . "). 10 am Anfang zugefuegt";
				$flag = 1;	# ok
			}
		}
	}
	return (-1,"Somfy check error!") if ($flag == 0);
	
	my $encData = SIGNALduinoAdv_b2h($bitData);

	#Log3 $name, 4, "$name: Somfy RTS protocol enc: $encData";
	return (1, $encData);
}


sub SIGNALduinoAdv_TestLength
{
	my ($name, $id, $message_length, $logMsg) = @_;
	my $length;
	
	if (defined($ProtocolListSIGNALduino{$id}{length_min}) && $message_length < $ProtocolListSIGNALduino{$id}{length_min}) {
		$length = ", length_min=$ProtocolListSIGNALduino{$id}{length_min}, length=$message_length";
		Log3 $name, 4, "$name: $logMsg: message is to short$length" if ($logMsg ne "");
		return (0, "message is to short$length");
	}
	elsif (defined($ProtocolListSIGNALduino{$id}{length_max}) && $message_length > $ProtocolListSIGNALduino{$id}{length_max}) {
		$length = ", length_max=$ProtocolListSIGNALduino{$id}{length_max}, length=$message_length";
		Log3 $name, 4, "$name: $logMsg: message is to long$length" if ($logMsg ne "");
		return (0, "message is to long$length");
	}
	return (1,"");
}

# - - - - - - - - - - - -
#=item SIGNALduino_filterMC()
#This functons, will act as a filter function. It will decode MU data via Manchester encoding
# 
# Will return  $count of ???,  modified $rawData , modified %patternListRaw,
# =cut


sub SIGNALduino_filterMC
{
	
	## Warema Implementierung : Todo variabel gestalten
	my ($name,$id,$rawData,%patternListRaw) = @_;
	my $debug = AttrVal($name,"debug",0);
	
	my ($ht, $hasbit, $value) = 0;
	$value=1 if (!$debug);
	my @bitData;
	my @sigData = split "",$rawData;

	foreach my $pulse (@sigData)
	{
	  next if (!defined($patternListRaw{$pulse})); 
	  #Log3 $name, 4, "$name: pulese: ".$patternListRaw{$pulse};
		
	  if (SIGNALduinoAdv_inTol($ProtocolListSIGNALduino{$id}{clockabs},abs($patternListRaw{$pulse}),$ProtocolListSIGNALduino{$id}{clockabs}*0.5))
	  {
		# Short	
		$hasbit=$ht;
		$ht = $ht ^ 0b00000001;
		$value='S' if($debug);
		#Log3 $name, 4, "$name: filter S ";
	  } elsif ( SIGNALduinoAdv_inTol($ProtocolListSIGNALduino{$id}{clockabs}*2,abs($patternListRaw{$pulse}),$ProtocolListSIGNALduino{$id}{clockabs}*0.5)) {
	  	# Long
	  	$hasbit=1;
		$ht=1;
		$value='L' if($debug);
		#Log3 $name, 4, "$name: filter L ";	
	  } elsif ( SIGNALduinoAdv_inTol($ProtocolListSIGNALduino{$id}{syncabs}+(2*$ProtocolListSIGNALduino{$id}{clockabs}),abs($patternListRaw{$pulse}),$ProtocolListSIGNALduino{$id}{clockabs}*0.5))  {
	  	$hasbit=1;
		$ht=1;
		$value='L' if($debug);
	  	#Log3 $name, 4, "$name: sync L ";
	
	  } else {
	  	# No Manchester Data
	  	$ht=0;
	  	$hasbit=0;
	  	#Log3 $name, 4, "$name: filter n ";
	  }
	  
	  if ($hasbit && $value) {
	  	$value = lc($value) if($debug && $patternListRaw{$pulse} < 0);
	  	my $bit=$patternListRaw{$pulse} > 0 ? 1 : 0;
	  	#Log3 $name, 5, "$name: adding value: ".$bit;
	  	
	  	push @bitData, $bit ;
	  }
	}

	my %patternListRawFilter;
	
	$patternListRawFilter{0} = 0;
	$patternListRawFilter{1} = $ProtocolListSIGNALduino{$id}{clockabs};
	
	#Log3 $name, 5, "$name: filterbits: ".@bitData;
	$rawData = join "", @bitData;
	Log3 $name, 5, "$name applied filterfunc: SIGNALduino_filterMC, rawData=$rawData";
	return (undef ,$rawData, %patternListRawFilter);
	
}

sub SIGNALduino_CalculateCRC16
{
	my ($dmsg,$poly,$crc16) = @_;
	my $len = length($dmsg);
	my $i;
	my $byte;
	
	for ($i=0; $i<$len; $i+=2) {
		$byte = hex(substr($dmsg,$i,2)) * 0x100;	# in 16 Bit wandeln
		for (0..7)	# 8 Bits pro Byte
		{
			#if (($byte & 0x8000) ^ ($crc16 & 0x8000)) {
			if (($byte ^ $crc16) & 0x8000) {
				$crc16 <<= 1;
				$crc16 ^= $poly;
			} else {
				$crc16 <<= 1;
			}
			$crc16 &= 0xFFFF;
			$byte <<= 1;
			$byte &= 0xFFFF;
		}
	}
	return $crc16;
}

sub SIGNALduino_CalculateCRC_LaCrosse
{
	my ($dmsg,$len) = @_;
	my $i;
	my $j;
	my $tmp;
	my $val;
	my $res = 0;
	my @data = ();

	for ($i=0; $i<=$len; $i++ ) {
		push(@data,hex(substr($dmsg,$i*2,2)));
	}
	#Debug "data=@data\n";

  for ($j = 0; $j < $len; $j++) {
    $val = $data[$j];
    for ($i = 0; $i < 8; $i++) {
      $tmp = ($res ^ $val) & 0x80;
      $res <<= 1;
      $res &= 0xFF;
      if ($tmp != 0) {
        $res ^= 0x31;
      }
      $val <<= 1;
    }
  }
  return ($res, $data[$len]);
}

sub SIGNALduino_CalculateCRC_TX38
{
	my $dmsg = shift;
	my $tmp;
	my $val;
	my $res = 0;
	my $bitNum=0;
	
	for (my $j = 0; $j < 3; $j++) {
		$val = hex(substr($dmsg,$j*2,2));
		for (my $i = 0; $i < 8; $i++) {
			if ($bitNum < 20) {
				$tmp = ($res ^ $val) & 0x80;
				$res <<= 1;
				$res &= 0xFF;
				if ($tmp != 0) {
					$res ^= 0x31;
				}
				$val <<= 1;
			}
			$bitNum++;
		}
	}
	return $res;
}

sub SIGNALduino_CalculateCRC
{
	my ($len, @data) = @_;
	my $res = 0;

  for (my $j = 0; $j < $len; $j++) {
    $res ^= $data[$j];
    for (my $i = 0; $i < 8; $i++) {
      if ($res & 0x80) {
        $res = ($res << 1) ^ 0x31;
      }
      else {
        $res = ($res << 1)
      }
      $res &= 0xFF;
    }
  }
  return $res;
}

# xFSK method

sub SIGNALduino_FSK_default
{
	my ($name,$dmsg,$id) = @_;
	
	return (1,$dmsg);
}

sub SIGNALduino_LaCrosse
{
	my ($name,$dmsg,$id) = @_;
	
       #
       # Message Format:
       #
       # .- [0] -. .- [1] -. .- [2] -. .- [3] -. .- [4] -.
       # |       | |       | |       | |       | |       |
       # SSSS.DDDD DDN_.TTTT TTTT.TTTT WHHH.HHHH CCCC.CCCC
       # |  | |     ||  |  | |  | |  | ||      | |       |
       # |  | |     ||  |  | |  | |  | ||      | `--------- CRC
       # |  | |     ||  |  | |  | |  | |`-------- Humidity
       # |  | |     ||  |  | |  | |  | |
       # |  | |     ||  |  | |  | |  | `---- weak battery
       # |  | |     ||  |  | |  | |  |
       # |  | |     ||  |  | |  | `----- Temperature T * 0.1
       # |  | |     ||  |  | |  |
       # |  | |     ||  |  | `---------- Temperature T * 1
       # |  | |     ||  |  |
       # |  | |     ||  `--------------- Temperature T * 10
       # |  | |     | `--- new battery
       # |  | `---------- ID
       # `---- START
       #
       #

	#my $hash = $defs{$name};
	#$hash->{LaCrossePair} = 2;
	
	my ($calccrc,$crc) = SIGNALduino_CalculateCRC_LaCrosse($dmsg,4);
	
	if ($calccrc !=$crc) {
		#Log3 $name, 4, "$name LaCrosse_convert: Error! dmsg=$dmsg checksumCalc=$calccrc checksum=$crc";
		return (-1,"LaCrosse_convert checksum Error: dmsg=$dmsg checksumCalc=$calccrc checksum=$crc");
	}
	
	my $addr = ((hex(substr($dmsg,0,2)) & 0x0F) << 2) | ((hex(substr($dmsg,2,2)) & 0xC0) >> 6);
	#my $temperature = ( ( ((hex(substr($dmsg,2,2)) & 0x0F) * 100) + (((hex(substr($dmsg,4,2)) & 0xF0) >> 4) * 10) + (hex(substr($dmsg,4,2)) & 0x0F) ) / 10) - 40;
	my $temperature = ( ( (hex(substr($dmsg,3,1)) * 100) + (hex(substr($dmsg,4,1)) * 10) + hex(substr($dmsg,5,1) ) ) / 10) - 40;
	return (-1,"LaCrosse_convert Error temp=$temperature (out of Range)") if ($temperature >= 60 || $temperature <= -40);

	my $humidity = hex(substr($dmsg,6,2));
	my $batInserted = ((hex(substr($dmsg,2,2)) & 0x20) << 2);
	my $SensorType = 1;
	my $channel = "";
	my $humObat = $humidity & 0x7F;
	if ($humObat == 106) {	# Kanal 1
		$channel = " channel=1 no";
	}
	elsif ($humObat == 125) {	# Kanal 2
		$SensorType = 2;
		$channel = " channel=2 no";
	}
	elsif ($humObat > 99) {
		return (-1,"LaCrosse_convert: hum=$humObat")
	}
	
	Log3 $name, 4, "$name LaCrosse_convert: ID=$id, addr=$addr temp=$temperature " . $channel . "hum=$humObat bat=" . ($humidity & 0x80)  . " batInserted=$batInserted";
	
	# build string for 36_LaCrosse.pm
	my $dmsgMod = "OK 9 $addr ";
	$dmsgMod .= ($SensorType | $batInserted);

	$temperature = (($temperature* 10 + 1000) & 0xFFFF);
	$dmsgMod .= " " . (($temperature >> 8) & 0xFF)  . " " . ($temperature & 0xFF) . " $humidity";
	return (1,$dmsgMod);
}

sub SIGNALduino_PCA301
{
	my ($name,$rmsg,$id) = @_;
	
	my $checksum = substr($rmsg,20,4);
	my $dmsg = substr($rmsg,0,20);
	my $chk16 = SIGNALduino_CalculateCRC16($dmsg,0x8005,0x0000);
	Log3 $name, 5, "$name PCA301_convert: checksumCalc=$chk16 checksum=" . hex($checksum);
	if ($chk16 == hex($checksum)) {
		my $channel = hex(substr($rmsg,0,2));
		my $command = hex(substr($rmsg,2,2));
		my $addr1 = hex(substr($rmsg,4,2));
		my $addr2 = hex(substr($rmsg,6,2));
		my $addr3 = hex(substr($rmsg,8,2));
		my $plugstate = substr($rmsg,11,1);
		my $power1 = hex(substr($rmsg,12,2));
		my $power2 = hex(substr($rmsg,14,2));
		my $consumption1 = hex(substr($rmsg,16,2));
		my $consumption2 = hex(substr($rmsg,18,2));
		$dmsg = "OK 24 $channel $command $addr1 $addr2 $addr3 $plugstate $power1 $power2 $consumption1 $consumption2 $checksum";
		Log3 $name, 4, "$name PCA301_convert: translated native RF telegram PCA301 $dmsg";
	}
	else {
		#Log3 $name, 4, "$name PCA301_convert: wrong checksum $checksum";
		return (-1,"PCA301_convert: wrong checksum $checksum");
	}
	return (1,$dmsg);
}

sub SIGNALduino_KoppFreeControl
{
	my ($name,$dmsg,$id) = @_;
	my $anz = hex(substr($dmsg,0,2)) + 1;
	return (-1,"KoppFreeControl, hexData is to short")
		if ( length($dmsg) < $anz * 2 );  # check double, in def length_min set
	
	my $blkck = 0xAA;
	my $d;
	for (my $i = 0; $i < $anz; $i++) {
		$d = hex(substr($dmsg,$i*2,2));
		$blkck ^= $d;
	}
	my $chk = hex(substr($dmsg,$anz*2,2));
	
	if ($blkck != $chk) {
		#Log3 $name, 4, "$name KoppFreeControl: Error! dmsg=$dmsg checksumCalc=$blkck checksum=$chk";
		return (-1,"KoppFreeControl checksum Error: msg=$dmsg checksumCalc=$blkck checksum=$chk");
	}
	else {
		Log3 $name, 4, "$name KoppFreeControl: dmsg=$dmsg anz=$anz checksum=$blkck ok";
		return (1, "kr" . substr($dmsg,0,$anz*2));
	}
}

sub SIGNALduino_Bresser_5in1
{
	my ($name,$dmsg,$id) = @_;
	my $d1;
	my $d2;
	my $bit;
	my $bitsumRef;
	my $bitadd = 0;
	my $sumFlag = -1;
	
	for (my $i = 0; $i < 13; $i++) {
		$d1 = hex(substr($dmsg,$i*2,2));
		$d2 = hex(substr($dmsg,($i+13)*2,2));
		if (($d1 + $d2) != 255) {
			$sumFlag = $i;
			last;
		}
		if ($i == 0) {
			$bitsumRef = $d2;
		}
		else {
			while ($d2) {
				$bitadd += $d2 & 1;
				$d2 >>= 1;
			}
			#Log3 $name, 4, "$name Bresser: $bit $bitsum $d2 n=$bitadd";
		}
	}
	if ($sumFlag != -1) {
		return (-1, "Bresser 5in1: Checksum Error pos=$sumFlag");
	}
	if ($bitadd != $bitsumRef) {
		return (-1, "Bresser 5in1: Bitsum Error bitsum=$bitadd ref=$bitsumRef");
	}
	$dmsg = substr($dmsg, 28, 24);
	return (1,$dmsg);
}


sub lfsr_digest16 {
    my ($dmsg, $len, $gen, $key) = @_;
    my $sum = 0;
    my $data;
	
    for (my $k = 0; $k < $len; $k++) {
        $data = hex(substr($dmsg,$k*2,2));
        for (my $i = 7; $i >= 0; $i--) {
            if (($data >> $i) & 1) {
                $sum ^= $key;
                $sum &= 0xFFFF;
            }
            if ($key & 1) {
                $key = ($key >>1) ^ $gen;
                $key &= 0xFFFF;
            }
            else {
                $key = ($key >>1);
            }
        }
    }
    return $sum;
}

sub SIGNALduino_Bresser_5in1_neu
{
	my ($name,$dmsg,$id) = @_;
	
	my $digest = lfsr_digest16(substr($dmsg,4), 15, 0x8810, 0x5412);
	my $digestHex = sprintf('%04X',$digest);
	my $digestRef = substr($dmsg,0,4);
	
	if ($digestHex ne $digestRef) {
		return (-1, "Bresser 5in1_neu: crc Error crc=$digestHex crcRef=$digestRef");
	}
	
	my $sum = 0;
	for (my $i = 2; $i < 18; $i++) {
		$sum += hex(substr($dmsg, $i * 2, 2));
	}
	$sum &= 0xFF;
	if ($sum != 0xFF) {
		return (-1, "Bresser 5in1_neu: sum Error sum=$sum != 255");
	}
	Log3 $name, 5, "$name Bresser_5in1_neu: dmsg=$dmsg crc=$digestHex ok, sum ok";
	
	return (1, substr($dmsg, 4, 30));
}

sub SIGNALduino_Bresser_7in1
{
	my ($name,$rawdmsg,$id) = @_;
	my $dmsg = '';
	my $data;
	
	for (my $i = 0; $i < 23; $i++) {
		$data = hex(substr($rawdmsg,$i*2,2)) ^ 0xaa;
		$dmsg .= sprintf('%02X',$data);
	}
	
	my $digest = lfsr_digest16(substr($dmsg,4), 21, 0x8810, 0xba95);
	my $digestRef = substr($dmsg,0,4);
	my $crcXORref = $digest ^ hex($digestRef);
	
	if ($crcXORref != 0x6df1) {
		my $crcXORrefHex = sprintf('%04X',$crcXORref);
		return (-1, "Bresser 7in1 crc Error: crcXORref=$crcXORrefHex not equal to 0x6DF1");
	}
	
	Log3 $name, 5, "$name Bresser_7in1: dmsg=$dmsg crc16 ok";
	
	return (1, substr($dmsg, 4));
}

sub AddWord
{
	my $value = shift;
	
	my $res = ' ' . (($value >> 8) & 0xFF)  . ' ' . ($value & 0xFF);
	
	return $res;
}

sub SIGNALduino_WS1080
{
	my ($name,$dmsg,$id) = @_;
	
	my @data = ();
	
	for (my $i=0; $i<9; $i++ ) {
		push(@data,hex(substr($dmsg,$i*2,2)));
	}
	my $crc = SIGNALduino_CalculateCRC(9, @data);
	my $crcRef = hex(substr($dmsg,18,2));
	if ($crc != $crcRef) {
		return (-1, "WS1080_convert: crc Error crc=$crc crcRef=$crcRef");
	}
	Log3 $name, 4, "$name WS1080_convert: dmsg=$dmsg crc=$crc ok";
	
	my $addr = hex(substr($dmsg,1,2));
	my $sign = ($data[1] >> 3) & 1;
	my $temp = (($data[1] & 0x07) << 8) | $data[2];
	if ($sign) {
		$temp = -$temp;
	}
	my $hum = $data[3] & 0x7F;
	return (-1,"WS1080_convert: Error temp=".($temp/10)." hum=$hum (out of Range)") if ($temp >= 600 || $temp <= -400 || $hum > 99);
	
	my $WindSpeed = $data[4] * 3.4;
	my $WindGust = $data[5] * 3.4;
	my $rain = ((($data[6] & 0x0F) << 8) | $data[7]) * 0.6;
	my $WindDirection = 225 * ($data[8] & 0x0F);
	
	my $flags = 0;
	
	my $dmsgMod = "OK WS $addr 3";
	$dmsgMod .= AddWord($temp+1000) . " $hum";
	$dmsgMod .= AddWord(round($rain,0));
	$dmsgMod .= AddWord($WindDirection);
	$dmsgMod .= AddWord(round($WindSpeed,0)) . AddWord(round($WindGust,0));
	$dmsgMod .= " $flags";
	
	return (1,$dmsgMod);
}

sub SIGNALduino_TX22
{
	my ($name,$dmsg,$pid) = @_;
	
	my $byte1 = hex(substr($dmsg,2,2));
	my $ct = $byte1 & 7;
	return (-1,"LaCrosse_TX22_convert: count=$ct (out of range 1-5)") if ($ct < 1 || $ct > 5);
	my $frameLength = 3 + 2 * $ct;
	return (-1,"LaCrosse_TX22_convert: dmsg=$dmsg frameLength=$frameLength ist too short") if (length($dmsg) < $frameLength*2);
	#Log3 $name, 5, "$name TX22: dmsg=$dmsg ct=$ct byte1=$byte1 frameLength=$frameLength len=" . length($dmsg);
	my ($crc,$crcRef) = SIGNALduino_CalculateCRC_LaCrosse($dmsg, $frameLength-1);
	if ($crc != $crcRef) {
		return (-1,"LaCrosse_TX22_convert: crc Error dmsg=$dmsg crc=$crc crcRef=$crcRef");
	}

	my $addr = hex(substr($dmsg,1,2)) >> 2;
	my $NewBatteryFlag = $byte1 & 0x20;
	my $ErrorFlag = $byte1 & 0x10;
	my $LowBatteryFlag = $byte1 & 8;
	my $temp = ' 255 255';
	my $hum = ' 255';
	my $rain = ' 255 255';
	my $WindDirection = ' 255 255';
	my $WindSpeed = ' 255 255';
	my $WindGust = ' 255 255';
	for (my $i = 0;  $i < $ct; $i++) {
		my $type = hex(substr($dmsg,4+$i*4, 1));
		my $q1 = hex(substr($dmsg,5+$i*4, 1));
		my $q2 = hex(substr($dmsg,6+$i*4, 1));
		my $q3 = hex(substr($dmsg,7+$i*4, 1));
		#Log3 $name, 5, "$name TX22: i=$i type=$type q=$q1 $q2 $q3";
		if ($type == 0) {
			$temp = ($q1*100 + $q2*10 + $q3) -400;
			return (-1,"LaCrosse_TX22_convert: Error temp=".($temp/10)." (out of Range)") if ($temp >= 600 || $temp <= -400);
			$temp = AddWord($temp+1000);
		}
		elsif ($type == 1) {
			$hum = $q2*10 + $q3;
			return (-1,"LaCrosse_TX22_convert: Error hum=$hum (out of Range)") if ($hum > 99);
			$hum = " $hum";
		}
		elsif ($type == 2) {
			$rain = $q1*256 + $q2*16 + $q3;
			$rain = AddWord($rain*2);
		}
		elsif ($type == 3) {
			$WindDirection = AddWord($q1*225);
			$WindSpeed = AddWord($q2*16 + $q3);
		}
		elsif ($type == 4) {
			$WindGust = AddWord($q2*16 + $q3);
		}
	}
	my $flags = 0;
	if ($NewBatteryFlag) {
		$flags = 1;
	}
	if ($ErrorFlag) {
		$flags += 2;
	}
	if ($LowBatteryFlag) {
		$flags += 4;
	}
	
	my $dmsgMod = "OK WS $addr 1" . $temp . $hum . $rain . $WindDirection . $WindSpeed . $WindGust . " $flags";
	
	Log3 $name, 4, "$name LaCrosse_TX22_convert: dmsg=$dmsg addr=$addr count=$ct crc=$crc ok";
	
	return (1,$dmsgMod);
}

sub SIGNALduino_TX38
{
	my ($name,$dmsg,$pid) = @_;
	
	my $crc = SIGNALduino_CalculateCRC_TX38($dmsg);
	my $crcRef = hex(substr($dmsg,5,2));
	if ($crc != $crcRef) {
		return (-1, "LaCrosse_TX38_convert: crc Error crc=$crc crcRef=$crcRef");
	}
	Log3 $name, 4, "$name LaCrosse_TX38_convert: dmsg=$dmsg crc=$crc ok";
	
	my $addr = hex(substr($dmsg,0,2)) & 0x3F;
	my $byte1 = hex(substr($dmsg,2,2));
	my $NewBatteryFlag = $byte1 & 0x80;
	my $LowBatteryFlag = $byte1 & 0x40;
	my $temp = (($byte1 & 0x3F) * 16 + hex(substr($dmsg,4,1))) - 400;
	return (-1,"LaCrosse_TX38_convert: Error temp=". ($temp/10) ." (out of Range)") if ($temp >= 600 || $temp <= -400);
	
	my $hum = $LowBatteryFlag == 0x40 ? 234 : 106;
	
	my $dmsgMod = "OK 9 $addr ";
	$dmsgMod .= (1 + $NewBatteryFlag);
	$dmsgMod .= AddWord($temp+1000) . " $hum";
	
	return (1,$dmsgMod);
}

sub SIGNALduino_WH24
{
	my ($name,$dmsg,$id) = @_;

	my @data = ();
	my $crcLen = 16;
	my $sumLen = 17;
	my $len = 16;
	
	if (length($dmsg) > 32) {
		$len = $sumLen;
	}
	for (my $i=0; $i<$len; $i++ ) {
		push(@data,hex(substr($dmsg,$i*2,2)));
	}
	
	my $crc = SIGNALduino_CalculateCRC($crcLen-1, @data);
	my $crcRef = $data[$crcLen-1];
	if ($crc != $crcRef) {
		return (-1, "WH24: crc Error crc=$crc crcRef=$crcRef");
	}
	
	my $checksumTxt = '';
	if ($len == $sumLen) {
		my $checksum = 0;
		for (my $i=0; $i<$sumLen-1; $i++ ) {
			$checksum += $data[$i];
		}
		$checksum &= 0xFF;
		my $checksumRef = $data[$sumLen-1];
		if ($checksum != $checksumRef) {
			#return (-1, "WH24: checksum Error checksum=$checksum checksumRef=$checksumRef");
			$checksumTxt = "checksum=$checksum checksumRef=$checksumRef";
		}
		else {
			$checksumTxt = "checksum=$checksum ok";
		}
	}
	else {
		$checksumTxt = "no checksum";
	}
	Log3 $name, 4, "$name WH24: dmsg=$dmsg crc=$crc ok, $checksumTxt";
	
	return (1, substr($dmsg, 0, 30));
}

sub SIGNALduino_WH25
{
	my ($name,$dmsg,$id) = @_;

	my $checksum = 0;
	my $bitsum = 0;
	my $byte;
	
	for (my $i=0; $i<=5; $i++ ) {
		$byte = hex(substr($dmsg,$i*2,2));
		$checksum += $byte;
		$bitsum ^= $byte;
	}
	$checksum &= 0xFF;
	my $checksumRef = hex(substr($dmsg,12,2));
	if ($checksum != $checksumRef) {
		return (-1, "WH25: checksum Error checksum=$checksum checksumRef=$checksumRef");
	}
	$bitsum = sprintf('%02X',$bitsum);
	if ($id eq '205.1') { # with bitsum check
		my $bitsumRef = substr($dmsg,15,1) . substr($dmsg,14,1);
		if ($bitsum ne $bitsumRef) {
			return (-1, "WH25: bitsum Error bitsum=$bitsum bitsumRef=$bitsumRef");
		}
		Log3 $name, 4, "$name WH25: dmsg=$dmsg checksum=$checksum ok, bitsum=0x$bitsum ok";
	}
	else { # without bitsum check
		Log3 $name, 4, "$name WH25/WH32B: dmsg=$dmsg checksum=$checksum ok, bitsum=0x$bitsum (no check)";
	}
	
	return (1, $dmsg);
}

sub SIGNALduino_CalculateCRC_W136
{
	my $dmsg = shift;
	my $crc = 0xFF;
	my $data1;

	for (my $n = 0; $n < 21; $n++) {
		$data1 = hex(substr($dmsg,$n*2,2));
		for (my $i = 0; $i < 8; $i++) {
			my $tmp = ($crc ^ $data1) & 0x01;
			$crc >>= 1;
			if ($tmp) {
				$crc ^= 0x8C;
			}
			$data1 >>= 1;
		}
	}
	return $crc;
}

sub SIGNALduino_W136
{
	my ($name,$dmsg,$id) = @_;

	my $crc = SIGNALduino_CalculateCRC_W136($dmsg);
	my $crcRef = hex(substr($dmsg,42,2));
	if ($crc != $crcRef) {
		return (-1, "W136: crc Error crc=$crc crcRef=$crcRef");
	}
	Log3 $name, 4, "$name W136: dmsg=$dmsg crc=$crc ok";
	
	return (1, $dmsg);
}

sub SIGNALduino_WMBus
{
    my ($name,$dmsg,$id) = @_;

    if ($id == 210 && substr($dmsg, 0, 1) eq 'X') {  # WMBus C FrameA
        $dmsg = substr($dmsg, 1);
    }

    return (1, $dmsg);
}

sub SIGNALduino_MAX
{
    my ($name,$dmsg,$id) = @_;
    
    return (1, substr($dmsg, 0, 24));

}

# - - - - - - - - - - - -
#=item SIGNALduino_filterSign()
#This functons, will act as a filter function. It will remove the sign from the pattern, and compress message and pattern
# 
# Will return  $count of combined values,  modified $rawData , modified %patternListRaw,
# =cut


sub SIGNALduino_filterSign	# wurde von Livolo verwendet
{
	my ($name,$id,$rawData,%patternListRaw) = @_;
	my $debug = AttrVal($name,"debug",0);


	my %buckets;
	# Remove Sign
    %patternListRaw = map { $_ => abs($patternListRaw{$_})} keys %patternListRaw;  ## remove sign from all
    
    my $intol=0;
    my $cnt=0;

    # compress pattern hash
    foreach my $key (keys %patternListRaw) {
			
		#print "chk:".$patternListRaw{$key};
    	#print "\n";

        $intol=0;
		foreach my $b_key (keys %buckets){
			#print "with:".$buckets{$b_key};
			#print "\n";
			
			# $value  - $set <= $tolerance
			if (SIGNALduinoAdv_inTol($patternListRaw{$key},$buckets{$b_key},$buckets{$b_key}*0.25))
			{
		    	#print"\t". $patternListRaw{$key}."($key) is intol of ".$buckets{$b_key}."($b_key) \n";
				$cnt++;
				eval "\$rawData =~ tr/$key/$b_key/";

				#if ($key == $msg_parts{clockidx})
				#{
			#		$msg_pats{syncidx} = $buckets{$key};
			#	}
			#	elsif ($key == $msg_parts{syncidx})
			#	{
			#		$msg_pats{syncidx} = $buckets{$key};
			#	}			
				
				$buckets{$b_key} = ($buckets{$b_key} + $patternListRaw{$key}) /2;
				#print"\t recalc to ". $buckets{$b_key}."\n";

				delete ($patternListRaw{$key});  # deletes the compressed entry
				$intol=1;
				last;
			}
		}	
		if ($intol == 0) {
			$buckets{$key}=abs($patternListRaw{$key});
		}
	}
	Log3 $name, 5, "$name applied filterfunc: SIGNALduino_filterSign, count=$cnt";

	return ($cnt,$rawData, %patternListRaw);
	#print "rdata: ".$msg_parts{rawData}."\n";

	#print Dumper (%buckets);
	#print Dumper (%msg_parts);

	#modify msg_parts pattern hash
	#$patternListRaw = \%buckets;
}


# - - - - - - - - - - - -
#=item SIGNALduino_compPattern()
#This functons, will act as a filter function. It will remove the sign from the pattern, and compress message and pattern
# 
# Will return  $count of combined values,  modified $rawData , modified %patternListRaw,
# =cut


sub SIGNALduino_compPattern
{
	my ($name,$id,$rawData,%patternListRaw) = @_;
	my $debug = AttrVal($name,"debug",0);


	my %buckets;
	# Remove Sign
    #%patternListRaw = map { $_ => abs($patternListRaw{$_})} keys %patternListRaw;  ## remove sing from all
    
    my $intol=0;
    my $cnt=0;

    # compress pattern hash
    foreach my $key (keys %patternListRaw) {
			
		#print "chk:".$patternListRaw{$key};
    	#print "\n";

        $intol=0;
		foreach my $b_key (keys %buckets){
			#print "with:".$buckets{$b_key};
			#print "\n";
			
			# $value  - $set <= $tolerance
			if (SIGNALduinoAdv_inTol($patternListRaw{$key},$buckets{$b_key},$buckets{$b_key}*0.4))
			{
		    	#print"\t". $patternListRaw{$key}."($key) is intol of ".$buckets{$b_key}."($b_key) \n";
				$cnt++;
				eval "\$rawData =~ tr/$key/$b_key/";

				#if ($key == $msg_parts{clockidx})
				#{
			#		$msg_pats{syncidx} = $buckets{$key};
			#	}
			#	elsif ($key == $msg_parts{syncidx})
			#	{
			#		$msg_pats{syncidx} = $buckets{$key};
			#	}			
				
				$buckets{$b_key} = ($buckets{$b_key} + $patternListRaw{$key}) /2;
				#print"\t recalc to ". $buckets{$b_key}."\n";

				delete ($patternListRaw{$key});  # deletes the compressed entry
				$intol=1;
				last;
			}
		}	
		if ($intol == 0) {
			$buckets{$key}=$patternListRaw{$key};
		}
	}
	Log3 $name, 5, "$name applied filterfunc: SIGNALduino_compPattern, count=$cnt";

	return ($cnt,$rawData, %patternListRaw);
	#print "rdata: ".$msg_parts{rawData}."\n";

	#print Dumper (%buckets);
	#print Dumper (%msg_parts);

	#modify msg_parts pattern hash
	#$patternListRaw = \%buckets;
}


################################################
# Helper to get a reference of the protocolList Hash
sub SIGNALduinoAdv_getProtocolList
{
	return \%ProtocolListSIGNALduino
}


sub SIGNALduinoAdv_FW_getLastFlashlog
{
	my $name = shift;
	
	my $filename = AttrVal("global", "logdir", "./log/") . "$defs{$name}->{TYPE}-Flash.log";
	my $ret;
	my $openflag = 1;
	open my $fh, "<", $filename or $openflag = 0;
	if ($openflag) {
		$ret = do { local $/; <$fh> };
		#$ret = FW_htmlEscape($ret);
		$ret = "<pre>$ret</pre>";
		$ret =~ s/\n/<br>/g;
		Log3 $name, 4, "getLastFlashlog: filename=$filename";
		close $fh;
	}
	else {
		$ret = "$filename not found";
	}
	
	return $ret;
}

sub SIGNALduinoAdv_FW_getProtocolList
{
	my $name = shift;
	my $dispChanged = shift;
	my $hash = $defs{$name};
	my $ret;
	my $devText = "";
	my $blackTxt = "";
	my %BlacklistIDs;
	my @IdList = ();
	my $comment;
	my $knownFreqs;
	my $actTime;
	
	Log3 $name,5, "$name IdList: Display changes=$dispChanged";
	$actTime = time() if ($dispChanged >= 0);
	
	my $blacklist = AttrVal($name,"blacklist_IDs","");
	if (length($blacklist) > 0) {							# Blacklist in Hash wandeln
		#Log3 $name, 5, "$name getProtocolList: attr blacklistIds=$blacklist";
		%BlacklistIDs = map { $_ => 1 } split(",", $blacklist);;
	}
	
	my $whitelist = AttrVal($name,"whitelist_IDs","#");
	if (AttrVal($name,"blacklist_IDs","") ne "") {				# wenn es eine blacklist gibt, dann "." an die Ueberschrift anhaengen
		$blackTxt = ".";
	}
	
	my ($develop,$devFlag) = SIGNALduinoAdv_getAttrDevelopment($name);	# $devFlag = 1 -> alle developIDs y aktivieren
	$devText = "development version - " if ($devFlag == 1);
	
	my %activeIdHash;
	@activeIdHash{@{$hash->{msIdList}}, @{$hash->{muIdList}}, @{$hash->{mcIdList}}, @{$hash->{mnIdList}}} = (undef);
	#Log3 $name,4, "$name IdList: $mIdList";
	
	my %IDsNoDispatch;
	if (defined($hash->{IDsNoDispatch})) {
		%IDsNoDispatch = map { $_ => 1 } split(",", $hash->{IDsNoDispatch});
		#Log3 $name,4, "$name IdList IDsNoDispatch=" . join ', ' => map "$_" => keys %IDsNoDispatch;
	}
	
	foreach my $id (keys %ProtocolListSIGNALduino)
	{
		if ($dispChanged < 0) {
			push (@IdList, $id);
		}
		else {
		   my $changed = SIGNALduinoAdv_getProtoProp($id,"changed","");
		   if ($changed ne "") {
			  my $year = substr($changed,0,4);
			  my $mon = substr($changed,4,2);
			  my $mday = substr($changed,6,2);
			  my $changedTime = fhemTimeLocal(0, 0, 0, $mday, $mon - 1, $year - 1900);
			  my $diffDays = int(($actTime - $changedTime) / 24 / 3600);

			  if ($diffDays <= $dispChanged) {
			     push (@IdList, $id);
			     #Log3 $name,5, "$name GetIdList=$changed days=$diffDays";
			  }
		   }
		}
	}
	@IdList = sort { $a <=> $b } @IdList;

	$ret = "<table class=\"block wide internals wrapcolumns\">";
	
	$ret .="<caption id=\"SD_protoCaption\">$devText";
  if ($dispChanged < 0) {
	if (substr($whitelist,0,1) ne "#") {
		$ret .="whitelist active$blackTxt</caption>";
	}
	else {
		$ret .="whitelist not active (save activate it)$blackTxt</caption>";
	}
  }
  else {
		$ret .="changes since $dispChanged days</caption>";
  }
	$ret .= "<thead style=\"text-align:center\"><td>act.</td><td>dev</td><td>ID</td><td>MsgType</td><td>modulname</td><td>protocolname</td> <td># comment</td></thead>";
	$ret .="<tbody>";
	my $oddeven="odd";
	my $checked;
	my $checkAll;
	
	foreach my $id (@IdList)
	{
		my $msgtype = "";
		my $chkbox;
		
		if (exists ($ProtocolListSIGNALduino{$id}{format}) && $ProtocolListSIGNALduino{$id}{format} eq "manchester")
		{
			$msgtype = "MC";
		}
		elsif (exists ($ProtocolListSIGNALduino{$id}{cc1101FIFOmode}))
		{
			$msgtype = "MN";
		}
		elsif (exists ($ProtocolListSIGNALduino{$id}{sync}))
		{
			$msgtype = "MS";
		}
		elsif (exists ($ProtocolListSIGNALduino{$id}{clockabs}))
		{
			$msgtype = "MU";
		}
		
		$checked="";
		
		if (substr($whitelist,0,1) ne "#") {	# whitelist aktiv, dann ermitteln welche ids bei select all nicht checked sein sollen
			$checkAll = "SDcheck";
			if (exists($BlacklistIDs{$id})) {
				$checkAll = "SDnotCheck";
			}
			elsif (exists($ProtocolListSIGNALduino{$id}{developId})) {
				if ($devFlag == 1 && $ProtocolListSIGNALduino{$id}{developId} eq "p") {
					$checkAll = "SDnotCheck";
				}
				elsif ($devFlag == 0 && $ProtocolListSIGNALduino{$id}{developId} eq "y" && $develop !~ m/y$id/) {
					$checkAll = "SDnotCheck";
				}
				#elsif ($ProtocolListSIGNALduino{$id}{developId} eq "m") {
				#	$checkAll = "SDnotCheck";
				#}
			}
		}
		else {
			$checkAll = "SDnotCheck";
		}
		
		if (exists($activeIdHash{$id}))
		{
			$checked="checked";
			if (substr($whitelist,0,1) eq "#") {	# whitelist nicht aktiv, dann entspricht select all dem $activeIdHash 
				$checkAll = "SDcheck";
			}
		}
		
		#if (exists($ProtocolListSIGNALduino{$id}{developId}) && $ProtocolListSIGNALduino{$id}{developId} eq "m") {
		#	$checkAll = "SDnotCheck";
		#}
		
		if ($devFlag == 0 && $dispChanged < 0 && exists($ProtocolListSIGNALduino{$id}{developId}) && $ProtocolListSIGNALduino{$id}{developId} eq "p") {
			$chkbox="<div> </div>";
		}
		else {
			$chkbox=sprintf("<INPUT type=\"checkbox\" name=\"%s\" value=\"%s\" %s/>", $checkAll, $id, $checked);
		}
		
		if ($dispChanged < 0) {
			$comment = SIGNALduinoAdv_getProtoProp($id,"comment","");
			if (exists($IDsNoDispatch{$id})) {
				$comment .= " (dispatch is only with a active whitelist possible)";
			}
			$knownFreqs = SIGNALduinoAdv_getProtoProp($id,"knownFreqs","");
			if ($msgtype eq "MN") {		# xFSK
				my $modulation = SIGNALduinoAdv_getProtoProp($id,"modulation","");
				my $datarate = SIGNALduinoAdv_getProtoProp($id,"datarate","");
				my $sync = SIGNALduinoAdv_getProtoProp($id,"sync","");
				$comment .= " (modulation=" . SIGNALduinoAdv_getProtoProp($id,"modulation","") . ", datarate=" . SIGNALduinoAdv_getProtoProp($id,"datarate","") . ", sync=" . SIGNALduinoAdv_getProtoProp($id,"sync","");
				if (length($knownFreqs) > 2) {
					$comment .= ", " . $knownFreqs . "MHz";
				}
				if (exists($ProtocolListSIGNALduino{$id}{length_min})) {
					$comment .= ", Bmin=" . $ProtocolListSIGNALduino{$id}{length_min} / 2;
				}
				if (exists($ProtocolListSIGNALduino{$id}{N})) {
					$comment .= ", N=" . join (' ', @{$ProtocolListSIGNALduino{$id}{N}});
				}
				$comment .= ")";
			}
			elsif (exists($ProtocolListSIGNALduino{$id}{modulation})) {
				$comment .= " (modulation=" . $ProtocolListSIGNALduino{$id}{modulation};
				if (length($knownFreqs) > 2) {
					$comment .= ", " . $knownFreqs . "MHz";
				}
				$comment .= ")";
			}
			elsif (length($knownFreqs) > 2) {
				$comment .= " (" . $knownFreqs . "MHz)";
			}
		}
		else {
			if (exists($ProtocolListSIGNALduino{$id}{deleted})) {
				$comment = "<font color=\"red\">" . SIGNALduinoAdv_getProtoProp($id,"changed","") . "</font>";
			}
			else {
				$comment = SIGNALduinoAdv_getProtoProp($id,"changed","");
			}
		}
		$ret .= sprintf("<tr class=\"%s\"><td>%s</td><td><div>%s</div></td><td><div>%3s</div></td><td><div>%s</div></td><td><div>%s</div></td><td><div>%s</div></td><td><div>%s</div></td></tr>",$oddeven,$chkbox,SIGNALduinoAdv_getProtoProp($id,"developId",""),$id,$msgtype,SIGNALduinoAdv_getProtoProp($id,"clientmodule",""),SIGNALduinoAdv_getProtoProp($id,"name",""),$comment);
		$oddeven= $oddeven eq "odd" ? "even" : "odd" ;
		
		$ret .= "\n";
	}
	$ret .= "</tbody></table>";
	return $ret;
}


sub SIGNALduinoAdv_querygithubreleases
{
    my ($hash, $account) = @_;
    my $name = $hash->{NAME};
    my $param = {
                    url        => "https://api.github.com/repos/$account/SIGNALDuino/releases",
                    timeout    => 5,
                    hash       => $hash,                                                                                 # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method     => "GET",                                                                                 # Lesen von Inhalten
                    header     => "User-Agent: perl_fhem\r\nAccept: application/json",  								 # Den Header gemaess abzufragender Daten aendern
                    callback   =>  \&SIGNALduinoAdv_githubParseHttpResponse,                                                # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                    command    => "queryReleases"
                    
                };

    HttpUtils_NonblockingGet($param);                                                                                     # Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
}

sub SIGNALduinoAdv_githubParseHttpResponse
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
    my $ret = '';
    my $channel=AttrVal($name,"updateChannelFW","stable");
    my $hardware=AttrVal($name,"hardware",undef);
    $hardware =~ s/_optiboot$//;
    if ($hardware eq "nano") {
       $hardware = "nano328";
    }
    elsif ($hardware eq "miniculCC1101") {
       $hardware = "minicul";
    }
    
    if($err ne "")                                                                                                         # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 3, "error while requesting ".$param->{url}." - $err (command: $param->{command}";                                                  # Eintrag fuers Log
        #readingsSingleUpdate($hash, "fullResponse", "ERROR");                                                              # Readings erzeugen
    }

    elsif($data ne "" && defined($hardware))                                                                                                     # wenn die Abfrage erfolgreich war ($data enthaelt die Ergebnisdaten des HTTP Aufrufes)
    {
    	my $json_array = decode_json($data);
    	#print  Dumper($json_array);
       	if ($param->{command} eq "queryReleases") {
	        #Log3 $name, 3, "url ".$param->{url}." returned: $data";                                                            # Eintrag fuers Log
			
			my $releaselist="";
			my @fwreleases;
			if (ref($json_array) eq "ARRAY") {
				foreach my $item( @$json_array ) { 
					next if ($channel eq "stable" && $item->{prerelease});

					#Debug " item = ".Dumper($item);
					
					foreach my $asset (@{$item->{assets}})
					{
						#Log3 $name, 5, "$name queryReleases: hardware=$hardware name=$asset->{name}";
						next if ($asset->{name} !~ m/$hardware/i);
						$ret .= $asset->{name} . "\n";
						#Log3 $name, 5, "$name queryReleases: hardware=$hardware name=$asset->{name}";
						$releaselist.=$item->{tag_name}."__".substr($item->{created_at},0,10)."," ;		
						last;
					}
				}
			}
			#Debug " releases = ".Data::Dumper->new([\@fwreleases],[qw(fwreleases)])->Indent(3)->Quotekeys(0)->Dump;
			
			$releaselist =~ s/,$//;
		  	$hash->{additionalSets}{flash} = $releaselist;                                                               # Readings erzeugen
    	} elsif ($param->{command} eq "getReleaseByTag" && defined($hardware)) {
			#Debug " json response = ".Dumper($json_array);
			
			my @fwfiles;
			foreach my $asset (@{$json_array->{assets}})
			{
				my %fileinfo;
				if ( $asset->{name} =~ m/$hardware/i)  
				{
					$fileinfo{filename} = $asset->{name};
					$fileinfo{dlurl} = $asset->{browser_download_url};
					$fileinfo{create_date} = $asset->{created_at};
					#Debug " firmwarefiles = ".Dumper(@fwfiles);
					push @fwfiles, \%fileinfo;
					
					my $set_return = SIGNALduinoAdv_Set($hash,$name,"flash",$asset->{browser_download_url}); # $hash->{SetFn
					if(defined($set_return))
					{
						Log3  $name, 3, "$name: Error while trying to download firmware: $set_return";    	
					} 
					last;
				}
			}
    	} 
    } elsif (!defined($hardware))  {
    	Log3 $name, 5, "$name: SIGNALduino_githubParseHttpResponse hardware is not defined";
    }                                                                                              # wenn
    # Damit ist die Abfrage zuende.
    # Evtl. einen InternalTimer neu schedulen
    FW_directNotify("#FHEMWEB:$FW_wname", "location.reload('true')", "");
    if (defined($hash->{asyncOut})) {
		$ret = "Fetching $channel firmware versions for $hardware from github\n\n" . $ret;
		$hash->{ret} = $ret;
		InternalTimer(gettimeofday() + 0.1, "SIGNALduinoAdv_asyncOutput", $hash, 0);
		#my $ao = asyncOutput( $hash->{asyncOut}, $ret );
		#delete($hash->{asyncOut});
	}
	#InternalTimer(gettimeofday() + 1, "SIGNALduino_location_reload", $hash, 0);
	#Log3 $name, 5, "$name: SIGNALduino_githubParseHttpResponse done:";
	return 0;
}

sub SIGNALduinoAdv_asyncOutput
{
	my ($hash) = @_;
	my $ao = asyncOutput( $hash->{asyncOut}, $hash->{ret} );
	delete($hash->{ret});
	delete($hash->{asyncOut});
}

#sub SIGNALduino_location_reload
#{
#    FW_directNotify("#FHEMWEB:$FW_wname", "location.reload('true')", "");
#}


1;

=pod
=item summary    supports the same low-cost receiver for digital signals
=item summary_DE Unterst&uumltzt den gleichnamigen Low-Cost Empf&aumlnger f&uuml;r digitale Signale
=begin html

<a id="SIGNALduino"></a>
<h3>SIGNALduino</h3>

	<table>
	<tr><td>
	The SIGNALduino ia based on an idea from mdorenka published at <a href="http://forum.fhem.de/index.php/topic,17196.0.html">FHEM Forum</a>. With the opensource firmware (see this <a href="https://github.com/RFD-FHEM/SIGNALduino">link</a>) it is capable to receive and send different protocols over different medias. Currently are 433Mhz protocols implemented.<br><br>
	The following device support is currently available:<br><br>
	Wireless switches<br>
	<ul>
		<li>ITv1 & ITv3/Elro and other brands using pt2263 or arctech protocol--> uses IT.pm<br>In the ITv1 protocol is used to sent a default ITclock from 250 and it may be necessary in the IT-Modul to define the attribute ITclock</li>
    		<li>ELV FS10 -> 10_FS10</li>
    		<li>ELV FS20 -> 10_FS20</li>
	</ul>
	<br>
	Temperature / humidity sensors
	<ul>
		<li>PEARL NC7159, LogiLink WS0002,GT-WT-02,AURIOL,TCM97001, TCM27 and many more -> 14_CUL_TCM97001 </li>
		<li>Oregon Scientific v2 and v3 Sensors  -> 41_OREGON.pm</li>
		<li>Temperatur / humidity sensors suppored -> 14_SD_WS07</li>
    		<li>technoline WS 6750 and TX70DTH -> 14_SD_WS07</li>
    		<li>Eurochon EAS 800z -> 14_SD_WS07</li>
    		<li>CTW600, WH1080	-> 14_SD_WS09 </li>
    		<li>Hama TS33C, Bresser Thermo/Hygro Sensor -> 14_Hideki</li>
    		<li>FreeTec Aussenmodul NC-7344 -> 14_SD_WS07</li>
    		<li>La Crosse WS-7035, WS-7053, WS-7054 -> 14_CUL_TX</li>
    		<li>ELV WS-2000, La Crosse WS-7000 -> 14_CUL_WS</li>
	</ul>
	<br>
	It is possible to attach more than one device in order to get better reception, fhem will filter out duplicate messages. See more at the <a href="#global">global</a> section with attribute dupTimeout<br><br>
	Note: this module require the Device::SerialPort or Win32::SerialPort module. It can currently only attatched via USB.
	</td>
	</tr>
	</table>
	<br>
	<a name="SIGNALduinodefine"></a>
	<b>Define</b>
	<ul><code>define &lt;name&gt; SIGNALduino &lt;device&gt; </code></ul>
	USB-connected devices (SIGNALduino):<br>
	<ul>
		<li>
		&lt;device&gt; specifies the serial port to communicate with the SIGNALduino. The name of the serial-device depends on your distribution, under linux the cdc_acm kernel module is responsible, and usually a /dev/ttyACM0 or /dev/ttyUSB0 device will be created. If your distribution does not have a	cdc_acm module, you can force usbserial to handle the SIGNALduino by the following command:
		<ul>		
			<li>modprobe usbserial</li>
			<li>vendor=0x03eb</li>
			<li>product=0x204b</li>
		</ul>
		In this case the device is most probably /dev/ttyUSB0.<br><br>
		You can also specify a baudrate if the device name contains the @ character, e.g.: /dev/ttyACM0@57600<br><br>This is also the default baudrate.<br>
		It is recommended to specify the device via a name which does not change:<br>
		e.g. via by-id devicename: /dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0@57600<br>
		If the baudrate is "directio" (e.g.: /dev/ttyACM0@directio), then the perl module Device::SerialPort is not needed, and fhem opens the device with simple file io. This might work if the operating system uses sane defaults for the serial parameters, e.g. some Linux distributions and OSX.<br><br>
		</li>
	</ul>
	<a name="SIGNALduinointernals"></a>
	<b>Internals</b>
	<ul>
		<li><b>IDsNoDispatch</b>: Here are protocols entryls listed by their numeric id for which not communication to a logical module is enabled. To enable, look at the menu option <a href="#SIGNALduinoDetail">Display protocollist</a>.</li>
		<li><b>versionmodule</b>: This shows the version of the SIGNALduino FHEM module itself.</li>
		<li><b>version</b>: This shows the version of the SIGNALduino microcontroller.</li>
	</ul>
	
	<a name="SIGNALduinoset"></a>
	<b>Set</b>
	<ul>
		<li>freq / bWidth / patable / rAmpl / sens<br>
		Only with CC1101 receiver.<br>
		Set the sduino frequency / bandwidth / PA table / receiver-amplitude / sensitivity<br>
		
		Use it with care, it may destroy your hardware and it even may be
		illegal to do so. Note: The parameters used for RFR transmission are
		not affected.<br>
		<ul>
			<a name="cc1101_freq"></a>
			<li><code>cc1101_freq</code> sets both the reception and transmission frequency. Note: Although the CC1101 can be set to frequencies between 315 and 915 MHz, the antenna interface and the antenna is tuned for exactly one frequency. Default is 433.920 MHz (or 868.350 MHz). If not set, frequency from <code>cc1101_frequency</code> attribute will be set.</li>
			<a name="cc1101_bWidth"></a>
			<li><code>cc1101_bWidth</code> can be set to values between 58 kHz and 812 kHz. Large values are susceptible to interference, but make possible to receive inaccurately calibrated transmitters. It affects tranmission too. Default is 325 kHz.</li>
			<a name="cc1101_patable"></a>
			<li><code>cc1101_patable</code> change the PA table (power amplification for RF sending)</li>
			<a name="cc1101_rAmpl"></a>
			<li><code>cc1101_rAmpl</code> is receiver amplification, with values between 24 and 42 dB. Bigger values allow reception of weak signals. Default is 42.</li>
			<a name="cc1101_sens"></a>
			<li><code>cc1101_sens</code> is the decision boundary between the on and off values, and it is 4, 8, 12 or 16 dB.  Smaller values allow reception of less clear signals. Default is 4 dB.</li>
		</ul>
		</li><br>
		<a name="close"></a>
		<li>close<br>
		Closes the connection to the device.
		</li><br>
		<a name="disableMessagetype"></a>
		<li>disableMessagetype<br>
			Allows you to disable the message processing for 
			<ul>
				<li>messages with sync (syncedMS),</li>
				<li>messages without a sync pulse (unsyncedMU)</li> 
				<li>manchester encoded messages (manchesterMC) </li>
			</ul>
			The new state will be saved into the eeprom of your arduino.
		</li><br>
		<a name="enableMessagetype"></a>
		<li>enableMessagetype<br>
			Allows you to enable the message processing for 
			<ul>
				<li>messages with sync (syncedMS)</li>
				<li>messages without a sync pulse (unsyncedMU)</li>
				<li>manchester encoded messages (manchesterMC)</li>
			</ul>
			The new state will be saved into the eeprom of your arduino.
		</li><br>
		<a name="flash"></a>
		<li>flash [hexFile|url]<br>
		The SIGNALduino needs the right firmware to be able to receive and deliver the sensor data to fhem. In addition to the way using the arduino IDE to flash the firmware into the SIGNALduino this provides a way to flash it directly from FHEM. You can specify a file on your fhem server or specify a url from which the firmware is downloaded There are some requirements:
		<ul>
			<li>avrdude must be installed on the host<br> On a Raspberry PI this can be done with: sudo apt-get install avrdude</li>
			<li>the hardware attribute must be set if using any other hardware as an Arduino nano<br> This attribute defines the command, that gets sent to avrdude to flash the uC.</li>
			<li>If you encounter a problem, look into the logfile</li>
		</ul>
		Example:
		<ul>
			<li>flash via Version Name: Versions are provided via get availableFirmware</li>
			<li>flash via hexFile: <code>set sduino flash ./FHEM/firmware/SIGNALduino_mega2560.hex</code></li>
			<li>flash via url for Nano with CC1101: <code>set sduino flash https://github.com/RFD-FHEM/SIGNALDuino/releases/download/3.3.1-RC7/SIGNALDuino_nanocc1101.hex</code></li>
		</ul>
		<i><u>note model radino:</u></i>
		<ul>
			<li>Sometimes there can be problems flashing radino on Linux. <a href="https://wiki.in-circuit.de/index.php5?title=radino_common_problems">Here in the wiki under point "radino & Linux" is a patch!</a></li>
			<li>To activate the bootloader of the radino there are 2 variants.
			<ul>
				<li>1) modules that contain a BSL-button:
				<ul>
					<li>apply supply voltage</li>
					<li>press & hold BSL- and RESET-Button</li>
					<li>release RESET-button, release BSL-button</li>
			 		<li>(repeat these steps if your radino doesn't enter bootloader mode right away.)</li>
				</ul>
				</li>
				<li>2) force bootloader:
				<ul>
					<li>pressing reset button twice</li>
				</ul>
				</li>
			</ul>
			<li>In bootloader mode, the radino gets a different USB ID.</li><br>
			<b>If the bootloader is enabled, it signals with a flashing LED. Then you have 8 seconds to flash.</b>
			</li>
		</ul>
		</li><br>
		<a name="reset"></a>
		<li>reset<br>
		This will do a reset of the usb port and normaly causes to reset the uC connected.
		</li><br>
		<a name="raw"></a>
		<li>raw<br>
		Issue a SIGNALduino firmware command, without waiting data returned by
		the SIGNALduino. See the SIGNALduino firmware code  for details on SIGNALduino
		commands. With this line, you can send almost any signal via a transmitter connected

        To send some raw data look at these examples:
		P<protocol id>#binarydata#R<num of repeats>#C<optional clock>   (#C is optional)<br>
		<br>Example 1: set sduino raw SR;R=3;P0=500;P1=-9000;P2=-4000;P3=-2000;D=0302030;  sends the data in raw mode 3 times repeated
        <br>Example 2: set sduino raw SM;R=3;C=250;D=A4F7FDDE;  sends the data manchester encoded with a clock of 250uS
        <br>Example 3: set sduino raw SC;R=3;SR;P0=5000;D=0;SM;C=250;D=A4F7FDDE;  sends a combined message of raw and manchester encoded repeated 3 times
		</p>
		</li>
        <a name="sendMsg"></a>
		<li>sendMsg<br>
		This command will create the needed instructions for sending raw data via the signalduino. Insteaf of specifying the signaldata by your own you specify 
		a protocol and the bits you want to send. The command will generate the needed command, that the signalduino will send this.
		It is also supported to specify the data in hex. prepend 0x in front of the data part.
		<br><br>
		Please note, that this command will work only for MU or MS protocols. You can't transmit manchester data this way.
		<br><br>
		Input args are:
		<p>
		<ul><li>P<protocol id>#binarydata#R<num of repeats>#C<optional clock>   (#C is optional) 
		<br>Example binarydata: <code>set sduino sendMsg P0#0101#R3#C500</code>
		<br>Will generate the raw send command for the message 0101 with protocol 0 and instruct the arduino to send this three times and the clock is 500.
		<br>SR;R=3;P0=500;P1=-9000;P2=-4000;P3=-2000;D=03020302;</li></ul><br>
		<ul><li>P<protocol id>#0xhexdata#R<num of repeats>#C<optional clock>    (#C is optional) 
		<br>Example 0xhexdata: <code>set sduino sendMsg P29#0xF7E#R4</code>
		<br>Generates the raw send command with the hex message F7E with protocl id 29 . The message will be send four times.
		<br>SR;R=4;P0=-8360;P1=220;P2=-440;P3=-220;P4=440;D=01212121213421212121212134;
		</p></li></ul>
		</li>
	</ul>
	
	
	<a name="SIGNALduinoget"></a>
	<b>Get</b>
	<ul>
        <a name="availableFirmware"></a>
        <li>availableFirmware<br>
		Retrieves available firmware versions from github and displays them in set flash command.
		</li><br>
		<a name="ccconf"></a>
        <li>ccconf<br>
		Read some CUL radio-chip (cc1101) registers (frequency, bandwidth, etc.),
		and display them in human readable form.<br>
		Only with cc1101 receiver.
		</li><br>
        <a name="ccpatable"></a>
		<li>ccpatable<br>
		read cc1101 PA table (power amplification for RF sending)<br>
		Only with cc1101 receiver.
		</li><br>
        <a name="ccreg"></a>
		<li>ccreg<br>
		read cc1101 registers (99 reads all cc1101 registers)<br>
		Only with cc1101 receiver.
		</li><br>
        <a name="cmds"></a>
		<li>cmds<br>
		Depending on the firmware installed, SIGNALduinos have a different set of
		possible commands. Please refer to the sourcecode of the firmware of your
		SIGNALduino to interpret the response of this command. See also the raw-
		command.
		</li><br>
        <a name="config"></a>
		<li>config<br>
		Displays the configuration of the SIGNALduino protocol category. | example: <code>MS=1;MU=1;MC=1;Mred=0</code>
		</li><br>
        <a name="freeram"></a>
		<li>freeram<br>
		Displays the free RAM.
		</li><br>
        <a name="ping"></a>
		<li>ping<br>
		Check the communication with the SIGNALduino.
		</li><br>
        <a name="raw"></a>
		<li>raw<br>
		Issue a SIGNALduino firmware command, and wait for one line of data returned by
		the SIGNALduino. See the SIGNALduino firmware code  for details on SIGNALduino
		commands. With this line, you can send almost any signal via a transmitter connected
		</li><br>
        <a name="uptime"></a>
		<li>uptime<br>
		Displays information how long the SIGNALduino is running. A FHEM reboot resets the timer.
		</li><br>
        <a name="version"></a>
		<li>version<br>
		return the SIGNALduino firmware version
		</li><br>		
	</ul>

	
	<a name="SIGNALduinoattr"></a>
	<b>Attributes</b>
	<ul>
		<li><a href="#addvaltrigger">addvaltrigger</a><br>
        	Create triggers for additional device values. Right now these are RSSI, RAWMSG and DMSG.
        	</li><br>
        	<a name="blacklist_IDs"></a>
        	<li>blacklist_IDs<br>
        	The blacklist works only if a whitelist not exist.
        	</li><br>
        	<a name="cc1101_frequency"></a>
		<li>cc1101_frequency<br>
        	Since the PA table values are frequency-dependent, at 868 MHz a value greater 800 required.
        	</li><br>
		<a name="debug"></a>
		<li>debug<br>
		This will bring the module in a very verbose debug output. Usefull to find new signals and verify if the demodulation works correctly.
		</li><br>
		<a name="development"></a>
		<li>development<br>
		The development attribute is only available in development version of this Module for backwart compatibility. Use the whitelistIDs Attribute instead. Setting this attribute to 1 will enable all protocols which are flagged with developID=Y.
		<br>
		To check which protocols are flagged, open via FHEM webinterface in the section "Information menu" the option "Display protocollist". Look at the column "dev" where the flags are noted.
		<br>
		</li>
		<li><a href="#do_not_notify">do_not_notify</a></li><br>
		<li><a href="#attrdummy">dummy</a></li><br>
    		<a name="doubleMsgCheck_IDs"></a>
		<li>doubleMsgCheck_IDs<br>
		This attribute allows it, to specify protocols which must be received two equal messages to call dispatch to the modules.<br>
		You can specify multiple IDs wih a colon : 0,3,7,12<br>
		</li><br>
    		<a name="eventlogging"></a>
		<li>eventlogging<br>
    		With this attribute you can control if every logmessage is also provided as event. This allows to generate event for every log messages.
    		Set this to 0 and logmessages are only saved to the global fhem logfile if the loglevel is higher or equal to the verbose attribute.
    		Set this to 1 and every logmessages is also dispatched as event. This allows you to log the events in a seperate logfile.
    		</li><br>
		<a name="flashCommand"></a>
		<li>flashCommand<br>
    		This is the command, that is executed to performa the firmware flash. Do not edit, if you don't know what you are doing.<br>
		If the attribute not defined, it uses the default settings. <b>If the user defines the attribute manually, the system uses the specifications!</b><br>
    		<ul>
			<li>default for nano, nanoCC1101, miniculCC1101, promini: <code>avrdude -c arduino -b [BAUDRATE] -P [PORT] -p atmega328p -vv -U flash:w:[HEXFILE] 2>[LOGFILE]</code></li>
			<li>default for radinoCC1101: <code>avrdude -c avr109 -b [BAUDRATE] -P [PORT] -p atmega32u4 -vv -D -U flash:w:[HEXFILE] 2>[LOGFILE]</code></li>
		</ul>
		It contains some place-holders that automatically get filled with the according values:<br>
		<ul>
			<li>[BAUDRATE]<br>
			is the speed (e.g. 57600)</li>
			<li>[PORT]<br>
			is the port the Signalduino is connectd to (e.g. /dev/ttyUSB0) and will be used from the defenition</li>
			<li>[HEXFILE]<br>
			is the .hex file that shall get flashed. There are three options (applied in this order):<br>
			- passed in set flash as first argument<br>
			- taken from the hexFile attribute<br>
			- the default value defined in the module<br>
			</li>
			<li>[LOGFILE]<br>
			The logfile that collects information about the flash process. It gets displayed in FHEM after finishing the flash process</li>
		</ul><br>
		<u><i>note:</u></i> ! Sometimes there can be problems flashing radino on Linux. <a href="https://wiki.in-circuit.de/index.php5?title=radino_common_problems">Here in the wiki under the point "radino & Linux" is a patch!</a>
    		</li><br>
    		<a name="hardware"></a>
		<li>hardware<br>
    		When using the flash command, you should specify what hardware you have connected to the usbport. Doing not, can cause failures of the device.
		<ul>
			<li>ESP_1M: ESP8266 with 1 MB flash and CC1101 receiver</li>
			<li>ESP32: ESP32</li>
			<li>nano: Arduino Nano 328 with cheap receiver</li>
			<li>nanoCC1101: Arduino Nano 328 wirh CC110x receiver</li>
			<li>miniculCC1101: Arduino pro Mini with CC110x receiver and cables as a minicul</li>
			<li>promini: Arduino Pro Mini 328 with cheap receiver </li>
			<li>radinoCC1101: Arduino compatible radino with cc1101 receiver</li>
		</ul>
	</li><br>
	<li>maxMuMsgRepeat<br>
	MU signals can contain multiple repeats of the same message. The results are all send to a logical module. You can limit the number of scanned repetitions. Defaukt is 4, so after found 4 repeats, the demoduation is aborted. 	
	<br></li>
    <a name="minsecs"></a>
	<li>minsecs<br>
    This is a very special attribute. It is provided to other modules. minsecs should act like a threshold. All logic must be done in the logical module. 
    If specified, then supported modules will discard new messages if minsecs isn't past.
    </li><br>
    <a name="noMsgVerbose"></a>
    <li>noMsgVerbose<br>
    With this attribute you can control the logging of debug messages from the io device.
    If set to 3, this messages are logged if global verbose is set to 3 or higher.
    </li><br>
    <a name="longids"></a>
	<li>longids<br>
        Comma separated list of device-types for SIGNALduino that should be handled using long IDs. This additional ID allows it to differentiate some weather sensors, if they are sending on the same channel. Therfor a random generated id is added. If you choose to use longids, then you'll have to define a different device after battery change.<br>
		Default is to not to use long IDs for all devices.
      <br><br>
      Examples:<PRE>
# Do not use any long IDs for any devices:
attr sduino longids 0
# Use any long IDs for all devices (this is default):
attr sduino longids 1
# Use longids for BTHR918N devices.
# Will generate devices names like BTHR918N_f3.
attr sduino longids BTHR918N
</PRE></li>
<a name="rawmsgEvent"></a>
<li>rawmsgEvent<br>
When set to "1" received raw messages triggers events
</li><br>
<a name="suppressDeviceRawmsg"></a>
<li>suppressDeviceRawmsg<br>
When set to 1, the internal "RAWMSG" will not be updated with the received messages
</li><br>
	<a name="updateChannelFW"></a>
	<li>updateChannelFW<br>
		The module can search for new firmware versions (<a href="https://github.com/RFD-FHEM/SIGNALDuino/releases">SIGNALDuino</a> and <a href="https://github.com/RFD-FHEM/SIGNALESP/releases">SIGNALESP</a>). Depending on your choice, only stable versions are displayed or also prereleases are available for flash. The option testing does also provide the stable ones.
		<ul>
			<li>stable: only versions marked as stable are available. These releases are provided very infrequently</li>
			<li>testing: These versions needs some verifications and are provided in shorter intervals</li>
		</ul>
		<br>Reload the available Firmware via get availableFirmware manually.
		</li><br>
		<a name="whitelist_IDs"></a>
		<li>whitelist_IDs<br>
		This attribute allows it, to specify whichs protocos are considured from this module. Protocols which are not considured, will not generate logmessages or events. They are then completly ignored. This makes it possible to lower ressource usage and give some better clearnes in the logs. You can specify multiple whitelistIDs wih a colon : 0,3,7,12<br> With a # at the beginnging whitelistIDs can be deactivated.
		<br>
		Not using this attribute or deactivate it, will process all stable protocol entrys. Protocols which are under development, must be activated explicit via this Attribute.
		</li><br>
   		<a name="WS09_CRCAUS"></a>
   		<li>WS09_CRCAUS<br>
       		<ul>
				<li>0: CRC-Check WH1080 CRC = 0  on, default</li>
       			<li>2: CRC = 49 (x031) WH1080, set OK</li>
			</ul>
    	</li>
   	</ul>
   	<a name="SIGNALduinoDetail"></a>
	<b>Information menu</b>
	<ul>
   	    <a name="Display protocollist"></a>
		<li>Display protocollist<br> 
		Shows the current implemented protocols from the SIGNALduino and to what logical FHEM Modul data is sent.<br>
		Additional there is an checkbox symbol, which shows you if a protocol will be processed. This changes the Attribute whitlistIDs for you in the background. The attributes whitelistIDs and blacklistIDs affects this state.
		Protocols which are flagged in the row <code>dev</code>, are under development
		<ul>
			<li>If a row is flagged via 'm', then the logical module which provides you with an interface is still under development. Per default, these protocols will not send data to logcial module. To allow communication to a logical module you have to enable the protocol.</li> 
			<li>If a row is flagged via 'p', then this protocol entry is reserved or in early development state.</li>
			<li>If a row is flalged via 'y' then this protocol isn't fully tested or reviewed.</li>
		</ul>
		<br>
		If you are using blacklistIDs, then you also can not activate them via the button, delete the attribute blacklistIDs if you want to control enabled protocols via this menu.
		</li><br>
   	</ul>
							  		   
=end html
=begin html_DE

<a id="SIGNALduinoAdv"></a>
<h3>SIGNALduinoAdv</h3>

	<table>
	<tr><td>
	Der <a href="https://wiki.fhem.de/wiki/SIGNALduino">SIGNALduino</a> ist basierend auf einer Idee von "mdorenka" und ver&ouml;ffentlicht im <a href="http://forum.fhem.de/index.php/topic,17196.0.html">FHEM Forum</a>.<br>

	Mit der OpenSource-Firmware (<a href="https://github.com/Ralf9/SIGNALDuino/releases">SIGNALDuino</a>) ist dieser f&auml;hig zum Empfangen und Senden verschiedener Protokolle auf 433 und 868 Mhz.
	<br><br>
	Folgende Ger&auml;te werden zur Zeit unterst&uuml;tzt:
	<br><br>
	Funk-Schalter<br>
	<ul>
		<li>ITv1 & ITv3/Elro und andere Marken mit dem pt2263-Chip oder welche das arctech Protokoll nutzen --> IT.pm<br> Das ITv1 Protokoll benutzt einen Standard ITclock von 250 und es kann vorkommen, das in dem IT-Modul das Attribut "ITclock" zu setzen ist.</li>
    		<li>ELV FS10 -> 10_FS10</li>
    		<li>ELV FS20 -> 10_FS20</li>
	</ul>
	Temperatur-, Luftfeuchtigkeits-, Luftdruck-, Helligkeits-, Regen- und Windsensoren:
	<ul>
		<li>PEARL NC7159, LogiLink WS0002,GT-WT-02,AURIOL,TCM97001, TCM27 und viele anderen -> 14_CUL_TCM97001.pm</li>
		<li>Oregon Scientific v2 und v3 Sensoren  -> 41_OREGON.pm</li>
		<li>Temperatur / Feuchtigkeits Sensoren unterst&uuml;tzt -> 14_SD_WS07.pm</li>
    		<li>technoline WS 6750 und TX70DTH -> 14_SD_WS07.pm</li>
    		<li>Eurochon EAS 800z -> 14_SD_WS07.pm</li>
    		<li>CTW600, WH1080	-> 14_SD_WS09.pm</li>
    		<li>Hama TS33C, Bresser Thermo/Hygro Sensoren -> 14_Hideki.pm</li>
    		<li>FreeTec Aussenmodul NC-7344 -> 14_SD_WS07.pm</li>
    		<li>La Crosse WS-7035, WS-7053, WS-7054 -> 14_CUL_TX</li>
    		<li>ELV WS-2000, La Crosse WS-7000 -> 14_CUL_WS</li>
	</ul>
	<br>
	Es ist m&ouml;glich, mehr als ein Ger&auml;t anzuschliessen, um beispielsweise besseren Empfang zu erhalten. FHEM wird doppelte Nachrichten herausfiltern.
	Mehr dazu im dem <a href="#global">global</a> Abschnitt unter dem Attribut dupTimeout<br><br>
	Hinweis: Dieses Modul erfordert das Device::SerialPort oder Win32::SerialPort
	Modul. Es kann derzeit nur &uuml;ber USB angeschlossen werden.
	</td>
	</tr>
	</table>
	<br>
	<a id="SIGNALduinoAdv-define"></a>
	<b>Define</b>
	<code>define &lt;name&gt; SIGNALduinoAdv &lt;device&gt; </code>
	USB-connected devices (SIGNALduino):<br>
	<ul><li>
		&lt;device&gt; spezifiziert den seriellen Port f&uuml;r die Kommunikation mit dem SIGNALduino.
		Der Name des seriellen Ger&auml;ts h&auml;ngt von Ihrer  Distribution ab. In Linux ist das <code>cdc_acm</code> Kernel_Modul daf&uuml;r verantwortlich und es wird ein <code>/dev/ttyACM0</code> oder <code>/dev/ttyUSB0</code> Ger&auml;t angelegt. Wenn deine Distribution kein <code>cdc_acm</code> Module besitzt, kannst du usbserial nutzen um den SIGNALduino zu betreiben mit folgenden Kommandos:
		<ul>
			<li>modprobe usbserial</li>
			<li>vendor=0x03eb</li>
			<li>product=0x204b</li>
		</ul>
		In diesem Fall ist das Ger&auml;t h&ouml;chstwahrscheinlich <code>/dev/ttyUSB0</code>.<br><br>

		Sie k&ouml;nnen auch eine Baudrate angeben, wenn der Ger&auml;tename das @ enth&auml;lt, Beispiel: <code>/dev/ttyACM0@57600</code><br>Dies ist auch die Standard-Baudrate.<br><br>
		Es wird empfohlen, das Ger&auml;t &uuml;ber einen Namen anzugeben, der sich nicht &auml;ndert. Beispiel via by-id devicename: <code>/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0@57600</code><br>
		Wenn die Baudrate "directio" (Bsp: <code>/dev/ttyACM0@directio</code>), dann benutzt das Perl Modul nicht Device::SerialPort und FHEM &ouml;ffnet das Ger&auml;t mit einem file io. Dies kann funktionieren, wenn das Betriebssystem die Standardwerte f&uuml;r die seriellen Parameter verwendet. Bsp: einige Linux Distributionen und
		OSX.<br><br>
		</li>
	</ul>
	
	<a id="SIGNALduinoAdv-internals"></a>
	<b>Internals</b>
	<ul>
		<li><b>IDsNoDispatch</b>: Hier werden protokoll Eintr&auml;ge mit ihrer numerischen ID aufgelistet, f&ouml;r welche keine Weitergabe von Daten an logische Module aktiviert wurde. Um die weiterhabe zu aktivieren, kann die Me&uuml;option <a href="#SIGNALduinoDetail">Display protocollist</a> verwendet werden.</li>
		<li><b>versionmodule</b>: Hier wird die Version des SIGNALduino FHEM Modules selbst angezeigt.</li>
		<li><b>version</b>: Hier wird die Version des SIGNALduino microcontrollers angezeigt.</li>
	</ul>
	

	<a id="SIGNALduinoAdv-set"></a>
	<b>SET</b>
	<ul>
		<a id="SIGNALduinoAdv-set-LaCrossePairForSec"></a>
		<li>LaCrossePairForSec<br>
		(NUR bei Verwendung eines cc110x Funk-Moduls)<br>
		Aktivieren Sie die automatische Erstellung neuer LaCrosse-Sensoren für "x" Sekunden. Wenn ignore_battery nicht angegeben wird, werden nur Sensoren erstellt, die das Flag 'Neue Batterie' senden.</li><br>
		<li>cc1101_freq / cc1101_bWidth / cc1101_patable / cc1101_rAmpl / cc1101_sens<br>
		(NUR bei Verwendung eines cc110x Funk-Moduls)<br><br>
		Stellt die SIGNALduino-Frequenz / Bandbreite / PA-Tabelle / Empf&auml;nger-Amplitude / Empfindlichkeit ein.<br>
		Verwenden Sie es mit Vorsicht. Es kann Ihre Hardware zerst&ouml;ren und es kann sogar illegal sein, dies zu tun.<br>
		Hinweis: Die f&uuml;r die RFR-&Uuml;bertragung verwendeten Parameter sind nicht betroffen.<br></li>
		<ul>
		<a id="SIGNALduinoAdv-set-cc1101_freq"></a>
		<li><code>cc1101_freq</code> , legt sowohl die Empfangsfrequenz als auch die &Uuml;bertragungsfrequenz fest.<br>
		Hinweis: Obwohl der CC1101 auf Frequenzen zwischen 315 und 915 MHz eingestellt werden kann, ist die Antennenschnittstelle und die Antenne auf genau eine Frequenz abgestimmt. Standard ist 433.920 MHz (oder 868.350 MHz). Wenn keine Frequenz angegeben wird, dann wird die Frequenz aus dem Attribut <code>cc1101_frequency</code> geholt.</li>
		<a id="SIGNALduinoAdv-set-cc1101_bWidth"></a>
		<li><code>cc1101_bWidth</code> , kann auf Werte zwischen 58 kHz und 812 kHz eingestellt werden. Grosse Werte sind st&ouml;ranf&auml;llig, erm&ouml;glichen jedoch den Empfang von ungenau kalibrierten Sendern. Es wirkt sich auch auf die &Uuml;bertragung aus. Standard ist 325 kHz.</li>
		<a id="SIGNALduinoAdv-set-cc1101_patable_433"></a>
		<li><code>cc1101_patable_433</code> , &Auml;nderung der PA-Tabelle bei 433 MHz (Leistungsverst&auml;rkung f&uuml;r HF-Senden)</li>
		<a id="SIGNALduinoAdv-set-cc1101_patable_868"></a>
		<li><code>cc1101_patable_868</code> , &Auml;nderung der PA-Tabelle (Leistungsverst&auml;rkung f&uuml;r HF-Senden)</li>
		<a id="SIGNALduinoAdv-set-cc1101_rAmpl"></a>
		<li><code>cc1101_rAmpl</code> , ist die Empf&auml;ngerverst&auml;rkung mit Werten zwischen 24 und 42 dB. Gr&ouml;ssere Werte erlauben den Empfang schwacher Signale. Der Standardwert ist 42.</li>
		<a id="SIGNALduinoAdv-set-cc1101_sens"></a>
		<li><code>cc1101_sens</code> , ist die Entscheidungsgrenze zwischen den Ein- und Aus-Werten und betr&auml;gt 4, 8, 12 oder 16 dB. Kleinere Werte erlauben den Empfang von weniger klaren Signalen. Hat bei xFSK eine andere Bedeutung.</li>
		<a id="SIGNALduinoAdv-set-cc1101_reg"></a>
		<li><code>cc1101_reg</code> Es k&ouml;nnen mehrere Register auf einmal gesetzt werden. Das Register wird &uuml;ber seinen zweistelligen Hexadezimalwert angegeben, gefolgt von einem zweistelligen Wert. Mehrere Register werden via Leerzeichen getrennt angegeben</li>
		</ul>
		<br>
		<a id="SIGNALduinoAdv-set-close"></a>
		<li>close<br>
		Beendet die Verbindung zum Ger&auml;t.</li><br>
		<a id="SIGNALduinoAdv-set-disableMessagetype_3" data-pattern="disableMessagetype_3|enableMessagetype_3"></a>
		<li>disableMessagetype_3 / enableMessagetype_3<br>
		Erm&ouml;glicht das Deaktivieren der Nachrichtenverarbeitung f&uuml;r
		<ul>
			<li>Nachrichten mit sync (syncedMS)</li>
			<li>Nachrichten ohne einen sync pulse (unsyncedMU)</li> 
			<li>Manchester codierte Nachrichten (manchesterMC)</li>
		</ul>
		Der neue Status wird in den eeprom vom sduino geschrieben.
		</li><br>
		<a id="SIGNALduinoAdv-set-disableMessagetype_4" data-pattern="disableMessagetype_4|enableMessagetype_4"></a>
		<li>disableMessagetype_4 / enableMessagetype_4 (Maple oder ESP32, Firmware 4.x.x)<br>
		Erm&ouml;glicht das Deaktivieren der Nachrichtenverarbeitung f&uuml;r
		<ul>
			<li>Nachrichten mit sync (syncedMS)</li>
			<li>Nachrichten mit sync (syncedMSEQ)</li>
			<li>Nachrichten ohne einen sync pulse (unsyncedMU)</li> 
			<li>Manchester codierte Nachrichten (manchesterMC)</li>
		</ul>
		syncedMSEQ (Nur beim Maple oder ESP32:)<br>
		Die zweite und folgenden MS-Nachrichten werden nun mit der vorherigen MS-Nachricht verglichen, sind sie gleich, wird am Ende ein "Q" ausgegeben.<br>
		Werden 3 gleiche MS-Nachrichten in Folge empfangen, so werden die folgenden MS-Nachrichten nicht mehr ausgegeben.<br>
		Dies kann mit CEQ aktiviert und mit CDQ deaktiviert werden. Wenn aktiviert, dann steht bei get config (CG): MSEQ=1;<br>
		<br>
		Der neue Status wird in den eeprom vom Arduino geschrieben.
		</li><br>
		<a id="SIGNALduinoAdv-set-flash"></a>
		<li>flash [hexFile|url]<br>
		Der SIGNALduino ben&ouml;tigt die richtige Firmware, um die Sensordaten zu empfangen und zu liefern. Unter Verwendung der Arduino IDE zum Flashen der Firmware in den SIGNALduino bietet dies eine M&ouml;glichkeit, ihn direkt von FHEM aus zu flashen. Sie k&ouml;nnen eine Datei auf Ihrem fhem-Server angeben oder eine URL angeben, von der die Firmware heruntergeladen wird. Es gibt einige Anforderungen:
		<ul>
			<li><code>avrdude</code> muss auf dem Host installiert sein. Auf einem Raspberry PI kann dies getan werden mit: <code>sudo apt-get install avrdude</code></li>
			<li>Das Hardware-Attribut muss festgelegt werden, wenn eine andere Hardware als Arduino Nano verwendet wird. Dieses Attribut definiert den Befehl, der an avrdude gesendet wird, um den uC zu flashen.</li>
			<li>Bei Problem mit dem Flashen, k&ouml;nnen im Logfile interessante Informationen zu finden sein.</li>
		</ul>
		Beispiele:
		<ul>
			<li>flash mittels Versionsnummer: Versionen k&ouml;nnen mit get availableFirmware abgerufen werden</li>		
			<li>flash via hexFile: <code>set sduino flash ./FHEM/firmware/SIGNALduino_mega2560.hex</code></li>
			<li>flash via url f&uuml;r einen Nano mit CC1101: <code>set sduino flash https://github.com/RFD-FHEM/SIGNALDuino/releases/download/3.3.1-RC7/SIGNALDuino_nanocc1101.hex</code></li>
		</ul>
		<i><u>Hinweise Modell radino:</u></i>
		<ul>
			<li>Teilweise kann es beim flashen vom radino unter Linux Probleme geben. <a href="https://wiki.in-circuit.de/index.php5?title=radino_common_problems">Hier im Wiki unter dem Punkt "radino & Linux" gibt es einen Patch!</a></li>
			<li>Um den Bootloader vom radino zu aktivieren gibt es 2 Varianten.
			<ul>
				<li>1) Module welche einen BSL-Button besitzen:
				<ul>
					<li>Spannung anlegen</li>
					<li>druecke & halte BSL- und RESET-Button</li>
					<li>RESET-Button loslassen und danach den BSL-Button loslassen</li>
					<li>(Wiederholen Sie diese Schritte, wenn Ihr radino nicht sofort in den Bootloader-Modus wechselt.)</li>
				</ul>
				</li>
				<li>2) Bootloader erzwingen:
				<ul>
					<li>durch zweimaliges druecken der Reset-Taste</li>
				</ul>
				</li>
			</ul>
			<li>Im Bootloader-Modus erh&auml;lt der radino eine andere USB ID.</li><br>
			<b>Wenn der Bootloader aktiviert ist, signalisiert er das mit dem Blinken einer LED. Dann hat man ca. 8 Sekunden Zeit zum flashen.</b>
			</li>
		</ul>
		</li><br>
	<a id="SIGNALduinoAdv-set-raw"></a>
	<li>raw<br>
	Sendet einen SIGNALduino Firmware Befehl ohne auf die vom SIGNALduino zur&uuml;ckgegebenen Daten zu warten. Siehe auch get raw.<br>
	Damit l&auml;sst sich auch fast jedes Signal &uuml;ber einen angeschlossenen Sender senden. Um einige Rohdaten zu senden, schauen Sie sich diese Beispiele an:<br>
			<ul>
				<li> <code>set sduino raw SR;R=3;P0=500;P1=-9000;P2=-4000;P3=-2000;D=0302030;</code> , sendet die Daten im Raw-Modus dreimal wiederholt</li>
				<li> <code>set sduino raw SM;R=3;C=250;D=A4F7FDDE;</code> , sendet die Daten Manchester codiert mit einem clock von 250&micro;S</li>
				<li> <code>set sduino raw SC;R=3;SR;P0=5000;D=0;SM;C=250;D=A4F7FDDE;</code> , sendet eine kombinierte Nachricht von Raw und Manchester codiert 3 mal wiederholt</li>
				<li> <code>set sduino raw SN;R=1;N=3;D=010403B7A100FFFFFFFF8D6EAAAAAA;</code> , sendet die xFSK - Daten einmal</li>
				<li> <code>set sduino raw bss0F44AE0C7856341201074447780B12436587255D</code> , sendet eine WMBus S Nachricht (ab Firmware V 4.2.2)</li>
				<li> <code>set sduino raw bst0F44AE0C7856341201074447780B12436587255D</code> , sendet eine WMBus T Nachricht (ab Firmware V 4.2.2)</li>
				</ul>
	</li><br>
	<a id="SIGNALduinoAdv-set-reset"></a>
	<li>reset<br>
	&Ouml;ffnet die Verbindung zum Ger&auml;t neu und initialisiert es.</li><br>
	<a id="SIGNALduinoAdv-set-rfmode"></a>
	<li>rfmode<br>
	Damit kann ein rfmode ausgew&auml;hlt werden, es werden dann die dazu notwendigen Register zum sduino mit dem CW Befehl gesendet.<br>
	Bei slowRf wird ein cc1101 Factoryreset durchgef&uuml;hrt<br>
	Die FSK-Bezeichung hat den folgenden Aufbau: "Name_Bx_Nx_Datarate"<br>
	- Bx: die Anzahl der Bytes die empfangen werden<br>
	- Nx: Nummerierung der cc1101 konfig<br>
	- Bei gleicher Nummerierung werden auch rfmode Eintr&auml;ge mit kleinerer Byteanzahl (Bx) verarbeitet</li><br>
	<a id="SIGNALduinoAdv-set-rfmodeTesting"></a>
	<li>rfmodeTesting<br>
	optimierte cc1101 Registerkonfigurationen (rfmode) für Firmware V3.3.5 und V4.2.2</li><br>
	<a id="SIGNALduinoAdv-set-sendMsg"></a>
	<li>sendMsg<br>
	Dieser Befehl erstellt die erforderlichen Anweisungen zum Senden von Rohdaten &uuml;ber den SIGNALduino. Sie k&ouml;nnen die Signaldaten wie Protokoll und die Bits angeben, die Sie senden m&ouml;chten.<br>
	Alternativ ist es auch m&ouml;glich, die zu sendenden Daten in hexadezimaler Form zu &uuml;bergeben. Dazu muss ein 0x vor den Datenteil geschrieben werden.
	<br><br>
		Argumente sind:
    <p>
      <ul>
        <li>P&lt;protocol id&gt;#binarydata#R&lt;anzahl der wiederholungen&gt;#C&ltoptional taktrate&gt;  (#C is optional)
          <br>Beispiel binarydata: <code>set sduino sendMsg P0#0101#R3#C500</code>
          <br>Dieser Befehl erzeugt ein Sendekommando f&uuml;r die Bitfolge 0101 anhand der protocol id 0. Als Takt wird 500 verwendet.
          <br>SR;R=3;P0=500;P1=-9000;P2=-4000;P3=-2000;D=03020302;<br>
        </li>
      </ul>
      <ul>
        <li>Beispiel ITv1: <code>set sduino sendMsg P3#isF0FFFFFF0FFF#R6#C350#F10b071</code>   (#C #F ist optional)
          <br>SR;R=6;P0=350;P1=-10850;P2=1050;P3=-350;P4=-1050;D=01042304040423042304230423042304230404042304230423;F=10b071;   (raw Sendekommando)
      </li>
      </ul>
      <ul>
        <li>P&lt;protocol id&gt;#0xhexdata#R&lt;anzahl der wiederholungen&gt;#C&lt;optional taktrate&gt;    (#C is optional)
          <br>Beispiel 0xhexdata: <code>set sduino sendMsg P29#0xF7E#R4</code>
          <br>Dieser Befehl erzeugt ein Sendekommando f&ouml;r die Hexfolge F7E anhand der protocol id 29. Die Nachricht soll 4x gesendet werden.
          <br>SR;R=4;P0=-8360;P1=220;P2=-440;P3=-220;P4=440;D=01212121213421212121212134;
        </li>
      </ul>
      <ul>
        <li>Beispiel MC-Nachricht (SOMFY): <code>set sduino sendMsg P43#ADEBEBD64C7466#R6</code>
          <br>SC;R=6;SR;P0=-2560;P1=2560;P3=-640;D=10101010101010113;SM;C=645;D=ADEBEBD64C7466;F=10AB85550A;   (raw Sendekommando)
        </li>
      </ul>
      <ul>
        <li>Beispiel FSK: <code>set sduino sendMsg P112#08C1148440123456#R5</code>
           <br>SN;R=5;N=9;D=08C1148440123456;       (raw Sendekommando)
        </li>
      </ul>
    </p>
  </li>
</ul>
<br>

	
	<a id="SIGNALduinoAdv-get"></a>
	<b>Get</b>
	<ul>
	<a id="SIGNALduinoAdv-get-zAvailableFirmware"></a>
	<li>availableFirmware<br>
	Ruft die verf&uuml;gbaren Firmware-Versionen von Github ab und macht diese im <code>set flash</code> Befehl ausw&auml;hlbar.
	</li><br>
	<a id="SIGNALduinoAdv-get-ccconf"></a>
	<li>ccconf<br>
   	Liest s&auml;mtliche radio-chip (cc1101) Register (Frequenz, Bandbreite, etc.) aus und zeigt die aktuelle Konfiguration an.<br>
	(NUR bei Verwendung eines cc1101 Funk-Moduls)
   	</li><br>
	<a id="SIGNALduinoAdv-get-ccpatable"></a>
	<li>ccpatable<br>
   	Liest die cc1101 PA Tabelle aus (power amplification for RF sending).<br>
	(NUR bei Verwendung eines cc1101 Funk-Moduls)
   	</li><br>
	<a id="SIGNALduinoAdv-get-ccreg"></a>
	<li>ccreg<br>
   	Liest das cc1101 Register aus (NUR bei Verwendung eines cc1101 Funk-Moduls)<br>
   	  99 - liest alle aus<br>
   	  31 - chip Version<br>
   	  35 - MARCSTATE Register (1 idle, 0D Rx, 13 Tx)<br>
	</li><br>
	<a id="SIGNALduinoAdv-get-cmdBank"></a>
	<li>cmdBank<br>
	(NUR bei Verwendung eines cc110x Funk-Moduls und EEPROM Speicherb&auml;nke)<br>
	Damit kann eine Info über die EEPROM Speicherb&auml;nke ausgegeben werden oder die Speicherb&auml;nke den cc1101 zugeordnet werden.<br>
	<code>s   - </code>damit wird eine &Uuml;bersicht von allen B&auml;nken ausgegeben.<br>
	<code>1-9 - </code>aktiviert die angegebene Speicherbank, dazu wird der cc1101 mit den in der Speicherbank gespeicherten Registern initialisiert.<br>
    ...Mit nachgestelltem W wird es im EEPROM gespeichert.<br>
    ...Mit nachgestelltem f optimiertes wechseln der aktiven EEPROM Bank (nur bei FSK, ccmode 1-4, nur ab Firmware V3.3.5 und V4.2.2)<br>
    ...Mit nachgestelltem - wird die Bank deaktiviert (ung&uuml;ltig gemacht)(nur ab Firmware V3.3.5 und V4.2.2)<br>
	Nur beim Maple oder ESP32:<br>
	<code>r   - </code>damit wird von allen cc1101 eine Bankinfo ausgegeben.<br>
	<code>A-D - </code>damit wird ein cc1101 (A-D) selektiert. Die Befehle zum lesen und schreiben vom EEPROM und cc1101 Registern werden auf das selektierte cc1101 angewendet.<br>
	<code>A-D<0-9> - </code>damit wird ein cc1101 (A-D) mit einer Speicherbank (0-9) initialisiert. z.B. mit A3 wird das das erste cc1101 Modul A mit der Speicherbank 3 initalisiert.<br>
	<code>           </code>Mit nachgestelltem W wird es im EEPROM gespeichert.<br>
	</li><br>
	<a id="SIGNALduinoAdv-get-cmds"></a>
	<li>cmds<br>
	Abh&auml;ngig von der installierten Firmware besitzt der SIGNALduino verschiedene Befehle.<br>
	S - Zeigt die ConfigSet Variablen an.
	</li><br>
	<a id="SIGNALduinoAdv-get-config"></a>
	<li>config<br>
	Zeigt Ihnen die aktuelle Konfiguration der SIGNALduino Protokollkathegorie an. | Bsp: <code>MS=1;MU=1;MC=1;Mred=0</code>
	</li><br>
	<a id="SIGNALduinoAdv-get-freeram"></a>
	<li>freeram<br>
   	Zeigt den freien RAM an.
	</li><br>
	<a id="SIGNALduinoAdv-get-ping"></a>
   	<li>ping<br>
	Pr&uuml;ft die Kommunikation mit dem SIGNALduino.
	</li><br>
	<a id="SIGNALduinoAdv-get-protocolIdToJson"></a>
	<li>protocolIdToJson<br>
	Damit kann eine vorhandene Protokoll ID als json String ausgegeben werden. Unter dem json String wird die Protokolldefinition besser lesbar dargestellt.<br>
	Der json String kann dann bei Bedarf z.B. in einem Texteditor editiert werden und dann in das Attribut <code>"userprotocol"</code> eingetragen werden.<br>
	Damit es keine Konflikte mit vorhandenen Protokoll IDs geben kann, ist zu empfehlen für die ID eine hohe Nummer z.B. ab 500 zu verwenden.
	</li><br>
	<a id="SIGNALduinoAdv-get-raw"></a>
	<li>raw<br>
	Verarbeitet Nachrichten (MS, MC, MU, ...), als ob sie vom SIGNALduino empfangen wurden (Nur beim DummySduino)<br>
	Es k&ouml;nnen auch DMSG direkt per dispatch an ein Clientmodul &uuml;bergeben werden. Z.B: <code>set raw P7#9020A7F31</code> (Nur beim DummySduino)<br><br>
	Sendet einen CUL Firmware Befehl und gibt die R&uuml;ckgabe aus:<br>

         <small>(Hinweis: Die falsche Benutzung kann zu Fehlfunktionen des SIGNALduino´s f&uuml;hren!)</small>
          <ul>
            <li>CED / CDD -> Debugausgaben ein/aus</li>
            <li>CDL / CEL -> LED aus/ein</li>
            <li>CDR / CER -> Aus-/Einschalten der Datenkomprimierung (config: Mred=0/1)(nur Firmware V3...)</li>
            <li>CSmscnt=[Wert] -> Wiederholungszaehler fuer den split von MS Nachrichten</li>
            <li>CSmuthresh=[Wert] -> Schwellwert fuer den split von MU Nachrichten (0=aus)</li>
            <li>CSmcmbl=[Wert] -> minbitlen fuer MC-Nachrichten</li>
            <li>CSfifolimit=[Wert] -> Schwellwert fuer debug Ausgabe der Pulsanzahl im FIFO Puffer</li>
            <li>e  -> EEPROM / factory reset der cc1101 Register 
            <li>eC - initEEPROMconfig, damit werden die config Daten im EEPROM auf default zurückgesetzt</li>
            <li>WS[Wert] -> Strobe commands z.B. 34 Rx, 35 Tx, 36 idle, 3D nop -> R&uuml;ckgabe 0 idle, 1 Rx, 2 Tx</li>
            <li>XQ -> disableReceiver</li>
            <li>XE -> enableReceiver</li>
          </ul>
         <br></li>
	</li><br>
	<a id="SIGNALduinoAdv-get-uptime"></a>
	<li>uptime<br>
	Zeigt Ihnen die Information an, wie lange der SIGNALduino l&auml;uft. Ein FHEM Neustart setzt den Timer zur&uuml;ck.
	</li><br>
	<a id="SIGNALduinoAdv-get-version"></a>
	<li>version<br>
	Zeigt Ihnen die Information an, welche aktuell genutzte Software Sie mit dem SIGNALduino verwenden.
	</li><br>
	</ul>
	
	
	<a id="SIGNALduinoAdv-attr"></a>
	<b>Attributes</b>
	<ul>
	<a id="SIGNALduinoAdv-attr-addvaltrigger"></a>
	<li>addvaltrigger<br>
	Generiert Trigger f&uuml;r zus&auml;tzliche Werte. Momentan werden DMSG , RAWMSG und RSSI unterst&uuml;zt.
	</li><br>
	<a id="SIGNALduinoAdv-attr-blacklist_IDs"></a>
	<li>blacklist_IDs<br>
	Dies ist eine durch Komma getrennte Liste. Die Blacklist funktioniert nur, wenn keine Whitelist existiert! Hier kann man ID´s eintragen welche man nicht ausgewertet haben m&ouml;chte.
	</li><br>
	<a id="SIGNALduinoAdv-attr-cc1101_frequency"></a>
	<li>cc1101_frequency<br>
	Wenn bei <code>set cc1101_freq</code> keine Frequenz angegeben wird, dann wird diese hier verwendet.
	</li><br>
	<a id="SIGNALduinoAdv-attr-debug"></a>
	<li>debug<br>
	Dies bringt das Modul in eine sehr ausf&uuml;hrliche Debug-Ausgabe im Logfile. Somit lassen sich neue Signale finden und Signale &uuml;berpr&uuml;fen, ob die Demodulation korrekt funktioniert.
	</li><br>
	<a id="SIGNALduinoAdv-attr-development"></a>
	<li>development<br>
	Das development Attribut ist nur in den Entwicklungsversionen des FHEM Modules aus Gr&uuml;den der Abw&auml;rtskompatibilit&auml;t vorhanden. Bei Setzen des Attributes auf "1" werden alle Protokolle aktiviert, welche mittels developID=y markiert sind. 
	<br>
	Wird das Attribut auf 1 gesetzt, so werden alle in Protokolle die mit dem developID Flag "y" markiert sind aktiviert. Die Flags (Spalte dev) k&ouml;nnen &uuml;ber das Webfrontend im Abschnitt "Information menu" mittels "Display protocollist" eingesehen werden.
	<br>
	</li><br>
	<li><a href="#do_not_notify">do_not_notify</a></li><br>
	<a id="SIGNALduinoAdv-attr-doubleMsgCheck_IDs"></a>
	<li>doubleMsgCheck_IDs<br>
	Dieses Attribut erlaubt es, Protokolle anzugeben, die zwei gleiche Nachrichten enthalten m&uuml;ssen, um diese an die Module zu &uuml;bergeben. Sie k&ouml;nnen mehrere IDs mit einem Komma angeben: 0,3,7,12
	</li><br>
	<li><a href="#dummy">dummy</a></li><br>
	<a id="SIGNALduinoAdv-attr-flashCommand"></a>
	<li>flashCommand<br>
	Dies ist der Befehl, der ausgef&uuml;hrt wird, um den Firmware-Flash auszuf&uuml;hren. Nutzen Sie dies nicht, wenn Sie nicht wissen, was Sie tun!<br>
	Wurde das Attribut nicht definiert, so verwendet es die Standardeinstellungen.<br><b>Sobald der User das Attribut manuell definiert, nutzt das System diese Vorgaben!</b><br>
	<ul>
	<li>Standard nano, nanoCC1101, miniculCC1101, promini:<br><code>avrdude -c arduino -b [BAUDRATE] -P [PORT] -p atmega328p -vv -U flash:w:[HEXFILE] 2>[LOGFILE]</code></li>
	<li>Standard radinoCC1101:<br><code>avrdude -c avr109 -b [BAUDRATE] -P [PORT] -p atmega32u4 -vv -D -U flash:w:[HEXFILE] 2>[LOGFILE]</code></li>
	</ul>
	Es enth&auml;lt einige Platzhalter, die automatisch mit den entsprechenden Werten gef&uuml;llt werden:
		<ul>
			<li>[BAUDRATE]<br>
			Ist die Schrittgeschwindigkeit. (z.Bsp: 57600)</li>
			<li>[PORT]<br>
			Ist der Port, an dem der SIGNALduino angeschlossen ist (z.Bsp: /dev/ttyUSB0) und wird von der Definition verwendet.</li>
			<li>[HEXFILE]<br>
			Ist die .hex-Datei, die geflasht werden soll. Es gibt drei Optionen (angewendet in dieser Reihenfolge):<br>
			<ul>
				<li>in <code>set SIGNALduino flash</code> als erstes Argument &uuml;bergeben</li>
				<li>aus dem Hardware-Attribut genommen</li>
				<li>der im Modul definierte Standardwert</li>
			</ul>
			</li>
			<li>[LOGFILE]<br>
			Die Logdatei, die Informationen &uuml;ber den Flash-Prozess sammelt. Es wird nach Abschluss des Flash-Prozesses in FHEM angezeigt</li>
		</ul><br>
	<u><i>Hinweis:</u></i> ! Teilweise kann es beim Flashen vom radino unter Linux Probleme geben. <a href="https://wiki.in-circuit.de/index.php5?title=radino_common_problems">Hier im Wiki unter dem Punkt "radino & Linux" gibt es einen Patch!</a>
	</li><br>
	<a id="SIGNALduinoAdv-attr-hardware"></a>
	<li>hardware<br>
		Notwendig f&uuml;r den Befehl <code>get zAvailableFirmware</code> und <code>set flash</code>. Hier sollten Sie angeben, welche Hardware Sie verwenden. Andernfalls kann es zu Fehlfunktionen des Ger&auml;ts kommen. Wichtig ist auch das Attribut <code>updateChannelFW</code><br>
	</li><br>
	<a id="SIGNALduinoAdv-attr-longids"></a>
	<li>longids<br>
	Durch Komma getrennte Liste von Device-Typen f&uuml;r Empfang von langen IDs mit dem SIGNALduino. Diese zus&auml;tzliche ID erlaubt es Wettersensoren, welche auf dem gleichen Kanal senden zu unterscheiden. Hierzu wird eine zuf&auml;llig generierte ID hinzugef&uuml;gt. Wenn Sie longids verwenden, dann wird in den meisten F&auml;llen nach einem Batteriewechsel ein neuer Sensor angelegt. Standardm&auml;ssig werden keine langen IDs verwendet.<br>
	Folgende Module verwenden diese Funktionalit&auml;t: 14_Hideki, 41_OREGON, 14_CUL_TCM97001, 14_SD_WS07.<br>
	Beispiele:<PRE>
    		# Keine langen IDs verwenden (Default Einstellung):
    		attr sduino longids 0
    		# Immer lange IDs verwenden:
    		attr sduino longids 1
    		# Verwende lange IDs f&uuml;r SD_WS07 Devices.
    		# Device Namen sehen z.B. so aus: SD_WS07_TH_3.
    		attr sduino longids SD_WS07
	</PRE></li>
	<a id="SIGNALduinoAdv-attr-maxMuMsgRepeat"></a>
	<li>maxMuMsgRepeat<br>
	In MU Signalen k&ouml;nnen mehrere Wiederholungen stecken. Diese werden einzeln ausgewertet und an ein logisches Modul uebergeben. Mit diesem Attribut kann angepasst werden, wie viele Wiederholungen gesucht werden. Standard ist 4.
	</li><br>
	<a id="SIGNALduinoAdv-attr-minsecs"></a>
	<li>minsecs<br>
	Es wird von anderen Modulen bereitgestellt. Minsecs sollte wie eine Schwelle wirken. Wenn angegeben, werden unterst&uuml;tzte Module neue Nachrichten verworfen, wenn minsecs nicht vergangen sind.
	</li><br>
	<a id="SIGNALduinoAdv-attr-noMsgVerbose"></a>
	<li>noMsgVerbose<br>
	Mit diesem Attribut k&ouml;nnen Sie die Protokollierung von Debug-Nachrichten vom io-Ger&auml;t steuern. Wenn dieser Wert auf 3 festgelegt ist, werden diese Nachrichten protokolliert, wenn der globale Verbose auf 3 oder h&ouml;her eingestellt ist.
	</li><br>
	<a id="SIGNALduinoAdv-attr-parseMUclockCheck"></a>
	<li>parseMUclockCheck<br>
	wenn &gt; 0 dann ist bei MU Nachrichten der test ob die clock in der Toleranz ist, aktiv<br>
	wenn &equals; 2 dann wird im log, wenn die clock in der Toleranz ist,  &quot;clock is in tol&quot; ausgegeben<br>
	</li><br>
	<a id="SIGNALduinoAdv-attr-rawmsgEvent"></a>
	<li>rawmsgEvent<br>
	Bei der Einstellung "1", l&ouml;sen empfangene Rohnachrichten Ereignisse aus.
	</li><br><br>
	<a id="SIGNALduinoAdv-attr-rfmode_user"></a>
	<li>rfmode_user<br>
	Der hier gespeicherte CW-Befehl kann mit <code>set sduino rfmode custom</code> zum sduino gesendet werden.<br>
	Mit dem CW-Befehl kann eine Folge von cc1101 Registern gesetzt und in die aktuelle EEPROM Speicherbank geschrieben werden.<br>
	Es kann damit auch gleich die Konfigvariable ccN (Adr 3D) und ccmode (Adr 3E) gesetzt werden.<br>
	Es kann auch eine max 8 Zeichen (Adr 0x40 bis 0x47) Bankkurzbeschreibung ins EEPROM geschrieben werden.<br>
	Ab der Firmware V3.3.5 und V4.2.2 k&ouml;nnen auch die CC1101 Register TEST2 (Adr 2C) - TEST0 (Adr 2E) ins EEPROM geschrieben werden, dazu m&uuml;ssen auch die Adr 3A und 3B gesetzt werden (3AA5,3B60).<br>
	
	</li><br>
	<a id="SIGNALduinoAdv-attr-sendSlowRF_A_IDs"></a>
	<li>sendSlowRF_A_IDs<br>
	Nur für MapleSduino Firmware ab V 4.12<br>
	Hier k&ouml;nnen komma getrennt die protocolId angegeben bei denen das cc1101 Modul A zu senden verwendet wird.
	</li><br>
	<a id="SIGNALduinoAdv-attr-suppressDeviceRawmsg"></a>
	<li>suppressDeviceRawmsg<br>
	Bei der Einstellung "1" wird das interne "RAWMSG" nicht mit den empfangenen Nachrichten aktualisiert.
	</li><br>
	<a id="SIGNALduinoAdv-attr-updateChannelFW"></a>
	<li>updateChannelFW<br>
		Das Modul sucht nach Verf&uuml;gbaren Firmware Versionen (<a href="https://github.com/RFD-FHEM/SIGNALDuino/releases">GitHub</a>) und bietet diese via dem Befehl <code>flash</code> zum Flashen an.<br>
		Die Option testing inkludiert auch die stabilen Versionen.
		<ul>
			<li>stable (von Sidey): Als stabil getestete Versionen, erscheint nur sehr selten</li>
			<li>testing (von Sidey): Neue Versionen, welche noch getestet werden muss</li>
			<li>Ralf9: Versionen von Ralf9 (<a href="https://github.com/Ralf9/SIGNALDuino/releases">GitHub</a>)</li>
		</ul>
		<br>Die Liste der verf&uuml;gbaren Versionen muss manuell mittels <code>get availableFirmware</code> neu geladen werden.
		
	</li><br>
	<a id="SIGNALduinoAdv-attr-userProtocol"></a>
	<li>userProtocol<br>
	Siehe <code>get protocolIdToJson</code>
	</li><br>
	<a id="SIGNALduinoAdv-attr-whitelist_IDs"></a>
	<li>whitelist_IDs<br>
	Dieses Attribut erlaubt es, festzulegen, welche Protokolle von diesem Modul aus verwendet werden. Protokolle, die nicht beachtet werden, erzeugen keine Logmeldungen oder Ereignisse. Sie werden dann vollst&auml;ndig ignoriert. Dies erm&ouml;glicht es, die Ressourcennutzung zu reduzieren und bessere Klarheit in den Protokollen zu erzielen. Sie k&ouml;nnen mehrere WhitelistIDs mit einem Komma angeben: 0,3,7,12. Mit einer # am Anfang k&ouml;nnen WhitelistIDs deaktiviert werden. 
	<br>
	Wird dieses Attribut nicht verwrndet oder deaktiviert, werden alle stabilen Protokolleintr&auml;ge verarbeitet. Protokolleintr&auml;ge, welche sich noch in Entwicklung befinden m&uuml;ssen explizit &uuml;ber dieses Attribut aktiviert werden.
	</li><br>
	<a id="SIGNALduinoAdv-attr-WS09_CRCAUS"></a>
	<li>WS09_CRCAUS<br>
		<ul>
			<li>0: CRC-Check WH1080 CRC = 0 on, Standard</li>
			<li>2: CRC = 49 (x031) WH1080, set OK</li>
		</ul>
	</li><br>
  </ul>


	<a id="SIGNALduinoAdv-Detail"></a>
	<b>Information menu</b>
	<ul>
		<a id="SIGNALduinoAdv-Detail-Display protocollist"></a>
		<li>Display protocollist<br> 
		Zeigt Ihnen die aktuell implementierten Protokolle des SIGNALduino an und an welches logische FHEM Modul Sie &uuml;bergeben werden.<br>
		Ausserdem wird mit checkbox Symbolen angezeigt ob ein Protokoll verarbeitet wird. Durch Klick auf das Symbol, wird im Hintergrund das Attribut whitlelistIDs angepasst. Die Attribute whitelistIDs und blacklistIDs beeinflussen den dargestellten Status.
		Protokolle die in der Spalte <code>dev</code> markiert sind, befinden sich in Entwicklung. 
		<ul>
			<li>Wenn eine Zeile mit 'm' markiert ist, befindet sich das logische Modul, welches eine Schnittstelle bereitstellt in Entwicklung. Im Standard &uuml;bergeben diese Protokolle keine Daten an logische Module. Um die Kommunikation zu erm&ouml;glichenm muss der Protokolleintrag aktiviert werden.</li> 
			<li>Wenn eine Zeile mit 'p' markiert ist, wurde der Protokolleintrag reserviert oder befindet sich in einem fr&uuml;hen Entwicklungsstadium.</li>
			<li>Wenn eine Zeile mit 'y' markiert ist, wurde das Protkokoll noch nicht ausgiebig getestet und &uuml;berpr&uuml;ft.</li>
		</ul>
		</li><br>
   	</ul>
   
     
=end html_DE
=cut
