'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';

const S = {
  h1: { color: '#f0f0f0', fontSize: '1.5rem', fontWeight: 700, margin: '0.8em 0 0.4em', lineHeight: 1.3 },
  h2: { color: '#f0f0f0', fontSize: '1.25rem', fontWeight: 600, margin: '0.8em 0 0.35em', lineHeight: 1.3 },
  h3: { color: '#f0f0f0', fontSize: '1.1rem', fontWeight: 600, margin: '0.7em 0 0.3em', lineHeight: 1.3 },
  p:  { color: '#f0f0f0', margin: '0.5em 0', lineHeight: 1.7 },
  ul: { margin: '0.4em 0', paddingLeft: '1.4em', listStyleType: 'disc' },
  ol: { margin: '0.4em 0', paddingLeft: '1.4em', listStyleType: 'decimal' },
  li: { color: '#f0f0f0', margin: '0.15em 0', lineHeight: 1.6 },
  hr: { border: 'none', borderTop: '1px solid #333333', margin: '1.25em 0' },
  blockquote: { borderLeft: '3px solid #ff6900', paddingLeft: '0.9em', margin: '0.75em 0', color: '#a0a0a0', fontStyle: 'italic' },
  inlineCode: { background: '#1a1a1a', color: '#ff6900', padding: '0.1em 0.35em', borderRadius: '3px', fontSize: '0.85em', fontFamily: 'monospace' },
  a: { color: '#60a5fa', textDecoration: 'underline' },
  strong: { color: '#f0f0f0', fontWeight: 600 },
  em: { color: '#f0f0f0', fontStyle: 'italic' },
  del: { color: '#a0a0a0', textDecoration: 'line-through' },
};

function MarkdownPre({ children }) {
  const codeEl = Array.isArray(children) ? children[0] : children;
  const className = codeEl?.props?.className || '';
  const match = /language-(\w+)/.exec(className);
  const code = String(codeEl?.props?.children || '').replace(/\n$/, '');

  if (match) {
    return (
      <SyntaxHighlighter
        language={match[1]}
        style={vscDarkPlus}
        customStyle={{ margin: '0.75em 0', borderRadius: '6px', fontSize: '0.82em', padding: '1em' }}
        codeTagProps={{ style: { fontFamily: 'monospace' } }}
      >
        {code}
      </SyntaxHighlighter>
    );
  }

  return (
    <pre style={{ background: '#1a1a1a', padding: '0.9em 1em', borderRadius: '6px', margin: '0.75em 0', overflowX: 'auto', fontSize: '0.82em', fontFamily: 'monospace', color: '#f0f0f0' }}>
      <code>{code}</code>
    </pre>
  );
}

const mdComponents = {
  h1: ({ children }) => <h1 style={S.h1}>{children}</h1>,
  h2: ({ children }) => <h2 style={S.h2}>{children}</h2>,
  h3: ({ children }) => <h3 style={S.h3}>{children}</h3>,
  p:  ({ children }) => <p style={S.p}>{children}</p>,
  ul: ({ children }) => <ul style={S.ul}>{children}</ul>,
  ol: ({ children }) => <ol style={S.ol}>{children}</ol>,
  li: ({ children }) => <li style={S.li}>{children}</li>,
  hr: () => <hr style={S.hr} />,
  blockquote: ({ children }) => <blockquote style={S.blockquote}>{children}</blockquote>,
  strong: ({ children }) => <strong style={S.strong}>{children}</strong>,
  em: ({ children }) => <em style={S.em}>{children}</em>,
  del: ({ children }) => <del style={S.del}>{children}</del>,
  a: ({ href, children }) => <a href={href} target="_blank" rel="noopener noreferrer" style={S.a}>{children}</a>,
  pre: MarkdownPre,
  code: ({ children, className }) => {
    if (className) return <code className={className}>{children}</code>;
    return <code style={S.inlineCode}>{children}</code>;
  },
  input: ({ type, checked }) => {
    if (type === 'checkbox') {
      return <input type="checkbox" checked={checked} readOnly style={{ marginRight: '0.4em', accentColor: '#ff6900', verticalAlign: 'middle' }} />;
    }
    return <input type={type} />;
  },
};

export default function NoteEditor({ note, onUpdate, onDelete, onBack }) {
  const [tab, setTab] = useState('write');
  const [title, setTitle] = useState(note?.title ?? '');
  const [body, setBody] = useState(note?.body ?? '');
  const saveTimer = useRef(null);

  useEffect(() => {
    setTitle(note?.title ?? '');
    setBody(note?.body ?? '');
    setTab('write');
  }, [note?.id]);

  const flush = useCallback((t, b) => {
    if (!note) return;
    onUpdate(note.id, { title: t, body: b });
  }, [note, onUpdate]);

  function handleTitle(e) {
    const t = e.target.value;
    setTitle(t);
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => flush(t, body), 500);
  }

  function handleBody(e) {
    const b = e.target.value;
    setBody(b);
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => flush(title, b), 500);
  }

  if (!note) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>
          Select a note or create one
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden" style={{ background: 'var(--bg-base)' }}>
      {/* Toolbar */}
      <div
        className="flex items-center justify-between gap-3 border-b px-4 py-2"
        style={{ borderColor: 'var(--border)' }}
      >
        {onBack && (
          <button
            onClick={onBack}
            className="flex items-center gap-1 text-sm md:hidden"
            style={{ color: 'var(--text-secondary)' }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M10 3L5 8l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Notes
          </button>
        )}

        <div
          className="flex rounded-md overflow-hidden text-xs font-medium"
          style={{ background: 'var(--bg-surface)' }}
        >
          {['write', 'preview'].map(t => (
            <button
              key={t}
              onClick={() => { if (t !== 'write') flush(title, body); setTab(t); }}
              className="px-3 py-1.5 capitalize transition-colors"
              style={{
                background: tab === t ? 'var(--accent)' : 'transparent',
                color: tab === t ? '#fff' : 'var(--text-secondary)',
              }}
            >
              {t}
            </button>
          ))}
        </div>

        <button
          onClick={() => onDelete(note.id)}
          className="ml-auto rounded p-1.5 transition-colors hover:text-red-400"
          style={{ color: 'var(--text-secondary)' }}
          title="Delete note"
        >
          <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
            <path d="M2 4h11M5 4V2.5A.5.5 0 0 1 5.5 2h4a.5.5 0 0 1 .5.5V4M6 7v4M9 7v4M3 4l.8 8.1A1 1 0 0 0 4.8 13h5.4a1 1 0 0 0 1-.9L12 4"
              stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
      </div>

      {/* Content */}
      <div className="flex flex-1 flex-col overflow-hidden p-4 gap-3">
        {tab === 'write' ? (
          <>
            <input
              className="w-full bg-transparent text-xl font-bold outline-none placeholder:opacity-40"
              style={{ color: 'var(--text-primary)' }}
              placeholder="Title"
              value={title}
              onChange={handleTitle}
            />
            <textarea
              className="flex-1 w-full resize-none bg-transparent text-sm leading-relaxed outline-none placeholder:opacity-30"
              style={{ color: 'var(--text-primary)' }}
              placeholder="Write in markdown..."
              value={body}
              onChange={handleBody}
            />
          </>
        ) : (
          <div className="flex-1 overflow-y-auto">
            {title && (
              <h1 className="mb-4 text-xl font-bold" style={{ color: 'var(--text-primary)' }}>
                {title}
              </h1>
            )}
            {body ? (
              <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdComponents}>
                {body}
              </ReactMarkdown>
            ) : (
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Nothing to preview yet.</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
