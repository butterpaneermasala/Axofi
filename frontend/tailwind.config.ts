import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        clario: {
          bg: '#050505', // main page background token from Clario
          surface: '#0d0d0d',
          muted: 'rgba(255,255,255,0.65)',
          neon: '#8cff2e', // primary accent (bright green)
          neon600: '#74e528',
          link: '#0099ff',
        },
        primary: {
          50: '#f3ffe6',
          100: '#e6ffd1',
          200: '#cfff9b',
          300: '#b8ff64',
          400: '#a1ff2e',
          500: '#8cff2e',
          600: '#74e528',
          700: '#5cc01f',
          800: '#458f14',
          900: '#2e6009',
        },
        accent: {
          DEFAULT: '#0099ff',
        },
      },
      fontSize: {
        // Clario heading scales from mirrored CSS: large hero sizes
        'clario-h1': ['64px', { lineHeight: '1em', letterSpacing: '-0.04em' }],
        'clario-h1-md': ['54px', { lineHeight: '1em', letterSpacing: '-0.04em' }],
        'clario-lead': ['18px', { lineHeight: '1.5', letterSpacing: '0' }],
      },
      letterSpacing: {
        'clario-tight': '-0.04em',
      },
      fontFamily: {
        // Primary Clario fonts (Manrope used for headings, Inter for UI/bold accents)
        manrope: ['Manrope', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        inter: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        sans: ['Manrope', 'Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        'clario-neon-sm': '0 6px 18px rgba(140,255,46,0.18), 0 2px 6px rgba(140,255,46,0.06)',
        'clario-neon-lg': '0 12px 40px rgba(140,255,46,0.22), 0 6px 20px rgba(140,255,46,0.08)',
      },
      backgroundImage: {
        'clario-neon- subtle': 'linear-gradient(90deg, rgba(140,255,46,0.06), rgba(140,255,46,0.02))',
        'clario-neon': 'linear-gradient(90deg, #8cff2e, #74e528)'
      },
    },
  },
  plugins: [],
};

export default config;
