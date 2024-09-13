<?php

// Inits vars and default config vars values
// -----------------------------------------------------
$bindir=dirname($_SERVER["SCRIPT_FILENAME"]); 
$cmd=$bindir . "/LinkyGraphCreate.pl";

//
// Compute cmd to run based on FORM inputs
// ######################################################################################################
$cmd .= ( isset($_GET['AUTO_UPDATE'])) ? " -a " : "";
$cmd .= ( isset($_GET['START_DATE'])) ? " -s " . $_GET['START_DATE'] : " -s " . date("Y_m_d");
$cmd .= ( isset($_GET['END_DATE'])) ? " -e " . $_GET['END_DATE'] : "";

//
// Run Graph ouputs 
// ######################################################################################################
system($cmd);


?>
