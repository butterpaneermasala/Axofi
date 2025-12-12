"use client";

import { ReactNode, useEffect, useRef } from "react";
const GridTiles = () => null;

interface HeroSectionProps {
  title: string;
  subtitle: string;
  description: string;
  primaryButton?: {
    text: string;
    onClick: () => void;
    icon?: ReactNode;
  };
  secondaryButton?: {
    text: string;
    onClick: () => void;
    icon?: ReactNode;
  };
  className?: string;
}

export default function HeroSection({
  title,
  subtitle,
  description,
  primaryButton,
  secondaryButton,
}: HeroSectionProps) {
  const heroRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const el = heroRef.current;
    if (!el) return;

    const onPointerMove = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      el.style.setProperty('--cursor-x', `${x}px`);
      el.style.setProperty('--cursor-y', `${y}px`);
      el.style.setProperty('--cursor-opacity', '0.9');
      // do NOT toggle `.grid-green` — tiles will glow individually instead
    };

    const onPointerLeave = () => {
      el.style.setProperty('--cursor-opacity', '0');
      // leave grid state alone
    };

    el.addEventListener('pointermove', onPointerMove as any);
    el.addEventListener('pointerleave', onPointerLeave as any);

    return () => {
      el.removeEventListener('pointermove', onPointerMove as any);
      el.removeEventListener('pointerleave', onPointerLeave as any);
      el.style.removeProperty('--cursor-opacity');
      el.classList.remove('grid-green');
    };
  }, []);

  return (
    <section ref={heroRef} className="hero">
      {/* place GridTiles as a direct child of .hero so its absolute inset:0 aligns with the hero origin */}
      <GridTiles />
      <div className="container" style={{ position: 'relative', zIndex: 2 }}>
        {subtitle && <div className="neon-badge">{subtitle}</div>}
        <h1 className="title">{title}</h1>
        <p className="lead">{description}</p>

        <div className="cta-wrap">
          {primaryButton && (
            <button onClick={primaryButton.onClick} className="btn-primary">{primaryButton.text}</button>
          )}
          {secondaryButton && (
            <button onClick={secondaryButton.onClick} className="btn-ghost">{secondaryButton.text}</button>
          )}
        </div>
      </div>
    </section>
  );
}