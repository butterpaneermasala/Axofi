"use client";

import { ReactNode, useState, useRef } from "react";

interface Feature {
  icon?: ReactNode;
  title: string;
  description: string;
}

interface FeatureSectionProps {
  title: string;
  subtitle?: string;
  features: Feature[];
  columns?: 2 | 3 | 4;
  id?: string;
}

export default function FeatureSection({
  title,
  subtitle,
  features,
  columns = 3,
  id,
}: FeatureSectionProps) {
  const cols = columns === 2 ? 2 : columns === 4 ? 4 : 3;

  function FeatureItem({ feature }: { feature: Feature }) {
    const [style, setStyle] = useState<React.CSSProperties | undefined>(undefined);
    const ref = useRef<HTMLDivElement | null>(null);

    const handleMove = (e: React.MouseEvent) => {
      const el = ref.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left; // x position within element
      const y = e.clientY - rect.top; // y position within element
      const cx = rect.width / 2;
      const cy = rect.height / 2;
      const dx = (x - cx) / cx; // -1 .. 1
      const dy = (y - cy) / cy; // -1 .. 1
      const rotateX = (-dy * 6).toFixed(2);
      const rotateY = (dx * 6).toFixed(2);
      const translateY = (-Math.abs(dy) * 6).toFixed(2);
      setStyle({ transform: `rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(${translateY}px)` });
    };

    const handleLeave = () => setStyle({ transform: `rotateX(0deg) rotateY(0deg) translateY(0px)` });

    return (
      <div className="feature-card" style={{ position: 'relative' }}>
        <div
          ref={ref}
          className="card-inner"
          style={{ textAlign: 'center', ...style }}
          onMouseMove={handleMove}
          onMouseLeave={handleLeave}
        >
          {feature.icon && (
            <div style={{ width: 64, height: 64, margin: '0 auto 12px', background: 'rgba(255,255,255,0.02)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 12 }}>
              {feature.icon}
            </div>
          )}
          <h3 className="feature-title">{feature.title}</h3>
          <p style={{ color: 'rgba(255,255,255,0.75)' }}>{feature.description}</p>
        </div>
        <div className="card-glow" />
      </div>
    );
  }

  return null;
}