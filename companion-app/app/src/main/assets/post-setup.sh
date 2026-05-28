#!/usr/bin/env bash
# OpenClaw Android — Unified Post-Bootstrap Setup
# This script delegates the actual installation to the OpenClaw-On-Android scripts.
set -eo pipefail

OCA_DIR="$HOME/.openclaw-android"

echo -e "\n\033[1;32m[+] Starting Unified OpenClaw Installer (RTX Swarm)\033[0m\n"

cd "$OCA_DIR/oca_scripts"
bash install.sh
