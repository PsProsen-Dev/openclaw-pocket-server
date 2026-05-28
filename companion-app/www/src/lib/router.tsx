/**
 * Minimal hash-based router for file:// protocol.
 * History API doesn't work with file:// — hash routing required.
 */

import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react'

interface RouterContext {
  path: string
  navigate: (hash: string) => void
}

const Ctx = createContext<RouterContext>({ path: '', navigate: () => {} })

function getHashPath(): string {
  const hash = window.location.hash
  return hash ? hash.slice(1) : '/dashboard'
}

export function Router({ children }: { children: ReactNode }) {
  const [path, setPath] = useState(getHashPath)

  useEffect(() => {
    const onChange = () => setPath(getHashPath())
    window.addEventListener('hashchange', onChange)
    return () => window.removeEventListener('hashchange', onChange)
  }, [])

  const navigate = useCallback((hash: string) => {
    window.location.hash = hash
  }, [])

  return <Ctx.Provider value={{ path, navigate }}>{children}</Ctx.Provider>
}

export function useRoute(): RouterContext {
  return useContext(Ctx)
}

export function Route({ path, children }: { path: string; children: ReactNode }) {
  const { path: current } = useRoute()
  // Exact match or prefix match for nested routes
  if (current === path || current.startsWith(path + '/')) {
    return <>{children}</>
  }
  return null
}

export function navigate(hash: string) {
  window.location.hash = hash
}
