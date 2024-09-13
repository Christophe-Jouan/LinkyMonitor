#!/usr/bin/perl
#
# ROLE et USAGE
# 	Please refer to Usage()  procedure
#
# VERSION : 1.0
#
# HISTORY
#	04/2022	: v1.0 	C.Jouan - : Creation
#
#
# TODO
#
#
#################################################################################################
# Linky display
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
Linky Data Display (OLED management) 
reads LinkyAcq log files to display computed valued on OLED screen:
			------------------
			|   EJP :  NON   |
			|C=x.yyy  I=x.yyy|
			------------------

Usage:  $0  [-t max_sec]  
		-h			help / usage
		-t	<sec>	max exec time (sec) 
		-l			GPIO activation for EJP extra alarm 
					Default = GPIO 25 switched ON if EJP 
					(LED can be connected to GPIO 25)

Outputs:
	- Display LinkyAcq values on OLED mmonitor
	- Activate/de-activate GPIO pin for EJP/HN

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


# Acquisition file read
##################
sub newAcqFile {
	close ($ACQFILE) if ( $ACQFILE);
	$ACQFILE = new IO::File;
	$fic=strftime("$LOGDIR/%Y_%m_%d_LinkyAcq.pl.log",gmtime());
	if ( ! open($ACQFILE, "$fic") ) {
		logmsg("Unable to open acquisition file $fic. waiting...", "WARN");
		}
	# Reset EJP flag
	$EJPDetected=0;
	# Reset Indexes
	$firstIndexHN=$firstIndexHPM=0;
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
use Date::Parse;
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
$LOGFILE = new IO::File;
$fic="$LOGDIR/$TOOLNAME.log";
if ( ! open($LOGFILE, ">>$fic") ) {
	$LOGFILE = STDERR;
	logmsg("Unable to write logfile $fic. Using STDERR", "WARN");
	}

# Logging script activation
logmsg(	"Entering $TOOLNAME with params " . join(" ",@ARGV), "INFO");



# Config file name
#################################################################################################
$_=$TOOLNAME; s/\.[^\.]*$//;
$CONFIGFILE="$CONFDIR/$_.conf";



#################################################################################################
# Default vars
#################################################################################################
$configVars{MAX_TIME}=99999999; 						# Max processing time (3 years)
$configVars{READ_TIMEOUT}=10;							# Default timeout for reads attempts on ACQFILE
$configVars{WAIT_BETWEEN_READ_FAILURE}=20;				# Default tempo after read time-put reached (rotate acq file)
$configVars{WAIT_BETWEEN_READ}=10;					# Default tempo after each read
$configVars{OLED_DISPLAY_TYPE}=SSD1306_128_X_32_I2C;	# Default OLED Display type
$configVars{OLED_ADDRESS}=0x3C; 						# Default OLED address
$configVars{OLED_FLIPPED}=0; 							# Default OLED Flip
$configVars{LED_INIT_CMD}="raspi-gpio set 25 op";		# Default GPIO command for LED initialization
$configVars{LED_ON_CMD}="raspi-gpio set 25 dh";		# Default GPIO command for LED ON
$configVars{LED_OFF_CMD}="raspi-gpio set 25 dl";		# Default GPIO command for LED ON
	``;
	``;

# Override default values w/ config file content
parseConfig();



#################################################################################################
# Analyse ligne de commande
#################################################################################################
GetOptions ("time=s" => \$opt_t, 
			"led" => \$opt_l,
			"help" => \$opt_h);

# option -h (help)
if ($opt_h) { 
	usage ("Help",0);
	}

# GPIO activation  
if ($opt_l) { 
	`$configVars{LED_INIT_CMD}`;
	`$configVars{LED_OFF_CMD}`;
	}

# Max execution time  
if ($opt_t) { 
	if ( $opt_t !~ /\d+/ ) { usage("invalid option -t : must be positive integer",-1) };
	$configVars{MAX_TIME}=$opt_t;
	}



#################################################################################################
# Main init: execution variables 
#################################################################################################
# OLED Display  init
$oled = HiPi::Interface::MonoOLED->new(
    type 		=> $configVars{OLED_DISPLAY_TYPE},
    address		=> $configVars{OLED_ADDRESS},
    flipped 	=> $configVars{OLED_FLIPPED},
    skip_logo 	=> 1
	);
$oled->clear_buffer();
($w, $h) = $oled->draw_text(0,0,'LinkyMonitor Init...', 'Sans14');
$oled->display_update();

# Load LinkAcq log file
newAcqFile();

# Starting time of execution
$START=time();



#################################################################################################
# Main loop for MAX_TIME seconds
#################################################################################################
while ( (time() - $START) < $configVars{MAX_TIME} ) {
	# Try to read on ACQFILE w/ time-out
	# Read log file w/ following format:
	#2021/02/20 19:10:22	DATA	Periode=HN.., IndexHN=000688322, IndexHPM=000080072, PuissConsommee=00000, IConsommee=013
	eval {
    		local $SIG{ALRM} = sub { die "alarm\n" }; 
   		alarm($configVars{READ_TIMEOUT});
		$lig=<$ACQFILE>;
	 	alarm(0);
		};

	# Read time-out triggered
	if ($@) {
		logmsg("Read time out on LinkyAcq logfile, re-opening new file", "WARNING");
		sleep($configVars{WAIT_BETWEEN_READ_FAILURE});
		newAcqFile();
		}

	# Read OK
	else {
		$lig=~s/[\r\n]//g;
		# Select DATA lines
		if($lig =~ /^(\d\d\d\d\/\d\d\/\d\d) \d\d:\d\d:\d\d\tDATA\t(.*)/){
			$readDate=$1;
			$temps=$2;
			$temps =~ s/\s//g;
		
			# Get values form log line
			foreach $s ( split(",",$temps) ) {
				# Split label / value
				($n,$v)=split("=",$s);
				$vals{$n}=$v;
				} # End read values
	
			# Detect HN --> HP  switch
			if ( $EJPDetected==1 && $vals{"Periode"} eq "HN..") {
				$EJPDetected=0;
				$oled->normal_display();
				`$configVars{LED_ON_CMD}` if ($opt_l);
				}

			# Detect HP --> HN  switch
			elsif ( $EJPDetected==0 && $vals{"Periode"} eq "HP..") {
				$EJPDetected=1;
				$oled->invert_display();
				`$configVars{LED_OFF_CMD}` if ($opt_l);
				}
		
			# Reset indexes if needed
			if ( $firstIndexHN == 0) {
				$firstIndexHN=$vals{IndexHN};
				$firstIndexHPM=$vals{IndexHPM};
				}			

			# Compute strings to display
			$puisConInst=$vals{PuissConsommee}/1000;
			$SpuisConInst=sprintf("%.3f", $puisConInst);

			$puisInjInst=($vals{PuissConsommee}==0)?($vals{IConsommee}*0.220):0;
			$SpuisInjInst=sprintf("%.3f", $puisInjInst);
	
			# Display data
			#---------------------
			#|   EJP :  NON      |
			#|C=x.yyy  I=x.yyy   |
			#---------------------
			$oled->clear_buffer();
			$y=0; 
			$str= ($vals{Periode} eq "HP.." ) ? "EJP :    OUI" : "EJP :    NON";
			( $w, $h ) = $oled->draw_text(20, $y, $str, 'Mono19');
			$y += $h - 2;
			$str="C=" . $SpuisConInst . "__I=" . $SpuisInjInst;
			( $w, $h ) = $oled->draw_text(0, $y, $str, 'MonoExtended17');

#print STDERR "$lig ==> $str\n";
			$oled->display_update();
		
			} # End DATA line

		# Wait for in between frames duration
		sleep ($configVars{WAIT_BETWEEN_READ});
		}

	}	# End While (time())

