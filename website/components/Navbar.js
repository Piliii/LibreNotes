'use client';

import { useState, useEffect } from 'react';
import { siGithub } from 'simple-icons';
import BrandIcon from './BrandIcon';

const LINKS = [
  { label: 'Screenshots', href: '#screenshots' },
  { label: 'Features', href: '#features' },
  { label: 'Demo', href: '#demo' },
  { label: 'Download', href: '#download' },
  { label: 'Server setup', href: '#server' },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 50);
    window.addEventListener('scroll', handler, { passive: true });
    return () => window.removeEventListener('scroll', handler);
  }, []);

  return (
    <nav
      className="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
      style={{
        background: scrolled ? 'rgba(26,26,26,0.9)' : 'transparent',
        backdropFilter: scrolled ? 'blur(14px)' : 'none',
        borderBottom: scrolled ? '1px solid #2a2a2a' : '1px solid transparent',
      }}
    >
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
        <a href="#hero" className="flex items-center gap-2">
          <img src="/icon.png" alt="LibreNotes" className="h-6 w-6 rounded-md" />
          <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
            LibreNotes
          </span>
        </a>

        <div className="hidden items-center gap-6 md:flex">
          {LINKS.map(l => (
            <a
              key={l.label}
              href={l.href}
              className="text-xs font-medium transition-colors hover:text-[#ff6900]"
              style={{ color: 'var(--text-secondary)' }}
            >
              {l.label}
            </a>
          ))}
        </div>

        <a
          href="https://github.com/Piliii/LibreNotes"
          target="_blank"
          rel="noopener noreferrer"
          className="transition-colors hover:text-[#ff6900]"
          style={{ color: 'var(--text-secondary)' }}
          aria-label="GitHub"
        >
          <BrandIcon icon={siGithub} size={17} />
        </a>
      </div>
    </nav>
  );
}
