// Hand-drawn SVG icons (viewBox 0 0 100 100) in the game's outline style — used where the
// emoji font has no glyph yet. Keys are referenced from edit.json / data.json ("icon").
const K = "#1A1208";
const S = `stroke="${K}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"`;
const svg = body => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${body}</svg>`;

export const ICONS = {
  bolt: svg(`<path d="M60 4 L20 56 H45 L36 96 L80 40 H55 L66 4 Z" fill="#FFD43B" ${S}/><path d="M58 12 L32 48" stroke="#FFF1A8" stroke-width="5" stroke-linecap="round"/>`),
  parachute: svg(`<path d="M8 46 C8 18 30 6 50 6 C70 6 92 18 92 46 C85 39 77 39 71 46 C65 39 57 39 50 46 C43 39 35 39 29 46 C23 39 15 39 8 46 Z" fill="#FF6BD6" ${S}/>
    <path d="M50 7 C40 14 34 30 29 46 M50 7 C60 14 66 30 71 46" fill="none" stroke="${K}" stroke-width="4"/>
    <path d="M29 12 C22 22 18 34 17 42" stroke="#FFD1F3" stroke-width="5" fill="none" stroke-linecap="round"/>
    <path d="M9 47 L43 80 M29 47 L45 78 M50 47 L50 76 M71 47 L55 78 M91 47 L57 80" stroke="${K}" stroke-width="3" fill="none"/>
    <rect x="38" y="74" width="24" height="20" rx="5" fill="#C8873A" ${S}/><path d="M42 80 H58" stroke="#8a5a1f" stroke-width="3"/>`),
  sheep: svg(`<g fill="#FFF6E3" ${S}><circle cx="36" cy="44" r="16"/><circle cx="56" cy="38" r="17"/><circle cx="72" cy="50" r="15"/><circle cx="58" cy="62" r="16"/><circle cx="38" cy="62" r="15"/></g>
    <g fill="#FFF6E3"><circle cx="50" cy="52" r="18"/></g>
    <path d="M40 74 V90 M50 76 V92 M62 76 V92 M70 70 V88" stroke="${K}" stroke-width="7" stroke-linecap="round"/>
    <ellipse cx="20" cy="48" rx="13" ry="15" fill="#3a2a3a" ${S}/><circle cx="16" cy="45" r="3" fill="#fff"/><path d="M11 36 C4 32 3 42 9 44" fill="#3a2a3a" ${S}/>`),
  updown: svg(`<path d="M30 8 L52 36 H39 V58 H21 V36 H8 Z" fill="#2BD98A" ${S}/><path d="M70 92 L48 64 H61 V42 H79 V64 H92 Z" fill="#FF4D6D" ${S}/>`),
  moneybag: svg(`<path d="M36 22 C30 14 36 6 44 10 C48 4 56 4 58 10 C66 6 72 14 64 22 Z" fill="#C8873A" ${S}/>
    <path d="M36 24 C14 38 8 66 18 82 C26 94 74 94 82 82 C92 66 86 38 64 24 Z" fill="#E0A04A" ${S}/>
    <path d="M34 24 H66" stroke="${K}" stroke-width="7" stroke-linecap="round"/>
    <path d="M58 46 C54 40 40 40 40 50 C40 60 60 58 60 68 C60 78 44 78 40 70 M50 36 V82" fill="none" stroke="#FFD43B" stroke-width="7" stroke-linecap="round"/>`),
  hat: svg(`<ellipse cx="50" cy="80" rx="44" ry="11" fill="#2a2240" ${S}/><path d="M26 78 V26 C26 18 74 18 74 26 V78 Z" fill="#2a2240" ${S}/>
    <rect x="26" y="60" width="48" height="12" fill="#FF6BD6" ${S}/><path d="M34 28 V56" stroke="#5a4c80" stroke-width="5" stroke-linecap="round"/>`),
  runner: svg(`<circle cx="60" cy="16" r="10" fill="#FFD43B" ${S}/>
    <path d="M54 30 L42 58 L22 66 M42 58 L56 72 L50 94 M52 34 L70 46 L84 40 M52 34 L34 36 L24 48" fill="none" stroke="${K}" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M54 30 L42 58 L22 66 M42 58 L56 72 L50 94 M52 34 L70 46 L84 40 M52 34 L34 36 L24 48" fill="none" stroke="#2BD98A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M6 30 H22 M2 44 H16 M8 58 H18" stroke="#FFF6E3" stroke-width="5" stroke-linecap="round" opacity=".8"/>`),
  storm: svg(`<path d="M22 58 C8 58 8 38 22 38 C22 22 44 16 52 30 C60 18 84 22 82 40 C96 42 94 58 80 58 Z" fill="#B9B2E6" ${S}/>
    <path d="M52 50 L36 74 H48 L42 96 L66 66 H53 L60 50 Z" fill="#FFD43B" ${S}/>`),
  party: svg(`<path d="M10 92 L32 30 L72 70 Z" fill="#FFC93C" ${S}/><path d="M22 60 L46 82 M28 44 L58 72" stroke="#FF6BD6" stroke-width="7"/>
    <path d="M10 92 L32 30 L72 70 Z" fill="none" ${S}/>
    <path d="M44 26 C48 14 60 16 58 6 M62 40 C74 30 84 40 94 30 M72 54 C80 52 86 60 94 56" fill="none" stroke="#5FC4FF" stroke-width="6" stroke-linecap="round"/>
    <rect x="66" y="10" width="9" height="9" rx="2" fill="#2BD98A" transform="rotate(20 70 14)"/><circle cx="86" cy="16" r="5" fill="#FF6BD6"/><rect x="80" y="72" width="9" height="9" rx="2" fill="#FFD43B" transform="rotate(-25 84 76)"/>`),
  cap: svg(`<path d="M26 50 V70 C26 80 74 80 74 70 V50" fill="#2a2240" ${S}/><path d="M50 18 L96 38 L50 58 L4 38 Z" fill="#3a2f5c" ${S}/>
    <path d="M50 38 L80 48 V72" fill="none" stroke="#FFC93C" stroke-width="5" stroke-linecap="round"/><path d="M74 72 L80 90 L86 72 Z" fill="#FFC93C" ${S}/>`),
  tools: svg(`<g transform="rotate(45 50 50)"><rect x="44" y="30" width="12" height="64" rx="5" fill="#C8873A" ${S}/><rect x="24" y="8" width="52" height="24" rx="6" fill="#9AA3B8" ${S}/></g>
    <g transform="rotate(-45 50 50)"><rect x="44" y="34" width="12" height="60" rx="6" fill="#DCE2EE" ${S}/><path d="M32 18 C32 4 68 4 68 18 C68 30 58 34 58 34 H42 C42 34 32 30 32 18 Z M44 6 V20 H56 V6" fill="#DCE2EE" ${S}/></g>`),
  ban: svg(`<rect x="22" y="14" width="56" height="72" rx="10" fill="#FFF6E3" ${S}/><path d="M40 38 C40 28 60 28 60 38 C60 46 50 46 50 54 M50 64 V66" fill="none" stroke="${K}" stroke-width="6" stroke-linecap="round"/>
    <circle cx="50" cy="50" r="40" fill="none" stroke="#FF4D6D" stroke-width="10"/><path d="M22 22 L78 78" stroke="#FF4D6D" stroke-width="10" stroke-linecap="round"/>`),
  timer: svg(`<circle cx="50" cy="56" r="36" fill="#FFF6E3" ${S}/><rect x="42" y="6" width="16" height="10" rx="3" fill="#FFF6E3" ${S}/>
    <path d="M50 56 L50 32" stroke="${K}" stroke-width="7" stroke-linecap="round"/><path d="M50 56 L66 64" stroke="#FF4D6D" stroke-width="7" stroke-linecap="round"/><circle cx="50" cy="56" r="5" fill="${K}"/>`),
  pause: svg(`<circle cx="50" cy="50" r="42" fill="#FFF6E3" ${S}/><rect x="33" y="28" width="12" height="44" rx="4" fill="${K}"/><rect x="55" y="28" width="12" height="44" rx="4" fill="${K}"/>`),
  toggle: svg(`<rect x="6" y="28" width="88" height="44" rx="22" fill="#6b6690" ${S}/><circle cx="30" cy="50" r="16" fill="#FFF6E3" ${S}/><path d="M60 42 L76 58 M76 42 L60 58" stroke="#FFF6E3" stroke-width="6" stroke-linecap="round"/>`),
  banana: svg(`<path d="M16 26 C16 70 60 98 94 80 C99 77 97 70 91 71 C62 80 34 60 30 24 Z" fill="#FFD43B" ${S}/><path d="M24 36 C28 62 54 82 84 80" fill="none" stroke="#FFF1A8" stroke-width="5" stroke-linecap="round"/><path d="M16 26 L14 12 L28 11 L30 24 Z" fill="#6B4A12" ${S}/>`),
  coin: svg(`<circle cx="50" cy="50" r="44" fill="#F5B301" ${S}/><circle cx="50" cy="50" r="34" fill="none" stroke="#FFDE6B" stroke-width="4"/>
    <g fill="${K}" opacity=".85"><circle cx="35" cy="42" r="7"/><circle cx="65" cy="42" r="7"/><circle cx="50" cy="48" r="16"/></g><ellipse cx="50" cy="55" rx="10" ry="7.5" fill="#F5B301"/><circle cx="44" cy="44" r="2.6" fill="#F5B301"/><circle cx="56" cy="44" r="2.6" fill="#F5B301"/>`),
};

