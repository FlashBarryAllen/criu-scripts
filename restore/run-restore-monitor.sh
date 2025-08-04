#!/bin/bash

# --- 脚本配置 ---
# 请根据您的实际情况修改这些路径
CRIU_BIN="/home/yangchunlin/criu/criu/criu/criu"
CHECKPOINT_DIR="/home/yangchunlin/checkpoints/mcf_r/"
RESTORE_LOG="restore.log"
PTRACE_WAIT_BIN="/home/yangchunlin/criu-scripts-master/ptrace-wait"
PSTREE_CONT_SCRIPT="/home/yangchunlin/criu-scripts-master/pstree_cont.py"
TARGET_PROG="mcf_r_base.ycl-64"
SIMPOINTS_FILE="../bbv/results.simpts"
INTERVAL_SIZE=100000000
INSTRUCTION_COUNT=$((1 * INTERVAL_SIZE))

echo > res_monitor.log

read_simpoints_to_array() {
    local file_path=$1
    local array_name=$2
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "Error: SimPoints file '$file_path' not found." >&2
        return 1
    fi
    
    # 使用 awk 提取第一列数据，并使用 readarray 保存到数组
    # 注意: readarray (或 mapfile) 是 Bash 4.0+ 的功能
    #readarray -t "${array_name}" < <(awk '{print $1}' "$file_path" | sort -n)
    readarray -t "${array_name}" < <(awk '{print $1}' "$file_path")
    
    # 检查数组是否为空
    eval "local -a temp_array=(\"\${$array_name[@]}\")"
    if [ ${#temp_array[@]} -eq 0 ]; then
        echo "Warning: No simpoints found in '$file_path'." >&2
        return 1
    fi
    
    return 0
}

# 调用函数，将文件数据保存到名为 simpoints_array 的数组中
declare -a simpoints_array  # 声明一个数组
if read_simpoints_to_array "$SIMPOINTS_FILE" "simpoints_array"; then
    echo "成功从文件中读取 SimPoints。" >> res_monitor.log
else
    echo "无法读取 SimPoints 文件，脚本退出。"
    exit 1
fi

i=0

while true; do
    PID_TO_RESTORE=$(pidof $TARGET_PROG)
    # 检查是否存在 pid.txt 文件
    if [ -z "$PID_TO_RESTORE" ]; then
        continue
    else
        echo "simpoint: ${simpoints_array[i]}" >> res_monitor.log
        echo "pid:      $PID_TO_RESTORE"     >> res_monitor.log
        echo "Using ptrace-wait to stop process $PID_TO_RESTORE after $INSTRUCTION_COUNT instructions..." >> res_monitor.log
        $PTRACE_WAIT_BIN "$PID_TO_RESTORE" "$INSTRUCTION_COUNT" >> res_monitor.log
        kill -9 "$PID_TO_RESTORE" 2>/dev/null
        ((i++))
    fi
    
done
