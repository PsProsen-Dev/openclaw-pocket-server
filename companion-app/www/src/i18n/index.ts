import { createContext, useContext } from 'react'
import { en } from './en'
import { ko } from './ko'
import { zh } from './zh'

export type TranslationKey = keyof typeof en
type Translations = Record<TranslationKey, string>

const locales: Record<string, Translations> = { en, ko, zh }

function detectLocale(): string {
  // 1. Check saved preference
  try {
    const saved = localStorage.getItem('locale')
    if (saved && locales[saved]) return saved
  } catch {
    // localStorage may not be available
  }

  // 2. Detect from browser/system language
  const lang = navigator.language || ''
  if (lang.startsWith('ko')) return 'ko'
  if (lang.startsWith('zh')) return 'zh'
  return 'en'
}

let currentLocale = detectLocale()
let currentTranslations = locales[currentLocale] || en

export function getLocale(): string {
  return currentLocale
}

export function setLocale(locale: string) {
  if (locales[locale]) {
    currentLocale = locale
    currentTranslations = locales[locale]
    try {
      localStorage.setItem('locale', locale)
    } catch {
      // ignore
    }
  }
}

export function t(key: TranslationKey, vars?: Record<string, string>): string {
  let text = currentTranslations[key] || en[key] || key
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      text = text.replace(`{${k}}`, v)
    }
  }
  return text
}

// Context for triggering re-renders on locale change
export const LocaleContext = createContext<string>(currentLocale)
export const useLocale = () => useContext(LocaleContext)

export const availableLocales = [
  { code: 'en', label: 'English' },
  { code: 'ko', label: '한국어' },
  { code: 'zh', label: '中文' },
]
