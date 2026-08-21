import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: process.env['WEB_URL'] || 'http://localhost:4200',
    supportFile: false,
    specPattern: 'cypress/e2e/**/*.cy.{js,ts}',
    env: {
      LIVE_CLUSTER: true,
      OIDC_USERNAME: process.env['OIDC_USERNAME'] || 'user',
      OIDC_PASSWORD: process.env['OIDC_PASSWORD'] || 'password',
    },
  },
});
