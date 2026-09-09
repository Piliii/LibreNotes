import { siGithub, siFdroid } from 'simple-icons';
import BrandIcon from './BrandIcon';

const LINKS = [
  { label: 'GitHub', href: 'https://github.com/Piliii/LibreNotes', external: true },
  { label: 'F-Droid', href: 'https://f-droid.org/en/packages/dev.librenotes.app/', external: true },
  { label: 'AGPLv3 license', href: 'https://github.com/Piliii/LibreNotes/blob/main/LICENSE', external: true },
];

const NAV = [
  { label: 'Screenshots', href: '#screenshots' },
  { label: 'Features', href: '#features' },
  { label: 'Demo', href: '#demo' },
  { label: 'Download', href: '#download' },
  { label: 'Server setup', href: '#server' },
];

export default function Footer() {
  return (
    <footer className="border-t px-4 py-12 sm:px-6 lg:px-8" style={{ background: 'var(--bg-surface)', borderColor: 'var(--border)' }}>
      <div className="mx-auto max-w-5xl">
        <div className="flex flex-col gap-10 sm:flex-row sm:justify-between">
          {/* Brand */}
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-2">
              <img src="/icon.png" alt="LibreNotes" className="h-7 w-7 rounded-md" />
              <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>LibreNotes</span>
            </div>
            <p className="max-w-xs text-xs leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
              Private, offline-first notes with end-to-end encryption, synced to your own server.
            </p>
            <div className="flex items-center gap-3 mt-1">
              <a
                href="https://github.com/Piliii/LibreNotes"
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-[#ff6900]"
                style={{ color: 'var(--text-secondary)' }}
                aria-label="GitHub"
              >
                <BrandIcon icon={siGithub} size={16} />
              </a>
              <a
                href="https://f-droid.org/en/packages/dev.librenotes.app/"
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-[#ff6900]"
                style={{ color: 'var(--text-secondary)' }}
                aria-label="F-Droid"
              >
                <BrandIcon icon={siFdroid} size={16} />
              </a>
            </div>
          </div>

          <div className="flex gap-16">
            {/* Page links */}
            <div className="flex flex-col gap-2">
              <p className="mb-1 text-[10px] font-semibold uppercase tracking-widest" style={{ color: 'var(--text-secondary)', opacity: 0.5 }}>
                Navigation
              </p>
              {NAV.map(l => (
                <a
                  key={l.label}
                  href={l.href}
                  className="text-xs transition-colors hover:text-[#ff6900]"
                  style={{ color: 'var(--text-secondary)' }}
                >
                  {l.label}
                </a>
              ))}
            </div>

            {/* External links */}
            <div className="flex flex-col gap-2">
              <p className="mb-1 text-[10px] font-semibold uppercase tracking-widest" style={{ color: 'var(--text-secondary)', opacity: 0.5 }}>
                Project
              </p>
              {LINKS.map(l => (
                <a
                  key={l.label}
                  href={l.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs transition-colors hover:text-[#ff6900]"
                  style={{ color: 'var(--text-secondary)' }}
                >
                  {l.label}
                </a>
              ))}
            </div>
          </div>
        </div>

        <div className="mt-10 border-t pt-6" style={{ borderColor: 'var(--border)' }}>
          <p className="text-center text-[11px]" style={{ color: 'var(--text-secondary)', opacity: 0.5 }}>
            LibreNotes is free and open source software, licensed under the AGPLv3.
          </p>
        </div>
      </div>
    </footer>
  );
}
