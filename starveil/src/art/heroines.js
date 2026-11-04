// 동료 일러스트(SVG). heroineSVG(id, { e: 표정, outfit, cls })
// 좌표계: 320 × 430, 얼굴 중심 x=160
let uid = 0;

const SKIN = '#ffe7dd', SKIN_SH = '#f6cbbd', SKIN_LINE = '#e3a594';
const LASH = '#3a2340';

const P = {
  lyra: {
    hair: '#eaa7da', hairSh: '#c47fc2', hairHi: '#ffd9f3', hairLine: '#a3609f',
    iris1: '#5a4fd6', iris2: '#b9a7ff', pupil: '#2a1f6a',
  },
  mio: {
    hair: '#ffae66', hairSh: '#e07f38', hairHi: '#ffdcae', hairLine: '#b85f24',
    iris1: '#1f8f84', iris2: '#7fe6cf', pupil: '#0f4a44',
  },
  seren: {
    hair: '#e3e9f7', hairSh: '#a9b5d6', hairHi: '#ffffff', hairLine: '#8590b4',
    iris1: '#2f4fc4', iris2: '#9cb8ff', pupil: '#16246a',
  },
};

// ───────── 얼굴 ─────────
const FACE = 'M104 150C104 104 128 78 160 78S216 104 216 150C216 193 196 227 160 245C124 227 104 193 104 150Z';
const EYE_WHITE = 'M114 171C114 155 150 152 153 168C153 187 119 192 114 171Z';

function eye(k, pal, e) {
  const id = `ey${k}`;
  if (e === 'happy') return `<path d="M115 178C121 163 146 163 152 178" fill="none" stroke="${LASH}" stroke-width="4.4" stroke-linecap="round"/><path d="M114 177l-6 -3" stroke="${LASH}" stroke-width="3" stroke-linecap="round"/>`;
  if (e === 'blink') return `<path d="M115 174C124 181 143 181 152 173" fill="none" stroke="${LASH}" stroke-width="3.8" stroke-linecap="round"/><path d="M116 174l-7 -3" stroke="${LASH}" stroke-width="3" stroke-linecap="round"/>`;
  const big = e === 'surprise';
  const irx = big ? 12 : 14.5, iry = big ? 16 : 19;
  const prx = big ? 4.5 : 6.5, pry = big ? 6.5 : 9.5;
  const ix = 134, iy = big ? 173 : 175;
  let out = `<defs><clipPath id="${id}c"><path d="${EYE_WHITE}"/></clipPath>
    <radialGradient id="${id}g" cx=".5" cy=".62" r=".62"><stop offset="0" stop-color="${pal.iris2}"/><stop offset=".55" stop-color="${pal.iris1}"/><stop offset="1" stop-color="${pal.pupil}"/></radialGradient>
    <linearGradient id="${id}w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e6e0f4"/><stop offset=".4" stop-color="#ffffff"/></linearGradient></defs>`;
  out += `<path d="${EYE_WHITE}" fill="url(#${id}w)"/>`;
  out += `<g clip-path="url(#${id}c)">
    <ellipse cx="${ix}" cy="${iy}" rx="${irx}" ry="${iry}" fill="url(#${id}g)" stroke="${pal.pupil}" stroke-width="1.6"/>
    <ellipse cx="${ix}" cy="${iy + 1}" rx="${prx}" ry="${pry}" fill="${pal.pupil}"/>
    <path d="M${ix - irx + 3} ${iy + 6}Q${ix} ${iy + iry + 4} ${ix + irx - 3} ${iy + 6}Q${ix} ${iy + iry - 5} ${ix - irx + 3} ${iy + 6}Z" fill="${pal.iris2}" opacity=".85"/>
    <path d="M110 148H160V167C146 158 126 158 110 169Z" fill="${pal.pupil}" opacity=".35"/>
  </g>`;
  out += `<ellipse cx="${ix - 5.5}" cy="${iy - 8}" rx="${big ? 3.4 : 4.6}" ry="${big ? 4 : 5.4}" fill="#fff"/><circle cx="${ix + 6}" cy="${iy + 7}" r="2.1" fill="#fff" opacity=".95"/>
    <path d="M${ix + 6} ${iy - 7}l1 2.6 2.6 1-2.6 1-1 2.6-1-2.6-2.6-1 2.6-1z" fill="#fff" opacity=".85" class="h-twinkle"/>`;
  if (e === 'pout') out += `<path d="M110 150H158V171C142 165 126 165 110 172Z" fill="${SKIN}"/><path d="M114 171C126 166 142 166 154 170" fill="none" stroke="${LASH}" stroke-width="4" stroke-linecap="round"/>`;
  else out += `<path d="M115 157C123 150 142 148 151 153" fill="none" stroke="${SKIN_LINE}" stroke-width="1.4" stroke-linecap="round" opacity=".75"/>
    <path d="M111 168C116 153 145 149 155 162" fill="none" stroke="${LASH}" stroke-width="5" stroke-linecap="round"/>
    <path d="M112 166L104 160L109 168ZM114 160L108 152L113 162Z" fill="${LASH}"/>`;
  out += `<path d="M121 190C128 193 140 193 147 189" fill="none" stroke="${SKIN_LINE}" stroke-width="1.6" stroke-linecap="round"/>`;
  if (e === 'sad') out += `<path d="M148 186c3 5 3 9 0 11-3-2-3-6 0-11z" fill="#9fd8ff" opacity=".9"/>`;
  return out;
}

