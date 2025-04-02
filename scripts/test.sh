#!/bin/sh

#   $#	获取参数个数（不包括脚本名 $0）
#   $@	所有参数的列表（推荐使用）
#   #$*	所有参数合并成一个字符串
#
#
#
echo "test脚本执行：开始"
# 获取脚本的真实路径并解析所有符号链接

dir2=$(readlink -f "$0")
echo "当前脚本所在目录readlink: $dir2"
dir3=$(dirname "$dir2")
echo "当前脚本所在目录dirname: $dir3"


echo "参数个数: $#"
echo "所有参数: $@"

echo "参数 0: $0"
echo "参数 1: $1"
echo "参数 2: $2"
echo "参数 3: $3"
echo "参数 4: $4"
echo "参数 5: $5"
echo "参数 6: $6"
echo "参数 7: $7"
echo "参数 8: $8"
echo "参数 9: $9"
echo "参数 10: $10"
echo "参数 11: $11"
echo "参数 12: $12"
echo "参数 13: $13"
echo "参数 14: $14"
echo "参数 15: $15"


echo "test脚本执行：结束"
