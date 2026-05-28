import { StrictMode, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Router } from './lib/router'
import { App } from './App'
import { LocaleContext, getLocale } from './i18n'
import './styles/global.css'

function Root() {
  const [locale] = useState(getLocale)
  return (
    <StrictMode>
      <LocaleContext.Provider value={locale}>
        <Router>
          <App />
        </Router>
      </LocaleContext.Provider>
    </StrictMode>
  )
}

createRoot(document.getElementById('root')!).render(<Root />)
