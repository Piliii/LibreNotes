import { Download, Package, ArrowRight, Info } from 'lucide-react';
import { siLinux, siArchlinux, siDebian, siFedora, siAndroid, siFdroid, siGoogleplay } from 'simple-icons';
import BrandIcon from './BrandIcon';

const GH_RELEASE = 'https://github.com/Piliii/LibreNotes/releases/latest';
const FDROID_URL = 'https://f-droid.org/en/packages/dev.librenotes.app/';
const AUR_URL = 'https://aur.archlinux.org/packages/librenotes-bin';

const LINUX_OPTIONS = [
  {
    label: 'AppImage',
    description: 'Runs on any Linux distro.',
    href: GH_RELEASE,
    icon: <Download size={20} strokeWidth={1.6} />,
  },
  {
    label: 'Tarball (.tar.gz)',
    description: 'Portable archive for manual install.',
    href: GH_RELEASE,
    icon: <Package size={20} strokeWidth={1.6} />,
  },
  // TODO: point these at the real assets once a GitHub
  // release actually ships the .deb/.rpm files (planned for v1.6.0).
  {
    label: 'Debian / Ubuntu (.deb)',
    description: 'Debian, Ubuntu, Mint.',
    href: GH_RELEASE,
    comingSoon: true,
    icon: <BrandIcon icon={siDebian} size={20} />,
  },
  {
    label: 'Fedora / openSUSE (.rpm)',
    description: 'Fedora, openSUSE, RPM distros.',
    href: GH_RELEASE,
    comingSoon: true,
    icon: <BrandIcon icon={siFedora} size={20} />,
  },
  {
    label: 'AUR (librenotes-bin)',
    description: 'Arch Linux and Arch-based distros.',
    href: AUR_URL,
    icon: <BrandIcon icon={siArchlinux} size={20} />,
  },
];

// Windows 10-style logo from Material Design Icons (Iconify: mdi:microsoft-windows);
// simple-icons no longer ships Microsoft brand icons.
const siWindows = {
  title: 'Windows',
  path: 'M3 12V6.75l6-1.32v6.48zm17-9v8.75l-10 .15V5.21zM3 13l6 .09v6.81l-6-1.15zm17 .25V22l-10-1.91V13.1z',
};

// TODO: Windows ships in v1.8.0. Once a GitHub release carries the files,
// point href at the /dl/windows short links (vercel.json).
const WINDOWS_OPTIONS = [
  {
    label: 'Installer (.exe)',
    description: 'Windows 10/11 setup wizard.',
    href: GH_RELEASE,
    comingSoon: true,
    icon: <BrandIcon icon={siWindows} size={20} />,
  },
  {
    label: 'Portable (.zip)',
    description: 'Unzip and run, no install.',
    href: GH_RELEASE,
    comingSoon: true,
    icon: <Package size={20} strokeWidth={1.6} />,
  },
];

function DownloadCard({ icon, label, description, href, badge, comingSoon }) {
  if (comingSoon) {
    return (
      <div
        aria-disabled="true"
        className="flex min-h-[84px] cursor-not-allowed select-none items-center gap-4 rounded-xl border p-5 opacity-50 grayscale"
        style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
      >
        <div
          className="shrink-0 rounded-lg p-2"
          style={{ background: 'var(--bg-surface)', color: 'var(--text-secondary)' }}
        >
          {icon}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
              {label}
            </span>
            <span
              className="rounded-full px-2 py-0.5 text-[10px] font-medium"
              style={{ background: 'var(--bg-surface)', color: 'var(--text-secondary)' }}
            >
              Coming soon
            </span>
          </div>
          <p className="mt-0.5 text-xs leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
            {description}
          </p>
        </div>
      </div>
    );
  }

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="group flex min-h-[84px] items-center gap-4 rounded-xl border p-5 transition-all duration-200 hover:border-[#ff6900] hover:-translate-y-0.5"
      style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
    >
      <div
        className="shrink-0 rounded-lg p-2 transition-colors group-hover:bg-[#ff6900] group-hover:text-white"
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
        className="shrink-0 opacity-0 transition-opacity group-hover:opacity-100"
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
      <div className="mx-auto max-w-6xl">
        <div className="mb-14 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Download
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Free, forever. No account required.
          </p>
        </div>

        <div className="grid gap-10 lg:grid-cols-3">
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
                href={FDROID_URL}
                label="F-Droid"
                description="Official F-Droid repo."
                icon={<BrandIcon icon={siFdroid} size={20} />}
              />
              {/* TODO: point href at the Play listing and drop the badge once it's live. */}
              <DownloadCard
                href={GH_RELEASE}
                label="Google Play"
                description="Official Play Store listing."
                comingSoon
                icon={<BrandIcon icon={siGoogleplay} size={20} />}
              />
              <DownloadCard
                href={GH_RELEASE}
                label="Direct APK"
                description="arm64-v8a APK from GitHub."
                icon={<Download size={20} strokeWidth={1.6} />}
              />
            </div>
          </div>

          {/* Windows */}
          <div>
            <div className="opacity-50 grayscale">
              <SectionLabel icon={<BrandIcon icon={siWindows} size={16} />}>Windows (coming soon)</SectionLabel>
            </div>
            <div className="space-y-3">
              {WINDOWS_OPTIONS.map(o => (
                <DownloadCard key={o.label} {...o} />
              ))}
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
                Binary or Docker, runs on Linux. See{' '}
                <a
                  href="#server"
                  className="underline hover:text-[#ff6900]"
                  style={{ color: 'var(--text-primary)' }}
                >
                  Server Setup
                </a>{' '}
                below.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
