import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    {
      name: 'screensaver-classic-build',
      transformIndexHtml(html) {
        // 1. Remove rel="modulepreload" links entirely to prevent CORS issues over file://
        let cleanHtml = html.replace(/<link rel="modulepreload"[^>]*>/g, '');
        // 2. Remove type="module" and crossorigin from script tags
        cleanHtml = cleanHtml.replace(/type="module" crossorigin/g, '');
        cleanHtml = cleanHtml.replace(/type="module"/g, '');
        // 3. Remove crossorigin from any remaining script or link tags
        cleanHtml = cleanHtml.replace(/crossorigin=""/g, '');
        cleanHtml = cleanHtml.replace(/crossorigin/g, '');
        return cleanHtml;
      }
    }
  ],
  base: './',
  build: {
    outDir: 'dist',
    minify: true,
    assetsDir: 'assets',
    cssCodeSplit: false, // Force all CSS into a single style file
    rollupOptions: {
      input: {
        screensaver: 'screensaver.html'
      },
      output: {
        format: 'iife', // Target classic self-executing IIFE format
        name: 'MyUniverse', // Expose as global namespace MyUniverse
        inlineDynamicImports: true, // Force Rollup to merge dynamic imports and avoid code splitting
      }
    }
  }
});
