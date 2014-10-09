#!/bin/bash
#
# @author Juraj Puchký - Devtech <sjurajpuchky@seznam.cz>
# @author Markus Kitsinger <swooshycueb@tearmedia.info>
# @description Script to generate a dll to native library wrapper for wine from a dll
# @copyright (c) 2014 Juraj Puchky - Devtech
# @copyright (c) 2014 Markus Kitsinger
# @license GPLv3
#
scriptname="wrappit4wine"
version="1.0.1+ors2"

DEFS=()
PREFIX="wine_"
INCLUDE_DIRS=()
INCLUDE_DIRS_SPECIFIED=0
LIB_DIRS=()
LIB_DIRS_SPECIFIED=0
genheader="no"
tracething="no"
winedumpspec="no"
silence_progress="no"
suppress_prompt="no"
author=`whoami`
desc=
WWW="https://github.com/SwooshyCueb/wrappit4wine"
copyright=
date=`date`
license="LGPL-2.1+"
dll=

# Check for dependencies
if [ ! -f `which dialog` ]; then
 echo "ERROR: Could not find dialog. Cannot conitnue.";
 exit 2;
fi

if [ ! -f `which winedump` ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find winedump. Cannot continue.\Zn" 6 35
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
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find perl. Cannot continue.\Zn" 6 35
 exit 2;
fi

function usage() {
 cat << _EOF_
$scriptname
============
Version $version

 Usage: $0 -I <include directory> -L <library directory> [options] dllfile
 Required options:
	-I (--include-dir)      Directory containing headers with prototypes for
	                        functions in the library. Can be specified multiple
	                        times.
	-L (--lib-dir)          Directory contiaining the static native libraries
	                        that contain the functions to be wrapped. Can be
	                        specified multiple times.
 Options:
	-p (--prefix)           String prepended to wrapper function names.
	-h (--generate-header)  Generate header file for wrapper.
	-t (--add-trace)        Add 'WINE_TRACE("\n");' to wrapper functions.
	-d (--winedump-spec)    Generate a spec file with winedump. This is not
	                        done by default because winedump can choke and
	                        crash.
	-q                      Quiet operation. Progress information and initial
	                        information prompt disabled.
	--author                Author of wrapper
	--desc                  Description of wrapper
	--license               Wrapper license
	--date                  Date to include in source file(s)
	--www                   Website to include in source file(s)
	--copyright             One-line copyright notice to include in source
	                        file(s)
	--suppress-info-prompt  Suppress inital information prompt.
	--suppress-progress     Silence progress information.
	--help                  Display this usage information.

_EOF_
 exit 1;
}

OPT=`getopt -o D:p:I:L:htdq -l define:,prefix:,include-dir:,lib-dir:,generate-header,add-trace,winedump-spec,author:,desc:,license:,www:,copyright:,date:,suppress-info-prompt,suppress-progress,help -n '$scriptname' -s bash -- "$@"`
eval set -- "$OPT"

if [ "$1" == "--" ] && [ -z "$2" ]; then
  usage
fi

while true ; do
 case "$1" in
  --help) usage ;;
  -D|--define) DEFS+=("$2") ; shift 2 ;; #not yet implemented or documented
  -p|--prefix)
   if [ -n "$PREFIX"]; then
    dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Multiple prefixes specified.\Zn" 6 35
    exit 1
   else
    PREFIX="$2"
   fi
   shift 2
  ;;
  -I|--include-dir)
   if [ ! -d "$2" ]; then
    dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find include directory $2.\Zn" 6 35
    exit 2;
   fi
   INCLUDE_DIRS+=("$2")
   INCLUDE_DIRS_SPECIFIED=1
   shift 2
  ;;
  -L|--lib-dir)
   if [ ! -d "$2" ]; then
    dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find library directory $2.\Zn" 6 35
    exit 2;
   fi
   LIB_DIRS+=("$2")
   LIB_DIRS_SPECIFIED=1
   shift 2
  ;;
  -h|--generate-header) genheader="yes" ; shift ;;
  -t|--add-traces) tracething="yes" ; shift ;;
  -d|--winedump-spec) winedumpspec="yes" ; shift ;;
  -q) silence_progress="yes" ; suppress_prompt="yes" ; shift ;;
  --author) author="$2" ; shift 2 ;;
  --desc) desc="$2" ; shift 2 ;;
  --license) licesne="$2" ; shift 2 ;;
  --www) WWW="$2" ; shift 2 ;;
  --copyright) copyright="$2" ; shift 2 ;;
  --date) date="$2" ; shift 2 ;;
  --suppress-info-prompt) suppress_prompt="yes" ; shift ;;
  --suppress-progress) silence_progress="yes" ; shift ;;
  --) shift ; dll="$1" ; break ;;
  *) echo "Internal error!" ; exit 1 ;;
 esac
