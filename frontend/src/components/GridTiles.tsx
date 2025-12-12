"use client";

import React from 'react';

/**
 * Minimal GridTiles placeholder. The original project referenced a GridTiles
 * component but it was missing — this provides a lightweight, styled grid
 * that sits absolutely inside the Hero section.
 */
export default function GridTiles() {
  return (
    <div className="grid-tiles" aria-hidden="true">
      <style jsx>{`
        .grid-tiles { position: absolute; inset: 0; z-index: 1; pointer-events: none; display: grid; grid-template-columns: repeat(12, 1fr); grid-auto-rows: 1fr; gap: 8px; padding: 24px; }
        .grid-tiles .tile { background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.02); border-radius: 4px; box-shadow: inset 0 1px 0 rgba(255,255,255,0.02); }
        @media (max-width: 900px) { .grid-tiles { display: none; } }
      `}</style>
      {Array.from({ length: 36 }).map((_, i) => (
        // eslint-disable-next-line react/no-array-index-key
        <div key={i} className="tile" style={{ opacity: 0.6 }} />
      ))}
    </div>
  );
}
