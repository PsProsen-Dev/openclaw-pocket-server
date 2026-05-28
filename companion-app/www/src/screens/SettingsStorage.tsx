import { useState, useEffect } from 'react'
import { useRoute } from '../lib/router'
import { bridge } from '../lib/bridge'
import { t } from '../i18n'

interface StorageInfo {
  totalBytes: number
  freeBytes: number
  bootstrapBytes: number
  wwwBytes: number
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
}

const STORAGE_COLORS = {
  bootstrap: '#58a6ff',
  www: '#3fb950',
  free: 'var(--bg-tertiary)',
}

export function SettingsStorage() {
  const { navigate } = useRoute()
  const [info, setInfo] = useState<StorageInfo | null>(null)
  const [clearing, setClearing] = useState(false)

  useEffect(() => {
    const data = bridge.callJson<StorageInfo>('getStorageInfo')
    if (data) setInfo(data)
  }, [])

  function handleClearCache() {
    setClearing(true)
    bridge.call('clearCache')
    setTimeout(() => {
      setClearing(false)
      const data = bridge.callJson<StorageInfo>('getStorageInfo')
      if (data) setInfo(data)
    }, 2000)
  }

  const totalUsed = info ? info.bootstrapBytes + info.wwwBytes : 0

  return (
    <div className="page">
      <div className="page-header">
        <button className="back-btn" onClick={() => navigate('/settings')}>←</button>
        <div className="page-title">{t('storage_title')}</div>
      </div>

      {info && (
        <>
          <div style={{ fontSize: 15, marginBottom: 20 }}>
            {t('storage_total')}<strong>{formatBytes(totalUsed)}</strong>
          </div>

          <div className="card">
            <div className="card-row">
              <div className="card-content">
                <div className="card-label">{t('storage_bootstrap')}</div>
                <div className="card-desc">{formatBytes(info.bootstrapBytes)}</div>
              </div>
            </div>
            <div className="storage-bar">
              <div
                className="storage-fill"
                style={{
                  width: `${Math.min(100, (info.bootstrapBytes / (info.totalBytes - info.freeBytes)) * 100)}%`,
                  background: STORAGE_COLORS.bootstrap,
                }}
              />
            </div>
          </div>

          <div className="card">
            <div className="card-row">
              <div className="card-content">
                <div className="card-label">{t('storage_www')}</div>
                <div className="card-desc">{formatBytes(info.wwwBytes)}</div>
              </div>
            </div>
            <div className="storage-bar">
              <div
                className="storage-fill"
                style={{
                  width: `${Math.min(100, (info.wwwBytes / (info.totalBytes - info.freeBytes)) * 100)}%`,
                  background: STORAGE_COLORS.www,
                }}
              />
            </div>
          </div>

          <div className="card">
            <div className="card-row">
              <div className="card-content">
                <div className="card-label">{t('storage_free')}</div>
                <div className="card-desc">{formatBytes(info.freeBytes)}</div>
              </div>
            </div>
          </div>

          <div style={{ marginTop: 24 }}>
            <button
              className="btn btn-secondary"
              onClick={handleClearCache}
              disabled={clearing}
            >
              {clearing ? t('storage_clearing') : t('storage_clear')}
            </button>
          </div>
        </>
      )}

      {!info && (
        <div style={{ textAlign: 'center', color: 'var(--text-secondary)', marginTop: 40 }}>
          {t('storage_loading')}
        </div>
      )}
    </div>
  )
}
