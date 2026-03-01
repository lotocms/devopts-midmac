#!/bin/bash
LEN=32

if [[ $# -gt 0 ]];then
  if [[ $1 -ge 6 && $1 -le 48 ]];then
    LEN=$1
  fi
fi

random_str1=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c $LEN ; echo '')
echo "随机串: $random_str1"
