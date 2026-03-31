#!/usr/bin/env bash
# setup-lsp-python.sh — install pyright and mcp-language-server for Python LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

echo "[lsp-python] installing pyright"
npm install -g pyright > /dev/null

echo "[lsp-python] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-python] LSP setup complete"