function brow(e, pal) {
  const d = e === 'sad' ? 'M121 134C129 133 139 129 146 124' : e === 'pout' ? 'M120 128C129 129 139 131 147 135' : e === 'surprise' ? 'M120 126C128 120 139 120 147 123' : 'M121 132C128 127 139 127 146 130';
  const one = `<path d="${d}" fill="none" stroke="${pal.hairLine}" stroke-width="2.6" stroke-linecap="round" opacity=".85"/>`;
  return one + `<g transform="translate(320 0) scale(-1 1)">${one}</g>`;
}

function mouth(e) {
  const red = '#c4566a';
  switch (e) {
    case 'smile': return `<path d="M150 210C153 222 167 222 170 210Z" fill="${red}"/><path d="M154 217C157 220 163 220 166 217C163 215 157 215 154 217Z" fill="#ff98a8"/>`;
    case 'happy': return `<path d="M148 208C151 225 169 225 172 208Z" fill="${red}"/><path d="M153 218C157 222 163 222 167 218C163 215 157 215 153 218Z" fill="#ff98a8"/>`;
    case 'blush': return `<path d="M152 214C155 211 157 217 160 214S165 211 168 214" fill="none" stroke="${red}" stroke-width="2.4" stroke-linecap="round"/>`;
    case 'surprise': return `<ellipse cx="160" cy="215" rx="5" ry="6.5" fill="${red}"/>`;
    case 'sad': return `<path d="M152 217C156 211 164 211 168 217" fill="none" stroke="${red}" stroke-width="2.5" stroke-linecap="round"/>`;
    case 'pout': return `<path d="M155 211C159 214 159 214 156 217M161 211C165 214 165 214 162 217" fill="none" stroke="${red}" stroke-width="2.2" stroke-linecap="round"/>`;
    default: return `<path d="M151 211C155 216 165 216 169 211" fill="none" stroke="${red}" stroke-width="2.5" stroke-linecap="round"/>`;
  }
}

function blush(e, k) {
  const strong = e === 'blush' || e === 'happy' || e === 'pout';
  let s = `<defs><radialGradient id="bl${k}"><stop offset="0" stop-color="#ff7a9a" stop-opacity="${strong ? 0.75 : 0.42}"/><stop offset="1" stop-color="#ff7a9a" stop-opacity="0"/></radialGradient></defs><g fill="url(#bl${k})"><ellipse cx="121" cy="198" rx="17" ry="8.5"/><ellipse cx="199" cy="198" rx="17" ry="8.5"/></g>`;
  if (e === 'blush') s += `<g stroke="#ff6f92" stroke-width="1.8" stroke-linecap="round" opacity=".8"><path d="M113 199l4-6M120 199l4-6M127 199l4-6M190 199l4-6M197 199l4-6M204 199l4-6"/></g>`;
  return s;
}

function face(k, pal, e, extra = '', bangs = '') {
  const L = eye(k + 'l', pal, e);
  const R = eye(k + 'r', pal, e);
  return `<defs><clipPath id="fc${k}"><path d="${FACE}"/></clipPath><linearGradient id="sk${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff1ea"/><stop offset=".7" stop-color="${SKIN}"/><stop offset="1" stop-color="#fbd8cc"/></linearGradient></defs>
    <path d="${FACE}" fill="url(#sk${k})"/>
    <g clip-path="url(#fc${k})">${bangs ? `<path d="${bangs}" fill="${SKIN_SH}" opacity=".6" transform="translate(-2 9)"/>` : ''}
    <path d="M118 222C134 238 186 238 202 222C196 232 182 241 160 245C138 241 124 232 118 222Z" fill="${SKIN_SH}" opacity=".45"/></g>
    ${blush(e, k)}
    <g>${L}</g><g transform="translate(320 0) scale(-1 1)">${R}</g>
    <path d="M159 197l2 3" stroke="${SKIN_LINE}" stroke-width="2" stroke-linecap="round"/>
    ${mouth(e)}${extra}`;
}

