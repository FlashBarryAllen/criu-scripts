/*
 * ptrace-wait -- a tool to wait for any task to exit regardless of
 * parent-child relations. Also extended to calculate CPI.
 *
 * Copyright (c) 2015, The Linux Foundation. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 and only version
 * 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <assert.h>
#include <signal.h>
#include <limits.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <linux/perf_event.h>
#include <sys/syscall.h>

static int perf_event_open(struct perf_event_attr *attr, pid_t pid,
			   int cpu, int group_fd, unsigned long flags)
{
	return syscall(__NR_perf_event_open, attr, pid, cpu, group_fd, flags);
}

static int g_child_pid = -1;

void sig_handler(int sig)
{
	if (g_child_pid > 0)
		kill(g_child_pid, SIGTERM);
	exit(1);
}

static int setup_counters(pid_t pid, long long *instr_fd, long long *cycle_fd)
{
	struct perf_event_attr pe;

	memset(&pe, 0, sizeof(pe));
	pe.type = PERF_TYPE_HARDWARE;
	pe.size = sizeof(pe);
	pe.config = PERF_COUNT_HW_INSTRUCTIONS;
	pe.disabled = 1;
	pe.exclude_kernel = 1;
	pe.exclude_hv = 1;

	*instr_fd = perf_event_open(&pe, pid, -1, -1, 0);
	if (*instr_fd == -1) {
		fprintf(stderr, "Error opening instructions perf_event_open: %s\n",
			strerror(errno));
		return -1;
	}

	pe.config = PERF_COUNT_HW_CPU_CYCLES;
	*cycle_fd = perf_event_open(&pe, pid, -1, -1, 0);
	if (*cycle_fd == -1) {
		fprintf(stderr, "Error opening cycles perf_event_open: %s\n",
			strerror(errno));
		return -1;
	}

	return 0;
}

static void perf_wait(pid_t pid, unsigned long count)
{
	long long instr_fd = -1, cycle_fd = -1;
	unsigned long long instr_val, cycle_val;
	double cpi;
	int status, ret;

	if (setup_counters(pid, &instr_fd, &cycle_fd))
		return;

	ioctl(instr_fd, PERF_EVENT_IOC_RESET, 0);
	ioctl(instr_fd, PERF_EVENT_IOC_ENABLE, 0);

	ioctl(cycle_fd, PERF_EVENT_IOC_RESET, 0);
	ioctl(cycle_fd, PERF_EVENT_IOC_ENABLE, 0);

	ret = ptrace(PTRACE_SEIZE, pid, 0, 0);
	if (ret) {
		fprintf(stderr, "ptrace(SEIZE) failed for %d: %s\n",
			pid, strerror(errno));
		goto cleanup;
	}

	while (1) {
		ret = waitpid(pid, &status, WNOHANG);
		if (ret < 0) {
			fprintf(stderr, "waitpid() failed: %s\n", strerror(errno));
			goto cleanup;
		}

		ret = read(instr_fd, &instr_val, sizeof(instr_val));
		if (ret < sizeof(instr_val)) {
			fprintf(stderr, "Error reading instructions counter: %s\n",
				strerror(errno));
			goto cleanup;
		}

		if (instr_val >= count)
			break;

		usleep(100);
	}

	ptrace(PTRACE_INTERRUPT, pid, 0, 0);
	waitpid(pid, &status, 0);

	ioctl(instr_fd, PERF_EVENT_IOC_DISABLE, 0);
	ioctl(cycle_fd, PERF_EVENT_IOC_DISABLE, 0);

	ret = read(cycle_fd, &cycle_val, sizeof(cycle_val));
	if (ret < sizeof(cycle_val)) {
		fprintf(stderr, "Error reading cycles counter: %s\n",
			strerror(errno));
		goto cleanup;
	}

	ptrace(PTRACE_DETACH, pid, 0, SIGSTOP);
	waitpid(pid, &status, 0);

	if (instr_val > 0) {
		cpi = (double)cycle_val / instr_val;
		printf("====================================================\n");
		printf("Instruction Count: %llu\n", instr_val);
		printf("Cycle Count: %llu\n", cycle_val);
		printf("CPI: %.3f\n", cpi);
		printf("====================================================\n");
	} else {
		printf("Error: Instruction count is zero.\n");
	}

cleanup:
	if (instr_fd != -1)
		close(instr_fd);
	if (cycle_fd != -1)
		close(cycle_fd);
}

int main(int argc, char *argv[])
{
	unsigned long count;
	pid_t pid;

	if (argc < 3) {
		printf("Usage: %s <pid> <instruction_count>\n", argv[0]);
		return EXIT_FAILURE;
	}

	pid = atoi(argv[1]);
	count = atol(argv[2]);

	if (pid <= 0 || count <= 0) {
		printf("Invalid PID or instruction count\n");
		return EXIT_FAILURE;
	}

	perf_wait(pid, count);

	return EXIT_SUCCESS;
}