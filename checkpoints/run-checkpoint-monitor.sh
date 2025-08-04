#!/bin/bash

# --- 脚本配置 ---
# 替换为您的实际路径
BENCH_TYPE="refrate"  # 或 "test"，根据需要选择
BENCH_DIR="/home/yangchunlin/cpu2017/benchspec/CPU/505.mcf_r/run/run_base_refrate_ycl-64.0000"
CRIU_BIN="/home/yangchunlin/criu/criu/criu/criu"
PTRACE_WAIT_BIN="/home/yangchunlin/criu-scripts-master/ptrace-wait"
TARGET_PROG="mcf_r_base.ycl-64"
INPUT_FILE="inp.in"
INTERVAL_SIZE=100000000
SIMPOINTS_FILE="../bbv/results.simpts"
PID_FILE="pid.txt"

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

i=0
echo > cpt_monitor.log
rm -rf $PID_FILE
touch $PID_FILE

# 定义一个函数来处理单个 SimPoint 的检查点创建
checkpoint_monitor() {
    while true; do
        PID=$(pidof $TARGET_PROG)
        # 检查是否存在 pid.txt 文件
        if [ -z "$PID" ]; then
            continue
        else
            echo $PID >> $PID_FILE
            simpoint_value=${simpoints_array[i]}
            #simpoint_value=259
            local INSTRUCTION_COUNT=$((simpoint_value * INTERVAL_SIZE))
            local checkpoint_dir="/home/yangchunlin/checkpoints/mcf_r/cpt_$simpoint_value"

            rm -rf $checkpoint_dir
            mkdir -p $checkpoint_dir

            echo "simpoint: ${simpoints_array[i]}" >> cpt_monitor.log
            echo "pid:      $PID"                  >> cpt_monitor.log

            echo "Using ptrace-wait to stop process $PID after $INSTRUCTION_COUNT instructions..." >> cpt_monitor.log
            $PTRACE_WAIT_BIN $PID $INSTRUCTION_COUNT >> cpt_monitor.log

            # 4. 检查进程是否已停止
            if kill -0 $PID 2>/dev/null; then
                echo "Process $PID is stopped. Proceeding with CRIU dump..." >> cpt_monitor.log
            else
                echo "Error: Process $PID is not running or stopped. Aborting." >> cpt_monitor.log
                exit 1
            fi

            # 5. 使用 criu dump 保存进程状态
            echo "Dumping process state with CRIU..." >> cpt_monitor.log
            $CRIU_BIN dump -D $checkpoint_dir -o dump.log -v4 -j -t $PID

            # 6. 脚本完成
            echo "CRIU dump completed. The checkpoint is in $checkpoint_dir." >> cpt_monitor.log
            kill -9 $PID 2>/dev/null || true  # 确保进程被终止
            ((i++))
        fi
    done
}

checkpoint_monitor