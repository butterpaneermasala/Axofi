"use client";

import React, { useEffect } from "react";

export default function LandingPage() {
  useEffect(() => {
    // --- 0. Meta tags for AxoFi (inject at runtime because this is a client component) ---
    try {
      const title = 'AxoFi — Volatility Dam for Mantle';
      document.title = title;

      const metas: Array<{ name?: string; property?: string; content: string }> = [
        { name: 'description', content: 'AxoFi provides fixed-like savings by isolating predictable payoff exposure on Mantle. Built with mUSD and Ondo integrations.' },
        { property: 'og:title', content: 'AxoFi — Volatility Dam for Mantle' },
        { property: 'og:description', content: 'Predictable savings for everyday users — AxoFi separates deterministic payoff exposure from variable yield.' },
        { property: 'og:type', content: 'website' },
        { property: 'og:url', content: (typeof window !== 'undefined' && window.location.href) || '' },
        { property: 'og:image', content: 'https://raw.githubusercontent.com/butterpaneermasala/assets/main/axofi-share.png' },
        { name: 'twitter:card', content: 'summary_large_image' },
        { name: 'twitter:site', content: '@axolotlfi' },
      ];

      metas.forEach((m) => {
        let el: HTMLMetaElement | null = null;
        if (m.name) el = document.head.querySelector(`meta[name="${m.name}"]`);
        else if (m.property) el = document.head.querySelector(`meta[property="${m.property}"]`);

        if (el) {
          el.setAttribute('content', m.content);
        } else {
          const meta = document.createElement('meta');
          if (m.name) meta.setAttribute('name', m.name);
          if (m.property) meta.setAttribute('property', m.property);
          meta.setAttribute('content', m.content);
          document.head.appendChild(meta);
        }
      });
    } catch (e) {
      // harmless if document/head is not available in some environments
      // keep silent
    }

    // --- 1. Terrain Logic ---
    const terrainPath = document.getElementById("terrain-path");
    const TERRAIN_WIDTH = 1000;
    const TERRAIN_HEIGHT = 400;

    function getTerrainHeight(x: number) {
      const nx = x;
      const h1 = Math.sin(nx * 0.01) * 60;
      const h2 = Math.sin(nx * 0.03) * 20;
      const h3 = Math.sin(nx * 0.1) * 5;
      return 200 - (h1 + h2 + h3);
    }

    function drawTerrain() {
      if (!terrainPath) return;
      let d = `M0,${TERRAIN_HEIGHT} `;
      for (let x = 0; x <= TERRAIN_WIDTH; x += 10) {
        const y = getTerrainHeight(x);
        d += `L${x},${y} `;
      }
      d += `L${TERRAIN_WIDTH},${TERRAIN_HEIGHT} Z`;
      terrainPath.setAttribute("d", d);
    }

    drawTerrain();

    // (bubbles removed)

    // --- 3. Pixel Cloud Logic ---
    const hero = document.getElementById("hero");
    const wrapper = document.getElementById("cloud-wrapper");
    const BLOCK_SIZE = 10;

    function createPixel(x: number, y: number) {
      if (!wrapper) return;
      const div = document.createElement("div");
      div.classList.add("pixel");
      div.style.left = `${x}px`;
      div.style.top = `${y}px`;
      div.addEventListener("mouseenter", () => breakPixel(div));
      wrapper.appendChild(div);
    }

    function generateTextCloud() {
      if (!wrapper) return;
      const width = 600;
      const height = 250;
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d");
      if (!ctx) return;

      ctx.fillStyle = "white";
      ctx.font = "900 150px Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("AxoFi", width / 2, height / 2);

      const imageData = ctx.getImageData(0, 0, width, height);
      const data = imageData.data;

      // Clear existing content if any (prevents dupes on re-renders)
      wrapper.innerHTML = ""; 

      for (let y = 0; y < height; y += BLOCK_SIZE) {
        for (let x = 0; x < width; x += BLOCK_SIZE) {
          const index = (y * width + x) * 4;
          if (data[index + 3] > 128) {
            createPixel(x, y);
          }
        }
      }
    }

    function breakPixel(element: HTMLElement) {
      if (
        element.classList.contains("broken") ||
        element.classList.contains("shaking") ||
        element.classList.contains("returning")
      )
        return;

      const rect = element.getBoundingClientRect();
      const startX = rect.left + 5;
      const startY = rect.top;

      if (!hero) return;
      const heroRect = hero.getBoundingClientRect();
      const terrainBottomY = heroRect.bottom;

      const winWidth = window.innerWidth;
      const terrainX = (startX / winWidth) * TERRAIN_WIDTH;
      const svgY = getTerrainHeight(terrainX);
      const terrainContainerHeight = window.innerHeight * 0.4; // 40vh
      const scaleY = terrainContainerHeight / TERRAIN_HEIGHT;

      const landYFromBottom = (TERRAIN_HEIGHT - svgY) * scaleY;
      const landY = terrainBottomY - landYFromBottom;

      const delta = 5;
      const hLeft = getTerrainHeight(terrainX - delta);
      const hRight = getTerrainHeight(terrainX + delta);
      const slope = (hRight - hLeft) / (delta * 2);

      let rollDist = slope * 200;
      if (rollDist > 150) rollDist = 150;
      if (rollDist < -150) rollDist = -150;
      if (Math.abs(slope) < 0.2) rollDist = (Math.random() - 0.5) * 20;

      const finalTerrainX = terrainX + rollDist;
      const finalSvgY = getTerrainHeight(finalTerrainX);
      const finalYFromBottom = (TERRAIN_HEIGHT - finalSvgY) * scaleY;

      const finalY = terrainBottomY - finalYFromBottom;

      const deltaLandY = landY - startY - 5;
      const deltaFinalX = (finalTerrainX - terrainX) * (winWidth / TERRAIN_WIDTH);
      const deltaFinalY = finalY - startY - 5;

      const rotation = (Math.random() > 0.5 ? 1 : -1) * (360 + Math.random() * 360);

      element.style.setProperty("--land-x", `${0}px`); // Logic simplifies here as deltaLandX is 0 in your code
      element.style.setProperty("--land-y", `${deltaLandY}px`);
      element.style.setProperty("--final-x", `${deltaFinalX}px`);
      element.style.setProperty("--final-y", `${deltaFinalY}px`);
      element.style.setProperty("--rot", `${rotation}deg`);

      element.classList.add("broken");

      // Slow down the lifecycle so blocks fall/roll more slowly and return more gently
      setTimeout(() => {
        element.classList.remove("broken");
        element.classList.add("shaking");

        setTimeout(() => {
          element.classList.remove("shaking");
          element.classList.add("returning");

          setTimeout(() => {
            element.classList.remove("returning");
          }, 900);
        }, 900);
      }, 6000);
    }

    generateTextCloud();

    // --- 4. Touch Event Listeners ---
    function onTouchMove(e: TouchEvent) {
      const touch = e.touches[0];
      const element = document.elementFromPoint(touch.clientX, touch.clientY);
      if (element && (element as HTMLElement).classList.contains("pixel")) {
        breakPixel(element as HTMLElement);
      }
    }

    document.addEventListener("touchmove", onTouchMove, { passive: true });

    // --- 5. Twitter Widget Loader ---
    const tweetRoot = document.getElementById("tweet-embed-root");
    if (tweetRoot) {
      // Inject HTML safely via JS
      tweetRoot.innerHTML = `
        <blockquote class="twitter-tweet">
          <p lang="en" dir="ltr">AxoFi - The Volatility Dam for Mantle Network<br><br>we are building on <a href="https://twitter.com/Mantle_Official?ref_src=twsrc%5Etfw">@Mantle_Official</a> and <a href="https://twitter.com/OndoFinance?ref_src=twsrc%5Etfw">@OndoFinance</a> for the Mantle Global Hackathon on <a href="https://twitter.com/HackQuest_?ref_src=twsrc%5Etfw">@HackQuest_</a> <br><br>more updates soon... <a href="https://t.co/0uL99M1KrG">pic.twitter.com/0uL99M1KrG</a></p>&mdash; AxoFi (@axolotlfi) <a href="https://twitter.com/axolotlfi/status/1999176995444498808?ref_src=twsrc%5Etfw">December 11, 2025</a>
        </blockquote>
      `;

      // Load script
      const scriptId = "twitter-wjs";
      if (!document.getElementById(scriptId)) {
        const s = document.createElement("script");
        s.id = scriptId;
        s.src = "https://platform.twitter.com/widgets.js";
        s.async = true;
        s.charset = "utf-8";
        document.body.appendChild(s);
      }
      
      // Attempt to load widgets
      const loadWidgets = () => {
        const w = (window as any).twttr;
        if (w && w.widgets && typeof w.widgets.load === "function") {
          w.widgets.load(tweetRoot);
        }
      };

      // Check repeatedly in case script is loading
      const interval = setInterval(() => {
        const w = (window as any).twttr;
        if (w) {
          loadWidgets();
          clearInterval(interval);
        }
      }, 200);

      // Cleanup interval after 5 seconds to prevent memory leak if script fails
      setTimeout(() => clearInterval(interval), 5000);
    }

    return () => {
      document.removeEventListener("touchmove", onTouchMove);
    };
  }, []);

  return (
    <>
      <style jsx global>{`
        @import url('https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap');
        html, body { height: 100%; }
        body { margin: 0; padding: 0; width: 100vw; overflow-x: hidden; overflow-y: auto; background-color: #001e36; font-family: sans-serif; cursor: crosshair; -webkit-user-select: none; user-select: none; }
        #hero { position: relative; width: 100%; height: 100vh; overflow: hidden; background: linear-gradient(to bottom, #4ca1af, #c4e0e5); z-index: 5; }
        .airplane-wrapper { position: absolute; top: 10%; left: 100%; z-index: 4; display: flex; align-items: center; animation: flyAcross 25s linear infinite; pointer-events: none; }
        .pixel-plane { width: 100px; height: 50px; background-image: url("https://raw.githubusercontent.com/butterpaneermasala/assets/main/image-removebg-preview.png"); background-repeat: no-repeat; background-size: contain; background-position: center; margin-right: 0px; filter: drop-shadow(4px 4px 0 rgba(0,0,0,0.2)); }
        .pixel-banner { background-color: #ff5252; color: white; font-family: 'Press Start 2P', cursive; font-size: 0.8rem; padding: 8px 12px; border: 2px solid white; box-shadow: 4px 4px 0 rgba(0,0,0,0.2); white-space: nowrap; }
        @keyframes flyAcross { 0% { transform: translateX(0); left: 110%; } 100% { transform: translateX(0); left: -600px; } }
        #ocean { position: relative; width: 100%; min-height: auto; background: linear-gradient(to bottom, #005b82 0%, #001e36 100%); z-index: 20; padding-bottom: 40px; margin-top: 0; }
        .ocean-top-divider { position: absolute; top: -100px; left: 0; width: 100%; height: 101px; overflow: hidden; z-index: 20; pointer-events: none; }
        .fog-wrapper { position: absolute; bottom: 0; left: 0; width: 100%; height: 250px; z-index: 25; pointer-events: none; overflow: hidden; }
        .fog-layer { position: absolute; bottom: 0; left: 0; width: 200%; height: 100%; background-repeat: repeat-x; background-position: bottom left; filter: blur(8px); }
        .fog-1 { bottom: 20px; height: 120px; opacity: 0.5; background-image: radial-gradient(circle at 50% 100%, white 50%, transparent 51%); background-size: 120px 100px; animation: fogDrift 90s linear infinite; }
        .fog-2 { bottom: 0px; height: 160px; opacity: 0.7; background-image: radial-gradient(circle at 50% 100%, rgb(220, 240, 255) 55%, transparent 56%); background-size: 180px 140px; animation: fogDrift 70s linear infinite reverse; }
        .fog-3 { bottom: -30px; height: 200px; opacity: 0.9; background-image: radial-gradient(circle at 50% 100%, rgb(240, 250, 255) 60%, transparent 61%); background-size: 250px 180px; animation: fogDrift 50s linear infinite; }
        @keyframes fogDrift { 0% { transform: translateX(0); } 100% { transform: translateX(-50%); } }
        .float-wrapper { position: relative; z-index: 30; display: flex; flex-direction: column; align-items: center; gap: 80px; padding-top: 50px; width: 100%; max-width: 900px; margin: 0 auto; pointer-events: none; }
        .raft { background-color: #8d6e63; border: 4px solid #3e2723; box-shadow: 0px 10px 0px rgba(0,0,0,0.2), inset 0 0 20px rgba(0,0,0,0.2); padding: 20px; width: 80%; max-width: 600px; font-family: 'Press Start 2P', cursive; color: #fff; line-height: 1.4; font-size: 0.78rem; text-align: center; position: relative; image-rendering: pixelated; animation: bob 3s ease-in-out infinite; display: flex; flex-direction: column; justify-content: center; align-items: center; aspect-ratio: 1 / 1; }
        .raft::after { content: ''; position: absolute; bottom: -12px; left: 10%; width: 80%; height: 4px; background: rgba(255,255,255,0.3); border-radius: 50%; animation: ripple 3s ease-in-out infinite; }
        .raft-title { color: #ffeb3b; font-size: 1rem; margin-bottom: 8px; text-transform: uppercase; text-shadow: 2px 2px 0px #3e2723; }
        .highlight { color: #81d4fa; font-weight: bold; }
        @keyframes bob { 0%, 100% { transform: translateY(0px) rotate(0deg); } 50% { transform: translateY(-15px) rotate(1deg); } }
        @keyframes ripple { 0%, 100% { transform: scaleX(1); opacity: 0.3; } 50% { transform: scaleX(1.1); opacity: 0.5; } }
        /* bubbles removed */
        .mountain-layer { position: absolute; bottom: 0; left: 0; width: 100%; pointer-events: none; }
        #mountain-back { height: 60%; background: #2E5936; clip-path: polygon(0% 100%, 0% 40%, 20% 60%, 40% 30%, 60% 50%, 80% 20%, 100% 45%, 100% 100%); opacity: 0.8; z-index: 1; }
        #mountain-mid { height: 45%; background: #407A4B; clip-path: polygon(0% 100%, 0% 50%, 15% 70%, 35% 40%, 60% 60%, 85% 30%, 100% 60%, 100% 100%); opacity: 0.9; z-index: 2; }
        #terrain-svg { position: absolute; bottom: 0; left: 0; width: 100%; height: 40%; z-index: 10; fill: #143D21; filter: drop-shadow(0 -2px 4px rgba(0,0,0,0.2)); pointer-events: none; }
        #axolotl { position: absolute; bottom: 15%; left: 5%; width: 150px; height: auto; z-index: 15; pointer-events: none; filter: drop-shadow(0 5px 5px rgba(0,0,0,0.3)); }
        /* Container that groups the pixel cloud and the AxoFi tag so the tag stays below */
        .cloud-container { position: absolute; top: 20%; left: 50%; transform: translateX(-50%); width: 600px; height: auto; z-index: 20; display: flex; flex-direction: column; align-items: center; gap: 12px; }
        #cloud-wrapper { position: relative; width: 600px; height: 250px; }
        .pixel { position: absolute; width: 10px; height: 10px; background: rgba(255,255,255,0.95); border-radius: 1px; will-change: transform; z-index: 30; }
        /* AxoFi tag (pill under the pixel cloud) */
        .axofi-tag { display: inline-block; margin-top: 14px; background: rgba(0,0,0,0.45); color: #ffeb3b; border: 2px solid rgba(255,255,255,0.08); padding: 8px 14px; border-radius: 999px; font-family: 'Press Start 2P', cursive; font-size: 0.7rem; z-index: 40; pointer-events: none; text-transform: uppercase; letter-spacing: 0.02em; }
        .pixel.broken { pointer-events: none; z-index: 50; animation: bounceAndRoll 1.8s cubic-bezier(0.3, 0.05, 0.2, 1) forwards; }
        .pixel.shaking { z-index: 50; animation: shakeGround 0.15s infinite; transform: translate(var(--final-x), var(--final-y)) rotate(var(--rot)); }
        .pixel.returning { pointer-events: none; z-index: 100; animation: flyBack 0.6s ease-in forwards; }
          /* Slow animations so broken pixels fall/roll slower */
          .pixel.broken { pointer-events: none; z-index: 50; animation: bounceAndRoll 3s cubic-bezier(0.3, 0.05, 0.2, 1) forwards; }
          .pixel.returning { pointer-events: none; z-index: 100; animation: flyBack 1.2s ease-in forwards; }
        @keyframes bounceAndRoll { 0% { transform: translate(0, 0) rotate(0deg); } 30% { transform: translate(var(--land-x), var(--land-y)) rotate(var(--rot)); } 45% { transform: translate(var(--land-x), calc(var(--land-y) - 40px)) rotate(calc(var(--rot) * 1.1)); } 60% { transform: translate(var(--land-x), var(--land-y)) rotate(var(--rot)); } 100% { transform: translate(var(--final-x), var(--final-y)) rotate(calc(var(--rot) + 180deg)); } }
          @keyframes shakeGround { 0% { transform: translate(var(--final-x), var(--final-y)) rotate(var(--rot)); } 50% { transform: translate(calc(var(--final-x) + 2px), var(--final-y)) rotate(var(--rot)); } 100% { transform: translate(var(--final-x), var(--final-y)) rotate(var(--rot)); } }
        @keyframes flyBack { 0% { transform: translate(var(--final-x), var(--final-y)) rotate(var(--rot)); } 100% { transform: translate(0, 0) rotate(0deg); } }
          @keyframes flyBack { 0% { transform: translate(var(--final-x), var(--final-y)) rotate(var(--rot)); } 100% { transform: translate(0, 0) rotate(0deg); } }
        .hint { position: absolute; bottom: 40px; left: 50%; transform: translateX(-50%); width: auto; padding: 12px 24px; background-color: rgba(0, 0, 0, 0.6); border-radius: 50px; border: 2px solid rgba(255, 255, 255, 0.2); text-align: center; color: #ffffff; font-family: 'Press Start 2P', cursive; font-size: 0.65rem; line-height: 1.4; pointer-events: none; z-index: 50; white-space: nowrap; box-shadow: 0 4px 10px rgba(0,0,0,0.3); text-shadow: 1px 1px 0 #000; }

        /* X (Twitter) embed + link in ocean */
        .ocean-x { position: absolute; bottom: 6%; left: 65%; transform: translateX(-50%); z-index: 16; display: flex; gap: 18px; align-items: flex-end; pointer-events: none; }
        .x-link { background: rgba(0,0,0,0.55); color: #fff; padding: 8px 12px; border-radius: 10px; text-decoration: none; font-family: 'Press Start 2P', cursive; font-size: 12px; pointer-events: auto; box-shadow: 0 6px 10px rgba(0,0,0,0.25); }
        .tweet-embed iframe { width: 320px; height: 380px; border: none; border-radius: 8px; pointer-events: auto; }
        /* Target the injected twitter widget iframe specifically */
        #tweet-embed-root iframe { width: 320px !important; border-radius: 12px !important; pointer-events: auto; }

        /* Protocol info raft styling */
        .protocol-raft { text-align: left; font-size: 0.78rem; padding: 20px; line-height: 1.4; }
        .protocol-raft ul { margin: 8px 0 0 18px; }

        @media (min-width: 900px) {
          .ocean-x { left: auto; right: 4%; bottom: 10%; transform: none; flex-direction: column; align-items: flex-end; }
          .tweet-embed iframe { width: 420px; height: 420px; }
          #tweet-embed-root iframe { width: 400px !important; }
        }

        /* Ocean stickers: each sticker sits in its own positioned wrapper */
        .sticker-wrapper { position: absolute; z-index: 9999; pointer-events: none; }
        .sticker-wrapper.left { left: 4%; top: 590px; }
        .sticker-wrapper.right { right: 4%; top: 20px; }
        .ocean-sticker { width: 220px; height: auto; filter: drop-shadow(0 6px 6px rgba(0,0,0,0.35)); display: block; }

        /* Container for stickers so they can be separated from float tiles */
        .ocean-stickers { position: absolute; left: 0; top: 0; width: 100%; z-index: 9998; pointer-events: none; display: block; }

        /* Tiles grouping: three small rafts */
        .tiles { display: flex; flex-direction: column; gap: 24px; width: 100%; align-items: center; }
        .tiles .raft { width: 90%; max-width: 740px; }
        .raft-subtitle { color: #ffe082; font-size: 0.95rem; margin-top: 6px; font-family: 'Press Start 2P', cursive; }
        .raft-body { margin-top: 10px; font-size: 0.85rem; }

        /* Protocol container separate from tiles */
        .protocol-container { width: 100%; margin-top: 16px; display: flex; justify-content: center; }
        /* Make the protocol raft appear as a square (like other tiles) and center its content */
        .protocol-container .protocol-raft { width: 90%; max-width: 620px; display: flex; align-items: center; justify-content: center; padding: 8px; box-sizing: border-box; }
        .protocol-container .protocol-raft .raft { padding: 18px; aspect-ratio: 1 / 1; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: left; }
        .protocol-container .protocol-raft .raft p, .protocol-container .protocol-raft .raft ul { margin: 6px 0; font-size: 0.78rem; }

        /* Make rafts layout responsive: tiles become a row on wide screens; protocol stays centered below */
        @media (min-width: 900px) {
          .tiles { flex-direction: row; gap: 40px; align-items: stretch; }
          .tiles .raft { width: 28%; max-width: none; }
          .protocol-container { width: 100%; }
          .protocol-container .protocol-raft { width: 40%; max-width: 420px; }
          .raft { width: 28%; max-width: none; }
          #cloud-wrapper { left: 50%; top: 14%; }
        }

        /* Responsive: remove enforced square aspect on very small screens so content fits */
        @media (max-width: 520px) {
          .raft { aspect-ratio: auto; width: 90%; height: auto; padding: 18px; }
          .protocol-container .protocol-raft .raft { aspect-ratio: auto; }
          .ocean-sticker { width: 140px; }
        }
      `}</style>

      <div id="hero">
        <div className="airplane-wrapper">
          <div className="pixel-plane" />
          <div className="banner-rope" />
          <div className="pixel-banner">COMING SOON</div>
        </div>

        <div id="mountain-back" className="mountain-layer" />
        <div id="mountain-mid" className="mountain-layer" />

        <svg id="terrain-svg" viewBox="0 0 1000 400" preserveAspectRatio="none">
          <path id="terrain-path" d="" />
        </svg>

        <div className="fog-wrapper">
          <div className="fog-layer fog-1"></div>
          <div className="fog-layer fog-2"></div>
          <div className="fog-layer fog-3"></div>
        </div>

        <img id="axolotl" src="https://media.giphy.com/media/RJEBGVo2mrGxsujtAE/giphy.gif" alt="Axolotl Sticker" />

        <div className="cloud-container">
          <div id="cloud-wrapper"></div>
          <div className="axofi-tag">Predictable Savings</div>
        </div>

        <div className="hint">Scroll down for Ocean • Touch "AxoFi"</div>
      </div>

      <div id="ocean">
        <div className="ocean-top-divider">
          <svg viewBox="0 0 1200 120" preserveAspectRatio="none">
            <path d="M321.39,56.44c58-10.79,114.16-30.13,172-41.86,82.39-16.72,168.19-17.73,250.45-.39C823.78,31,906.67,72,985.66,92.83c70.05,18.48,146.53,26.09,214.34,3V0H0V27.35A600.21,600.21,0,0,0,321.39,56.44Z" fill="#005b82" transform="scale(1, -1) translate(0, -120)"></path>
          </svg>
        </div>

        <div className="float-wrapper">
          <div className="tiles">
            <div className="raft">
              <div className="raft-title">Project</div>
              <div className="raft-subtitle">Motive</div>
              <div className="raft-body">AxolotlFinance is the <span className="highlight">“Volatility Dam”</span> for Mantle: we strip variable yield so savers see fixed outcomes.</div>
            </div>

            <div className="raft">
              <div className="raft-title">The Build</div>
              <div className="raft-body">Built on <span className="highlight">Mantle</span> with Ondo Finance mUSD to offer consumer-grade fixed yield savings.</div>
            </div>

            <div className="raft">
              <div className="raft-title">Our Goal</div>
              <div className="raft-body"><span className="highlight">Predictable savings</span> for everyday users while traders absorb yield swings via YT.</div>
            </div>
          </div>

          <div className="protocol-container">
            <div className="raft protocol-raft">
              <div className="raft-title">Protocol Details</div>
              <p>
                AxolotlFinance provides fixed-like outcomes for savers by separating deterministic
                payoff exposure from variable yield. Key mechanisms and properties:
              </p>
              <ul>
                <li>Fixed outcome engineered by yield-tokenization and on-chain swaps.</li>
                <li>Built natively on Mantle for low fees and fast settlement.</li>
                <li>Uses mUSD (or equivalent stable pools) as the settlement asset.</li>
                <li>Traders absorb volatility (yield traders mint YT positions).</li>
                <li>Security: audited contracts, multisig guardians, and read-only monitoring.</li>
              </ul>
              <p style={{marginTop: '8px'}}>Contact: <a href="mailto:contactport8888@gmail.com">contactport8888@gmail.com</a></p>
            </div>
          </div>
        </div>
        
        {/* Corrected Tweet Embed Container */}
        <div id="tweet-embed-root" className="ocean-x" />

        <div className="ocean-stickers">
          <div className="sticker-wrapper left">
            <img src="https://media.giphy.com/media/LhDOszgcLnGf7ESJqy/giphy.gif" className="ocean-sticker" alt="Relaxing Axolotl" />
          </div>
          <div className="sticker-wrapper right">
            <img src="https://media.giphy.com/media/R9mrCK7qGidnrBzxyB/giphy.gif" className="ocean-sticker" alt="Peeking Angel" />
          </div>
        </div>

      </div>
    </>
  );
}