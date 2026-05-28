import { useState, useEffect, useCallback } from 'react'
import { useRoute } from '../lib/router'
import { bridge } from '../lib/bridge'
import { useNativeEvent } from '../lib/useNativeEvent'

interface Tool {
  id: string
  name: string
  desc: string
  category: string
}

const TOOLS: Tool[] = [
  { id: 'tmux', name: 'tmux', desc: 'Terminal multiplexer', category: 'Terminal Tools' },
  { id: 'code-server', name: 'code-server', desc: 'VS Code in browser', category: 'Terminal Tools' },
  { id: 'opencode', name: 'OpenCode', desc: 'AI coding assistant (TUI)', category: 'AI Tools' },
  { id: 'claude-code', name: 'Claude Code', desc: 'Anthropic AI CLI', category: 'AI Tools' },
  { id: 'gemini-cli', name: 'Gemini CLI', desc: 'Google AI CLI', category: 'AI Tools' },
  { id: 'codex-cli', name: 'Codex CLI', desc: 'OpenAI AI CLI', category: 'AI Tools' },
  { id: 'openssh-server', name: 'SSH Server', desc: 'SSH remote access', category: 'Network & Access' },
  { id: 'ttyd', name: 'ttyd', desc: 'Web terminal access', category: 'Network & Access' },
  { id: 'dufs', name: 'dufs', desc: 'File server (WebDAV)', category: 'Network & Access' },
  { id: 'android-tools', name: 'Android Tools', desc: 'ADB for disabling Phantom Process Killer', category: 'System' },
  { id: 'chromium', name: 'Chromium', desc: 'Browser automation (~400MB)', category: 'System' },
]

export function SettingsTools() {
  const { navigate } = useRoute()
  const [installed, setInstalled] = useState<Set<string>>(new Set())
  const [installing, setInstalling] = useState<string | null>(null)
  const [progress, setProgress] = useState(0)
  const [progressMsg, setProgressMsg] = useState('')

  useEffect(() => {
    // Check installed status for each tool
    const result = bridge.callJson<Array<{ id: string }>>('getInstalledTools')
    if (result) {
      setInstalled(new Set(result.map(t => t.id)))
    }
  }, [])

  const onInstallProgress = useCallback((data: unknown) => {
    const d = data as { target?: string; progress?: number; message?: string }
    if (d.progress !== undefined) setProgress(d.progress)
    if (d.message) setProgressMsg(d.message)
    if (d.progress !== undefined && d.progress >= 1) {
      if (d.target) setInstalled(prev => new Set([...prev, d.target!]))
      setInstalling(null)
      setProgress(0)
    }
  }, [])
  useNativeEvent('install_progress', onInstallProgress)

  function handleInstall(id: string) {
    setInstalling(id)
    setProgress(0)
    setProgressMsg(`Installing ${id}...`)
    bridge.call('installTool', id)
  }

  function handleUninstall(id: string) {
    bridge.call('uninstallTool', id)
    setInstalled(prev => {
      const next = new Set(prev)
      next.delete(id)
      return next
    })
  }

  // Group by category
  const categories = [...new Set(TOOLS.map(t => t.category))]

  return (
    <div className="page">
      <div className="page-header">
        <button className="back-btn" onClick={() => navigate('/settings')}>←</button>
        <div className="page-title">Additional Tools</div>
      </div>

      {installing && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div style={{ fontSize: 14, marginBottom: 8 }}>Installing {installing}...</div>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${Math.round(progress * 100)}%` }} />
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 6 }}>
            {progressMsg}
          </div>
        </div>
      )}

      {categories.map(cat => (
        <div key={cat}>
          <div className="section-title">{cat}</div>
          {TOOLS.filter(t => t.category === cat).map(tool => (
            <div key={tool.id} className="card">
              <div className="card-row">
                <div className="card-content">
                  <div className="card-label">{tool.name}</div>
                  <div className="card-desc">{tool.desc}</div>
                </div>
                {installed.has(tool.id) ? (
                  <button
                    className="btn btn-small btn-secondary"
                    onClick={() => handleUninstall(tool.id)}
                    disabled={installing !== null}
                  >
                    Installed ✓
                  </button>
                ) : (
                  <button
                    className="btn btn-small btn-primary"
                    onClick={() => handleInstall(tool.id)}
                    disabled={installing !== null}
                  >
                    Install
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      ))}
    </div>
  )
}
