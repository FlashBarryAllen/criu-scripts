#!/bin/bash

# --- 脚本配置 ---
# 替换为您的实际路径
BENCH_TYPE="refrate"  # 或 "test"，根据需要选
BENCH_DIR="/home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_refrate_ycl-64.0000"
CRIU_BIN="/home/yangchunlin/criu/criu/criu/criu"
PTRACE_WAIT_BIN="/home/yangchunlin/criu-scripts-master/ptrace-wait"
TARGET_PROG="mcf_r_base.ycl-64"
INPUT_FILE="inp.in"
INTERVAL_SIZE=100000000
SIMPOINTS_FILE="../bbv/results.simpts"
PID_FILE="/home/yangchunlin/checkpoints/mcf_r/checkpoints/pid.txt"

read_simpoints_to_array() {
    local file_path=$1
    local array_name=$2
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "Error: SimPoints file '$file_path' not found." >> cpt_monitor.log
        return 1
    fi
    
    # 使用 awk 提取第一列数据，并使用 readarray 保存到数组
    # 注意: readarray (或 mapfile) 是 Bash 4.0+ 的功能
    #readarray -t "${array_name}" < <(awk '{print $1}' "$file_path" | sort -n)
    readarray -t "${array_name}" < <(awk '{print $1}' "$file_path")
    
    # 检查数组是否为空
    eval "local -a temp_array=(\"\${$array_name[@]}\")"
    if [ ${#temp_array[@]} -eq 0 ]; then
        echo "Warning: No simpoints found in '$file_path'." >> cpt_monitor.log
        return 1
    fi
    
    return 0
}

# 调用函数，将文件数据保存到名为 simpoints_array 的数组中
declare -a simpoints_array  # 声明一个数组
if read_simpoints_to_array "$SIMPOINTS_FILE" "simpoints_array"; then
    echo "成功从文件中读取 SimPoints。" >> cpt_monitor.log
else
    echo "无法读取 SimPoints 文件，脚本退出。" >> cpt_monitor.log
    exit 1
fi

# 定义一个函数来处理单个 SimPoint 的检查点创建
create_checkpoint() {
    # 使用 local 关键字声明局部变量，并从函数参数中获取值
    local simpoint_value=$1
    local INSTRUCTION_COUNT=$((simpoint_value * INTERVAL_SIZE))
    local checkpoint_dir="/home/yangchunlin/checkpoints/mcf_r/cpt_$simpoint_value"
    echo "INTERVAL_SIZE: $INTERVAL_SIZE" >> cpt_monitor.log
    echo "INSTRUCTION_COUNT: $INSTRUCTION_COUNT" >> cpt_monitor.log

    # 0. 清理环境
    echo "Starting clean checkpoint dir..." >> cpt_monitor.log

    rm -rf $checkpoint_dir
    mkdir -p $checkpoint_dir

    # 1. 启动 mcf_r_base.ycl-64 程序并重定向输出到后台
    echo "Starting $TARGET_PROG in the background..." >> cpt_monitor.log
    $BENCH_DIR/$TARGET_PROG $BENCH_DIR/$INPUT_FILE > /dev/null 2>&1 &

    while true; do
        PID=$(pidof $TARGET_PROG)
        # 检查是否存在 pid.txt 文件
        if [ -z "$PID" ]; then
            echo "finish $simpoint_value checkpoint." >> cpt_monitor.log
            echo "----------------------------------" >> cpt_monitor.log
            break
        fi
    done
}

# 遍历数组，并为每个元素调用函数
for simpoint in "${simpoints_array[@]}"; do
    # 调用函数，并传递参数
    #simpoint=259
    echo "Creating checkpoint for SimPoint: $simpoint" >> cpt_monitor.log
    create_checkpoint "$simpoint"
    sleep 6
done
