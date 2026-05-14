#!/bin/bash
# analog-postlayout-verify :: BGR wrapper
# Source : https://github.com/GuoJiacheng0402/analog-postlayout-verify
set -e
cd "$(dirname "$0")"
python3 bgr_verify.py "$@"
