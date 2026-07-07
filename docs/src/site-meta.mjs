// Single source of truth for site URLs and JSON-LD @id anchors.
// Imported by astro.config.mjs, src/components/Head.astro and the
// scripts/ generators so the identifiers can never drift apart.
export const siteUrl = 'https://jmrplens.github.io';
export const basePath = '/Cloudflare-DNS-Updater';
export const fullUrl = `${siteUrl}${basePath}`;
export const repositoryUrl = 'https://github.com/jmrplens/Cloudflare-DNS-Updater';
export const authorUrl = 'https://jmrp.io';

export const authorId = `${authorUrl}/#person`;
export const websiteId = `${fullUrl}/#website`;
export const softwareId = `${repositoryUrl}#software`;
export const sourceCodeId = `${repositoryUrl}#source-code`;
// Project-as-Organization node: gives the docs/site a publisher entity distinct
// from the individual maintainer (Person). Google's Article guidelines prefer an
// Organization publisher with a logo, and it gives AI engines a project entity to
// attach to alongside the author.
export const organizationId = `${fullUrl}/#project`;
