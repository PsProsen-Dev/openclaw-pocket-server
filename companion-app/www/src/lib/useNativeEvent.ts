/**
 * EventBridge hook — listen for Kotlin→WebView events (§2.8).
 * Kotlin dispatches: window.__oc.emit(type, data)
 * Which creates: CustomEvent('native:'+type, { detail: data })
 */

import { useEffect } from 'react'

export function useNativeEvent(type: string, handler: (data: unknown) => void): void {
  useEffect(() => {
    const listener = (e: Event) => {
      handler((e as CustomEvent).detail)
    }
    window.addEventListener('native:' + type, listener)
    return () => window.removeEventListener('native:' + type, listener)
  }, [type, handler])
}
