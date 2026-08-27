// The phone card, drawn to a PNG from the table already on the page, so the
// image cannot disagree with what was on screen. All client-side.
//
// Sized in device pixels at roughly 3x the on-screen card.
const EMOJI_FONT = `"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", "Twemoji Mozilla", "EmojiOne Color", "Android Emoji", sans-serif`
const MONO_FONT = `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`

const IMAGE = {
  pad: 28,        // white margin, so the border is not flush with the edge
  labelCol: 92,   // object emoji down the left
  cellW: 116,     // 8 of these: 1020px of grid, a comfortable phone width
  headerH: 104,   // animal emoji across the top
  accent: 6,      // the animal's colour stripe under its header
  rowH: 82,
  idLine: 52
}

// Always light, whatever the page is set to: this gets saved, sent and
// printed.
function drawCard(card) {
  const heads = [...card.querySelectorAll("thead th[data-animal]")]
  const rows = [...card.querySelectorAll("tbody tr")]
  const {pad, labelCol, cellW, headerH, accent, rowH, idLine} = IMAGE

  const canvas = document.createElement("canvas")
  canvas.width = pad * 2 + labelCol + cellW * heads.length
  canvas.height = pad * 2 + headerH + rowH * rows.length + idLine

  const ctx = canvas.getContext("2d")
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  ctx.fillStyle = "#fff"
  ctx.fillRect(0, 0, canvas.width, canvas.height)

  const gridLeft = pad + labelCol
  const gridTop = pad + headerH
  const gridHeight = rowH * rows.length

  // Bands first, so every character lands on top of its own column.
  heads.forEach((head, i) => {
    const x = gridLeft + i * cellW
    ctx.fillStyle = head.dataset.tint
    ctx.fillRect(x, gridTop, cellW, gridHeight)
    ctx.fillStyle = head.dataset.accent
    ctx.fillRect(x, gridTop - accent, cellW, accent)
    ctx.fillStyle = "#000"
    ctx.font = `58px ${EMOJI_FONT}`
    ctx.fillText(head.textContent.trim(), x + cellW / 2, pad + (headerH - accent) / 2)
  })

  rows.forEach((row, r) => {
    const y = gridTop + r * rowH + rowH / 2
    ctx.fillStyle = "#000"
    ctx.font = `46px ${EMOJI_FONT}`
    ctx.fillText(row.querySelector("th").textContent.trim(), pad + labelCol / 2, y)
    ctx.font = `44px ${MONO_FONT}`
    row.querySelectorAll("td").forEach((cell, c) => {
      ctx.fillText(cell.textContent.trim(), gridLeft + c * cellW + cellW / 2, y)
    })
  })

  // The id is what reprints the card.
  ctx.fillStyle = "#555"
  ctx.font = `26px ${MONO_FONT}`
  ctx.fillText(card.dataset.cardId, canvas.width / 2, gridTop + gridHeight + idLine / 2)

  ctx.strokeStyle = "#000"
  ctx.lineWidth = 3
  ctx.strokeRect(pad / 2, pad / 2, canvas.width - pad, canvas.height - pad)

  return canvas
}

export function saveCardImage() {
  const card = document.getElementById("phone-card")
  if (!card) { return }

  drawCard(card).toBlob(blob => {
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = `paper-password-${card.dataset.cardId}.png`
    // Firefox only follows a click on an anchor that is in the document.
    document.body.appendChild(link)
    link.click()
    link.remove()
    // Not revoked inline: the download reads the blob after the click returns.
    setTimeout(() => URL.revokeObjectURL(url), 60000)
  }, "image/png")
}
