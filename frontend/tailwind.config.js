/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#faf5ff',
          100: '#f3e8ff',
          200: '#e9d5ff',
          300: '#d8b4fe',
          400: '#c084fc',
          500: '#a855f7',
          600: '#9333ea',
          700: '#7c3aed',
          800: '#6b21a8',
          900: '#581c87',
          950: '#3b0764',
        },
        panel: {
          dark: '#0f0a1a',
          darker: '#080510',
          card: '#1a1025',
          border: '#2d2240',
        },
        accent: {
          zomboid: '#4ade80',
          arma: '#f97316',
          minecraft: '#84cc16',
        }
      },
    },
  },
  plugins: [],
}
