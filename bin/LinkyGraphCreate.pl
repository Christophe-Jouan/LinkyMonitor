#!/usr/bin/perl
# Outputs HTML Graph data from log file dated with -d arg (or from STDIN)
#
#
#
# ROLE et USAGE
# 	Please refer to Usage()  procedure
#
# HISTORY
#	Feb-10-2018  : C.Jouan - Creation
#
# TODO
#
#
#################################################################################################

sub usage {
	$msg = @_[0];
	$cr = @_[1];
	$pos_reps = join ("\n\t\t", sort(@dataTypes));
	print <<FIN_USAGE;

**********   $0 : $msg	**************
Outputs HTML Graph data from log file dated with -d arg (or from STDIN)

Usage:  $0   [-h] [-s date]  [-e date] [-h]
		-s	Start date for plot (format YYYY_MM_DD)
		-e	End date for plot (format YYYY_MM_DD)
		-a	activate auto_update (every 30sec)
		-h	Help: display this message
**********   $0 : $msg	**************
	
FIN_USAGE
	print "$msg";
	print "Exiting $TOOLNAME with code $cr";
	exit $cr;
}


# Init
#################################################################################################
use POSIX;
use IO::File;
use Getopt::Long;
use File::Basename;
use Time::Piece;
$ENV{'TZ'}="GMT";
tzset();

#Tool main directory  name
$t=dirname($0);
$TOOLDIR=($t eq ".")?"..":dirname($t);

$opt_s=strftime("%Y_%m_%d", gmtime());

# Analysing args
##################
GetOptions ("help" => \$opt_h,
			"start=s" => \$opt_s,
			"autoupdate" => \$opt_a,
			"end=s" => \$opt_e);

# option -h (help)
if ($opt_h) { 
	usage ("Help",0);
	}

# option -e (end date)
if ($opt_e) { 
	}

# option -s (start date)
if ($opt_s) { 
	$logFile="$TOOLDIR/logs/$opt_s" . "_LinkyAcq.pl.log";
	$LOGFILE = new IO::File;
	if ( ! open($LOGFILE, "$logFile") ) {
		print ("Unable to read $logFile", "w");
		exit(-1);
		}
	}
else {
	$LOGFILE=STDIN;
	}


# Print HTML output, part1
#-----------------------------------------------
$body=($opt_a)?"<body onLoad='updTimer=setTimeout(auto_update, 600000, document.getElementById(\"autoUpdate\"))'>":"<body>";
print<<FIN_H1;
<html>
<head>
	<link rel="stylesheet" href="bootstrap.min.css">
	<link rel="stylesheet" src="dygraph.min.css" />
<script type="text/javascript"  src="dygraph.js"></script>
<script>
function auto_update(e) {
if (e.checked) {
	da = new Date();
	m = da.getUTCMonth(); m++; if ( m < 10 ) m = '0' + m;
	d = da.getUTCDate(); if ( d < 10 ) d = '0' + d;
	today = da.getUTCFullYear() + '_' + m + '_' + d 
	document.getElementById('startId').value=today;
//	alert("document.getElementById('form').submit()");
	document.getElementById('form').submit();
	}
else {
	if (updTimer) clearTimeout(updTimer)
	}
}
</script>
</head>
$body
<h2 align="center">Linky Monitor: $opt_s  $opt_e</h2>
<div id="graphdiv" style="width:1000px; height:400px;margin-left:20px"></div>
<p style="margin-left:70px"><b>Display: </b>
<input type=checkbox id=0 onClick="showGraph(this)" >
<label for="0"> Index heures normales  </label>
<input type=checkbox id=1 onClick="showGraph(this)" >
<label for="1"> Index heures pointe  </label>
<input type=checkbox id=2 onClick="showGraph(this)" checked>
<label for="2"> Puissance consomm&eacute;e (W)  </label>
<input type=checkbox id=3 onClick="showGraph(this)" checked>
<label for="3"> Intensit&eacute (A)  </label>
<input type=checkbox id=4 onClick="showGraph(this)" checked>
<label for="4"> Puissance inject&eacute;e (W)  </label>

