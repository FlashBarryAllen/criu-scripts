#!/bin/bash

#INTERVAL_SIZE=100000000 # 设置间隔大小一亿，100M
INTERVAL_SIZE=10000000 # 设置间隔大小一千万，10M

valgrind --tool=exp-bbv --pc-out-file=mcf_r.pc --interval-size=$INTERVAL_SIZE /home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_refrate_ycl-64.0000/mcf_r_base.ycl-64 /home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_refrate_ycl-64.0000/inp.in

#/home/kindles/simpoint/bin/simpoint  -loadFVFile bb.out -k 7 -saveSimpoints results.simpts -saveSimpointWeights results.weights