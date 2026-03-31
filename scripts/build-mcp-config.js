#!/usr/bin/env node
// build-mcp-config.js — reads agents.yml for a given agent slug and:
//   1. Writes /tmp/mcp.json with the mcpServers block
//   2. Appends to GITHUB_OUTPUT: mcp-config-path, allowed-tools, setup-script
//
// Usage: node scripts/build-mcp-config.js <agent-slug>
//
// Environment:
//   Any {{env.NAME}} placeholder in mcp.servers[*].env values is resolved from
//   process.env at config-build time. {{workspace}} → /github/workspace.
//   GOPATH (or $HOME/go) is used to resolve go-install binary paths.

'use strict'

const { execSync }    = require('child_process')
const { writeFileSync, appendFileSync } = require('fs')

function yq(expr) {
  try {
    const out = execSync(`yq '${expr}' .hall/agents.yml`, { encoding: 'utf8' }).trim()
    return out === 'null' || out === '' ? null : out
  } catch {
    return null
  }
}

function yqArray(expr) {
  const raw = yq(expr)
  if (!raw) return []
  return raw.split('\n').map(s => s.trim()).filter(Boolean)
}

function resolvePlaceholder(value) {
  if (typeof value !== 'string') return value
  return value
    .replace(/\{\{workspace\}\}/g, '/github/workspace')
    .replace(/\{\{env\.([^}]+)\}\}/g, (_, name) => process.env[name] || '')
}

function gopath() {
  try { return execSync('go env GOPATH', { encoding: 'utf8' }).trim() } catch { /* ignore */ }
  return process.env.GOPATH || (process.env.HOME || '/root') + '/go'
}

function binaryFromPackage(pkg) {
  // github.com/isaacphi/mcp-language-server → mcp-language-server
  return pkg.split('/').pop()
}

function appendToGithubOutput(lines) {
  const path = process.env.GITHUB_OUTPUT
  if (path) appendFileSync(path, lines + '\n')
  else       console.log(lines)
}

function main() {
  const agentSlug = process.argv[2]
  if (!agentSlug) {
    console.error('Usage: build-mcp-config.js <agent-slug>')
    process.exit(1)
  }

  const serverNames = yqArray(`.agents.${agentSlug}.mcp.servers | keys | .[]`)

  if (!serverNames.length) {
    console.log(`[mcp] no MCP servers configured for ${agentSlug}`)
    appendToGithubOutput('mcp-config-path=\nallowed-tools=\nmcp-servers=\nsetup-script=')
    return
  }

  const gp = gopath()
  const mcpServers = {}
  let setupScript  = ''

  for (const name of serverNames) {
    const base    = `.agents.${agentSlug}.mcp.servers.${name}`
    const runtime = yq(`${base}.runtime`) || 'npx'
    const pkg     = yq(`${base}.package`) || ''

    let command, args = [], env = {}

    // Resolve env block
    const envKeys = yqArray(`${base}.env | keys | .[]`)
    for (const k of envKeys) {
      const v = yq(`${base}.env.["${k}"]`) || yq(`${base}.env.${k}`) || ''
      env[k] = resolvePlaceholder(v)
    }

    if (runtime === 'npx') {
      command = 'npx'
      args    = ['-y', pkg]
    } else if (runtime === 'go-install') {
      const bin = binaryFromPackage(pkg)
      command   = `${gp}/bin/${bin}`
      args      = []

      const lspServer = yq(`${base}.lsp_server`)
      if (lspServer) {
        args.push('--workspace', '/github/workspace', '--lsp', lspServer)
        const lspArgs = yqArray(`${base}.lsp_args[]`)
        if (lspArgs.length) env['LSP_ARGS'] = lspArgs.map(resolvePlaceholder).join(' ')
      }

      const setup = yq(`${base}.setup`)
      if (setup && !setupScript) setupScript = setup
    } else {
      console.warn(`[mcp] unknown runtime '${runtime}' for '${name}' — skipping`)
      continue
    }

    mcpServers[name] = { command, args, ...(Object.keys(env).length ? { env } : {}) }
  }

  if (!Object.keys(mcpServers).length) {
    console.log(`[mcp] no valid MCP servers built for ${agentSlug}`)
    appendToGithubOutput('mcp-config-path=\nallowed-tools=\nmcp-servers=\nsetup-script=')
    return
  }

  writeFileSync('/tmp/mcp.json', JSON.stringify({ mcpServers }, null, 2))
  const serverList = Object.keys(mcpServers).join(',')
  console.log(`[mcp] wrote /tmp/mcp.json for ${agentSlug}:`, serverList)

  const allowedTools = yqArray(`.agents.${agentSlug}.mcp.allowed_tools[]`).join(',')

  appendToGithubOutput(
    `mcp-config-path=/tmp/mcp.json\nallowed-tools=${allowedTools}\nmcp-servers=${serverList}\nsetup-script=${setupScript}`
  )
}

main()
