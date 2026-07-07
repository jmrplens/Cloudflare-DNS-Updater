// One-off generator for public/og-image.png (1200x630 social card).
// Run manually when the branding changes: node scripts/gen-og-image.mjs
// The mark below mirrors src/assets/logo-dark.svg (dark-variant node colour
// for contrast on the dark card); keep them in sync if the logo changes.
import sharp from "sharp";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "public", "og-image.png");

// Project logo mark (512-unit viewBox), placed on the right of the card.
const mark = `
  <g fill="none" stroke="#F6821F" stroke-width="30">
    <path d="M 294.82 111.11 A 150 150 0 0 1 294.82 400.89"/>
    <path d="M 217.18 400.89 A 150 150 0 0 1 217.18 111.11"/>
  </g>
  <path d="M 261.98 409.69 L 310.31 427.8 L 294.79 369.84 Z" fill="#F6821F"/>
  <path d="M 250.02 102.31 L 201.69 84.2 L 217.21 142.16 Z" fill="#F6821F"/>
  <rect x="249" y="298.12" width="14" height="61.88" rx="7" fill="#4C9AFF"/>
  <circle cx="256" cy="356" r="24" fill="#4C9AFF"/>
  <g transform="translate(134.78 127.32) scale(7.6)">
    <path d="M25.5 13.1a7.5 7.5 0 0 0-14.6-1.9A6 6 0 0 0 6 23h18.5a5 5 0 0 0 1-9.9z" fill="#F6821F"/>
  </g>`;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#17110B"/>
      <stop offset="1" stop-color="#2B1C0E"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect x="0" y="0" width="1200" height="8" fill="#F6821F"/>
  <g transform="translate(800 143) scale(0.68)">${mark}</g>
  <text x="88" y="240" font-family="DejaVu Sans, Arial, sans-serif" font-size="62" font-weight="bold" fill="#FFFFFF">Cloudflare DNS</text>
  <text x="88" y="312" font-family="DejaVu Sans, Arial, sans-serif" font-size="62" font-weight="bold" fill="#FFFFFF">Updater</text>
  <text x="88" y="372" font-family="DejaVu Sans, Arial, sans-serif" font-size="28" fill="#E8DDD1">Dynamic DNS for Cloudflare in a single Bash script</text>
  <text x="88" y="478" font-family="DejaVu Sans, Arial, sans-serif" font-size="25" fill="#C9BBA8">A + AAAA records · batch API updates · IPv6-aware · notifications</text>
  <text x="88" y="560" font-family="DejaVu Sans Mono, monospace" font-size="23" fill="#F6821F">github.com/jmrplens/Cloudflare-DNS-Updater</text>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile(out);
console.log(`[gen-og-image] wrote ${out}`);
