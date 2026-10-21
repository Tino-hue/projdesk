import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: '/projdesk/',
  server: {
    port: 3000,
    host: '127.0.0.1',
  },
});

