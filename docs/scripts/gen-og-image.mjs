// One-off generator for public/og-image.png (1200x630 social card).
// Run manually when the branding changes: node scripts/gen-og-image.mjs
import sharp from "sharp";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "public", "og-image.png");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#17110B"/>
      <stop offset="1" stop-color="#2B1C0E"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect x="0" y="0" width="1200" height="8" fill="#F6821F"/>
  <g transform="translate(88 150) scale(5.2)">
    <path fill="#f6821f" d="M25.5 13.1a7.5 7.5 0 0 0-14.6-1.9A6 6 0 0 0 6 23h18.5a5 5 0 0 0 1-9.9z"/>
    <circle cx="12" cy="26.5" r="1.5" fill="#4693ff"/>
    <circle cx="16" cy="26.5" r="1.5" fill="#4693ff"/>
    <circle cx="20" cy="26.5" r="1.5" fill="#4693ff"/>
  </g>
  <text x="300" y="255" font-family="DejaVu Sans, Arial, sans-serif" font-size="64" font-weight="bold" fill="#FFFFFF">Cloudflare DNS Updater</text>
  <text x="300" y="330" font-family="DejaVu Sans, Arial, sans-serif" font-size="30" fill="#E8DDD1">Dynamic DNS for Cloudflare in a single Bash script</text>
  <text x="88" y="480" font-family="DejaVu Sans, Arial, sans-serif" font-size="26" fill="#C9BBA8">A + AAAA records · batch API updates · IPv6-aware · notifications</text>
  <text x="88" y="560" font-family="DejaVu Sans Mono, monospace" font-size="24" fill="#F6821F">github.com/jmrplens/Cloudflare-DNS-Updater</text>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile(out);
console.log(`[gen-og-image] wrote ${out}`);
