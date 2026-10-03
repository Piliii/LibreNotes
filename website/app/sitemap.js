import { DOCS } from '@/lib/docs';

export const dynamic = 'force-static';

const BASE = 'https://librenotes.ayopili.com';

export default function sitemap() {
  const routes = ['', '/docs', '/changelog', '/privacy'];
  const docs = DOCS.filter((d) => d.slug !== 'introduction').map((d) => `/docs/${d.slug}`);
  return [...routes, ...docs].map((route) => ({
    url: `${BASE}${route}`,
    changeFrequency: route === '' || route === '/changelog' ? 'weekly' : 'monthly',
  }));
}
