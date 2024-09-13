#!/usr/bin/perl
#
# ROLE et USAGE
# 	Please refer to Usage()  procedure
#
# VERSION : 1.0
#
# HISTORY
#	03/2022	: v1.1 	C.Jouan - : Creation
#
#
# TODO
#
#
#################################################################################################
# Linky monitoring
#
#
#################################################################################################


#
# Usage routine
########################################
sub usage {
	$msg = @_[0];
	$cr = @_[1];
	print <<FIN_USAGE;
**********   $0 : $msg	**************
Linky Monitoring 
Usage:  $0  [-m linky_mode] [-t max_sec]  
		-h	help / usage
		-m	Linky mode 'historique' or 'standard' 
		-t	max exec time (sec) 
		-l	Affichage OLED des informations lues + allumage LED en EJP 

Outputs:
	- Log file in log directory
	- Manage OLED display and alarm LED 

Ex:
$0 -m historique -t 3600 -l
	-o /tmp
**********   $0 : $msg	**************
	
	
FIN_USAGE
	exit $cr;
	}

# Config File parsing
##################
sub parseConfig {
if (open (CNF, $CONFIGFILE)) {
	while(<CNF>) {
		# Gets rid of comments
		next if (/^\s*\#/ );
		# Gets rid of new line chars
		s/[\r\n]//g;;
		# Read vars-values couples
		if (/\s*(\S+)\s+(\S+.*$)/) { 
			$configVars{$1}=$2;
			}		
		}
	close CNF;
	}
}

# Logfile creation
##################
sub newLogfile {
	close ($LOGFILE) if ( $LOGFILE);
	$LOGFILE = new IO::File;
	$fic=strftime("$LOGDIR/%Y_%m_%d_$TOOLNAME.log",gmtime());
	if ( ! open($LOGFILE, ">>$fic") ) {
		$LOGFILE = STDERR;
		logmsg("Unable to write logfile $fic. Using STDERR", "WARN");
		}
	# No buffering on logs
	$old_fh = select($LOGFILE);
	$| = 1;
	select($old_fh);
	}
	
# Logmsg
##################
sub logmsg {
($msg,$status) = @_;
print $LOGFILE strftime("%Y/%m/%d %H:%M:%S", gmtime()), "\t$status\t$msg\n";
}


#################################################################################################
# Inits
#################################################################################################
use POSIX;
use IO::File;
use Getopt::Long;
use File::Basename;
use HiPi qw( :oled );
use HiPi::Interface::MonoOLED;
$ENV{'TZ'}="GMT";
tzset();


# Tool main dirs and names
#################################################################################################
$TOOLNAME=basename($0);
$t=dirname($0);
$TOOLDIR=($t eq ".")?dirname($ENV{PWD}):dirname($t);
$BINDIR="$TOOLDIR/bin";
$TMPDIR="$TOOLDIR/tmp";
$LOGDIR="$TOOLDIR/logs";
$CONFDIR="$TOOLDIR/conf";


# Log file 
#################################################################################################
newLogfile();

# Logging script activation
logmsg(	"Entering $TOOLNAME with params " . join(" ",@ARGV), "INFO");


# Config file name
#################################################################################################
$_=$TOOLNAME; s/\.[^\.]*$//;
$CONFIGFILE="$CONFDIR/$_.conf";



#################################################################################################
# Default vars
#################################################################################################
$START=time();									# Starting time of execution
$configVars{READ_TIMEOUT}=5;					# Default timeout for reads attempts on INPUT_FD
$configVars{WAIT_BETWEEN_READ_FAILURE}=10;		# Default wait before retry in case of read failure
$configVars{FRAME_LENGTH}=8;					# Default number of PAPP lines between each log message

$configVars{INPUT_DEV}="/dev/ttyAMA0";					# Raspberry Pi 2B / Jessie : dev=/dev/ttyAMA0
$configVars{MAX_TIME}=99999999; 				# Max processing time (3 years)
$configVars{LINKY_MODE}="H"; 					# Default linky mode (historique)

$configVars{OLED_DISPLAY_TYPE}=SSD1306_128_X_32_I2C;	# Default OLED Display type
$configVars{OLED_ADDRESS}=0x3C; 						# Default OLED address
$configVars{OLED_FLIPPED}=0; 							# Default OLED Flip
$configVars{LED_INIT_CMD}="raspi-gpio set 25 op";		# Default GPIO command for LED initialization
$configVars{LED_ON_CMD}="raspi-gpio set 25 dh";		# Default GPIO command for LED ON
$configVars{LED_OFF_CMD}="raspi-gpio set 25 dl";		# Default GPIO command for LED ON

# Override default values w/ config file content
parseConfig();


#################################################################################################
# Analyse ligne de commande
#################################################################################################

GetOptions ("time=s" => \$opt_t, 
			"input=s" => \$opt_i,
			"mode=s" => \$opt_m,
			"led" => \$opt_l,
			"help" => \$opt_h);

# option -h (help)
if ($opt_h) { 
	usage ("Help",0);
	}

# Linky mode 
if ($opt_m) { 
	if ( $opt_m =~ /h/i ) { $configVars{LINKY_MODE}="H" }
	elsif ( $opt_m =~ /s/i) {$configVars{LINKY_MODE}="S"}
	else { usage("invalid option -m : must be 'historique' or 'standard'",-1) };
	}

# Max execution time  
if ($opt_t) { 
	if ( $opt_t !~ /\d+/ ) { usage("invalid option -t : must be positive integer",-1) };
	$configVars{MAX_TIME}=$opt_t;
	}

# Dev in  
if ($opt_i) { 
	if ( ! -r $opt_i ) { usage("invalid option -i : impossible to open  $opt_i for reading",-1) };
	$configVars{INPUT_DEV}=$opt_i;
	}



#################################################################################################
# Main init: execution variables 
#################################################################################################
# Input file descriptor based on configVars or stdin
if ( $configVars{INPUT_DEV} eq "stdin" ) {
	$INPUT_FD=STDIN;
} elsif ( -r $configVars{INPUT_DEV} ) {
	$INPUT_FD = new IO::File;
	open($INPUT_FD, "$configVars{INPUT_DEV}");
} else {
	usage("Input error: impossible to open $configVars{INPUT_DEV} for reading",-1)
	}

# OLED Display  init
if ( $opt_l) {
	$oled = HiPi::Interface::MonoOLED->new(
		type 		=> $configVars{OLED_DISPLAY_TYPE},
		address		=> $configVars{OLED_ADDRESS},
		flipped 	=> $configVars{OLED_FLIPPED},
		skip_logo 	=> 1
		);
	$oled->clear_buffer();
	($w, $h) = $oled->draw_text(0,0,'LinkyMonitor Init...', 'Sans14');
	$oled->display_update();
	}

# EJP flag
$EJPDetected=0;
$EJPstr="NON";

# Error counters
$checksumErrors=0;
$validLines=0;

# Current day date for log rotation
$curDate=strftime("%d", gmtime());

#################################################################################################
# Main loop for MAX_TIME seconds
#################################################################################################
while ( (time() - $START) < $configVars{MAX_TIME} ) {
	# Try to read on INPUT_DEV w/ time-out
	eval {
    	local $SIG{ALRM} = sub { die "alarm\n" }; 
   	 	alarm($configVars{READ_TIMEOUT});
		$lig=<$INPUT_FD>;
    	alarm(0);
		};

	# Read time-out triggered
	if ($@) {
		logmsg("Read time out on $INPUT_DEV", "ERROR");
		sleep($configVars{WAIT_BETWEEN_READ_FAILURE});
		}

	# Read OK
	else {
		$_=$lig;
		@t=split();
		# Data line detected
		if ( @t > 2 ) {
			$label=@t[0];
			$value=@t[1];
			$chk=@t[2];

	# Skip meaningless lines
	next if ( $label ne "PAPP" &&  $label ne "IINST" &&  $label ne "PTEC" &&  $label ne "EJPHN" &&  $label ne "EJPHPM");		

			# Checksum validation (see https://www.enedis.fr/media/2035/download#%5B%7B%22num%22%3A70%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C37%2C680%2C0%5D)
			#########################################################################################
			$lig_chk=0;
			foreach $c ( split(//, "$label $value") ) {  $lig_chk+=ord($c) } ; $lig_chk = ($lig_chk & 0x3F) + 0x20;
			$lig_chk=sprintf('0x%02x', $lig_chk) ; $chkf=sprintf('0x%02x', ord($chk));	
			if ("$lig_chk" ne "$chkf") {
				$checksumErrors++;
				logmsg("Checksum errors $lig_chk found / $chkf expected in: $label $data $chk", "ERROR");
				next;
				}
			$validLines++;


			# Data handling: OLED display / LED alarm
			#########################################################################################
			if ($opt_l) {
				# Detect HN --> HP  switch : LED alarm ON
				if ( $EJPDetected==1 && $label eq "PTEC" && $value eq "HN..") {
					$EJPDetected=0;
					$oled->normal_display();
					`$configVars{LED_ON_CMD}`;
					$EJPstr="NON";
					}

				# Detect HP --> HN  switch : LED alarm OFF
				elsif ( $EJPDetected==0 && $label eq "PTEC" && $value eq "HP..") {
					$EJPDetected=1;
					$oled->invert_display();
					`$configVars{LED_OFF_CMD}`;
					$EJPstr="OUI";
					}
					
				if ( $label eq "IINST") {
					}

				# Display OLED strings at end of frame (PAPP line)
				if ( $label eq "PAPP") {
					$SpuisConInst=sprintf("%.3f", $value/1000);
					$puisInjInst=($value==0)?($data{IINST}*0.220):0;
					$SpuisInjInst=sprintf("%.3f", $puisInjInst);
					$nbPAPP++;
					# Display OLED data
					#---------------------
					#|   EJP :  NON      |
					#|C=x.yyy  I=x.yyy   |
					#---------------------
					$oled->clear_buffer();
					$y=0;
					$alive=($nbPAPP%2==0)?"--":"__"; 
					( $w, $h ) = $oled->draw_text(0, $y, "C___EJP:$EJPstr"."___I", 'MonoExtended17');
					$y += $h - 2;
					$str="$SpuisConInst$alive$SpuisInjInst";
					( $w, $h ) = $oled->draw_text(0, $y, $str, 'Mono19');
					$oled->display_update();
					}

				}

			# Data handling: Update log file
			#########################################################################################
			# End of Frame detected (# of PAPP lines > 
			if ( $nbPAPP >= $configVars{FRAME_LENGTH} ) {
				logmsg("Periode=$data{PTEC}, IndexHN=$data{EJPHN}, IndexHPM=$data{EJPHPM}, PuissConsommee=$data{PAPP}, IConsommee=$data{IINST}", "DATA");

				# Reinit nbPAPP counter
				$nbPAPP=0;

				# Reload config in case of change
				parseConfig();
				
				# logfile rotation if change of date
				if (strftime("%d", gmtime()) ne $curDate ) { 
					newLogfile();
					$curDate=strftime("%d", gmtime());
					}
				}

			# Default line handling: fill %data
			$data{"$label"} = $value;	

			} # End Data line detected
		} # End read OK
	} # End while MAX_TIME
	

#################################################################################################
# Nice exit and clean
#################################################################################################
$flag=($checksumErrors > 0) ? "WARN":"INFO";
logmsg("Valid lines = $validLines - Checksum errors = $checksumErrors", $flag);
logmsg(	"Exiting $TOOLNAME with params " . join(" ",@ARGV), "INFO");

exit ($CR);
