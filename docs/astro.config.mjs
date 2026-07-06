// @ts-check
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';
import {
	siteUrl,
	basePath,
	fullUrl,
	repositoryUrl,
	authorUrl,
	authorId,
	websiteId,
	softwareId,
	sourceCodeId,
} from './src/site-meta.mjs';

// Single-sourced project version (the repo-root VERSION file also drives releases)
const version = readFileSync(new URL('../VERSION', import.meta.url), 'utf8').trim();

const releasesUrl = `${repositoryUrl}/releases`;
const socialImageUrl = `${fullUrl}/og-image.png`;
const siteDescription =
	'Open source dynamic DNS updater for Cloudflare: a single Bash program that keeps A and AAAA records pointed at your public IP, with batch API updates, IPv6-aware detection and notifications.';
const socialImageAlt =
	'Cloudflare DNS Updater keeps your Cloudflare DNS records pointed at your dynamic IP from a single Bash script';
const socialImage = {
	'@type': 'ImageObject',
	url: socialImageUrl,
	width: 1200,
	height: 630,
};

// Freshness signals for the SoftwareApplication node. `datePublished` is the
// first public release (v1.0.0) and is intentionally fixed. `dateModified`
// tracks the last repository change (HEAD commit date), falling back to build
// time only when git history is unavailable.
const datePublished = '2025-12-29';
const dateModified = (() => {
	try {
		return execFileSync('git', ['log', '-1', '--format=%cI'], {
			encoding: 'utf8',
		})
			.trim()
			.slice(0, 10);
	} catch {
		return new Date().toISOString().slice(0, 10);
	}
})();

// Human-readable capability list and requirements. These feed AI
// "what can it do?" and "what do I need?" queries directly from structured data.
const featureList = [
	'Updates Cloudflare A (IPv4) and AAAA (IPv6) DNS records with the current public IP',
	'Batch updates: all record changes pushed in a single Cloudflare API call, with automatic pagination for large zones',
	'Smart IPv6 detection: prefers the stable global address on the local interface, with external fallback services',
	'Per-domain configuration: proxy (orange cloud) toggle, TTL, IPv4/IPv6 selection, wildcard records',
	'Optional Telegram and Discord notifications on record changes',
	'Atomic locking (flock), log rotation, and secret redaction in debug output',
	'Runs anywhere Bash runs, plus standalone binaries bundling bash, curl and jq for Linux, macOS and Windows',
];
const softwareRequirements =
	'A Cloudflare zone and an API token with Edit zone DNS permission. From source: Bash 4+, curl and (recommended) jq. Standalone binaries have no dependencies beyond basic system tools.';

const jsonLd = JSON.stringify({
	'@context': 'https://schema.org',
	'@graph': [
		{
			// Mirrors the canonical Person node published at https://jmrp.io/#person
			// so AI engines and search graphs reconcile both into one entity.
			'@type': 'Person',
			'@id': authorId,
			name: 'José Manuel Requena Plens',
			alternateName: 'jmrplens',
			jobTitle: 'R&D Engineer',
			url: authorUrl,
			image: 'https://jmrp.io/_astro/mehome_landscape.Dg8oVd34.webp',
			worksFor: {
				'@type': 'Organization',
				name: 'Power Electronics',
				url: 'https://power-electronics.com/',
			},
			identifier: {
				'@type': 'PropertyValue',
				propertyID: 'ORCID',
				value: '0000-0003-1250-6212',
				url: 'https://orcid.org/0000-0003-1250-6212',
			},
			knowsAbout: ['DNS', 'Cloudflare', 'Bash', 'IPv6', 'Network Security', 'DevOps', 'Self-hosting'],
			sameAs: [
				'https://github.com/jmrplens',
				'https://www.linkedin.com/in/jmrplens',
				'https://mstdn.jmrp.io/@jmrplens',
				'https://matrix.to/#/@jmrplens:matrix.jmrp.io',
				'https://keyoxide.org/0A993B268654DBBA52B7E8D3FCF653391E2C91FC',
				'https://scholar.google.com/citations?user=9b0kPaUAAAAJ',
				'https://orcid.org/0000-0003-1250-6212',
				'https://www.researchgate.net/profile/Jose-Requena-Plens-2',
				'https://www.mathworks.com/matlabcentral/profile/authors/5890853',
			],
		},
		{
			'@type': 'WebSite',
			'@id': websiteId,
			name: 'Cloudflare DNS Updater',
			url: `${fullUrl}/`,
			description: siteDescription,
			inLanguage: ['en', 'es'],
			image: socialImage,
			publisher: { '@id': authorId },
			about: { '@id': softwareId },
		},
		{
			'@type': 'SoftwareApplication',
			'@id': softwareId,
			name: 'Cloudflare DNS Updater',
			softwareVersion: version,
			applicationCategory: 'UtilitiesApplication',
			applicationSubCategory: 'Networking',
			operatingSystem: 'Windows, Linux, macOS',
			programmingLanguage: 'Bash',
			url: repositoryUrl,
			downloadUrl: releasesUrl,
			codeRepository: repositoryUrl,
			image: socialImage,
			screenshot: socialImage,
			license: 'https://opensource.org/licenses/MIT',
			isAccessibleForFree: true,
			datePublished,
			dateModified,
			softwareRequirements,
			featureList,
			keywords:
				'dynamic DNS, DDNS, Cloudflare, Bash, DNS updater, IPv6, self-hosting, homelab',
			description:
				'Bash-based dynamic DNS updater that keeps Cloudflare A and AAAA records pointed at your current public IP.',
			offers: {
				'@type': 'Offer',
				price: '0',
				priceCurrency: 'USD',
			},
			author: { '@id': authorId },
		},
		{
			'@type': 'SoftwareSourceCode',
			'@id': sourceCodeId,
			name: 'Cloudflare DNS Updater source code',
			codeRepository: repositoryUrl,
			programmingLanguage: 'Bash',
			runtimePlatform: 'Windows, Linux, macOS',
			license: 'https://opensource.org/licenses/MIT',
			isPartOf: { '@id': softwareId },
			author: { '@id': authorId },
		},
	],
});

