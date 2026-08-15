describe('authentication entry point', () => {
  it('loads the SSO login screen', () => {
    cy.visit('/login');
    cy.contains('Login with SSO');
  });
});