const NECK = `<path d="M145 226C146 246 146 262 141 282H179C174 262 174 246 175 226Z" fill="${SKIN}"/><path d="M145 238C152 252 168 252 175 238V252C168 262 152 262 145 252Z" fill="${SKIN_SH}"/>`;
const BODY = 'M56 440C58 340 94 298 144 278H176C226 298 262 340 264 440Z';

// ───────── 리라 ─────────
function lyraBack(pal, outfit) {
  const tail = (m) => `<g ${m ? 'transform="translate(320 0) scale(-1 1)"' : ''}>
    <path d="M106 104C66 116 44 170 50 236C55 296 40 340 60 392C80 356 98 312 94 258C91 204 102 150 122 116Z" fill="${pal.hair}"/>
    <path d="M100 130C76 160 70 206 74 248C77 290 68 324 72 360C84 330 92 296 90 254C88 214 92 168 108 134Z" fill="${pal.hairSh}" opacity=".7"/>
    <path d="M78 170C70 200 72 230 76 250" fill="none" stroke="${pal.hairHi}" stroke-width="4" stroke-linecap="round" opacity=".6"/>
  </g>`;
  return tail(false) + tail(true) + `<path d="M92 152C88 82 120 54 160 54S232 82 228 152V232C210 244 110 244 92 232Z" fill="${pal.hairSh}"/>`;
}
function lyraFront(pal, outfit) {
  const ribbonC = outfit === 'festival' ? '#ff7aa8' : outfit === 'starlight' ? '#b9a7ff' : '#ff8fc8';
  let s = `<path stroke="${pal.hairLine}" stroke-width="1.4" stroke-opacity=".45" d="M102 152C100 96 126 60 160 58S220 96 218 152C212 134 207 122 199 114C201 132 195 147 189 154C187 134 181 120 171 112C171 130 165 144 157 152C155 132 149 118 139 112C139 130 133 144 123 154C123 134 119 122 113 116C111 130 108 142 102 152Z" fill="${pal.hair}"/>
    <path d="M104 138C95 170 95 222 108 266C115 238 117 198 117 162Z" fill="${pal.hair}"/>
    <path d="M216 138C225 170 225 222 212 266C205 238 203 198 203 162Z" fill="${pal.hair}"/>
    <path d="M140 112C140 128 134 142 124 152L130 128Z M171 112C171 130 165 144 157 152L164 128Z" fill="${pal.hairSh}" opacity=".55"/>
    <path d="M124 86C142 75 178 75 196 86" fill="none" stroke="${pal.hairHi}" stroke-width="7" stroke-linecap="round" opacity=".75"/>
    <path d="M160 58C148 36 162 24 174 32C165 36 163 45 168 57Z" fill="${pal.hair}"/>`;
  // 양갈래 리본
  const bow = (x, m) => `<g transform="translate(${x} 108) ${m ? 'scale(-1 1)' : ''}"><path d="M0 0L-16-10-14 10Z M0 0L14-12 16 8Z" fill="${ribbonC}"/><circle r="5" fill="${ribbonC}"/><circle r="2.4" fill="#fff" opacity=".6"/></g>`;
  s += bow(104, false) + bow(216, true);
  // 별 머리핀
  if (outfit !== 'default') s += starShape(196, 100, 9, '#ffe08a', '#e0b040');
  return s;
}
function lyraOutfit(outfit) {
  if (outfit === 'casual') return `<path d="${BODY}" fill="#fff4e8"/>
    <path d="M56 440C58 360 78 318 112 300C104 340 104 400 110 440Z M264 440C262 360 242 318 208 300C216 340 216 400 210 440Z" fill="#ffe2cf"/>
    <path d="M124 304H196L204 440H116Z" fill="#ffb3d1"/>
    <path d="M124 304C130 312 136 312 142 304C148 312 154 312 160 304C166 312 172 312 178 304C184 312 190 312 196 304" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/>
    <path d="M124 304L112 282M196 304L208 282" stroke="#ffb3d1" stroke-width="8" stroke-linecap="round"/>
    <path d="M144 280L160 296 176 280" fill="#fff" stroke="#f0d8c8" stroke-width="2"/>
    ${heartShape(160, 350, 12, '#ff7aa8')}`;
  if (outfit === 'festival') return `<path d="${BODY}" fill="#ffc6dd"/>
    <path d="M140 278L160 352 176 278Z" fill="#fff"/><path d="M134 278L160 360 168 350 150 278Z" fill="#ff8fbc"/>
    <path d="M60 396H260V440H60Z" fill="#8f6ad6"/><path d="M60 404H260" stroke="#ffe08a" stroke-width="3"/>
    <g fill="#fff" opacity=".85">${flower(92, 340)}${flower(226, 330)}${flower(206, 380)}${flower(110, 386)}</g>`;
  if (outfit === 'starlight') return `<path d="${BODY}" fill="#c9b8ff"/>
    <path d="M110 300C130 330 190 330 210 300L218 440H102Z" fill="#e2d8ff"/>
    <path d="M140 280C148 292 172 292 180 280" fill="none" stroke="#fff" stroke-width="4"/>
    ${starShape(160, 300, 12, '#fff3b0', '#e0b040')}
    <g fill="#fff">${spark(96, 350)}${spark(222, 340)}${spark(130, 400)}${spark(196, 410)}${spark(160, 372)}</g>`;
  // default: 남색 망토 + 블라우스
  return `<path d="${BODY}" fill="#2b2f6e"/>
    <path d="M56 440C58 350 92 304 140 284L132 440Z" fill="#363b84"/><path d="M264 440C262 350 228 304 180 284L188 440Z" fill="#363b84"/>
    <path d="M140 280L160 336 180 280Z" fill="#fff8f2"/>
    <path d="M140 278L160 300 150 314 128 288Z M180 278L160 300 170 314 192 288Z" fill="#fff" stroke="#e8dcef" stroke-width="1.5"/>
    <path d="M160 302L146 294 146 312Z M160 302L174 294 174 312Z" fill="#ff8fc8"/><circle cx="160" cy="303" r="4.5" fill="#ff6fb0"/>
    <path d="M80 360C110 380 210 380 240 360" fill="none" stroke="#ffe08a" stroke-width="3" opacity=".6"/>
    ${starShape(100, 300, 9, '#ffe08a', '#e0b040')}${starShape(220, 300, 9, '#ffe08a', '#e0b040')}`;
}
function lyraHat(outfit) {
  if (outfit === 'default') return `<g transform="translate(0 16) rotate(-9 160 80)">
    <path d="M114 78C126 44 150 14 198 0C188 22 196 44 212 76Z" fill="#2b2f6e"/>
    <path d="M198 0C206 8 220 6 230 0C222 14 206 18 196 12Z" fill="#2b2f6e"/>
    <path d="M150 34C164 30 178 30 190 36" fill="none" stroke="#3d4290" stroke-width="4"/>
    <path d="M118 70C140 60 186 60 208 68L210 80C186 72 140 72 116 82Z" fill="#ff8fc8"/>
    <ellipse cx="162" cy="80" rx="96" ry="17" fill="#232760"/>
    <ellipse cx="162" cy="76" rx="90" ry="12" fill="#2f3478"/>
    ${starShape(178, 64, 10, '#ffe08a', '#e0b040')}
  </g>`;
  if (outfit === 'festival') return `<g>${flowerBig(108, 96, '#ff7aa8')}</g>`;
  if (outfit === 'starlight') return `<path d="M128 70L136 52 146 66 160 44 174 66 184 52 192 70Z" fill="#ffe08a" stroke="#d9a830" stroke-width="2"/><circle cx="160" cy="62" r="4" fill="#9fd8ff"/>`;
  return '';
}

