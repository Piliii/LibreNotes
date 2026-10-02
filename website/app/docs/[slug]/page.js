import { notFound } from 'next/navigation';
import DocView from '@/components/docs/DocView';
import { DOCS, getDoc } from '@/lib/docs';

// Static export: only the slugs listed here exist.
export const dynamicParams = false;

export function generateStaticParams() {
  return DOCS.map((d) => ({ slug: d.slug }));
}

export async function generateMetadata({ params }) {
  const { slug } = await params;
  const doc = getDoc(slug);
  return doc ? { title: `${doc.title} - LibreNotes Docs` } : {};
}

export default async function DocPage({ params }) {
  const { slug } = await params;
  const doc = getDoc(slug);
  if (!doc) notFound();
  return <DocView doc={doc} />;
}
