import DocView from '@/components/docs/DocView';
import { getDoc } from '@/lib/docs';

export const metadata = {
  title: 'Documentation - LibreNotes',
  alternates: { canonical: '/docs' },
  description: 'Guides for installing LibreNotes, setting up sync, and understanding how your notes stay private.',
};

export default function DocsIndexPage() {
  return <DocView doc={getDoc('introduction')} />;
}
