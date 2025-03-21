#!/usr/bin/env bash
###
# File: gitlab-runner-cleanup.sh
# Project: bin
# File Created: Friday, 21st March 2025 4:28:00 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 4:29:16 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

DISK_USAGE_THRESHOLD=90
CLEANUP_HOURS=168 # 7 days

while true; do
    printf "  - Check current disk use\n"
    df -h /var/lib/docker
    current_disk_usage=$(df -h /var/lib/docker)
    current_percent=$(echo "${current_disk_usage}" | awk "NR==2 {print \$5}" | sed "s/%//")

    printf "  - Check current docker disk use\n"
    docker system df

    if [ "${current_percent}" -ge "$DISK_USAGE_THRESHOLD" ]; then
        printf "  - Disk usage is %s%%, which is greater than or equal to the threshold of %s%%\n" "$current_percent" "$DISK_USAGE_THRESHOLD"

        printf "    > Remove any stopped containers\n"
        FILTER_FLAG="label=com.gitlab.gitlab-runner.managed=true"
        STOPPED_CONTAINERS=$(docker ps -a -q --filter=status=exited --filter=status=dead --filter="$FILTER_FLAG")
        if [ "X${STOPPED_CONTAINERS}" != "X" ]; then
            docker rm -v "${STOPPED_CONTAINERS}"
        fi

        printf "    > Removing Docker images older than %s hours\n" "$CLEANUP_HOURS"
        docker image prune --all --force --filter "until=${CLEANUP_HOURS}h" --filter "label!=keep"

        printf "    > Removing Docker build cache older than %s hours\n" "$CLEANUP_HOURS"
        docker builder prune --all --force --filter "until=${CLEANUP_HOURS}h" --filter "label!=keep"

        printf "    > Cleanup completed\n"

        # Recheck disk usage
        printf "  - Rechecking disk use after cleanup\n"
        df -h /var/lib/docker
        current_disk_usage=$(df -h /var/lib/docker)
        current_percent=$(echo "${current_disk_usage}" | awk "NR==2 {print \$5}" | sed "s/%//")

        if [ "${current_percent}" -lt "$DISK_USAGE_THRESHOLD" ]; then
            printf "  - Disk usage reduced to %s%%, below the threshold of %s%%\n" "$current_percent" "$DISK_USAGE_THRESHOLD"
            break
        else
            printf "  - Disk usage is still %s%%, above the threshold of %s%%\n" "$current_percent" "$DISK_USAGE_THRESHOLD"
            CLEANUP_HOURS=$((CLEANUP_HOURS - 24))
            if [ "$CLEANUP_HOURS" -le 0 ]; then
                printf "  - Cleanup days reached 0, exiting script\n"
                break
            fi
        fi
    else
        printf "  - Disk usage is %s%%, which is below the threshold of %s%%\n" "$current_percent" "$DISK_USAGE_THRESHOLD"
        break
    fi
done
