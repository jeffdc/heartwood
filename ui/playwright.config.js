// heartwood_ui's browser tests: the components in Chromium, on the preview
// (dev.exs) with its generated photos, so they need no network. Run from
// ui/ with `npm test`; the preview starts on its own.
import {defineConfig, devices} from "@playwright/test"

const port = 4310

export default defineConfig({
  testDir: "test/browser",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  use: {baseURL: `http://127.0.0.1:${port}`, trace: "retain-on-failure"},
  projects: [{name: "chromium", use: {...devices["Desktop Chrome"]}}],
  webServer: {
    command: "mix dev",
    env: {PORT: String(port), PREVIEW_PHOTOS: "local"},
    url: `http://127.0.0.1:${port}`,
    timeout: 180_000,
    reuseExistingServer: !process.env.CI
  }
})
