export default function SectionDivider() {
  return (
    <div aria-hidden="true" className="relative h-px w-full overflow-visible">
      <div
        className="absolute inset-0"
        style={{
          background:
            'linear-gradient(90deg, transparent 0%, var(--border) 20%, var(--border) 80%, transparent 100%)',
        }}
      />
      <div
        className="absolute left-1/2 top-1/2 h-1.5 w-1.5 -translate-x-1/2 -translate-y-1/2 rotate-45"
        style={{
          background: 'var(--accent)',
          boxShadow: '0 0 12px 1px rgba(255, 105, 0, 0.55)',
        }}
      />
    </div>
  );
}