// ───────── 미오 ─────────
function mioBack(pal, outfit) {
  const ear = (m) => `<g ${m ? 'transform="translate(320 0) scale(-1 1)"' : ''}>
    <path d="M100 100C92 70 90 40 96 14C116 28 136 48 148 72Z" fill="${pal.hair}"/>
    <path d="M106 88C101 66 100 46 103 30C116 42 128 56 136 72Z" fill="#fff3e6"/>
    <path d="M96 14C100 22 104 30 106 38" stroke="${pal.hairLine}" stroke-width="2" fill="none"/>
  </g>`;
  const tail = `<path d="M220 440C250 420 288 392 294 340C298 300 288 268 270 250C260 276 262 302 254 326C246 352 226 382 206 412Z" fill="${pal.hair}"/>
    <path d="M254 330C246 356 230 384 214 408" fill="none" stroke="${pal.hairSh}" stroke-width="4" stroke-linecap="round" opacity=".7"/>
    <path d="M270 250C288 268 298 300 294 332C284 314 272 302 262 298C263 282 265 266 270 250Z" fill="#fff6ea"/>`;
  return tail + `<path d="M88 152C82 82 120 54 160 54S238 82 232 152C236 204 242 252 234 290C222 276 214 286 204 294C200 276 120 276 116 294C106 286 98 276 86 290C78 252 84 204 88 152Z" fill="${pal.hairSh}"/>` + ear(false) + ear(true);
}
function mioFront(pal, outfit) {
  let s = `<path stroke="${pal.hairLine}" stroke-width="1.4" stroke-opacity=".45" d="M100 156C96 98 124 60 160 58S224 96 220 156C214 140 210 128 202 120C204 140 198 152 192 158C190 138 182 124 172 116C174 134 170 146 164 154C160 136 152 122 140 116C140 134 132 148 120 158C122 138 118 126 112 120C110 136 106 146 100 156Z" fill="${pal.hair}"/>
    <path d="M102 140C92 176 92 228 102 272C112 250 116 206 116 166Z" fill="${pal.hair}"/>
    <path d="M218 140C228 176 228 228 218 272C208 250 204 206 204 166Z" fill="${pal.hair}"/>
    <path d="M120 158C126 140 132 128 140 116C138 132 132 146 120 158Z" fill="${pal.hairSh}" opacity=".5"/>
    <path d="M126 86C144 75 178 75 196 86" fill="none" stroke="${pal.hairHi}" stroke-width="7" stroke-linecap="round" opacity=".7"/>`;
  if (outfit === 'festival') s += `<g transform="translate(88 92) rotate(-20)"><path d="M0 0C-4-14 0-26 6-30C10-20 16-18 24-18C32-18 38-20 42-30C48-26 52-14 48 0C46 18 34 28 24 28S2 18 0 0Z" fill="#fff"/><path d="M8 4L18 8M30 8L40 4" stroke="#e85a5a" stroke-width="3" stroke-linecap="round"/><circle cx="24" cy="16" r="3" fill="#e85a5a"/></g>`;
  else if (outfit === 'starlight') s += `<g transform="rotate(-10 160 70)"><path d="M108 74C112 44 208 44 212 74Z" fill="#24305e"/><ellipse cx="160" cy="76" rx="62" ry="10" fill="#1a2348"/><path d="M110 70H210" stroke="#ffcf5a" stroke-width="4"/>${starShape(160, 56, 8, '#ffcf5a', '#c99a20')}</g>`;
  else s += `<g transform="translate(206 112)">${coinClip()}</g>`;
  return s;
}
function coinClip() { return `<circle r="9" fill="#ffcf5a" stroke="#c99a20" stroke-width="2"/><circle r="4.5" fill="none" stroke="#c99a20" stroke-width="1.6"/>`; }
function mioOutfit(outfit) {
  if (outfit === 'casual') return `<path d="${BODY}" fill="#ffd2a3"/>
    <path d="M118 282C130 300 190 300 202 282L210 290C190 312 130 312 110 290Z" fill="#ffbf80"/>
    <path d="M148 300V350M172 300V350" stroke="#fff" stroke-width="3" stroke-linecap="round"/><circle cx="148" cy="352" r="4" fill="#fff"/><circle cx="172" cy="352" r="4" fill="#fff"/>
    <path d="M120 400H200V440H120Z" fill="#ffbf80"/>
    ${pawPrint(100, 360)}${pawPrint(222, 380)}`;
  if (outfit === 'festival') return `<path d="${BODY}" fill="#e85a5a"/>
    <path d="M140 278L160 352 176 278Z" fill="#fff"/><path d="M134 278L160 360 168 350 150 278Z" fill="#ffe2a0"/>
    <path d="M60 396H260V440H60Z" fill="#ffcf5a"/><path d="M60 404H260" stroke="#c94040" stroke-width="3"/>
    <g fill="#fff" opacity=".8">${flower(96, 340)}${flower(224, 336)}${flower(208, 378)}</g>`;
  if (outfit === 'starlight') return `<path d="${BODY}" fill="#24305e"/>
    <path d="M140 280L160 330 180 280Z" fill="#fff"/>
    <path d="M60 340C80 300 110 290 130 286L136 300C110 310 88 330 74 360Z M260 340C240 300 210 290 190 286L184 300C210 310 232 330 246 360Z" fill="#ffcf5a"/>
    <g fill="#ffcf5a">${[330, 360, 390, 420].map((y) => `<circle cx="146" cy="${y}" r="4"/><circle cx="174" cy="${y}" r="4"/>`).join('')}</g>`;
  return `<path d="${BODY}" fill="#fbf7f0"/>
    <path d="M56 440C58 344 94 302 138 284L154 350 146 440Z" fill="#3f7a55"/><path d="M264 440C262 344 226 302 182 284L166 350 174 440Z" fill="#3f7a55"/>
    <path d="M136 268C150 282 170 282 184 268L190 286C170 300 150 300 130 286Z" fill="#b8743c"/>
    <path d="M176 288L190 320 178 322Z" fill="#a0602c"/>
    <path d="M160 296V312" stroke="#c99a20" stroke-width="2"/><g transform="translate(160 322)">${coinClip()}</g>
    <path d="M86 380H128" stroke="#2f5f42" stroke-width="3"/>`;
}

