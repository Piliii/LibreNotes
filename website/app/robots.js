export const dynamic = 'force-static';

export default function robots() {
  return {
    rules: { userAgent: '*', allow: '/' },
    sitemap: 'https://librenotes.ayopili.com/sitemap.xml',
  };
}
