#!/bin/sh

# EasyBundler v0.1
# 2011 easyb

function usage()
{
  echo "usage: `basename $0` -n name -v version -e binary [-d dest]"
  echo "                  [-e binary2] [-i Icon.icns] [-p Info.plist]"
  echo "                  [-l lib1.dylib] [-l lib2.dylib] ..." 
  echo "                  [-r res1] [-r res2] ..."


#usage: `basename $0` -n name -v version -e binary [-e binary2] [-l lib1.dylib] [-l lib2.dylib] [-i Icon.icns] [-p Info.plist] [-d dest]
  exit
}

function change()
{
  FILE=$1
  
  echo "trying to change $FILE"
  
  #file $FILE 
  
  (( file $FILE | grep -q "binary" ) || ( file $FILE | grep -q "library" ) || ( file $FILE | grep -q "executable" )) && {

    STR=`otool -L "$FILE"`
    STR=`echo $STR | sed 's/.*://g'`
    STR=`echo $STR | sed 's/ ([a-z0-9,. ]*)//g'`
    
    STRS=( $STR )
    
    if [ `echo $FILE | grep '.dylib'` ]
    then
      unset STRS[0] # strip the first entriy if it's a lib (ID)
    fi
    
    install_name_tool -id "@executable_path/../Frameworks/`basename $FILE`" $FILE
    
    for N in ${LIBNAMES[@]}
    do
      echo "searching for $N in $FILE"
      for S in ${STRS[@]}
      do
        FOUND=`echo $S | grep $N`
        if [ "x$FOUND" != "x" ]
        then
          echo "precessing $FOUND in $FILE"
          install_name_tool -change $FOUND "@executable_path/../Frameworks/$N" $FILE
        fi 
      done
    done
  }
  
  return
}

if [ $# -lt 1 ]
  then
  usage
fi

DEST="."

while getopts  "n:v:e:d:l:i:p:r:h" flag
do
  case $flag in
    h) usage [destination-path];;
    n) NAME=$OPTARG;;
    v) VERSION=$OPTARG;;
    e) _BINS="$_BINS $OPTARG";; 
    d) DEST=$OPTARG;;
    l) _LIBS="$_LIBS $OPTARG"; _LIBNAMES="$_LIBNAMES `basename "$OPTARG"`";;
    i) ICONPATH=$OPTARG; ICON=`basename $OPTARG`;;
    p) INFO=$OPTARG;;
    r) _DATA="$_DATA $OPTARG";;
  esac
done

BINS=( $_BINS )
LIBS=( $_LIBS )
LIBNAMES=( $_LIBNAMES )
DATA=( $_DATA )

MAINBIN=`basename ${BINS[0]}`

ROOT=${DEST}/${NAME}.app/Contents
mkdir -p $ROOT

if [ "x${INFO}" != "x" ]
then
  echo "copying ${INFO}"
  cp ${INFO} ${ROOT}/Info.plist
else

  echo "creating Info.plist"
  cat <<EOF > ${ROOT}/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>English</string>
  <key>CFBundleExecutable</key>
  <string>${MAINBIN}</string>
  <key>CFBundleIconFile</key>
  <string>${ICON}</string>
  <key>CFBundleGetInfoString</key>
  <string>${NAME} version ${VERSION}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleLongVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleName</key>
  <string>${NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
</dict>
</plist>

EOF
fi

echo "creating PkgInfo"
echo -n 'APPL????' > ${ROOT}/PkgInfo

if [ "x${BINS[0]}" != "x" ]
then
  MACOS=${ROOT}/MacOS
  mkdir -p $MACOS
  
  for BINPATH in ${BINS[@]}
  do
    echo "copying "$BINPATH""
    cp $BINPATH $MACOS/
    BIN=`basename $BINPATH`
    change "${MACOS}/$BIN"
  done
fi

if [ "x${LIBS[0]}" != "x" ]
then
  FW=${ROOT}/Frameworks
  mkdir -p $FW
  
  for LIBPATH in ${LIBS[@]}
  do
    echo "copying "$LIBPATH""
    cp $LIBPATH ${FW}/
    LIB=`basename $LIBPATH`
    change "${FW}/$LIB"
  done
fi

RES=${ROOT}/Resources
mkdir -p $RES

if [ "x${ICON}" != "x" ]
then
  echo "copying icon $ICONPATH"
  cp $ICONPATH $RES
fi

if [ "x${DATA}" != "x" ]
then
  for FILE in ${DATA[@]}
  do
    echo "copying "$FILE""
    cp $FILE ${RES}/
  done
fi