</p>
<script type="text/javascript">
  g = new Dygraph(

    // containing div
    document.getElementById("graphdiv"),

    // CSV data.
FIN_H1


# Read log file w/ following format:
#2021/02/20 19:10:22	DATA	Periode=HN.., IndexHN=000688322, IndexHPM=000080072, PuissConsommee=00000, IConsommee=013
@labels=("Date");
$puisInjTot=0;
$EJPDetected=0;
$FirstEJPIndex=0;
$FirstHNIndex=0;
$EJPDetected=0;
$firstLine=1;
while(<$LOGFILE>) {
	s/[\r\n]//g;
	# Select date and temps data
	if(/^(\d\d\d\d\/\d\d\/\d\d \d\d:\d\d:\d\d)\tDATA\t(.*)/){
		@vals=("$1");$temps=$2;
		$tStamp=Time::Piece->strptime($vals[0],"%Y/%m/%d %H:%M:%S")->strftime("%s");
		$temps =~ s/\s//g;
		
		# Filling arrays for each var
		foreach $s ( split(",",$temps) ) {
			# Split label / value
			($n,$v)=split("=",$s);
			# EJP detect
			$EJPDetected=1 if ( $n eq "Periode" && $v ne "HN..");
			# Keep only num values
			next if ($v !~ /[\d\-]+/);
			# Create label line
			push (@labels,$n) if ($firstLine==1);
			# Fill arrays with sampled temp values
			push(@vals,$v) ; 
			}
		if ($firstLine==1) { 
			$FirstHNIndex=$vals[1];
			$FirstEJPIndex=$vals[2];
			push(@labels, "PuissInjectee");
			$dataLig=join(",",@labels);
			$dataLig=~s/\,\s*$//;
			print "\"$dataLig\\n\" "; 
			$firstLine=0;
			}
		# Add computed injected inst power
		$puisInjInst=($vals[3]==0)?($vals[4]*220):0;
		push(@vals, $puisInjInst);
		# Compute injected power over period
		$puisInjTot+=$puisInjInst*($tStamp-$prev_tStamp) if ($prev_tStamp);
		# Data line in DyGraph
		$dataLig=join(",",@vals);
		$dataLig=~s/\,$//;
		print "+\n\"$dataLig\\n\"";
		# tStamp reinit
		$prev_tStamp=$tStamp;
		}
	}

# Print HTML output, part2 (graph script end)
#-----------------------------------------------
print<<FIN_H2;
	,
  {
      colors: ["darkGreen","firebrick","red","blue","green"],
          series: {
            PuissConsommee: { color: "firebrick", fillGraph: true, fillAlpha: 0.5 },
            PuissInjectee: { color: "green", fillGraph: true, fillAlpha: 0.5 },
          }
    }
  );
  function showGraph(el) {
    g.setVisibility(el.id, el.checked);
  }
    // Hide counter indexes
    g.setVisibility(0, false);
    g.setVisibility(1, false);
</script>
FIN_H2



# Preparation tableau de synthese HTML
#-----------------------------------------------
# Flag HN/EJP
if($EJPDetected==1) { $HTML_EJP_FLAG="
<td style=\"background-color:#FF0000; color:#FFFFFF; text-align:center\" colspan=\"2\">
<div id=\"EJP\">
<b>EJP</b>
</div>
<script>
function blink(e) {
setInterval( function (){ e.style.visibility=(e.style.visibility=='hidden' ? '' : 'hidden')}, 1000);
}
blink(document.getElementById('EJP'))
</script>
</td>"
}
else {$HTML_EJP_FLAG="<td style=\"background-color:#00FF00\" colspan=\"2\"><b>Heures Normales</b></td>"}

# Conso EJP
$consoKWhEJP=($vals[2] - $FirstEJPIndex)/1000;
$consoEurosEJP=$consoKWhEJP*0.9418;
$s="style=\"color:#FF0000\"" if ($consoKWhEJP > 0 ) ;
$HTML_EJP_CONSO="<td $s>$consoKWhEJP KWh</td><td $s>" . sprintf("%.2f", $consoEurosEJP) ." &euro;</td>";

# Conso HN
$consoKWhHN=($vals[1] - $FirstHNIndex)/1000;
$consoEurosHN=$consoKWhHN*0.1283;
$HTML_HN_CONSO="<td>$consoKWhHN KWh</td><td>" . sprintf("%.2f", $consoEurosHN) ." &euro;</td>";

# Conso Totale
$consoKWh= $consoKWhEJP+$consoKWhHN;
$consoEuros=$consoEurosEJP+$consoEurosHN;
$HTML_TOTAL_CONSO="<td><b>$consoKWh KWh</b></td><td><b>" . sprintf("%.2f", $consoEuros) ." &euro;</b></td>";

# Injection Totale
$puisInjTot=$puisInjTot/3600000;
$injEuros=$puisInjTot * 0.16;
$puisInjTot=sprintf("%.3f", $puisInjTot);
$HTML_TOTAL_INJ="<td>$puisInjTot KWh</td><td>" . sprintf("%.2f", $injEuros) ." &euro;</td>";


# Print HTML output, part3 (EJP synthesis)
#-----------------------------------------------
print<<FIN_H3;
<hr/>
<div id="synthesis" style="width:1000px; margin-left:20px" align="center">
<table width="80%" border>
<tr>
<th>P&eacute;riode:</th> $HTML_EJP_FLAG
</tr>
<tr>
<th>Conso EJP sur p&eacute;riode:</th> $HTML_EJP_CONSO
</tr>
<tr>
<th>Conso HN sur p&eacute;riode:</th> $HTML_HN_CONSO
</tr>
<tr>
<th>Conso totale sur p&eacute;riode:</th> $HTML_TOTAL_CONSO
</tr>
<tr>
<th>Inject&eacute; sur p&eacute;riode:</th> $HTML_TOTAL_INJ
</tr>
</table>
</div>

FIN_H3


# Preparation formulaire d'acces aux autres logs
#-----------------------------------------------
$CHECKED=($opt_a)?"CHECKED":"";
print<<FIN_H4;
<hr/>
<div id="formDiv" style="width:1000px; margin-left:20px">
<form id='form'>
<input type="checkbox" id="autoUpdate" name="AUTO_UPDATE" onClick='auto_update(this)' $CHECKED>
<label for="0"> Auto update  </label>
<br/>
<label for="startId"> Date d&eacute;but (YYYY_MM_DD)  </label>
<input  id="startId" name="START_DATE"  value="$opt_s" >
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<label for="endId"> Date fin (YYYY_MM_DD)  </label>
<input  id="endId" name="END_DATE"  value="$opt_e" >
</form>
</div>
<hr/>
FIN_H4


# End html, exit and clean
#-----------------------------------------------
print "</body>\n</html>\n";

exit;
