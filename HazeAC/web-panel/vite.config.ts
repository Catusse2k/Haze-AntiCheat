import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    strictPort: true,
    hmr: false
  },
  build: {
    outDir: 'nui',
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: 'hazeac-panel.js',
        chunkFileNames: 'hazeac-panel.[name].js',
        assetFileNames: 'hazeac-panel.[name].[ext]'
      }
    }
  }
})