// Golden banana coin = the logo's coin (monkey-head embossing) with the "Bananen-Dollar" emblem from
// Web/img/monkey-money-logo.svg on its face.
export const COIN_FACE = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-60 -60 120 120">
  <defs><radialGradient id="cg" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#FFF1A8"/><stop offset="0.45" stop-color="#FFC93C"/><stop offset="1" stop-color="#E08A00"/></radialGradient></defs>
  <circle r="54" fill="url(#cg)" stroke="#1A1208" stroke-width="5"/>
  <circle r="43" fill="none" stroke="#FFE27A" stroke-width="3.5"/>
  <circle r="47.5" fill="none" stroke="#B7780B" stroke-width="2" stroke-dasharray="3 3.2"/>
  <g transform="scale(0.36) rotate(-6) translate(0 -8)">
    <path d="M -92 -20 C -78 26 -34 46 6 46 C 46 46 80 18 90 -24" fill="none" stroke="#1A1208" stroke-width="46" stroke-linecap="round"/>
    <path d="M -92 -20 C -78 26 -34 46 6 46 C 46 46 80 18 90 -24" fill="none" stroke="#FFD43B" stroke-width="35" stroke-linecap="round"/>
    <path d="M -78 -16 C -64 20 -28 36 4 37" fill="none" stroke="#FFF1A8" stroke-width="9" stroke-linecap="round"/>
    <path d="M -102 -38 L -108 -52" stroke="#1A1208" stroke-width="15" stroke-linecap="round"/>
    <path d="M 98 -42 L 103 -56" stroke="#1A1208" stroke-width="15" stroke-linecap="round"/>
    <g stroke="#1A1208" stroke-width="6"><rect x="-21" y="-50" width="15" height="140" rx="7" fill="#F5B301" transform="rotate(3)"/><rect x="8" y="-52" width="15" height="140" rx="7" fill="#F5B301" transform="rotate(-2)"/></g>
  </g>
  <path d="M -38 -26 A 46 46 0 0 1 -14 -42" fill="none" stroke="#FFFBE0" stroke-width="5" stroke-linecap="round"/>
</svg>`;
export const COIN_EDGE = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-60 -60 120 120"><circle r="54" fill="#B7780B" stroke="#1A1208" stroke-width="5"/></svg>`;

export const dataUrl = s => "data:image/svg+xml;charset=utf-8," + encodeURIComponent(s);
