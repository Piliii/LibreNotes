'use client';

import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

function buildComponents(textColor) {
  return {
    h3: ({ children }) => (
      <h4
        className="mb-1.5 mt-4 text-xs font-semibold uppercase tracking-widest first:mt-0"
        style={{ color: 'var(--accent)' }}
      >
        {children}
      </h4>
    ),
    p: ({ children }) => (
      <p className="text-sm leading-relaxed" style={{ color: textColor }}>
        {children}
      </p>
    ),
    ul: ({ children }) => (
      <ul className="mb-3 mt-1 space-y-1.5 pl-4" style={{ listStyleType: 'disc' }}>
        {children}
      </ul>
    ),
    li: ({ children }) => (
      <li className="text-sm leading-relaxed" style={{ color: textColor }}>
        {children}
      </li>
    ),
    strong: ({ children }) => (
      <strong style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{children}</strong>
    ),
    code: ({ children }) => (
      <code
        className="rounded px-1 py-0.5 text-xs"
        style={{ background: 'var(--bg-elevated)', color: 'var(--accent)', fontFamily: 'monospace' }}
      >
        {children}
      </code>
    ),
    a: ({ href, children }) => (
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className="underline hover:text-[#ff6900]"
        style={{ color: 'var(--text-primary)' }}
      >
        {children}
      </a>
    ),
  };
}

export default function ChangelogMarkdown({ children, emphasis = false }) {
  const components = buildComponents(emphasis ? 'var(--text-primary)' : 'var(--text-secondary)');
  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
      {children}
    </ReactMarkdown>
  );
}
