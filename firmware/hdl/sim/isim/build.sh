#!/usr/bin/env sh
fuse \
-intstyle ise \
-incremental \
-i ../../bench/verilog \
-o main -prj main.prj main
