'use client';

import { useEffect, useState } from 'react';
import { X, Sparkles } from 'lucide-react';
import { useChangelog } from '@/lib/changelog';
import ChangelogMarkdown from './ChangelogMarkdown';

const STORAGE_KEY = 'librenotes-last-seen-version';
const TRANSITION_MS = 200;

export default function WhatsNewModal() {
  const { loading, error, entries } = useChangelog();
  // closed -> opening (mounted, pre-transition styles) -> open (transitioned in) -> closing (transitioning out) -> closed
  const [phase, setPhase] = useState('closed');
  const latest = entries[0];

  useEffect(() => {
    if (loading || error || !latest) return;
    let lastSeen;
    try {
      lastSeen = window.localStorage.getItem(STORAGE_KEY);
    } catch {
      return;
    }
    if (lastSeen === null) {
      // First-time visitor: nothing is "new" to them. Record the current
      // version so only future releases trigger the popup.
      try {
        window.localStorage.setItem(STORAGE_KEY, latest.version);
      } catch {
        // best-effort only
      }
      return;
    }
    if (lastSeen !== latest.version) setPhase('opening');
  }, [loading, error, latest]);

  useEffect(() => {
    if (phase !== 'opening') return;
    const raf = requestAnimationFrame(() => setPhase('open'));
    return () => cancelAnimationFrame(raf);
  }, [phase]);

  useEffect(() => {
    if (phase === 'closed') return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [phase]);

  function dismiss() {
    setPhase('closing');
    try {
      window.localStorage.setItem(STORAGE_KEY, latest.version);
    } catch {
      // best-effort only
    }
    setTimeout(() => setPhase('closed'), TRANSITION_MS);
  }

  if (phase === 'closed' || !latest) return null;

  const shown = phase === 'open';

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 px-4 transition-opacity"
      style={{ transitionDuration: `${TRANSITION_MS}ms`, opacity: shown ? 1 : 0 }}
      onClick={dismiss}
    >
      <div
        className="max-h-[80vh] w-full max-w-md overflow-y-auto rounded-2xl border p-6 transition-all"
        style={{
          background: 'var(--bg-elevated)',
          borderColor: 'var(--border)',
          transitionDuration: `${TRANSITION_MS}ms`,
          transitionTimingFunction: shown ? 'cubic-bezier(0.16, 1, 0.3, 1)' : 'ease-in',
          opacity: shown ? 1 : 0,
          transform: shown ? 'scale(1) translateY(0)' : 'scale(0.94) translateY(10px)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-start justify-between gap-4">
          <div className="inline-flex items-center gap-2 rounded-full border border-[#ff6900] px-3 py-1 text-xs font-medium text-[#ff6900]">
            <Sparkles size={13} />
            New in v{latest.version}
          </div>
          <button onClick={dismiss} aria-label="Dismiss" style={{ color: 'var(--text-secondary)' }}>
            <X size={18} />
          </button>
        </div>

        <ChangelogMarkdown emphasis>{latest.body}</ChangelogMarkdown>

        <div className="mt-5 flex items-center justify-between">
          <a
            href="/changelog"
            className="text-xs underline hover:text-[#ff6900]"
            style={{ color: 'var(--text-secondary)' }}
          >
            Full changelog →
          </a>
          <button
            onClick={dismiss}
            className="rounded-lg bg-[#ff6900] px-4 py-2 text-xs font-semibold text-white transition-all duration-300 hover:rounded-[16px] hover:bg-[#e55e00]"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  );
}