// ───────── 세렌 ─────────
function serenBack(pal) {
  return `<path d="M92 152C88 80 122 54 160 54S232 80 228 152L246 440H74Z" fill="${pal.hairSh}"/>
    <path d="M100 200L88 440H112Z M220 200L232 440H208Z" fill="${pal.hair}" opacity=".5"/>`;
}
function serenFront(pal, outfit) {
  let s = `<path stroke="${pal.hairLine}" stroke-width="1.4" stroke-opacity=".45" d="M102 152C100 96 126 62 160 60S220 96 218 152H210L205 138 198 152 189 140 181 153 171 140 161 153 151 140 141 153 132 140 124 151 116 138 110 152Z" fill="${pal.hair}"/>
    <path d="M104 132C98 180 98 230 104 276L120 276C118 230 118 180 118 146Z" fill="${pal.hair}"/>
    <path d="M216 132C222 180 222 230 216 276L200 276C202 230 202 180 202 146Z" fill="${pal.hair}"/>
    <path d="M124 86C142 75 178 75 196 86" fill="none" stroke="${pal.hairHi}" stroke-width="7" stroke-linecap="round" opacity=".9"/>
    <path d="M140 66C136 90 134 120 138 146M182 66C186 90 188 120 184 146" fill="none" stroke="${pal.hairSh}" stroke-width="2" opacity=".6"/>`;
  // 땋은 머리
  s += `<g>${[0, 1, 2, 3, 4, 5].map((i) => `<ellipse cx="${210 + i * 2}" cy="${262 + i * 22}" rx="11" ry="13" fill="${i % 2 ? pal.hair : pal.hairSh}"/>`).join('')}<path d="M206 398L222 398 214 420Z" fill="${pal.hair}"/><path d="M204 392H226" stroke="#5a7bd6" stroke-width="5" stroke-linecap="round"/></g>`;
  if (outfit === 'festival') s += `<g transform="translate(206 96)">${moonShape(0, 0, 12, '#ffe08a')}</g>`;
  else if (outfit === 'starlight') s += `<path d="M120 84C140 70 180 70 200 84" fill="none" stroke="#e8eeff" stroke-width="5"/><circle cx="160" cy="74" r="6" fill="#7aa8ff" stroke="#fff" stroke-width="2"/>`;
  else s += `<path d="M112 92C134 70 186 70 208 92" fill="none" stroke="#5a7bd6" stroke-width="7" stroke-linecap="round"/><g transform="translate(206 100)">${moonShape(0, 0, 11, '#e8eeff')}</g>`;
  return s;
}
function serenOutfit(outfit) {
  if (outfit === 'casual') return `<path d="${BODY}" fill="#e9dbc4"/>
    <path d="M140 280L160 320 180 280Z" fill="#fff"/><path d="M138 278L160 300 146 310 130 286Z M182 278L160 300 174 310 190 286Z" fill="#fff" stroke="#e0e4ee" stroke-width="1.5"/>
    <path d="M150 300L144 440H176L170 300Z" fill="#fff" opacity=".9"/>
    <g fill="#c9a27a">${[330, 360, 390].map((y) => `<circle cx="140" cy="${y}" r="4"/>`).join('')}</g>
    <path d="M70 380C100 396 220 396 250 380" fill="none" stroke="#d9c6a8" stroke-width="3"/>`;
  if (outfit === 'festival') return `<path d="${BODY}" fill="#3a4f9a"/>
    <path d="M140 278L160 352 176 278Z" fill="#fff"/><path d="M134 278L160 360 168 350 150 278Z" fill="#9cb8ff"/>
    <path d="M60 396H260V440H60Z" fill="#c9d2e6"/>
    <g>${moonShape(96, 340, 10, '#ffe08a')}${moonShape(224, 330, 10, '#ffe08a')}${moonShape(206, 380, 8, '#ffe08a')}</g>`;
  if (outfit === 'starlight') return `<path d="${BODY}" fill="#eef2ff"/>
    <path d="M90 320C120 300 200 300 230 320L236 440H84Z" fill="#dfe6ff"/>
    <path d="M136 282C146 296 174 296 184 282" fill="none" stroke="#9cb8ff" stroke-width="3"/>
    <path d="M160 296L152 308 160 322 168 308Z" fill="#5a8bff" stroke="#fff" stroke-width="2"/>
    <g fill="#9cb8ff" opacity=".8">${spark(100, 360)}${spark(220, 360)}${spark(160, 410)}</g>`;
  return `<path d="${BODY}" fill="#2a3a66"/>
    <path d="M126 300H194L200 440H120Z" fill="#f3f6ff"/>
    <path d="M140 276L160 296 180 276 186 292 160 306 134 292Z" fill="#3a4f8a"/>
    <g transform="translate(160 360)"><path d="M-16-12H-1V12H-16Z M1-12H16V12H1Z" fill="#5a7bd6"/><path d="M0-12V12" stroke="#2a3a66" stroke-width="2"/></g>
    <ellipse cx="88" cy="318" rx="34" ry="22" fill="#c9d2e6" stroke="#8a96b6" stroke-width="3"/><ellipse cx="232" cy="318" rx="34" ry="22" fill="#c9d2e6" stroke="#8a96b6" stroke-width="3"/>
    <path d="M64 314C80 306 100 306 116 314M204 314C220 306 240 306 256 314" fill="none" stroke="#fff" stroke-width="3" opacity=".7"/>`;
}

