#!/bin/bash
set -euo pipefail
source ./setup_server.sh

reply=$(ssh_command 'printf chisel-ok')
[[ $reply == chisel-ok ]]
