import { defineConfig } from 'vite'

export default defineConfig({
  // Use relative paths for assets so they can be loaded via file:// protocol in the screensaver wrapper
  base: './',
})
