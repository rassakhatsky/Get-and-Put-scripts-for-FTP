#!/bin/bash

usage()
{
cat << EOF
Usage:
        $0 -c put -s conn -f local_file [-x] -d remote_dir
        $0 -c get -s conn -f remote_file -d local_dir [-a archive_dir]
        $0 -c list -s conn -f remote_file
        $0 -c list -s conn -d remote_dir
Options:
-h      Show this message
-c      Command: put, get, list
-s      Connection parameters: user@host
-f      Local or remote file name or mask
-x      Remove successfully transferred source file
-d      Local or remote directory
-a      Remote archive directory
EOF
}

test_conn()
{
    if [[ -z $CONN ]]
    then
        echo $0: option -s not specified
        usage
        exit 1
    fi
}

calc_fdflag()
{
    if [[ -n $FNAME ]] && [[ -n $DNAME ]]
    then
        FDFLAG=3
    else
        [[ -n $FNAME ]] && FDFLAG=1
        [[ -n $DNAME ]] && FDFLAG=2
    fi
}

test_fname()
{
    if [[ -n $FNAME ]]
    then
        for FL in $FNAME
        do
            if [[ ! -f $FL ]]
            then
                echo $0: file $FL does not exist
                exit 1
            fi
        done
    fi
}

test_dname()
{
    if [[ -n $DNAME ]] && [[ ! -d $DNAME ]]
    then
        echo $0: directory $DNAME does not exist
        exit 1
    fi
}

CMD=
CONN=
FNAME=
DNAME=
ANAME=
FDFLAG=0
XFLAG=0
EXFLAG=0

while getopts “hc:s:f:xd:a:” OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    c)
        CMD=$OPTARG
        ;;
    s)
        CONN=$OPTARG
        ;;
    f)
        FNAME=$OPTARG
        ;;
    x)
        XFLAG=1
        ;;
    d)
        DNAME=$OPTARG
        ;;
    a)
        ANAME=$OPTARG
        ;;
    ?)
        usage
        exit 1
        ;;
    esac
done

if [[ -z $CMD ]]
then
  echo $0: option -c not specified
  usage
  exit 1
fi

case $CMD in
put)
    test_conn
    calc_fdflag
    if [[ $FDFLAG != 3 ]]
    then
        echo $0: with $CMD mode it is required both -f and -d options to be set
        usage
        exit 1
    fi
    test_fname
    for FL in $FNAME
    do
        DN=$(cd $(dirname $FL); pwd)
        FN=`basename $FL`
        WF=$(mktemp /tmp/$(basename $0).XXXXXX)
        OUT=
        OUTR=8
        echo -e "cd $DNAME\nrm $FN.tmp\nput $DN/$FN $FN.tmp\nrm $FN\nrename $FN.tmp $FN\nls $FN\nbye\n" > $WF.~ftp
        sftp -b $WF.~ftp $CONN 2> /dev/null > $WF.~log
        OUTR=$?
        [[ $OUTR == 0 ]] && OUT=$(sed -n -e "/^sftp> ls $FN$/,/^sftp> bye$/p" $WF.~log|grep -v "sftp>")
        rm -f $WF*
        if [[ $FN == $OUT ]]
        then
            echo $0: \*\*\* PUT=$OUTR: $FL
            [[ $XFLAG == 1 ]] && rm -f $DN/$FN
        else
            EXFLAG=9
            echo $0: \*\*\* PUT=$EXFLAG: $FL
        fi
    done
    ;;
get)
    test_conn
    calc_fdflag
    if [[ $FDFLAG != 3 ]]
    then
        echo $0: with $CMD mode it is required both -f and -d options to be set
        usage
        exit 1
    fi
    test_dname
    WF=$(mktemp /tmp/$(basename $0).XXXXXX)
    OUT=
    OUTR=8
    echo -e "ls $FNAME\nbye\n" > $WF.~ftp
    sftp -b $WF.~ftp $CONN 2> /dev/null > $WF.~log
    OUTR=$?
    [[ $OUTR == 0 ]] && OUT=$(sed -n -e "/^sftp> ls .*/,/^sftp> bye$/p" $WF.~log|grep -v "sftp>")
    rm -f $WF*
    if [[ $OUTR != 0 ]]
    then
        echo $0: \*\*\* GET=$OUTR: \(not found\)
        exit 0
    fi
    for FL in $OUT
    do
        WF=$(mktemp /tmp/$(basename $0).XXXXXX)
        OUT=
        OUTR=8
        echo -e "lcd $DNAME\nget $FL\nbye\n" > $WF.~ftp
        sftp -b $WF.~ftp $CONN 2> /dev/null > $WF.~log
        OUTR=$?
        [[ $OUTR == 0 ]] && OUT=$(sed -n -e "/^sftp> get .*/,/^sftp> bye$/p" $WF.~log|grep -v "sftp>")
        rm -f $WF*
        echo $0: \*\*\* GET=$OUTR: $FL
        [[ $OUTR != 0 ]] && EXFLAG=9
        if [[ -n $ANAME ]]
        then
            OUT=
            OUTR=8
            FLS=`basename $FL`
            echo -e "rename $FL $ANAME/$FLS\nbye\n" > $WF.~ftp
            sftp -b $WF.~ftp $CONN 2> /dev/null > $WF.~log
            OUTR=$?
            [[ $OUTR == 0 ]] && OUT=$(sed -n -e "/^sftp> rename .*/,/^sftp> bye$/p" $WF.~log|grep -v "sftp>")
            rm -f $WF*
            echo $0: \*\*\* ARC=$OUTR: $ANAME/$FLS
            [[ $OUTR != 0 ]] && EXFLAG=9
        fi
    done
    ;;
list)
    test_conn
    calc_fdflag
    if [[ $FDFLAG == 3 ]]
    then
        echo $0: with $CMD mode only one of -f and -d options should be set
        usage
        exit 1
    fi
    WF=$(mktemp /tmp/$(basename $0).XXXXXX)
    OUT=
    OUTR=8
    [[ $FDFLAG == 1 ]] && echo -e "ls $FNAME\nbye\n" > $WF.~ftp
    [[ $FDFLAG == 2 ]] && echo -e "ls $DNAME\nbye\n" > $WF.~ftp
    sftp -b $WF.~ftp $CONN 2> /dev/null > $WF.~log
    OUTR=$?
    [[ $OUTR == 0 ]] && OUT=$(sed -n -e "/^sftp> ls .*/,/^sftp> bye$/p" $WF.~log|grep -v "sftp>")
    rm -f $WF*
    [[ $FDFLAG == 1 ]] && echo $0: \*\*\* LST=$OUTR: $FNAME
    [[ $FDFLAG == 2 ]] && echo $0: \*\*\* LST=$OUTR: $DNAME
    [[ $OUTR == 0 ]] && echo -e "$OUT"
    EXFLAG=$OUTR
    ;;
*)
    echo $0: option -c $CMD is not supported
    usage
    exit 1
    ;;
esac

exit $EXFLAG
