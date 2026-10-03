import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import DocsMarkdown from './DocsMarkdown';
import { groupedDocs } from '@/lib/docs';

function Sidebar({ current }) {
  return (
    <nav aria-label="Documentation" className="space-y-6">
      {groupedDocs().map((group) => (
        <div key={group.name}>
          <p
            className="mb-2 text-[10px] font-semibold uppercase tracking-widest"
            style={{ color: 'var(--text-secondary)', opacity: 0.6 }}
          >
            {group.name}
          </p>
          <ul className="space-y-0.5">
            {group.items.map((doc) => {
              const active = doc.slug === current;
              return (
                <li key={doc.slug}>
                  <a
                    href={`/docs/${doc.slug}`}
                    aria-current={active ? 'page' : undefined}
                    className="block rounded-lg px-3 py-1.5 text-sm transition-colors hover:text-[#ff6900]"
                    style={{
                      color: active ? 'var(--accent)' : 'var(--text-secondary)',
                      background: active ? 'var(--bg-surface)' : 'transparent',
                      fontWeight: active ? 600 : 400,
                    }}
                  >
                    {doc.title}
                  </a>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}

function PagerLink({ doc, label, align }) {
  if (!doc) return <span />;
  return (
    <a
      href={`/docs/${doc.slug}`}
      className="rounded-xl border px-4 py-3 transition-colors hover:border-[#ff6900]"
      style={{ borderColor: 'var(--border)', textAlign: align }}
    >
      <span className="block text-[11px]" style={{ color: 'var(--text-secondary)' }}>
        {label}
      </span>
      <span className="text-sm font-medium" style={{ color: 'var(--text-primary)' }}>
        {doc.title}
      </span>
    </a>
  );
}

export default function DocView({ doc }) {
  return (
    <>
      <Navbar />
      <main id="main" className="px-4 pb-24 pt-28 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
        <div className="mx-auto flex max-w-5xl flex-col gap-10 md:flex-row md:gap-14">
          <aside className="md:sticky md:top-24 md:h-fit md:w-52 md:shrink-0">
            <Sidebar current={doc.slug} />
          </aside>
          <article className="min-w-0 flex-1">
            <DocsMarkdown>{doc.body}</DocsMarkdown>
            <div className="mt-16 grid grid-cols-2 gap-4">
              <PagerLink doc={doc.prev} label="Previous" align="left" />
              <PagerLink doc={doc.next} label="Next" align="right" />
            </div>
          </article>
        </div>
      </main>
      <Footer />
    </>
  );
}
