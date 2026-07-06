import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

// Starlight's splash template disables the sidebar, and with it the mobile
// menu button — leaving phones with no way to navigate from the landing page.
// Re-enable the sidebar for splash pages only (other templates keep whatever
// they configured); src/styles/custom.css keeps the desktop splash layout
// full-width by hiding the sidebar pane on hero pages, so only the mobile
// menu button (drawer) is gained.
export const onRequest = defineRouteMiddleware((context) => {
	const { starlightRoute } = context.locals;
	if (starlightRoute.entry.data.template === 'splash') {
		starlightRoute.hasSidebar = true;
	}
});
