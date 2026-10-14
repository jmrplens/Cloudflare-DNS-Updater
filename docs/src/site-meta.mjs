// Single source of truth for site URLs and JSON-LD @id anchors.
// Imported by astro.config.mjs, src/components/Head.astro and the
// scripts/ generators so the identifiers can never drift apart.
//
// docs.jmrp.io is the custom domain of the jmrplens.github.io user site, so
// GitHub Pages serves this project site under it, at the repository name as
// base path. That path is case-sensitive: keep it spelled exactly as the
// repository is.
export const siteUrl = 'https://docs.jmrp.io';
export const basePath = '/Cloudflare-DNS-Updater';
export const fullUrl = `${siteUrl}${basePath}`;
export const repositoryUrl = 'https://github.com/jmrplens/Cloudflare-DNS-Updater';
export const authorUrl = 'https://jmrp.io';

export const authorId = `${authorUrl}/#person`;
export const websiteId = `${fullUrl}/#website`;
export const softwareId = `${repositoryUrl}#software`;
export const sourceCodeId = `${repositoryUrl}#source-code`;
