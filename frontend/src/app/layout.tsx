export const metadata = {
  title: 'AxoFi',
  description: 'AxoFi landing page - coming soon',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        {/* Favicon: put your preferred favicon image at `public/favicon.jpg` or change path below */}
        <link rel="icon" href="/favicon.jpg" />
        <link rel="apple-touch-icon" href="/favicon.jpg" />
      </head>
      <body>
        {children}
      </body>
    </html>
  );
}
