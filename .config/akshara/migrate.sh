#!/bin/bash

set -uo pipefail

source /var/tmp/fallback.sh

mapfile -t base < <(pacman -Qqn)
priority_v3 "${base[@]}"