// https://astro.build/config
export default defineConfig({
	site: siteUrl,
	base: basePath,
	integrations: [
		starlight({
			title: 'Cloudflare DNS Updater',
			description: siteDescription,
			plugins: [
				starlightLinksValidator({
					errorOnRelativeLinks: false,
					errorOnFallbackPages: false,
				}),
			],
			components: {
				// Per-page structured data (TechArticle / BreadcrumbList) and
				// per-page Twitter card tags, layered on the default head.
				Head: './src/components/Head.astro',
				// Adds a human-visible maintainer block below the default footer,
				// corroborating the Person node in the site-wide @graph.
				Footer: './src/components/Footer.astro',
			},
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/jmrplens/Cloudflare-DNS-Updater',
				},
				{
					icon: 'mastodon',
					label: 'Mastodon',
					href: 'https://mstdn.jmrp.io/@jmrplens',
				},
				{
					icon: 'linkedin',
					label: 'LinkedIn',
					href: 'https://linkedin.com/in/jmrplens',
				},
			],
			head: [
				// Open Graph image
				{ tag: 'meta', attrs: { property: 'og:image', content: socialImageUrl } },
				{ tag: 'meta', attrs: { property: 'og:image:alt', content: socialImageAlt } },
				{ tag: 'meta', attrs: { property: 'og:image:type', content: 'image/png' } },
				{ tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
				{ tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
				// Twitter card
				{ tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
				{ tag: 'meta', attrs: { name: 'twitter:image', content: socialImageUrl } },
				{ tag: 'meta', attrs: { name: 'twitter:image:alt', content: socialImageAlt } },
				// Author
				{ tag: 'meta', attrs: { name: 'author', content: 'José Manuel Requena Plens' } },
				// Theme color
				{ tag: 'meta', attrs: { name: 'theme-color', content: '#F6821F' } },
				// rel="me" identity links (mirror of the Person sameAs set)
				{ tag: 'link', attrs: { rel: 'me', href: 'https://github.com/jmrplens' } },
				{ tag: 'link', attrs: { rel: 'me', href: 'https://www.linkedin.com/in/jmrplens' } },
				{ tag: 'link', attrs: { rel: 'me', href: 'https://mstdn.jmrp.io/@jmrplens' } },
				{ tag: 'link', attrs: { rel: 'me', href: 'https://orcid.org/0000-0003-1250-6212' } },
				{
					tag: 'link',
					attrs: {
						rel: 'me',
						href: 'https://www.researchgate.net/profile/Jose-Requena-Plens-2',
					},
				},
				{
					tag: 'link',
					attrs: {
						rel: 'me',
						href: 'https://scholar.google.com/citations?user=9b0kPaUAAAAJ',
					},
				},
				{
					tag: 'link',
					attrs: { rel: 'me', href: 'https://matrix.to/#/@jmrplens:matrix.jmrp.io' },
				},
				{
					tag: 'link',
					attrs: {
						rel: 'me',
						href: 'https://keyoxide.org/0A993B268654DBBA52B7E8D3FCF653391E2C91FC',
					},
				},
				{ tag: 'link', attrs: { rel: 'me', href: 'https://jmrp.io' } },
				// PGP public key
				{
					tag: 'link',
					attrs: {
						rel: 'pgpkey',
						type: 'application/pgp-keys',
						href: 'https://keys.openpgp.org/vks/v1/by-fingerprint/0A993B268654DBBA52B7E8D3FCF653391E2C91FC',
					},
				},
				// Web app manifest
				{ tag: 'link', attrs: { rel: 'manifest', href: `${basePath}/manifest.json` } },
				// Bing Webmaster Tools site verification
				{
					tag: 'meta',
					attrs: { name: 'msvalidate.01', content: '7574EB3B44624C239F14920DBC34EE25' },
				},
				// Google Search Console site verification
				{
					tag: 'meta',
					attrs: {
						name: 'google-site-verification',
						content: '4Hx_PJ1seU_BgKfWpo_FA7_Hkh7GeYVNrvnvzqCjF0Q',
					},
				},
				// JSON-LD structured data
				{ tag: 'script', attrs: { type: 'application/ld+json' }, content: jsonLd },
			],
			defaultLocale: 'root',
			locales: {
				root: { label: 'English', lang: 'en' },
				es: { label: 'Español', lang: 'es' },
			},
			editLink: {
				baseUrl: 'https://github.com/jmrplens/Cloudflare-DNS-Updater/edit/main/docs/',
			},
			lastUpdated: true,
			favicon: '/favicon.svg',
			sidebar: [
				{
					label: 'Start Here',
					translations: { es: 'Empieza aquí' },
					items: [
						{ slug: 'getting-started' },
						{ slug: 'installation' },
						{ slug: 'configuration' },
					],
				},
				{
					label: 'Usage',
					translations: { es: 'Uso' },
					items: [
						{ slug: 'cli' },
						{ slug: 'automation' },
						{ slug: 'notifications' },
						{ slug: 'troubleshooting' },
					],
				},
				{
					label: 'Development',
					translations: { es: 'Desarrollo' },
					items: [{ slug: 'development/testing' }, { slug: 'development/building' }],
				},
			],
		}),
	],
});
