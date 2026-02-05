#!/bin/sh
#
# Copyright (c) 2026 LLVM Latest
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

# Global variable to store start time
LOG_START_TIME=""

# Function to calculate elapsed time
calculate_elapsed() {
    local start=$1
    local end=$2
    local elapsed=$((end - start))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))

    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Function to repeat a character
repeat_char() {
    local char="$1"
    local count="$2"
    local result=""
    local i=0
    while [ $i -lt $count ]; do
        result="${result}${char}"
        i=$((i + 1))
    done
    printf "%s" "$result"
}

# Function to print start banner
log_start() {
    trap 'if [ $? -eq 0 ]; then log_end; else log_error; fi' EXIT

    LOG_START_TIME=$(date +%s)
    TITLE="${1:-$(basename "$0")}"
    TITLE_LENGTH=$((${#TITLE} - 2))

    local sep="===============================$(repeat_char "=" "$TITLE_LENGTH")"
    local sep2="+-----------------------------$(repeat_char "-" "$TITLE_LENGTH")+"
    echo $sep
    echo "===== Start Executing: $TITLE ====="
    echo $sep
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo $sep
    echo $sep2
}

# Function to print end banner
log_end() {
    local end_time=$(date +%s)
    local elapsed=$(calculate_elapsed $LOG_START_TIME $end_time)
    local sep="==================================$(repeat_char "=" "$TITLE_LENGTH")"
    local sep2="+--------------------------------$(repeat_char "-" "$TITLE_LENGTH")+"
    echo $sep
    echo "===== Execution Finished: $TITLE ====="
    echo $sep
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Elapsed: $elapsed"
    echo $sep
    echo $sep2
}

# Function to print error banner
log_error() {
    local end_time=$(date +%s)
    local elapsed=$(calculate_elapsed $LOG_START_TIME $end_time)
    local sep="================================$(repeat_char "=" "$TITLE_LENGTH")"
    local sep2="+------------------------------$(repeat_char "-" "$TITLE_LENGTH")+"
    echo $sep
    echo "===== Execution Failed: $TITLE ====="
    echo $sep
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Elapsed: $elapsed"
    if [ -n "$1" ]; then
        echo "Error: $1"
    fi
    echo $sep
    echo $sep2
}

# Initialize the logging
log_start
