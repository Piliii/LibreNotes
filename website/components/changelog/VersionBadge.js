'use client';

import { useChangelog } from '@/lib/changelog';

export default function VersionBadge() {
  const { loading, error, entries } = useChangelog();
  const latest = entries[0];

  if (loading || error || !latest) return null;

  return (
    <a
      href="/changelog"
      className="hidden items-center rounded-full border px-2.5 py-1 text-[11px] font-medium transition-colors hover:border-[#ff6900] hover:text-[#ff6900] sm:inline-flex"
      style={{ borderColor: 'var(--border)', color: 'var(--text-secondary)' }}
      title="See what's new"
    >
      v{latest.version}
    </a>
  );
}
