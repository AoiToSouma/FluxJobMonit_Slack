#!/bin/bash

PATH_DIR_PARENT="$(dirname "$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)")"
PATH_FM_LOG=${PATH_DIR_PARENT}/fm_log
cd ${PATH_FM_LOG}

case "$1" in
#  latest)
  -l)
    case "$2" in
      all)
        cat $(ls -rt | tail -n 1)
        ;;
      time)
        cat $(ls -rt | tail -n 1) | cut -f 1 -d " " | cut -f 1 -d "." | sort | uniq -c | sort -r
        ;;
      neterror)
        cat $(ls -rt | tail -n 1) | grep --line-buffered  -o -f ../net_err_list.txt | sort | uniq -c | sort -r
        ;;
      *)
        echo
        echo "Usage: $0 $1 {function}"
        echo
        echo "where {function} is one of the following;"
        echo "    all      == Show latest fm_log."
        echo "    time     == Aggregate and display log occurrence time from latest fm_log."
        echo "    neterror == Aggregate and display of network errors from latest fm_log."
        echo
        exit
        ;;
    esac
    echo "======================================================"
    echo "latest fm_log: $(ls -rt | tail -n 1)"
    echo "======================================================"
    ;;
#  previous)
  -p)
    case "$2" in
      all)
        cat ~/.pm2/logs/NodeStartPM2-error.log.1
        ;;
      analyze)
        cat ~/.pm2/logs/NodeStartPM2-error.log.1 | awk -F'.go' '{print $1}' | cut -c 25- | \
        sed 's/Finished callback in [0-9]*.*[0-9]*.s *headtracker/Finished callback in 00\.00s                        headtracker/g' | \
        sed 's/RPC endpoint failed to respond to [0-9]*/RPC endpoint failed to respond to 00/g' | \
        sed 's/Starting backfill of logs from [0-9]*/Starting backfill of logs from 00/g' | \
        sed 's/block number [0-9]*/block number 00000000/g' | \
        sed 's/\#[0-9]* (0x[0-9a-zA-Z]*)/\#00000000 (0x0000000)/g' | \
        sed 's/Calculated gas price of [0-9]*.*[0-9]*.*wei/Calculated gas price of 000.000 mwei/g' | \
        sed 's/with hash 0x[0-9a-zA-Z]*/with hash 0x0000/g' | \
        sed 's/gas price: [0-9]*.*[0-9]* Gwei/gas price: 0.00 Gwei/g' | \
        sed 's/for block numbers \[.*\] even though the WS subscription/for block numbers \[00000000\] even though the WS subscription/g' | \
        sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z/0000-00-00T00:00:00Z/g' | \
        sed 's/subscriber 0x[0-9a-zA-Z]\{10\}/subscriber 0x0000000000/g' | \
        sed 's/loaded [0-9]*\/[0-9]* results */loaded 00\/00 results     /g' | \
        sed 's/completed in [0-9]*.*[0-9]*.*s */completed in 0.000000ms     /g' | \
        sed 's/logs from [0-9]* to [0-9]* */logs from 00000000 to 99999999 /g' | \
        sed 's/Plugin booted in [0-9]*.*s */Plugin booted in 00.00s                            /g' | \
        sed 's/random port [0-9]*.\./random port 00000\./g' | \
        sed 's/Node was offline for [0-9]*.*[0-9]*.*s/Node was offline for 0.0s/g' | \
        grep -e '^\s\[' | sort | uniq -c
        echo
        echo "============================================================"
        echo "[NodeStartPM2-error.log.1] update date: $(ls -l --time-style=+'%Y-%m-%dT%T' ~/.pm2/logs/NodeStartPM2-error.log.1 | sed -e 's/ \+/ /g' | cut -d' ' -f6)"
        echo "============================================================"
        echo
        ;;
      *)
        echo
        echo "Usage: $0 $1 {function}"
        echo
        echo "where {function} is one of the following;"
        echo "    all      == Show all logs from the previous day."
        echo "    analyze  == Analyze all logs from the previous day."
        echo
        exit
        ;;
    esac
    ;;
  *)
    echo
    echo "Usage: $0 $1 {function}"
    echo
    echo "    example: " $0 -l neterror""
    echo
    echo "where {function} is one of the following;"
    echo "    -l   == Show latest fm_log option."
    echo "    -p   == Show pm2log from the previous day."
    echo
esac
