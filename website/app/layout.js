import "./globals.css";

const DESCRIPTION =
  "End-to-end encrypted, offline-first notes synced to your own server. No cloud, no trackers, no subscriptions.";

export const metadata = {
  metadataBase: new URL("https://librenotes.ayopili.com"),
  title: "LibreNotes",
  description: DESCRIPTION,
  alternates: { canonical: "/" },
  openGraph: {
    title: "LibreNotes",
    description: DESCRIPTION,
    siteName: "LibreNotes",
    images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "LibreNotes: private, end-to-end encrypted notes synced to your own server" }],
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "LibreNotes",
    description: DESCRIPTION,
    images: ["/og-image.png"],
  },
};

export const viewport = {
  themeColor: "#1a1a1a",
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "LibreNotes",
  description: DESCRIPTION,
  url: "https://librenotes.ayopili.com",
  applicationCategory: "ProductivityApplication",
  operatingSystem: "Android, Linux",
  license: "https://www.gnu.org/licenses/agpl-3.0.html",
  isAccessibleForFree: true,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  downloadUrl: "https://f-droid.org/packages/dev.librenotes.app/",
  sameAs: ["https://github.com/Piliii/LibreNotes"],
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className="h-full">
      <head>
        <link rel="preconnect" href="https://fonts.bunny.net" />
        <link
          href="https://fonts.bunny.net/css?family=inter:400,500,600,700&display=swap"
          rel="stylesheet"
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }}
        />
      </head>
      <body className="min-h-full flex flex-col">
        <a href="#main" className="skip-link">
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}
