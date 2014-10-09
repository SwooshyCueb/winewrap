#!/bin/bash
#
# @author Markus Kitsinger <swooshycueb@tearmedia.info>
# @description Script to generate a dll to native library wrapper for wine from a native library
# @copyright (c) 2014 Markus Kitsinger
# @license GPLv3
# @version 1.0.1+ors1
#
scriptname="wrappit4wine-so"

# Uncomment this line if you want to condense the header into the c source file
noheader="yes"

# Uncomment this line if you want WINE_TRACE("\n"); in every wrapper function
tracething="yes"


if [ -z "$3" ] || [ "$1" == "help" ]; then
 cat << _EOF_
$scriptname 
============
Version 1.0.1

 Usage: $0 [native library] [Function prefix] [Include directory] [DEF]
 Legend:
	Function prefix   - String prepended to wrapper function names
	Include directory - Directory containing headers with prototypes for functions in the dll
	DEF:optional      - Compilation conditional, depending on this definition
 Sample:
	$0 /usr/lib/x86_64-linux-gnu/libgtk-x11-2.0.so GTK2_ /usr/include/gtk-2.0
 Commands:
	help - print this usage screen
 Requirements:
	sed
	tr
	grep
	perl
	dialog
	Header files or development package be installed
	Wrapped libraries
 Env:
	AUTHOR      - Who generated the wrapper
	SEE         - What is the wrapper's function
	LICENSE     - What is the licence?
	COPY        - Copyright
	DATE        - Date of creation
	WWW         - Website for project
	NOTEDIT     - Do not prompt to set these variables at start
	NOPROGRESS  - Do not display progress
_EOF_
 exit 1;
fi