// ───────── 장식 도형 ─────────
function starShape(x, y, r, fill, stroke) {
  const pts = [];
  for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5; const rr = i % 2 ? r * 0.45 : r; pts.push(`${(x + Math.cos(a) * rr).toFixed(1)},${(y + Math.sin(a) * rr).toFixed(1)}`); }
  return `<polygon points="${pts.join(' ')}" fill="${fill}" stroke="${stroke}" stroke-width="1.5" stroke-linejoin="round"/>`;
}
function heartShape(x, y, r, fill) { return `<path transform="translate(${x} ${y}) scale(${r / 10})" d="M0 9C-8 4-11-1-9-5-7-9-2-9 0-5 2-9 7-9 9-5 11-1 8 4 0 9Z" fill="${fill}"/>`; }
function flower(x, y) { return `<g transform="translate(${x} ${y})"><circle cx="0" cy="-5" r="4"/><circle cx="5" cy="-1" r="4"/><circle cx="3" cy="5" r="4"/><circle cx="-3" cy="5" r="4"/><circle cx="-5" cy="-1" r="4"/><circle r="2.5" fill="#ffe08a"/></g>`; }
function flowerBig(x, y, c) { return `<g transform="translate(${x} ${y})" fill="${c}"><circle cx="0" cy="-9" r="7"/><circle cx="9" cy="-2" r="7"/><circle cx="5" cy="8" r="7"/><circle cx="-5" cy="8" r="7"/><circle cx="-9" cy="-2" r="7"/><circle r="4.5" fill="#ffe08a"/></g>`; }
function spark(x, y) { return `<path transform="translate(${x} ${y})" d="M0-7L1.6-1.6 7 0 1.6 1.6 0 7-1.6 1.6-7 0-1.6-1.6Z"/>`; }
function moonShape(x, y, r, c) { return `<path transform="translate(${x} ${y}) scale(${r / 10})" d="M3-10A10 10 0 109 4 8 8 0 013-10Z" fill="${c}"/>`; }
function pawPrint(x, y) { return `<g transform="translate(${x} ${y})" fill="#fff" opacity=".8"><ellipse cy="4" rx="6" ry="5"/><circle cx="-6" cy="-4" r="2.6"/><circle cx="-2" cy="-8" r="2.6"/><circle cx="3" cy="-8" r="2.6"/><circle cx="7" cy="-4" r="2.6"/></g>`; }

