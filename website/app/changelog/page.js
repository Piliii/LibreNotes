import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import ChangelogList from './ChangelogList';

export const metadata = {
  title: 'Changelog - LibreNotes',
  alternates: { canonical: '/changelog' },
  description: 'What shipped in every LibreNotes release, from v1.0 to today.',
};

export default function ChangelogPage() {
  return (
    <>
      <Navbar />
      <main id="main" className="px-4 pb-24 pt-32 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
        <div className="mx-auto max-w-3xl">
          <div className="mb-14 text-center">
            <h1 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
              Changelog
            </h1>
            <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
              What shipped in every release, from v1.0 to today.
            </p>
          </div>
          <ChangelogList />
        </div>
      </main>
      <Footer />
    </>
  );
}
