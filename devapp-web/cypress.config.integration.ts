import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: process.env['WEB_URL'] || 'http://localhost:4200',
    supportFile: false,
    specPattern: 'cypress/e2e/**/*.cy.{js,ts}',
  },
});
