"use client";

import Link from "next/link";
import { usePathname } from 'next/navigation';

export default function Header() {
  const pathname = usePathname?.() || '';
  const hidePublicNav = pathname.startsWith('/app');

  return (
    <header>
      <div className="container nav">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
            <div className="brand">
            <div style={{ width: 48, height: 48, borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <img src="/logo.png" alt="AxoFi logo" className="logo" />
            </div>
            <Link href="/" className="title">AxoFi</Link>
          </div>

          <nav style={{ display: 'flex', gap: 18, alignItems: 'center' }}>
            {!hidePublicNav && (
              <>
                <a href="#features">Features</a>
                <a href="#how-it-works">How it Works</a>
                <a href="#docs">Docs</a>
                <Link href="/app">
                  <button className="btn-primary">Open Vault</button>
                </Link>
              </>
            )}
          </nav>
        </div>
      </div>
    </header>
  );
}
