import {saveCardImage} from "./card_image"

// Delegated from document rather than bound inline: `script-src 'unsafe-inline'`
// is what the CSP exists to rule out, and delegation also survives LiveView's
// DOM patching.
document.addEventListener("click", event => {
  if (event.target.closest("#darkmode-toggle")) {
    document.documentElement.classList.toggle("dark")
  } else if (event.target.closest("#print-card")) {
    window.print()
  } else if (event.target.closest("#save-image")) {
    saveCardImage()
  }
})
