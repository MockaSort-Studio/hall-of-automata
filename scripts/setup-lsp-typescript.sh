#!/usr/bin/env bash
# setup-lsp-typescript.sh — install typescript-language-server and mcp-language-server for TypeScript LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

echo "[lsp-typescript] installing typescript and typescript-language-server"
npm install -g typescript typescript-language-server > /dev/null

echo "[lsp-typescript] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-typescript] LSP setup complete"
