#!/usr/bin/env bash
# setup-lsp-cpp.sh — install clangd and mcp-language-server for C++ LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

echo "[lsp-cpp] installing clangd"
sudo apt-get install -y --no-install-recommends clangd > /dev/null

echo "[lsp-cpp] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-cpp] generating compile_commands.json (if CMakeLists.txt present)"
if [ -f CMakeLists.txt ]; then
  cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug . 2>&1 | tail -5
  cp build/compile_commands.json .
  echo "[lsp-cpp] compile_commands.json written"
else
  echo "[lsp-cpp] no CMakeLists.txt — skipping compile_commands generation"
fi
