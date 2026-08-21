describe('live cluster acceptance', () => {
  it('authenticates through Keycloak and loads both secured workflows', () => {
    cy.intercept('GET', '**/realms/devapp/.well-known/openid-configuration').as('oidcDiscovery');
    cy.visit('/login');
    cy.contains('One small app.');
    cy.wait('@oidcDiscovery', { timeout: 15_000 }).its('response.statusCode').should('eq', 200);
    cy.contains('button', 'Login with SSO').should('be.enabled').click();

    cy.location('pathname', { timeout: 20_000 }).should('include', '/auth/realms/devapp/');
    cy.env<{ OIDC_USERNAME: string; OIDC_PASSWORD: string }>(['OIDC_USERNAME', 'OIDC_PASSWORD'])
      .then(({ OIDC_USERNAME, OIDC_PASSWORD }) => {
        cy.get('#username').type(OIDC_USERNAME || 'user');
        cy.get('#password').type(OIDC_PASSWORD || 'password', { log: false });
        cy.get('#kc-login').click();
      });

    cy.location('pathname', { timeout: 20_000 }).should('eq', '/users');
    cy.contains('h1', 'People behind the requests.');
    cy.contains('h2', 'User directory');
    cy.get('.user-item', { timeout: 15_000 }).should('have.length.at.least', 1);

    cy.contains('a', 'Orders').click();
    cy.location('pathname').should('eq', '/orders');
    cy.contains('h1', 'Orders that travel the stack.');
    cy.contains('h2', 'Create an order');
  });
});
