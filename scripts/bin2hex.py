#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bin2hex.py  —— 把二进制文件转换成每行一个十六进制字节的 .hex 文件
用法:
    python3 bin2hex.py input.bin output.hex
"""
import argparse
import sys

def bin_to_hex(in_path, out_path):
    try:
        with open(in_path, "rb") as fin, open(out_path, "w") as fout:
            while True:
                chunk = fin.read(1024)
                if not chunk:
                    break
                for b in chunk:
                    fout.write("{:02X}\n".format(b))
    except IOError:  # 在 Python 2 中使用 IOError
        sys.exit("错误: 文件 '{}' 不存在".format(in_path))
    except OSError as e:
        sys.exit("错误: {}".format(e))

def main():
    parser = argparse.ArgumentParser(description="二进制 → 每行一字节十六进制")
    parser.add_argument("binfile", help="输入的二进制文件")
    parser.add_argument("hexfile", help="输出的 .hex 文件")
    args = parser.parse_args()
    bin_to_hex(args.binfile, args.hexfile)
    print("已生成 {}".format(args.hexfile))

if __name__ == "__main__":
    main()