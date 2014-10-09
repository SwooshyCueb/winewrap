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


if [ -z "$4" ] || [ "$1" == "help" ]; then
 cat << _EOF_
$scriptname 
============
Version 1.0.1

 Usage: $0 [native library] [wrapper name] [Function prefix] [Include directory] [DEF]
 Legend:
	Function prefix   - String prepended to wrapper function names
	Include directory - Directory containing headers with prototypes for functions in the dll
	DEF:optional      - Compilation conditional, depending on this definition
 Sample:
	$0 /usr/lib/x86_64-linux-gnu/libgtk-x11-2.0.so libgtk-win32-2.0 GTK2_ /usr/include/gtk-2.0
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

function CleanUpTemps() {
 rm -f "/tmp/$1.*";
}

function lookupForWrappedSourceDefinition() {
find "$SOURCEPATHS" -type f -iname "*.h" -exec perl -0777 -ne "while(m/.+$1 *\([\s\S]*?\) *;/g){print \"\$ARGV\n\";}" \{\} +|sort|uniq|while read fh
do
  cat "$fh"|sed -e 's/\/\*.*\*\///g'|sed -e 's/\/\/.*$//g'|sed ':a;N;$!ba;s/, *\n/, /g'|sed -e 's/ \+/ /g'|grep -e "$1 *(.*) *;"|grep -v "__device__"|grep -v "__global__"|sed -e "s/$1/$PREFIX$1/g"|sed -e 's/extern//g'|sed -e 's/__host__//g'|sed -e 's/__.*builtin__//g'|sed -e 's/ [A-Z]\+API / WINAPI /gi'|sed -e 's/^ *//g'|grep -v "^return"
done
}

function lookupForSourceDeps() {
 eSOURCEPATHS=`echo "$SOURCEPATHS"|sed -e 's/\//\\\\\//g'`;
 find "$SOURCEPATHS" -type f -iname "*.h" -exec perl -0777 -ne "while(m/.+$1 *\([\s\S]*?\) *;/g){print \"\$ARGV\n\";}" \{\} +|sort|uniq|while read dh
 do
  dhf=`echo "$dh"|sed -e "s/$eSOURCEPATHS\///g"`;
  echo "#include <$dhf>";
 done
}

function lookupPassParamsFromSourceDef() {
sed -e "s/$1 *(/\#/g"|sed -e "s/);/\#/g"|cut -d\# -f2|sed -e "s/,/\n/g"|awk -F" " '{print $(NF)}'|while read pl
do
  echo -n ", $pl";
done|sed -e 's/^, //g'
}

function prepareSpecParamsFromSourceDef() {
sed -e "s/$1 *(/\#/g"|sed -e "s/);/\#/g"|cut -d\# -f2|sed -e "s/,/\n/g"|awk -F" " '{print $(NF)}'|while read pl
do
  echo "$pl";
done|while read param
do
 case "$param" in
 *\**)
	echo -n " ptr ";
 ;;
 *)
	echo -n " long ";
 ;;
 esac
done
} 

# Lookup for dependencies
if [ ! -f `which dialog` ]; then
 echo "ERROR: Could not find dialog. Cannot conitnue.";
 exit 2;
fi

if [ ! -f `which sed` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find sed. Cannot continue.\Zn" 6 35
 exit 2;
fi

if [ ! -f `which tr` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find tr. Cannot conitnue.\Zn" 6 35
 exit 2;
fi

if [ ! -f `which grep` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find grep. Cannot continue.\Zn" 6 35
 exit 2;
fi

if [ ! -f `which perl` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find perl. Cannot continue.\Zn" 6 35
 exit 2;
fi


if [ ! -f "$1" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find file $1.\Zn" 6 35
 exit 2;
fi

if [ ! -d "$4" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1An include folder is required.\Zn" 6 35
 exit 2;
fi
