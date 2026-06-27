import { Download, Package, ArrowRight, Info } from 'lucide-react';
import { siLinux, siArchlinux, siAndroid, siFdroid, siFlatpak, siGithub } from 'simple-icons';
import BrandIcon from './BrandIcon';

const GH_RELEASE = 'https://github.com/Piliii/LibreNotes/releases/latest';
const FLATPAK_REPO = 'https://github.com/Piliii/dev.librenotes.app';
const FDROID_MR = 'https://gitlab.com/fdroid/fdroiddata/-/merge_requests/41300';
const AUR_URL = 'https://aur.archlinux.org/packages/librenotes-bin';

const LINUX_OPTIONS = [
  {
    label: 'AppImage',
    description: 'Runs on any Linux distro, no install needed.',
    href: GH_RELEASE,
    icon: <Download size={20} strokeWidth={1.6} />,
  },
  {
    label: 'Tarball (.tar.gz)',
    description: 'Portable archive for manual install.',
    href: GH_RELEASE,
    icon: <Package size={20} strokeWidth={1.6} />,
  },
  {
    label: 'AUR (librenotes-bin)',
    description: 'Arch Linux and Arch-based distros.',
    href: AUR_URL,
    icon: <BrandIcon icon={siArchlinux} size={20} />,
  },
  {
    label: 'Flatpak',
    description: 'Manual install from the manifest repo.',
    href: FLATPAK_REPO,
    icon: <BrandIcon icon={siFlatpak} size={20} />,
  },
];

function DownloadCard({ icon, label, description, href, badge }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="group flex items-start gap-4 rounded-xl border p-5 transition-all duration-200 hover:border-[#ff6900] hover:-translate-y-0.5"
      style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
    >
      <div
        className="mt-0.5 shrink-0 rounded-lg p-2 transition-colors group-hover:bg-[#ff6900] group-hover:text-white"
        style={{ background: 'var(--bg-surface)', color: 'var(--accent)' }}
      >
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
            {label}
          </span>
          {badge && (
            <span
              className="rounded-full px-2 py-0.5 text-[10px] font-medium"
              style={{ background: '#2a1f0a', color: '#ff6900' }}
            >
              {badge}
            </span>
          )}
        </div>
        <p className="mt-0.5 text-xs leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
          {description}
        </p>
      </div>
      <ArrowRight
        size={14}
        className="mt-1 shrink-0 opacity-0 transition-opacity group-hover:opacity-100"
        style={{ color: 'var(--accent)' }}
      />
    </a>
  );
}

function SectionLabel({ icon, children }) {
  return (
    <h3 className="mb-4 flex items-center gap-2 text-xs font-semibold uppercase tracking-widest" style={{ color: 'var(--text-secondary)' }}>
      <span style={{ color: 'var(--accent)' }}>{icon}</span>
      {children}
    </h3>
  );
}

export default function DownloadSection() {
  return (
    <section id="download" className="px-4 py-24 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
      <div className="mx-auto max-w-5xl">
        <div className="mb-14 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Download
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Free, forever. No account required.
          </p>
        </div>

        <div className="grid gap-10 lg:grid-cols-2">
          {/* Linux */}
          <div>
            <SectionLabel icon={<BrandIcon icon={siLinux} size={16} />}>Linux</SectionLabel>
            <div className="space-y-3">
              {LINUX_OPTIONS.map(o => (
                <DownloadCard key={o.label} {...o} />
              ))}
            </div>
          </div>

          {/* Android */}
          <div>
            <SectionLabel icon={<BrandIcon icon={siAndroid} size={16} />}>Android</SectionLabel>
            <div className="space-y-3">
              <DownloadCard
                href={FDROID_MR}
                badge="Pending review"
                label="F-Droid"
                description="FOSS-only Android app store. MR #41300 submitted, listing coming soon."
                icon={<BrandIcon icon={siFdroid} size={20} />}
              />
              <DownloadCard
                href={GH_RELEASE}
                label="Direct APK"
                description="arm64-v8a release APK from GitHub releases. Sideload manually."
                icon={<Download size={20} strokeWidth={1.6} />}
              />
            </div>

            {/* Server setup callout */}
            <div
              className="mt-6 rounded-xl border p-5"
              style={{ borderColor: '#ff6900', background: '#1f1408' }}
            >
              <div className="flex items-center gap-2 mb-1.5">
                <Info size={15} style={{ color: '#ff6900' }} />
                <p className="text-sm font-semibold" style={{ color: '#ff6900' }}>
                  Also need the sync server?
                </p>
              </div>
              <p className="text-xs leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                One binary, runs on Linux. See the{' '}
                <a
                  href="https://github.com/Piliii/LibreNotes#readme"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="underline hover:text-[#ff6900]"
                  style={{ color: 'var(--text-primary)' }}
                >
                  README
                </a>{' '}
                for setup. Takes about 5 minutes on a Raspberry Pi.
              </p>
            </div>
          </div>
        </div>

        {/* Footer */}
        <p className="mt-14 text-center text-xs" style={{ color: 'var(--text-secondary)' }}>
          <span className="inline-flex items-center gap-1.5">
            <BrandIcon icon={siGithub} size={13} />
            <a
              href="https://github.com/Piliii/LibreNotes"
              target="_blank"
              rel="noopener noreferrer"
              className="underline hover:text-[#ff6900]"
            >
              Open source on GitHub
            </a>
          </span>
          {' · '}AGPLv3 license
        </p>
      </div>
    </section>
  );
}
