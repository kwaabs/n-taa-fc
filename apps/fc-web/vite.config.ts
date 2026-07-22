import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    host: "localhost",
    port: 5356, // stack range (fc-api=5355 … martin=5360)
    strictPort: true,
    proxy: {
      "/api": "http://localhost:5355",
      "/health": "http://localhost:5355",
      "/gotrue": {
        target: "http://localhost:5354",
        rewrite: (path) => path.replace(/^\/gotrue/, ""),
      },
    },
  },
})