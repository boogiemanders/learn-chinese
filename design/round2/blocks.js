// Draws text as separate square blocks, like signage built from tiles.
// <span class="blocks" data-text="出口" data-cell="9" data-gap="2" data-color="#fff"></span>
// Renders the 16px bitmap font DotGothic16 onto a tiny canvas and turns every
// lit pixel into one square.
async function blockify(el) {
  const text = el.dataset.text;
  const cell = Number(el.dataset.cell || 6);
  const gap = Number(el.dataset.gap || 1);
  const color = el.dataset.color || '#fff';
  await document.fonts.load('16px "DotGothic16"', text);
  const c = document.createElement('canvas');
  const ctx = c.getContext('2d');
  ctx.font = '16px "DotGothic16"';
  const w = Math.ceil(ctx.measureText(text).width) + 2;
  const h = 18;
  c.width = w; c.height = h;
  ctx.font = '16px "DotGothic16"';
  ctx.textBaseline = 'top';
  ctx.fillStyle = '#000';
  ctx.fillText(text, 0, 1);
  const data = ctx.getImageData(0, 0, w, h).data;
  const on = (x, y) => x >= 0 && y >= 0 && x < w && y < h && data[(y * w + x) * 4 + 3] > 120;
  // data-bold="1": thicken strokes by one pixel right and down (chunky signage weight)
  const bold = el.dataset.bold === '1';
  let rects = '';
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (on(x, y) || (bold && (on(x - 1, y) || on(x, y - 1)))) {
        rects += `<rect x="${x * cell}" y="${y * cell}" width="${cell - gap}" height="${cell - gap}"/>`;
      }
    }
  }
  el.innerHTML = `<svg aria-hidden="true" width="${w * cell}" height="${h * cell}" viewBox="0 0 ${w * cell} ${h * cell}" fill="${color}" style="display:block">${rects}</svg>`;
}
window.addEventListener('load', () => {
  document.querySelectorAll('.blocks').forEach(blockify);
});
