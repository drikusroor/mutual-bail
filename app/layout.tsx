import './globals.css';
import { Nunito } from 'next/font/google';

const nunito = Nunito({ subsets: ['latin'], weight: ['400', '700', '800'] });

export const metadata = {
  title: 'MutualBail - Cancel Plans, Guilt-Free!',
  description: 'The easy way to mutually agree to cancel plans.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${nunito.className} bg-gradient-to-br from-purple-600 via-pink-500 to-orange-400 min-h-screen text-white flex flex-col items-center justify-center p-4 selection:bg-pink-300 selection:text-pink-800`}>
        {children}
      </body>
    </html>
  );
}
