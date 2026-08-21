import { expect, test } from '@playwright/test';

const username = process.env['OIDC_USERNAME'] ?? 'user';
const password = process.env['OIDC_PASSWORD'] ?? 'password';
const exerciseWrites = process.env['E2E_EXERCISE_WRITES'] === 'true';

interface CreatedOrder {
  id: number;
}

test('authenticates through Keycloak and loads both secured workflows', async (
  { page },
  testInfo,
) => {
  const discoveryResponse = page.waitForResponse(
    (response) =>
      new URL(response.url()).pathname.endsWith(
        '/realms/devapp/.well-known/openid-configuration',
      ),
    { timeout: 15_000 },
  );

  await page.goto('/login');
  await expect(page.getByText('One small app.')).toBeVisible();
  expect((await discoveryResponse).status()).toBe(200);

  const loginButton = page.getByRole('button', { name: 'Login with SSO' });
  await expect(loginButton).toBeEnabled();
  await Promise.all([
    page.waitForURL((url) => url.pathname.includes('/auth/realms/devapp/')),
    loginButton.click(),
  ]);

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
