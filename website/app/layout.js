import "./globals.css";

export const metadata = {
  metadataBase: new URL("https://librenotes.ayopili.com"),
  title: "LibreNotes",
  description: "End-to-end encrypted, offline-first notes synced to your own server. No cloud, no trackers, no subscriptions.",
  openGraph: {
    title: "LibreNotes",
    description: "End-to-end encrypted, offline-first notes synced to your own server. No cloud, no trackers, no subscriptions.",
    url: "https://librenotes.ayopili.com",
    siteName: "LibreNotes",
    images: [{ url: "/icon.png", width: 512, height: 512, alt: "LibreNotes" }],
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "LibreNotes",
    description: "End-to-end encrypted, offline-first notes synced to your own server. No cloud, no trackers, no subscriptions.",
    images: ["/icon.png"],
  },
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
      </head>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
