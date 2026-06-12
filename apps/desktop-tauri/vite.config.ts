import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { viteWatchIgnored } from "./src/config/viteWatchIgnores";

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    strictPort: true,
    port: 1420,
    watch: {
      ignored: viteWatchIgnored,
    },
  },
  envPrefix: ["VITE_", "TAURI_"],
  build: {
    target: "es2020",
    minify: false,
    sourcemap: true,
  },
});
