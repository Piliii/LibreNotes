const SCREENSHOTS = [
  { src: '/screenshots/1.jpg', label: 'Notes list' },
  { src: '/screenshots/2.jpg', label: 'Note editor' },
  { src: '/screenshots/3.jpg', label: 'Sync settings' },
];

function Phone({ src, label }) {
  return (
    <div className="flex flex-col items-center gap-3 shrink-0 group">
      <div
        className="overflow-hidden rounded-[2.5rem] border-[5px] transition-transform duration-300 group-hover:scale-[1.03]"
        style={{
          borderColor: '#2e2e2e',
          boxShadow: '0 24px 60px rgba(0,0,0,0.6)',
          width: 200,
        }}
      >
        <img
          src={src}
          alt={label}
          style={{ display: 'block', width: '100%' }}
        />
      </div>
      <span
        className="text-xs font-medium transition-colors duration-200 group-hover:text-[#ff6900]"
        style={{ color: 'var(--text-secondary)' }}
      >
        {label}
      </span>
    </div>
  );
}

export default function ScreenshotsSection() {
  return (
    <section id="screenshots" className="py-20" style={{ background: 'var(--bg-surface)' }}>
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
        <div className="mb-12 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Clean, fast, private
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Works on Android and Linux. No account needed to get started.
          </p>
        </div>
      </div>

      {/* Scroll container — full bleed so padding doesn't clip the overflow */}
      <div className="overflow-x-auto pb-4">
        <div className="flex gap-8 sm:gap-12 px-8 sm:justify-center sm:px-0" style={{ width: 'max-content', margin: '0 auto' }}>
          {SCREENSHOTS.map(s => (
            <Phone key={s.src} {...s} />
          ))}
        </div>
      </div>
    </section>
  );
}
