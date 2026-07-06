import { defineRouteMiddleware } from "@astrojs/starlight/route-data";

// Starlight's splash template disables the sidebar, and with it the mobile
// menu button — leaving phones with no way to navigate from the landing page.
// Enable the sidebar everywhere; src/styles/custom.css keeps the desktop
// splash layout full-width by hiding the sidebar pane on hero pages, so only
// the mobile menu button (drawer) is gained.
export const onRequest = defineRouteMiddleware((context) => {
	context.locals.starlightRoute.hasSidebar = true;
});
