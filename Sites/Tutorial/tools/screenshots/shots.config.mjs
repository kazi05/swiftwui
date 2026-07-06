// Frame manifest (spec §8). `project` is repo-relative; `scaffold: true`
// generates a fresh basic-template app with `swiftwui init` instead.
// `ssg: true` runs the sample's ssg entry before serving (prerendered shot).
export const shots = [
  {
    name: 'counter-3',
    project: 'Sites/Tutorial/Samples/ShipCounter',   // runs the EXACT ch4 code (pinned by SampleSyncTests)
    route: '/',
    actions: async (page) => {
      await page.getByRole('button', { name: '+' }).click({ clickCount: 3 });
      await page.getByText('Count: 3').waitFor();
    },
  },
  {
    name: 'first-project',
    scaffold: true,                                   // swiftwui init HelloWUI --template basic
    route: '/',
    actions: async (page) => { await page.getByText('Count:').waitFor(); },
  },
  {
    name: 'style-bubble',
    project: 'Sites/Tutorial/Samples/StyleBubble',
    route: '/',
    actions: async (page) => { await page.getByText('Knock, knock.').waitFor(); },
  },
  {
    name: 'chat-router',
    project: 'Sites/Tutorial/Samples/ChatRouter',
    route: '/chat',
    actions: async (page) => {
      await page.locator('input').fill('Hello from Swift');
      await page.getByRole('button', { name: 'Send' }).click();
      await page.getByText('Hello from Swift').waitFor();
    },
  },
  {
    name: 'ship-static',
    project: 'Sites/Tutorial/Samples/ShipCounter',
    route: '/about',
    ssg: true,
    actions: async (page) => { await page.getByText('prerendered at build time').waitFor(); },
  },
];
