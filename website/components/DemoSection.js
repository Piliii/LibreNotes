import { Info } from 'lucide-react';
import NotesDemoApp from './demo/NotesDemoApp';

export default function DemoSection() {
  return (
    <section id="demo" className="px-4 py-20 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
      <div className="mx-auto max-w-5xl">
        {/* Heading */}
        <div className="mb-10 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Want to try it yourself?
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            A browser version of the app. Notes stay in your browser - nothing is sent anywhere.
          </p>
        </div>

        {/* Demo frame */}
        <div
          className="relative overflow-hidden rounded-2xl border"
          style={{ borderColor: 'var(--border)', background: 'var(--bg-surface)', height: 560 }}
        >
          {/* Sticky demo banner */}
          <div
            className="flex items-center justify-center gap-2 border-b px-4 py-2 text-xs font-medium"
            style={{
              borderColor: 'var(--border)',
              background: 'var(--bg-elevated)',
              color: 'var(--text-secondary)',
            }}
          >
            <Info size={13} style={{ color: 'var(--accent)' }} />
            Demo mode - notes are not synced and live only in your browser.
          </div>

          {/* App */}
          <div style={{ height: 'calc(100% - 33px)' }}>
            <NotesDemoApp />
          </div>
        </div>

        {/* Caption */}
        <p className="mt-4 text-center text-xs" style={{ color: 'var(--text-secondary)' }}>
          The real app syncs to your own server with end-to-end encryption.{' '}
          <a href="#download" className="underline hover:text-[#ff6900]">
            Download it →
          </a>
        </p>
      </div>
    </section>
  );
}
