import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    // PWA: DataTicket instalável (celular/desktop) com atualização automática.
    // registerType 'autoUpdate' + skipWaiting garantem que cada deploy novo
    // substitui o app em cache imediatamente (sem usuários presos em versão
    // antiga — histórico de problemas de cache neste projeto).
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'],
      manifest: {
        name: 'DataTicket',
        short_name: 'DataTicket',
        description: 'Helpdesk DataTicket — DataTry Tecnologia e Negócios',
        lang: 'pt-BR',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        orientation: 'portrait',
        theme_color: '#2383e2',
        background_color: '#f3f4f6',
        icons: [
          { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: '/icons/icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        // SPA: navegações caem no index.html (rotas /tickets/..., /empresas...)
        navigateFallback: '/index.html',
        // NUNCA cachear a API (Railway é cross-origin e já fica de fora, mas
        // por segurança não interceptamos nada de /api)
        navigateFallbackDenylist: [/^\/api\//],
        globPatterns: ['**/*.{js,css,html,ico,png,svg,webmanifest}'],
        // Bundle é grande (~850 KB) — sobe o limite do precache
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
        cleanupOutdatedCaches: true,
        skipWaiting: true,
        clientsClaim: true,
      },
    }),
  ],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    proxy: {
      // All /api calls → Rails API (dev only)
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
      },
    },
  },
  preview: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
  },
})
