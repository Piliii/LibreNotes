import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

const components = {
  h1: ({ children }) => (
    <h1 className="text-3xl font-bold tracking-tight" style={{ color: 'var(--text-primary)' }}>
      {children}
    </h1>
  ),
  h2: ({ children }) => (
    <h2 className="mb-3 mt-12 text-xl font-semibold tracking-tight" style={{ color: 'var(--text-primary)' }}>
      {children}
    </h2>
  ),
  h3: ({ children }) => (
    <h3 className="mb-2 mt-8 text-base font-semibold" style={{ color: 'var(--text-primary)' }}>
      {children}
    </h3>
  ),
  p: ({ children }) => (
    <p className="mt-3 text-[15px] leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
      {children}
    </p>
  ),
  ul: ({ children }) => <ul className="mt-3 list-disc space-y-1.5 pl-5">{children}</ul>,
  ol: ({ children }) => <ol className="mt-3 list-decimal space-y-1.5 pl-5">{children}</ol>,
  li: ({ children }) => (
    <li className="text-[15px] leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
      {children}
    </li>
  ),
  strong: ({ children }) => <strong style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{children}</strong>,
  blockquote: ({ children }) => (
    <blockquote
      className="mt-4 rounded-r-lg border-l-2 py-1 pl-4"
      style={{ borderColor: 'var(--accent)', background: 'var(--bg-surface)' }}
    >
      {children}
    </blockquote>
  ),
  pre: ({ children }) => (
    <pre
      className="mt-4 overflow-x-auto rounded-xl border p-4 text-[13px] leading-relaxed"
      style={{ background: 'var(--bg-surface)', borderColor: 'var(--border)', color: 'var(--text-primary)' }}
    >
      {children}
    </pre>
  ),
  // Inline code gets the orange chip; code inside <pre> (has a language class
  // or a newline) stays plain.
  code: ({ className, children }) => {
    const block = Boolean(className) || String(children).includes('\n');
    if (block) return <code style={{ fontFamily: 'monospace' }}>{children}</code>;
    return (
      <code
        className="rounded px-1 py-0.5 text-[13px]"
        style={{ background: 'var(--bg-elevated)', color: 'var(--accent)', fontFamily: 'monospace' }}
      >
        {children}
      </code>
    );
  },
  a: ({ href = '', children }) => {
    const external = /^https?:\/\//.test(href);
    return (
      <a
        href={href}
        {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
        className="underline underline-offset-2 hover:text-[#ff6900]"
        style={{ color: 'var(--text-primary)' }}
      >
        {children}
      </a>
    );
  },
  table: ({ children }) => (
    <div className="mt-4 overflow-x-auto">
      <table className="w-full border-collapse text-left text-sm">{children}</table>
    </div>
  ),
  th: ({ children }) => (
    <th className="border-b px-3 py-2 font-semibold" style={{ borderColor: 'var(--border)', color: 'var(--text-primary)' }}>
      {children}
    </th>
  ),
  td: ({ children }) => (
    <td className="border-b px-3 py-2" style={{ borderColor: 'var(--border)', color: 'var(--text-secondary)' }}>
      {children}
    </td>
  ),
};

export default function DocsMarkdown({ children }) {
  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
      {children}
    </ReactMarkdown>
  );
}
