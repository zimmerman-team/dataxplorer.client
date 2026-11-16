import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import svgr from "vite-plugin-svgr";
import path from "path";

// Docker builds (RUNTIME_ENV=1, see Dockerfile) read the VITE_* settings when
// the page loads, from env.js, instead of baking them in at build time. The
// container writes env.js when it starts, so one image runs in any environment.
// Local development (yarn dev) keeps reading .env as usual.
const runtimeEnv = (): Plugin => ({
  name: "dx-runtime-env",
  enforce: "pre",
  transform(code, id) {
    if (id.includes("node_modules") || !code.includes("import.meta.env.VITE_")) {
      return null;
    }
    return {
      code: code.replace(
        /import\.meta\.env\.(VITE_[A-Z0-9_]+)/g,
        "(window.__DX_ENV__ || {}).$1",
      ),
      map: null,
    };
  },
  transformIndexHtml: (html) =>
    html.replace("<head>", '<head>\n    <script src="/env.js"></script>'),
});

// https://vite.dev/config/
export default defineConfig({
  server: {
    port: 3000,
    host: "0.0.0.0",
  },
  plugins: [
    react({
      babel: {
        plugins: ["babel-plugin-styled-components"],
      },
    }),
    svgr(),
    ...(process.env.RUNTIME_ENV ? [runtimeEnv()] : []),
  ],
  resolve: {
    alias: [{ find: "@app", replacement: path.resolve(__dirname, "src/app") }],
  },
  build: {
    outDir: "build",
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis",
      },
    },
  },
});
