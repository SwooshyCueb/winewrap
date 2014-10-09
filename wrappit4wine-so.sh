#!/bin/bash
#
# @author Juraj Puchký - Devtech <sjurajpuchky@seznam.cz>
# @author Markus Kitsinger <swooshycueb@tearmedia.info>
# @description Script to generate a dll to native library wrapper for wine from a native library
# @copyright (c) 2014 Juraj Puchky - Devtech
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
Version 1.0.1+ors1

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
	awk
	Header files or development package be installed
	Wrapped libraries
 Env:
	AUTHOR      - Who generated the wrapper
	SEE         - What is the function of the wrapper
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
  cat "$fh"|sed -e 's/\/\*.*\*\///g'|sed -e 's/\/\/.*$//g'|sed ':a;N;$!ba;s/, *\n/, /g'|sed -e 's/[ \t]\+/ /g'|grep -e "$1 *(.*) *;"|grep -v "__device__"|grep -v "__global__"|sed -e "s/$1/$PREFIX$1/g"|sed -e 's/extern//g'|sed -e 's/__host__//g'|sed -e 's/__.*builtin__//g'|sed -e 's/ [A-Z]\+API / WINAPI /gi'|sed -e 's/^ *//g'|grep -v "^return"
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

if [ ! -f `which awk` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find awk. Cannot continue.\Zn" 6 35
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

#Newline variable
newline='
'

#Progress dialog stuff
#width and height of progress message box
progh="20"
progw="80"
#progoverexert is the minimum amount of time in nanoseconds that must pass between executions of dialog
#this exists because for some reason executing dialog repeatedly too quickly will cause some weird issues
#if enough time has not passed, execution of dialog will simply be skipped.
progoverexert="100000000"
#Initializing these early
cmax=
progdate=`date '+%s%N'`

#Resets the data for starting a new series of progress updates
function proginit() {
 func=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
 status=("8" "8" "8" "8" "8" "8" "8" "8" "8" "8")
 p="0"
 c="0"
}

#pushes a new pair of operation values for progress updates
function progpush() { # $1=newfunc $2=status
 func=("$1" "${func[0]}" "${func[1]}" "${func[2]}" "${func[3]}" \
  "${func[4]}" "${func[5]}" "${func[6]}" "${func[7]}" "${func[8]}")
 status=("$2" "${status[0]}" "${status[1]}"  "${status[2]}" \
   "${status[3]}"  "${status[4]}"  "${status[5]}"  "${status[6]}" \
    "${status[7]}" "${status[8]}")
}

#sets the status of the current operation for progress updates
function progstatus() { #$1=status for func[0]
 status[0]=$1
}

#displays the progress dialog
function progdisplay { # $1=title $2=text $3=percent
 newprogdate=`date '+%s%N'`
 if [ -z "$NOPROGRESS" ] && [ "`expr $newprogdate - $progdate`" -gt "$progoverexert" ]; then
  progdate="$newprogdate"
  dialog --colors --backtitle "$scriptname" \
         --title "$1" \
         --mixedgauge "$2" \
         $progh $progw "$3" \
         "${func[9]}"  "${status[9]}" \
         "${func[8]}"  "${status[8]}" \
         "${func[7]}"  "${status[7]}" \
         "${func[6]}"  "${status[6]}" \
         "${func[5]}"  "${status[5]}" \
         "${func[4]}"  "${status[4]}" \
         "${func[3]}"  "${status[3]}" \
         "${func[2]}"  "${status[2]}" \
         "${func[1]}"  "${status[1]}" \
         "${func[0]}"  "${status[0]}"
 fi
}

#clear, but only if we're showing progress
function cls {
 if [ -z "$NOPROGRESS" ]; then
  clear
 fi
}

# Initialize
soname=`basename "$1"`;
dirname="$2";

if [ -z "$DATE" ]; then
 DATE=`date`;
fi
if [ -z "$AUTHOR" ]; then
 AUTHOR=`whoami`;
fi
if [ -z "$SEE" ]; then
 SEE="Wrapped $soname library for wine";
fi
if [ -z "$LICENSE" ]; then
 LICENSE="GPLv3";
fi
if [ -z "$COPY" ]; then
 YEAR=`date +%Y`;
 COPY="(c) $YEAR $AUTHOR";
fi
if [ -z "$WWW" ]; then
 WWW="http://";
fi

TS=`date +%s%N`;
PREFIX="$3";

if [ -z "$NOTEDIT" ]; then
dialog --colors --backtitle "$scriptname" --title "Information" --form "Provide information about the wrapper" 25 60 8 "Author:" 1 1 "$AUTHOR" 1 25 25 50 "Date:" 2 1 "$DATE" 2 25 25 50 "Description:" 3 1 "$SEE" 3 25 25 255 "License:" 4 1 "$LICENSE" 4 25 25 80 "Copyright:" 5 1 "$COPY" 5 25 25 160 "Website:" 6 1 "$WWW" 6 25 25 160 2>"/tmp/$TS.form"
AUTHOR=`cat "/tmp/$TS.form"|head -1|tail -1`;
DATE=`cat "/tmp/$TS.form"|head -2|tail -1`;
SEE=`cat "/tmp/$TS.form"|head -3|tail -1`;
LICENSE=`cat "/tmp/$TS.form"|head -4|tail -1`;
COPY=`cat "/tmp/$TS.form"|head -5|tail -1`;
HOME=`cat "/tmp/$TS.form"|head -6|tail -1`;
fi

SPEC_TARGET="$dirname.spec";
FUNCLIST_TARGET="$dirname.func";

# generation of function list
if [ ! -d "$dirname" ]; then
 mkdir "$dirname"
 cp "$1" "$dirname"
 cd "$dirname" && nm -D --defined-only "$soname"|awk '{ print $3 }' > "$FUNCLIST_TARGET"
 cmax=`cat "$FUNCLIST_TARGET"|wc -l`;
 rm -f "$soname"
 rm *.c 2> /dev/null
 rm *.h 2> /dev/null
 rm Makefile.in 2> /dev/null
 cls
else
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Folder \Zn\Zb$dirname\ZB \Z1for \Zn\Zb$soname\ZB \Z1already exists.\Zn" 6 35
 exit 2;
fi

C_TARGET="$dirname.c";
H_TARGET="$dirname.h";
LIBS_TARGET="$dirname.libs"
LIBDIRS_TARGET="$dirname.libdirs"
CONDDEF="$5";
SOURCEPATHS="$4";
TMP_SLIST="/tmp/$TS.slist";
TMP_FPPLIST="/tmp/$TS.fpplist";
TMP_DEPS="/tmp/$TS.deps";
TMP_LIBDEPS="/tmp/$TS.libs";
TMP_LIBDEPPATHS="/tmp/$TS.libpaths";
TMP_WRAPED_DEFS="/tmp/$TS.wrappeddefs";

# Gather header dependencies
c=0;
p=0;
cmax=`cat "$FUNCLIST_TARGET"|wc -l`;
proginit
cat "$FUNCLIST_TARGET"|while read funcName
do
 progpush "$funcName" "-0"
 progdisplay "Preparing dependencies" "Current operation:\nIdentifying required headers..." "$p"
 lookupForSourceDeps "$funcName" >> "$TMP_DEPS"
 c=`expr $c + 50`;
 p=`expr $c / $cmax`
 progstatus "-50"
 progdisplay "Preparing dependencies" "Current operation:\nSearching for function declaration..." "$p"
 lookupForWrappedSourceDefinition "$funcName" >> "$TMP_WRAPED_DEFS"
 c=`expr $c + 50`
 p=`expr $c / $cmax`
 progstatus "3"
done
cls

# Let's make sure we actually have some functions to wrap
cmax=`cat "$TMP_WRAPED_DEFS"|wc -l`;
if [ $cmax == "0" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "$scriptname was unable to find any wrappable functions in $soname with the given headers and libraries." 6 35
 exit 1
fi

# Building c source files
cat > "$C_TARGET" <<_EOF_
/*
 * @author $AUTHOR
 * @date $DATE
 * @description Source file $SEE
 * @license $LICENSE
 * @copyright $COPY
 * @Website $WWW
 */
_EOF_

if [ "$noheader" != "yes" ]; then
cat > "$H_TARGET" <<_EOF_
/*
 * @author $AUTHOR
 * @date $DATE
 * @description Header file $SEE
 * @license $LICENSE
 * @copyright $COPY
 * @Website $WWW
 */
_EOF_
cat > "$C_TARGET" <<_EOF_
#include "$dirname.h"
_EOF_
else
 H_TARGET="$C_TARGET"
fi
cat >> "$H_TARGET"<<_EOF_

#include "config.h"
#include <stdarg.h>
#include "windef.h"
#include "winbase.h"
#include "wine/debug.h"
_EOF_

cat "$TMP_DEPS"|sort|uniq >> "$H_TARGET";

cat >> "$H_TARGET" <<_EOF_

WINE_DEFAULT_DEBUG_CHANNEL($dirname);
_EOF_

cat >> "$C_TARGET" <<_EOF_
// DllMain definition
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    TRACE("(%p, %u, %p)\n", instance, reason, reserved);

    switch (reason)
    {
        case DLL_WINE_PREATTACH:
            return FALSE;
        case DLL_PROCESS_ATTACH:
            DisableThreadLibraryCalls(instance);
            break;
    }

    return TRUE;
}

_EOF_

if [ "$noheader" != "yes" ]; then
 cat "$TMP_WRAPED_DEFS" >> "$H_TARGET";
fi

cat "$TMP_WRAPED_DEFS"|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2-|cut -d\; -f1|sort|uniq|while read f; do echo "$PREFIX$f"; done > "$TMP_FPPLIST"

cat "$TMP_WRAPED_DEFS"|while read def
do
 funcName=`echo $def|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2|cut -d\( -f1`;
 progpush "$funcName" "7"
 progdisplay "Building source file" "Writing functions to $dirname.c" "$p"
 status[0]="5"
 c=`expr $c + 100`;
 p=`expr $c / $cmax`
 passParams=`echo "$def"|lookupPassParamsFromSourceDef "$funcName"|sed -e 's/\*//g'|sed -e 's/\&//g'`;
 isnoreturnreq=`echo "$def"|cut -d\( -f1|grep "void *[^\*]"`;
 callprefix=`echo "$SPEC_DEF"|sed -e 's/@ */__/g'`;
 echo -n "$callprefix$def"|sed -e "s/;$//g"|sed -e "s/$funcName/$PREFIX$funcName/g" >> "$C_TARGET";
 echo " {" >> "$C_TARGET";
 echo -ne "\t" >> "$C_TARGET";
 if [ "$tracething=" == "yes" ]; then
  echo 'WINE_TRACE("\n");' >> "$C_TARGET";
  echo -ne "\t" >> "$C_TARGET";
 fi
 if [ -z "$isnoreturnreq" ]; then
  echo "return $funcName($passParams);" >> "$C_TARGET";
 else
  echo "$funcName($passParams);" >> "$C_TARGET";
 fi
 echo "}" >> "$C_TARGET";
 echo >> "$C_TARGET"
done

# Fixing spec file
SPEC_DEF="@";
cat "$FUNCLIST_TARGET"|while read l
do
 isparametrized=`echo "$l"|grep "("`;
 if [ -n "$isparametrized" ]; then
   echo "$l"|cut -d")" -f1|while read pf
   do
    echo "$pf )";
   done
 else
   echo "$l";
 fi
done|while read specFunc
do
 funcName=`echo "$specFunc"|cut -d"(" -f1`;
 substFunc=`cat "$TMP_FPPLIST"|grep "^$PREFIX$funcName[ \t]*("|cut -d"(" -f1`;
 specParams=`cat "$TMP_WRAPED_DEFS"|grep "$PREFIX$funcName"|prepareSpecParamsFromSourceDef`;
 if [ -n "$substFunc" ]; then
  echo "$SPEC_DEF $specFunc($specParams) $substFunc";
 else
  echo "# $PREFIX$funcName not implemented yet";
 fi
done > "$SPEC_TARGET"

#cat "$TMP_DEPS"|sort|uniq;
#cat "$TMP_LIBDEPS"|sort|uniq > "$LIBS_TARGET"
#cat "$TMP_LIBDEPPATHS"|sort|uniq > "$LIBDIRS_TARGET"

cd ..
CleanUpTemps "$TS";
if [ -z "$NOPROGRESS" ]; then dialog --colors --backtitle "$scriptname" --title "Success!" --infobox "\ZbYour wrapper was generated successfully.\Zn" 11 50; fi
