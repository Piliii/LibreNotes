'use client';

import { Sparkles } from 'lucide-react';
import { useChangelog } from '@/lib/changelog';
import ChangelogMarkdown from './ChangelogMarkdown';

export default function WhatsNewSection() {
  const { loading, error, entries } = useChangelog();
  const latest = entries[0];

  if (!loading && (error || !latest)) return null;

  return (
    <section id="whats-new" className="px-4 py-24 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
      <div className="mx-auto max-w-3xl">
        <div className="mb-10 text-center">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-[#ff6900] px-4 py-1.5 text-xs font-medium text-[#ff6900]">
            <Sparkles size={13} />
            {loading ? 'Checking latest release…' : `What's new in v${latest.version}`}
          </div>
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Actively developed
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            LibreNotes ships regularly. Here's what changed most recently.
          </p>
        </div>

        <div
          className="rounded-2xl border p-7"
          style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
        >
          {loading ? (
            <div className="space-y-3">
              <div className="h-3 w-1/3 animate-pulse rounded" style={{ background: 'var(--border)' }} />
              <div className="h-3 w-full animate-pulse rounded" style={{ background: 'var(--border)' }} />
              <div className="h-3 w-5/6 animate-pulse rounded" style={{ background: 'var(--border)' }} />
            </div>
          ) : (
            <>
              {latest.date && (
                <p className="mb-3 text-xs" style={{ color: 'var(--text-secondary)', opacity: 0.7 }}>
                  Released {latest.date}
                </p>
              )}
              <ChangelogMarkdown>{latest.body}</ChangelogMarkdown>
            </>
          )}
        </div>

        <p className="mt-6 text-center text-xs">
          <a href="/changelog" className="underline hover:text-[#ff6900]" style={{ color: 'var(--text-secondary)' }}>
            View full changelog →
          </a>
        </p>
      </div>
    </section>
  );
}
