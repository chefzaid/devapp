import { expect, test } from '@playwright/test';

test('loads the SSO login screen', async ({ page }) => {
  await page.goto('/login');

  await expect(page.getByText('One small app.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Login with SSO' })).toBeVisible();
});