function glasses() { return `<g fill="none" stroke="#6a6f8a" stroke-width="2.6"><circle cx="134" cy="174" r="21"/><circle cx="186" cy="174" r="21"/><path d="M155 172C158 168 162 168 165 172"/></g><g fill="#fff" opacity=".18"><circle cx="134" cy="174" r="20"/><circle cx="186" cy="174" r="20"/></g>`; }

// ───────── 조립 ─────────
// ───────── 음영·선화 ─────────
function hex2rgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function mixc(h, t, k) { const a = hex2rgb(h), b = hex2rgb(t); return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * k).toString(16).padStart(2, '0')).join(''); }
// 단색 채우기를 위밝음·아래어두움 그라디언트로 바꿔요(조각마다 따로 음영)
function shadeFills(str, k, top = 0.25, bot = 0.2, skip = []) {
  const map = {};
  let defs = '';
  const out = str.replace(/fill="(#[0-9a-fA-F]{6})"/g, (m, col) => {
    const c = col.toLowerCase();
    if (skip.includes(c)) return m;
    if (!map[c]) {
      const gid = `${k}s${Object.keys(map).length}`;
      map[c] = gid;
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2=".22" y2="1"><stop offset="0" stop-color="${mixc(c, '#ffffff', top)}"/><stop offset=".55" stop-color="${c}"/><stop offset="1" stop-color="${mixc(c, '#2a1840', bot)}"/></linearGradient>`;
    }
    return `fill="url(#${map[c]})"`;
  });
  return { out, defs };
}
// 문서에 한 번 넣는 필터: 선화 외곽선, 머리카락 입체 음영
export const HER_DEFS = `<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
  <filter id="hline" x="-6%" y="-6%" width="112%" height="112%" color-interpolation-filters="sRGB">
    <feMorphology in="SourceAlpha" operator="dilate" radius="1.5" result="d"/>
    <feFlood flood-color="#3b1f48" flood-opacity=".92"/><feComposite in2="d" operator="in" result="l"/>
    <feMerge><feMergeNode in="l"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="hhair" x="-6%" y="-6%" width="112%" height="112%" color-interpolation-filters="sRGB">
    <feMorphology in="SourceAlpha" operator="dilate" radius="1.5" result="d"/>
    <feFlood flood-color="#3b1f48" flood-opacity=".92"/><feComposite in2="d" operator="in" result="l"/>
    <feOffset in="SourceAlpha" dx="0" dy="-9" result="o1"/><feGaussianBlur in="o1" stdDeviation="5" result="o1b"/>
    <feComposite in="SourceAlpha" in2="o1b" operator="out" result="m1"/>
    <feFlood flood-color="#3a1a5a" flood-opacity=".3"/><feComposite in2="m1" operator="in" result="sh"/>
    <feOffset in="SourceAlpha" dx="3" dy="5" result="o2"/><feGaussianBlur in="o2" stdDeviation="2.5" result="o2b"/>
    <feComposite in="SourceAlpha" in2="o2b" operator="out" result="m2"/>
    <feFlood flood-color="#ffffff" flood-opacity=".3"/><feComposite in2="m2" operator="in" result="rim"/>
    <feMerge><feMergeNode in="l"/><feMergeNode in="SourceGraphic"/><feMergeNode in="sh"/><feMergeNode in="rim"/></feMerge>
  </filter>
</defs></svg>`;

const STRANDS = (pal) => `<g fill="none" stroke="${pal.hairLine}" stroke-width="1.3" stroke-linecap="round" opacity=".45"><path d="M139 70C134 90 133 108 139 112M171 70C175 92 174 106 171 112M154 64C150 84 150 100 157 110M190 80C196 96 198 108 199 114M124 84C118 100 115 110 113 116"/></g>`;

export function heroineSVG(id, opt = {}) {
  const e = opt.e || 'normal';
  const outfit = opt.outfit || 'default';
  const pal = P[id];
  const k = 'h' + (++uid);
  let back = '', body = '', front = '', top = '', faceExtra = '';
  if (id === 'lyra') { back = lyraBack(pal, outfit); body = lyraOutfit(outfit); front = lyraFront(pal, outfit); top = lyraHat(outfit); }
  else if (id === 'mio') { back = mioBack(pal, outfit); body = mioOutfit(outfit); front = mioFront(pal, outfit); }
  else { back = serenBack(pal); body = serenOutfit(outfit); front = serenFront(pal, outfit); if (outfit === 'casual') faceExtra = glasses(); }
  const bangM = /<path[^>]*?\sd="(M1[0-9]{2} 1[0-9]{2}C[^"]+)"/.exec(front);
  const bangs = bangM ? bangM[1] : '';
  const skip = [SKIN.toLowerCase(), SKIN_SH.toLowerCase(), '#ffffff', '#fff'];
  const B = shadeFills(back, k + 'b', 0.28, 0.25);
  const Y = shadeFills(body, k + 'y', 0.2, 0.25, skip);
  const F = shadeFills(front + STRANDS(pal), k + 'f', 0.3, 0.18, ['#ffffff']);
  const T = shadeFills(top, k + 't', 0.25, 0.25, ['#ffffff']);
  const lid = `<path d="M109 172C109 149 157 145 158 166C158 191 114 197 109 172Z" fill="${SKIN}"/>${eye(k + 'bl', pal, 'blink')}`;
  const blinkLayer = e === 'happy' ? '' : `<g class="blink"><g>${lid}</g><g transform="translate(320 0) scale(-1 1)">${lid}</g></g>`;
  const ears = id === 'mio' ? '' : `<ellipse cx="104" cy="170" rx="8" ry="13" fill="${SKIN}"/><ellipse cx="216" cy="170" rx="8" ry="13" fill="${SKIN}"/><path d="M101 164C104 168 104 174 102 178M219 164C216 168 216 174 218 178" stroke="${SKIN_LINE}" stroke-width="1.4" fill="none" opacity=".7"/>`;
  const vb = opt.head ? '78 20 164 200' : '0 -20 320 450';
  const attrs = `viewBox="${vb}" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMax meet"`;
  return `<div class="heroine ${opt.cls || ''}"><div class="hl-back"><svg ${attrs}><defs>${B.defs}</defs><g filter="url(#hhair)">${B.out}</g></svg></div><svg class="hl-main" ${attrs}>
    <defs>${Y.defs}${F.defs}${T.defs}</defs>
    <g filter="url(#hline)">${Y.out}${NECK}</g>
    <g filter="url(#hline)">${ears}${face(k, pal, e, faceExtra, bangs)}${brow(e, pal)}${blinkLayer}</g>
    <g filter="url(#hhair)">${F.out}${T.out}</g>
  </svg></div>`;
}