done

if [ -z "$copyright" ]; then
 copyright="(c) `date +%Y` $author";
fi

if [ -z "$dll" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1No dll was specified.\Zn" 6 35
 exit 1
elif [ ! -f "$dll" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Could not find file $dll.\Zn" 6 35
 exit 2
fi

if [ "$INCLUDE_DIRS_SPECIFIED" -eq "0" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1An include directory is required.\Zn" 6 35
 exit 1
fi

if [ "$LIB_DIRS_SPECIFIED" -eq "0" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1A library directory is required.\Zn" 6 35
 exit 1
fi

function CleanUpTemps() {
 rm -f "/tmp/$1.*";
}

function lookupForWrappedSourceDefinition() {
find ${INCLUDE_DIRS[@]} -type f -iname "*.h" -exec perl -0777 -ne "while(m/.+$1 *\([\s\S]*?\) *;/g){print \"\$ARGV\n\";}" \{\} +|sort|uniq|while read fh
do
  cat "$fh"|sed -e 's/\/\*.*\*\///g'|sed -e 's/\/\/.*$//g'|sed ':a;N;$!ba;s/, *\n/, /g'|sed -e 's/[ \t]\+/ /g'|grep -e "$1 *(.*) *;"|grep -v "__device__"|grep -v "__global__"|sed -e "s/$1/$PREFIX$1/g"|sed -e 's/extern//g'|sed -e 's/__host__//g'|sed -e 's/__.*builtin__//g'|sed -e 's/ [A-Z]\+API / WINAPI /gi'|sed -e 's/^ *//g'|grep -v "^return"
done
}

function lookupForSourceDeps() {
 eINCLUDE_DIRS=`echo ${INCLUDE_DIRS[@]}|sed -e 's/\//\\\\\//g'`;
 find ${INCLUDE_DIRS[@]} -type f -iname "*.h" -exec perl -0777 -ne "while(m/.+$1 *\([\s\S]*?\) *;/g){print \"\$ARGV\n\";}" \{\} +|sort|uniq|while read dh
 do
  dhf=`echo "$dh"|sed -e "s/$eINCLUDE_DIRS\///g"`;
  echo "#include <$dhf>";
 done
}

function lookupForLibDeps() {
 find ${LIB_DIRS[@]} -type f -iname "*.so*" -exec grep -a "$1" {} +|cut -d: -f1|while read dl
 do
  isf=`strings "$dl"|grep "^$1$"`;
  if [ -n "$isf" ]; then
   dlf=`basename $dl|cut -d\. -f1`;
   libname=`echo "$dlf"|sed -e 's/^lib//g'`;
   echo "-l$libname";
  fi
 done
}

function lookupForLibDepPaths() {
 find ${LIB_DIRS[@]} -type f -iname "*.so*" -exec grep -a "$1" {} +|cut -d: -f1|sort|uniq|while read dl
 do
  isf=`strings "$dl"|grep "^$1$"`;
  if [ -n "$isf" ]; then
   dlf=`basename $dl`;
   libpath=`echo "$dl"|sed -e "s/\/$dlf//g"`;
   echo "-L $libpath";
  fi
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
 if [ "$silence_progress" == "no" ] && [ "`expr $newprogdate - $progdate`" -gt "$progoverexert" ]; then
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
 if [ "$silence_progress" == "no" ]; then
  clear
 fi
}

#parse output of winedump when generating spec from winedump
function winedumpline() { # $1 winedump output "line"
 wdlline_func=`echo $1 | grep -e ".*'.*'.*"|cut -d\' -f2`
 if [[ $1 == \[OK\]* ]] || [[ $1 == \[Not\ Found\]* ]] || [[ $1 == \[Ignoring\] ]]; then
  c=`expr $c + 100`;
  p=`expr $c / $cmax`
  if [[ $1 == \[OK\]* ]]; then
   status[0]="3"
  elif [[ $1 == \[Not\ Found\]* ]]; then
   status[0]="Not Found"
  elif [[ $1 == \[Ignoring\] ]]; then
   status[0]="6"
  fi
  progpush "-" "8"
 elif [ -n $wdlline_func ]; then
  func[0]=$wdlline_func
  status[0]="7"
  func[0]=$wdlline_func
 fi
 progdisplay "Creating interface specification" "Dumping function information..." "$p"
}

# Initialize
dllname=`basename "$dll"`
dirname=`echo "$dllname"|sed -e "s/\.so\.*.*//g"`;

if [ -z "$desc" ]; then
 desc="Wrapped $dllname library for wine";
fi

TS=`date +%s%N`;

if [ "$suppress_prompt" == "no" ]; then
dialog --colors --backtitle "$scriptname" --title "Information" --form "Provide information about the wrapper" 25 60 8 "Author:" 1 1 "$author" 1 25 25 50 "Date:" 2 1 "$date" 2 25 25 50 "Description:" 3 1 "$desc" 3 25 25 255 "License:" 4 1 "$license" 4 25 25 80 "Copyright:" 5 1 "$copyright" 5 25 25 160 "Website:" 6 1 "$WWW" 6 25 25 160 2>"/tmp/$TS.form"
author=`cat "/tmp/$TS.form"|head -1|tail -1`;
date=`cat "/tmp/$TS.form"|head -2|tail -1`;
desc=`cat "/tmp/$TS.form"|head -3|tail -1`;
license=`cat "/tmp/$TS.form"|head -4|tail -1`;
copyright=`cat "/tmp/$TS.form"|head -5|tail -1`;
WWW=`cat "/tmp/$TS.form"|head -6|tail -1`;
fi

SPEC="$dirname.spec.orig";
SPEC_DUMPED="$dirname.spec.dumped.orig"
SPEC_TARGET="$dirname.spec";
SPEC_DUMPED_TARGET="$dirname.spec.dumped"
FUNCLIST_TARGET="$dirname.func";

# generation of function list
# original winedump spec file also generated here
if [ ! -d "$dirname" ]; then
 mkdir "$dirname"
 cp "$dll" "$dirname"
 cd "$dirname" && winedump spec "$dllname"|grep -e ".*'.*'.*"|cut -d\' -f2 > "$FUNCLIST_TARGET"
 mv "$SPEC_TARGET" "$SPEC"
 cmax=`cat "$FUNCLIST_TARGET"|wc -l`;
 if [ "$winedumpspec" == "yes" ]; then
  progdisplay "Creating interface specification" "Dumping function information..." "0"
  c=0;
  wdlline=""
  OLD_IFS="$IFS"
  IFS=
  wd_include_dirs=
  for i in "${INCLUDE_DIRS[@]}"
  do
   wd_include_dirs+="-I \"$i\" "
  done
  stdbuf -o1 winedump spec "$dllname" $wd_include_dirs 2>/dev/null|while read -n 1 -r wdlchar
  do
   wdlline+="$wdlchar"
   if [ "${wdlline: -4}" == "... " ] || [ -z "$wdlchar" ]; then
    wdlline+="$newline"
    winedumpline "$wdlline"
    wdlline=""
   fi
  done
  mv "$SPEC_TARGET" "$SPEC_DUMPED"
  IFS="$OLD_IFS"
 fi
 rm -f "$dllname"
 rm *.c 2> /dev/null
 rm *.h 2> /dev/null
 rm Makefile.in 2> /dev/null
 cls
else
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "\n\Z1Folder \Zn\Zb$dirname\ZB \Z1for \Zn\Zb$dllname\ZB \Z1already exists.\Zn" 6 35
 exit 2;
fi

C_TARGET="$dirname.c";
H_TARGET="$dirname.h";
LIBS_TARGET="$dirname.libs"
LIBDIRS_TARGET="$dirname.libdirs"
TMP_SLIST="/tmp/$TS.slist";
TMP_SLIST_DUMPED="/tmp/$TS.slist.dumped";
TMP_FPPLIST="/tmp/$TS.fpplist";
TMP_DEPS="/tmp/$TS.deps";
TMP_LIBDEPS="/tmp/$TS.libs";
TMP_LIBDEPPATHS="/tmp/$TS.libpaths";
TMP_WRAPED_DEFS="/tmp/$TS.wrappeddefs";

# Gather dependencies
c=0;
p=0;
cmax=`cat "$FUNCLIST_TARGET"|wc -l`;
proginit
cat "$FUNCLIST_TARGET"|while read funcName
do
 progpush "$funcName" "-0"
 progdisplay "Preparing dependencies" "Current operation:\nIdentifying required libraries..." "$p"
 lookupForLibDeps "$funcName" >> "$TMP_LIBDEPS"
 c=`expr $c + 25`;
 p=`expr $c / $cmax`
 progstatus "-25"
 progdisplay "Preparing dependencies" "Current operation:\nIdentifying library paths..." "$p"
 lookupForLibDepPaths "$funcName" >> "$TMP_LIBDEPPATHS"
 c=`expr $c + 25`;
 p=`expr $c / $cmax`
 progstatus "-50"
 progdisplay "Preparing dependencies" "Current operation:\nIdentifying required headers..." "$p"
 lookupForSourceDeps "$funcName" >> "$TMP_DEPS"
 c=`expr $c + 25`;
 p=`expr $c / $cmax`
 progstatus "-75"
 progdisplay "Preparing dependencies" "Current operation:\nSearching for function declaration..." "$p"
 lookupForWrappedSourceDefinition "$funcName" >> "$TMP_WRAPED_DEFS"
 c=`expr $c + 25`
 p=`expr $c / $cmax`
 progstatus "3"
done
cls

# Let's make sure we actually have some functions to wrap
cmax=`cat "$TMP_WRAPED_DEFS"|wc -l`;
if [ $cmax == "0" ]; then
 dialog --colors --backtitle "$scriptname" --title "Error" --infobox "$scriptname was unable to find any wrappable functions in $dllname with the given headers and libraries." 6 35
 exit 1
fi

# Building c source files
cat > "$C_TARGET" <<_EOF_
/*
 * @author $author
 * @date $date
 * @description $desc
 * @license $license
 * @copyright $copyright
 * @website $WWW
 */
_EOF_

if [ "$genheader" == "yes" ]; then
cat > "$H_TARGET" <<_EOF_
/*
 * @author $author
 * @date $date
 * @description $desc; header file
 * @license $license
 * @copyright $copyright
 * @website $WWW
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

if [ "$genheader" == "yes" ]; then
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
cat "$SPEC"|grep "^[0-9]\+"|cut -d" " -f3- > "$TMP_SLIST"
SPEC_DEF="@";
cat "$TMP_SLIST"|while read l
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

if [ "$winedumpspec" == "yes" ]; then
 cat "$SPEC_DUMPED"|grep "^[0-9]\+"|cut -d" " -f3- > "$TMP_SLIST_DUMPED"
 cat "$TMP_SLIST_DUMPED"|while read l
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
  if [ -n "$substFunc" ]; then
   echo "$SPEC_DEF $specFunc $substFunc" >> "$SPEC_DUMPED_TARGET";
  else
   echo "# $PREFIX$funcName not implemented yet" >> "$SPEC_DUMPED_TARGET";
  fi
 done
fi

#cat "$TMP_DEPS"|sort|uniq;
cat "$TMP_LIBDEPS"|sort|uniq > "$LIBS_TARGET"
cat "$TMP_LIBDEPPATHS"|sort|uniq > "$LIBDIRS_TARGET"

cd ..
CleanUpTemps "$TS";
if [ "$silence_progress" == "no" ]; then dialog --colors --backtitle "$scriptname" --title "Success!" --infobox "\ZbYour wrapper was generated successfully.\Zn" 11 50; fi
