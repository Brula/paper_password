// Animates the stage between formats.
//
// Both heights are measured off the real element rather than declared in CSS,
// so nothing here is a guess about how tall a card is. A plain CSS transition
// cannot do it: the replacement card is already at full height before the
// transition can start, so growing snaps.
const STAGE_DURATION = 450
const STAGE_EASING = "cubic-bezier(0.22, 1, 0.36, 1)"

export default {
  beforeUpdate() {
    this.from = this.el.getBoundingClientRect().height
  },

  updated() {
    const to = this.el.getBoundingClientRect().height

    // Every patch inside the stage lands here, selecting a cell included.
    if (this.from === undefined || Math.abs(to - this.from) < 1) { return }
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) { return }

    this.animation?.cancel()
    // For the duration only. The card is already full height, so without this
    // it spills out of the growing box instead of being revealed.
    this.el.style.overflow = "hidden"
    this.animation = this.el.animate(
      [{height: `${this.from}px`}, {height: `${to}px`}],
      {duration: STAGE_DURATION, easing: STAGE_EASING}
    )
    this.animation.finished
      .then(() => { this.el.style.overflow = "" })
      .catch(() => {}) // cancelled by the next switch, which restores it instead
  }
}
