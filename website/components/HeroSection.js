export default function HeroSection() {
  return (
    <section
      id="hero"
      className="relative flex flex-col items-center justify-center min-h-screen px-6 pt-16 text-center"
    >
      {/* Badge */}
      <div className="mb-8 inline-flex items-center gap-2 rounded-full border border-[#ff6900] px-4 py-1.5 text-sm font-medium text-[#ff6900]">
        <span className="h-2 w-2 rounded-full bg-[#ff6900]" />
        Free & open source · AGPLv3
      </div>

      {/* Headline */}
      <h1 className="max-w-3xl text-5xl font-bold leading-tight tracking-tight text-[#f0f0f0] sm:text-6xl lg:text-7xl">
        Notes that belong{" "}
        <span className="text-[#ff6900]">to you</span>.
      </h1>

      {/* Sub-headline */}
      <p className="mt-6 max-w-xl text-lg leading-relaxed text-[#a0a0a0] sm:text-xl">
        End-to-end encrypted, offline-first markdown notes, synced to{" "}
        <strong className="text-[#f0f0f0]">your own server</strong>.
        No cloud, no trackers, no subscriptions.
      </p>

      {/* CTAs */}
      <div className="mt-10 flex flex-col gap-4 sm:flex-row">
        <a
          href="#demo"
          className="rounded-lg bg-[#ff6900] px-7 py-3.5 text-base font-semibold text-white transition-colors hover:bg-[#e55e00]"
        >
          Try the demo
        </a>
        <a
          href="#download"
          className="rounded-lg border border-[#333333] px-7 py-3.5 text-base font-semibold text-[#f0f0f0] transition-colors hover:border-[#ff6900] hover:text-[#ff6900]"
        >
          Download
        </a>
      </div>

      {/* Scroll hint */}
      <div className="absolute bottom-10 flex flex-col items-center gap-2 text-xs text-[#a0a0a0]">
        <span>Scroll to explore</span>
        <svg className="animate-bounce-hint" width="16" height="20" viewBox="0 0 16 20" fill="none">
          <path
            d="M8 3v14M3 13l5 5 5-5"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>
    </section>
  );
}
