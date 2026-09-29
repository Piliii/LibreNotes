import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export const metadata = {
  title: 'Page not found - LibreNotes',
};

export default function NotFound() {
  return (
    <>
      <Navbar />
      <main
        className="flex min-h-screen flex-col items-center justify-center px-6 text-center"
        style={{ background: 'var(--bg-base)' }}
      >
        <h1 className="max-w-xl text-4xl font-bold tracking-tight sm:text-5xl" style={{ color: 'var(--text-primary)' }}>
          This note doesn&apos;t exist :/
        </h1>
        <p className="mt-4 max-w-md text-base" style={{ color: 'var(--text-secondary)' }}>
          The page you&apos;re looking for was either moved, deleted, or maybe it never existed in the first place ¯\(ツ)/¯
        </p>
        <a
          href="/"
          className="mt-8 rounded-lg bg-[#ff6900] px-7 py-3.5 text-base font-semibold text-white transition-all duration-300 hover:rounded-[26px] hover:bg-[#e55e00]"
        >
          Let's go back home
        </a>
      </main>
      <Footer />
    </>
  );
}
