#!/usr/bin/env node
// build-mcp-config.js — reads agents.json for a given agent slug and:
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

const { execSync }                       = require('child_process')
const { readFileSync, writeFileSync, appendFileSync } = require('fs')

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

  const registry = JSON.parse(readFileSync('.hall/agents.json', 'utf8'))
  const agentCfg = registry.agents[agentSlug]

  if (!agentCfg || !agentCfg.mcp || !agentCfg.mcp.servers) {
    console.log(`[mcp] no MCP servers configured for ${agentSlug}`)
    appendToGithubOutput('mcp-config-path=\nallowed-tools=\nmcp-servers=\nsetup-script=')
    return
  }

  const servers     = agentCfg.mcp.servers
  const serverNames = Object.keys(servers)

  if (!serverNames.length) {
    console.log(`[mcp] no MCP servers configured for ${agentSlug}`)
    appendToGithubOutput('mcp-config-path=\nallowed-tools=\nmcp-servers=\nsetup-script=')
    return
  }

  const gp = gopath()
  const mcpServers = {}
  let setupScript  = ''

  for (const name of serverNames) {
    const cfg     = servers[name]
    const runtime = cfg.runtime || 'npx'
    const pkg     = cfg.package || ''

    let command, args = [], env = {}

    // Resolve env block
    for (const [k, v] of Object.entries(cfg.env || {})) {
      env[k] = resolvePlaceholder(v)
    }

    if (runtime === 'npx') {
      command = 'npx'
      args    = ['-y', pkg]
    } else if (runtime === 'go-install') {
      const bin = binaryFromPackage(pkg)
      command   = `${gp}/bin/${bin}`
      args      = []

      if (cfg.lsp_server) {
        args.push('--workspace', '/github/workspace', '--lsp', cfg.lsp_server)
        const lspArgs = cfg.lsp_args || []
        if (lspArgs.length) env['LSP_ARGS'] = lspArgs.map(resolvePlaceholder).join(' ')
      }

      if (cfg.setup && !setupScript) setupScript = cfg.setup
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

  const allowedTools = (agentCfg.mcp.allowed_tools || []).join(',')

  appendToGithubOutput(
    `mcp-config-path=/tmp/mcp.json\nallowed-tools=${allowedTools}\nmcp-servers=${serverList}\nsetup-script=${setupScript}`
  )
}

main()
