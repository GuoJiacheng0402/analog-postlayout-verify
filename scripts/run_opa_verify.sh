#!/bin/bash
# analog-postlayout-verify :: OPA wrapper
# Source : https://github.com/GuoJiacheng0402/analog-postlayout-verify
set -e
cd "$(dirname "$0")"
python3 opa_verify.py "$@"
