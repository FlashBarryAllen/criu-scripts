#!/bin/bash

# --- 脚本配置 ---
# 请根据您的实际情况修改这些路径
CRIU_BIN="/home/yangchunlin/criu/criu/criu/criu"
CHECKPOINT_DIR="/home/yangchunlin/checkpoints/mcf_r/"
RESTORE_LOG="restore.log"
PTRACE_WAIT_BIN="/home/yangchunlin/criu-scripts-master/ptrace-wait"
PSTREE_CONT_SCRIPT="/home/yangchunlin/criu-scripts-master/pstree_cont.py"
PID_FILE="/home/yangchunlin/checkpoints/mcf_r/checkpoints/pid.txt"
SIMPOINTS_FILE="../bbv/results.simpts"
INTERVAL_SIZE=100000000
INSTRUCTION_COUNT=$((1 * INTERVAL_SIZE))

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
    echo "成功从文件中读取 SimPoints。"
else
    echo "无法读取 SimPoints 文件，脚本退出。"
    exit 1
fi

read_pids_to_array() {
    local pid_file_path="$1"
    local array_name="$2"
    
    # 检查文件是否存在
    if [ ! -f "$pid_file_path" ]; then
        echo "Error: PID file '$pid_file_path' not found." >&2
        return 1
    fi

    # 使用 readarray -t 命令将文件内容逐行读入数组
    # eval 命令用于动态构建和执行命令，将结果保存到指定的全局数组中
    eval "readarray -t $array_name < \"$pid_file_path\""

    # 检查数组是否为空
    eval "local temp_array=(\"\${$array_name[@]}\")"
    if [ ${#temp_array[@]} -eq 0 ]; then
        echo "Warning: PID file '$pid_file_path' is empty." >&2
        return 1
    fi
    
    return 0
}

# 声明一个全局数组变量来存储结果
declare -a pid_list_array

# 调用函数，将 pid.txt 的内容保存到 pid_list_array 数组中
if read_pids_to_array "$PID_FILE" "pid_list_array"; then
    echo "成功从文件中读取 PID 列表："
    #echo "数组内容: ${pid_list_array[@]}"
else
    echo "无法读取 PID 文件，脚本退出。"
    exit 1
fi

# 定义一个函数来封装恢复和等待的逻辑
restore_and_ptrace_wait() {
    local simpoint_value=$1
    local PID_TO_RESTORE=$2
    local checkpoint_dir="/home/yangchunlin/checkpoints/mcf_r/cpt_$simpoint_value"
    
    echo "--- 开始恢复和等待 ---"

    echo "Restoring process with PID: $PID_TO_RESTORE"
    # 2. 使用 criu restore 恢复进程
    echo "Starting CRIU restore from $checkpoint_dir..."
    $CRIU_BIN restore -D "$checkpoint_dir" -o "$RESTORE_LOG" -v4 -j > /dev/null 2>&1 &

    python3 /home/yangchunlin/criu-scripts-master/pstree_cont.py $PID_TO_RESTORE

    return 0
}

echo > res_monitor.log

for i in "${!simpoints_array[@]}"; do
    simpoint_value="${simpoints_array[$i]}"
    pid_value="${pid_list_array[$i]}"
    
    echo "--------------------------------------------------------"
    echo "SimPoint 值: $simpoint_value"
    echo "对应的 PID: $pid_value"
    restore_and_ptrace_wait "$simpoint_value" "$pid_value"

    sleep 6
done
