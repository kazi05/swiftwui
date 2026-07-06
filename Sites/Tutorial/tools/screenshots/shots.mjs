// Screenshot driver (spec §8): per frame — build the sample through the CLI
// (isolated .build-wasm; NEVER raw `swift package js`), serve dist, run the
// frame's actions, save a 960×544@2x PNG into Assets/screens.
import { chromium } from '@playwright/test';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { shots } from './shots.config.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const SITE = resolve(HERE, '../..');            // Sites/Tutorial
const REPO = resolve(SITE, '../..');            // SwiftWUI checkout
const OUT = join(SITE, 'Assets/screens');
const PORT = 4173;

function swiftwui(args, cwd) {
  execFileSync('swift', ['run', '--package-path', REPO, 'swiftwui', ...args],
               { cwd, stdio: 'inherit' });
}

function serveDist(cwd) {
  const proc = spawn('swift',
    ['run', '--package-path', REPO, 'swiftwui', 'serve', 'dist', '--port', String(PORT)],
    { cwd, stdio: 'inherit', detached: true });
  return proc;
}

function killServer(server) {
  // SwiftPM runs the executable in its OWN process group — killing swift-run's
  // group leaves the swiftwui listener orphaned and the port busy, so the next
  // frame silently screenshots the WRONG app. Kill by port: only our server
  // ever binds it.
  try { process.kill(-server.pid, 'SIGTERM'); } catch { try { server.kill(); } catch {} }
  try { execFileSync('bash', ['-c', `lsof -ti :${PORT} | xargs kill 2>/dev/null; true`]); } catch {}
}

async function waitForServer(url, tries = 60) {
  for (let i = 0; i < tries; i++) {
    try { const r = await fetch(url); if (r.ok) return; } catch {}
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error(`server never came up at ${url}`);
}

const browser = await chromium.launch();
for (const shot of shots) {
  let projectDir;
  let scratch;
  if (shot.scaffold) {
    scratch = mkdtempSync(join(tmpdir(), 'tut-scaffold-'));
    execFileSync('swift', ['run', '--package-path', REPO, 'swiftwui',
                           'init', 'HelloWUI', '--swiftwui-path', REPO],
                 { cwd: scratch, stdio: 'inherit' });
    projectDir = join(scratch, 'HelloWUI');
  } else {
    projectDir = join(REPO, shot.project);
  }

  swiftwui(['build', '--out', 'dist'], projectDir);
  if (shot.ssg) {
    execFileSync('swift', ['run', shot.project.split('/').pop(), 'ssg', '--out', 'dist'],
                 { cwd: projectDir, stdio: 'inherit' });
  }

  const server = serveDist(projectDir);
  try {
    await waitForServer(`http://localhost:${PORT}${shot.route}`);
    const page = await browser.newPage({
      viewport: { width: 960, height: 544 },
      deviceScaleFactor: 2,
    });
    await page.goto(`http://localhost:${PORT}${shot.route}`);
    // build-only dists cold-mount (data-swui-mounted); data-swui-hydrated is
    // set ONLY on ssg adoption. mounted fires on both paths = "runtime live".
    await page.waitForSelector('[data-swui-mounted="true"]', { timeout: 30_000 });
    if (shot.actions) await shot.actions(page);
    await page.screenshot({ path: join(OUT, `${shot.name}.png`) });
    await page.close();
    console.log(`shot: ${shot.name}.png`);
  } finally {
    killServer(server);
    if (scratch) rmSync(scratch, { recursive: true, force: true });
  }
}
await browser.close();
