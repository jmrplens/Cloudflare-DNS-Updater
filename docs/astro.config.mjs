// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://jmrplens.github.io',
	base: '/Cloudflare-DNS-Updater',
	integrations: [
		starlight({
			title: 'Cloudflare DNS Updater',
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/jmrplens/Cloudflare-DNS-Updater',
				},
			],
			defaultLocale: 'root',
			locales: {
				root: { label: 'English', lang: 'en' },
				es: { label: 'Español', lang: 'es' },
			},
			editLink: {
				baseUrl: 'https://github.com/jmrplens/Cloudflare-DNS-Updater/edit/main/docs/',
			},
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
					items: [
						{ slug: 'development/testing' },
						{ slug: 'development/building' },
					],
				},
			],
		}),
	],
});
