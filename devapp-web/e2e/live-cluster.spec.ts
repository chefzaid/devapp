import { expect, test } from '@playwright/test';

const targetsBmCluster = process.env['WEB_URL']?.includes('devapp.swirlit.dev') ?? false;
const realm = process.env['OIDC_REALM'] ?? (targetsBmCluster ? 'swirlit' : 'devapp');
const username = process.env['OIDC_USERNAME'] ?? (targetsBmCluster ? 'zaid' : 'user');
const password = process.env['OIDC_PASSWORD'] ?? (targetsBmCluster ? '' : 'password');
const exerciseWrites = process.env['E2E_EXERCISE_WRITES'] === 'true';

interface CreatedOrder {
  id: number;
}

test('authenticates through Keycloak and loads both secured workflows', async (
  { page },
  testInfo,
) => {
  if (!password) {
    throw new Error('OIDC_PASSWORD is required for BM-cluster authentication');
  }
  const discoveryResponse = page.waitForResponse(
    (response) =>
      new URL(response.url()).pathname.endsWith(
        `/realms/${realm}/.well-known/openid-configuration`,
      ),
    { timeout: 15_000 },
  );

  await page.goto('/login');
  expect((await discoveryResponse).status()).toBe(200);

  // Production starts OIDC immediately. Local environments retain the
  // explicit button so the same test covers both supported entry paths.
  const loginButton = page.getByRole('button', { name: 'Login with SSO' });
  const redirectedAutomatically = await Promise.race([
    page
      .waitForURL((url) => url.pathname.includes(`/auth/realms/${realm}/`))
      .then(() => true),
    loginButton.waitFor({ state: 'visible' }).then(() => false),
  ]);
  if (!redirectedAutomatically) {
    await expect(page.getByText('One small app.')).toBeVisible();
    await expect(loginButton).toBeEnabled();
    await Promise.all([
      page.waitForURL((url) => url.pathname.includes(`/auth/realms/${realm}/`)),
      loginButton.click(),
    ]);
  }

  await expect(page.locator('#username')).toBeVisible();
  await page.locator('#username').fill(username);
  await page.locator('#password').fill(password);
  await Promise.all([
    page.waitForURL((url) => url.pathname === '/users'),
    page.locator('#kc-login').click(),
  ]);

  await expect(
    page.getByRole('heading', { level: 1, name: 'People behind the requests.' }),
  ).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: 'User directory' })).toBeVisible();

  if ((await page.locator('.user-item').count()) === 0 && exerciseWrites) {
    const userKey = `e2e-${testInfo.project.name}-${Date.now()}`;
    await page.getByLabel('Display name').fill(`Playwright ${testInfo.project.name}`);
    await page.getByLabel('Username').fill(userKey);
    await page.getByLabel('Email address').fill(`${userKey}@example.test`);

    const createdUserResponse = page.waitForResponse(
      (response) =>
        response.url().endsWith('/api/users') && response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'Create User' }).click();
    expect((await createdUserResponse).status()).toBe(201);
  }

  await expect(page.locator('.user-item').first()).toBeVisible();

  await page.getByRole('link', { name: 'Orders' }).click();
  await expect(page).toHaveURL((url) => url.pathname === '/orders');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Orders that travel the stack.' }),
  ).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: 'Create an order' })).toBeVisible();

  if (exerciseWrites) {
    const ownerSelect = page.getByLabel('Order owner');
    await expect.poll(() => ownerSelect.locator('option').count()).toBeGreaterThan(1);
    await ownerSelect.selectOption({ index: 1 });
    await page.getByLabel('Product ID').fill('1001');

    const createdOrderResponse = page.waitForResponse(
      (response) =>
        response.url().endsWith('/api/orders') && response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'Create Order' }).click();
    const orderResponse = await createdOrderResponse;
    expect(orderResponse.status()).toBe(201);
    const createdOrder = (await orderResponse.json()) as CreatedOrder;
    const orderCard = page.locator('.order-card').filter({
      has: page.getByRole('heading', { level: 3, name: `#${createdOrder.id}` }),
    });

    await expect(orderCard).toBeVisible();
    await expect
      .poll(
        async () => {
          const refreshedOrders = page.waitForResponse(
            (response) =>
              response.url().endsWith('/api/orders') && response.request().method() === 'GET',
          );
          await page.getByRole('button', { name: 'Refresh' }).click();
          expect((await refreshedOrders).status()).toBe(200);
          return (await orderCard.locator('.order-status').textContent())?.trim();
        },
        { timeout: 30_000 },
      )
      .toBe('APPROVED');
  }
});
