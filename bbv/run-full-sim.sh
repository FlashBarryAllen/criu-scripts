#!/bin/bash

TEST_DIR="/home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_test_ycl-64.0000"
REFRATE_DIR="/home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_refrate_ycl-64.0000"
BIN="mcf_r_base.ycl-64"
INPUT_FILE="inp.in"

echo > full_sim.log

#echo "-----------------------------------------"
#echo "Running performance tests for $TEST_DIR/$BIN with input $TEST_DIR/$INPUT_FILE" >> full_sim.log
#perf stat -e cycles,instructions $TEST_DIR/$BIN $TEST_DIR/$INPUT_FILE >> full_sim.log
#echo "-----------------------------------------"

echo "-----------------------------------------" >> full_sim.log
echo "Running reference rate tests for $REFRATE_DIR/$BIN with input $REFRATE_DIR/$INPUT_FILE" >> full_sim.log
perf stat -e cycles,instructions $REFRATE_DIR/$BIN $REFRATE_DIR/$INPUT_FILE >> full_sim.log
echo "-----------------------------------------" >> full_sim.log