// Hand-drawn 9×9 square-block glyphs, one-cell strokes, after the
// Fujimidai Tunnel signage approach (letters built from square tiles).
// <span class="glyph" data-char="出" data-cell="12" data-color="#fff"></span>
const GLYPHS = {
  '今': ['....#....', '...#.#...', '..#...#..', '##.....##', '..#####..', '.........', '.#######.', '......##.', '.....#...'],
  '日': ['.#######.', '.#.....#.', '.#.....#.', '.#.....#.', '.#######.', '.#.....#.', '.#.....#.', '.#.....#.', '.#######.'],
  '出': ['....#....', '#...#...#', '#...#...#', '#########', '....#....', '#...#...#', '#...#...#', '#...#...#', '#########'],
  '口': ['.........', '#########', '#.......#', '#.......#', '#.......#', '#.......#', '#.......#', '#########', '........#'],
};
function drawGlyph(el) {
  const rows = GLYPHS[el.dataset.char] || [];
  const cell = Number(el.dataset.cell || 8);
  const color = el.dataset.color || '#fff';
  let rects = '';
  rows.forEach((row, y) => [...row].forEach((ch, x) => {
    if (ch === '#') rects += `<rect x="${x * cell}" y="${y * cell}" width="${cell}" height="${cell}"/>`;
  }));
  el.innerHTML = `<svg aria-hidden="true" width="${9 * cell}" height="${9 * cell}" viewBox="0 0 ${9 * cell} ${9 * cell}" fill="${color}" style="display:block" shape-rendering="crispEdges">${rects}</svg>`;
}
window.addEventListener('DOMContentLoaded', () => document.querySelectorAll('.glyph').forEach(drawGlyph));
