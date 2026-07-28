import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@map-symbols": path.resolve(__dirname, "../../shared/map-symbols"),
    },
  },
  server: {
    host: "localhost",
    port: 5357, // stack range (fc-web=5356 … martin=5360)
    strictPort: true,
    fs: {
      allow: [path.resolve(__dirname, "../..")],
    },
    proxy: {
      "/gotrue": {
        target: "http://localhost:5354",
        rewrite: (p) => p.replace(/^\/gotrue/, ""),
      },
    },
  },
});
