import { defineConfig } from "vite";

export default defineConfig({
  base: "/workspace-ui/",
  build: {
    outDir: "../public/workspace-ui",
    emptyOutDir: true,
    manifest: true,
    rollupOptions: { input: "src/main.jsx" }
  }
});
