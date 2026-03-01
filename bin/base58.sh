#!/bin/zsh

# 生成指定长度的随机 base58 字符串
# 使用方法: ./base58.sh <长度>
# Base58 字符集
BASE58_CHARS="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <长度>"
    exit 1
fi

LENGTH=$1

# 验证长度参数是否为正整数
if ! [[ "$LENGTH" =~ ^[0-9]+$ ]] || [ "$LENGTH" -lt 1 ]; then
    echo "错误: 长度必须是正整数"
    exit 1
fi

# 生成随机字符串
result=""
for ((i=0; i<$LENGTH; i++)); do
    # 使用 openssl 生成 4 字节随机数 (8 位十六进制)，并在 zsh 中转为十进制后取模
    random_hex=$(openssl rand -hex 4)
    random_index=$(( 16#$random_hex % ${#BASE58_CHARS} ))
    result="$result${BASE58_CHARS:$random_index:1}"
done

echo "$result"
