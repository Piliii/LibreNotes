'use client';

import { useChangelog } from '@/lib/changelog';
import ChangelogMarkdown from '@/components/changelog/ChangelogMarkdown';

export default function ChangelogList() {
  const { loading, error, entries } = useChangelog();

  if (loading) {
    return (
      <div className="space-y-4">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="h-24 animate-pulse rounded-2xl"
            style={{ background: 'var(--bg-elevated)' }}
          />
        ))}
      </div>
    );
  }

  if (error || entries.length === 0) {
    return (
      <p className="text-center text-sm" style={{ color: 'var(--text-secondary)' }}>
        Couldn&apos;t load the changelog right now - see it directly on{' '}
        <a
          href="https://github.com/Piliii/LibreNotes/blob/main/CHANGELOG.md"
          target="_blank"
          rel="noopener noreferrer"
          className="underline hover:text-[#ff6900]"
        >
          GitHub
        </a>
        .
      </p>
    );
  }

  return (
    <div className="space-y-6">
      {entries.map((entry, i) => (
        <div
          key={entry.version}
          className="rounded-2xl border p-7"
          style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
        >
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <h2 className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>
              v{entry.version}
            </h2>
            {i === 0 && (
              <span
                className="rounded-full px-2 py-0.5 text-[10px] font-medium"
                style={{ background: '#2a1f0a', color: '#ff6900' }}
              >
                Latest
              </span>
            )}
            {entry.date && (
              <span className="text-xs" style={{ color: 'var(--text-secondary)', opacity: 0.7 }}>
                {entry.date}
              </span>
            )}
          </div>
          <ChangelogMarkdown emphasis>{entry.body}</ChangelogMarkdown>
        </div>
      ))}
    </div>
  );
}
