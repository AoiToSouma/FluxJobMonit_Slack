#!/bin/bash

change_network(){
    seq_no=0
    hit_no=-1
    max_no=$((${#URL_LIST[@]}-1))
    for var in ${URL_LIST[@]}
    do
        url=(${var//,/ })
        if grep -q "${url[0]}" $CONFIG && grep -q "${url[1]}" $CONFIG; then
            hit_no=$seq_no
            current_val=(${url[@]})
            break
        fi
        ((seq_no++))
    done
    if [ $hit_no -eq -1 ]; then
        #not found
        return 1
    fi
    if [ $hit_no -eq $max_no ]; then
        next_no=0
    else
        next_no=$((hit_no+1))
    fi
    next_val=${URL_LIST[$next_no]}
    next_val=(${next_val//,/ })

    #edit config.toml
    sed -i -e "s|${current_val[0]}|${next_val[0]}|g" -e "s|${current_val[1]}|${next_val[1]}|g" $CONFIG
    return 0
}

check_err_log(){
    from_log_line=$(cat $PLI_LOG_FILE | wc -l)
    sleep $CHECK_ERR_WAIT
    to_log_line=$(cat $PLI_LOG_FILE | wc -l)
    sed -n ${from_log_line},${to_log_line}p $PLI_LOG_FILE | grep --line-buffered -f ${NET_ERROR_LIST}
    if [ $? -eq 0 ]; then
        #Error occurred
        return 1
    fi
    return 0
}
