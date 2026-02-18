import { Injectable } from '@angular/core';
import { OAuthService, AuthConfig } from 'angular-oauth2-oidc';
import { environment } from '../../environments/environment';
import { BehaviorSubject, Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private isLoggedInSubject = new BehaviorSubject<boolean>(false);
  public isLoggedIn$ = this.isLoggedInSubject.asObservable();

  constructor(private oauthService: OAuthService) {
    this.configure();
  }

  private configure() {
    const authConfig: AuthConfig = {
      issuer: window.location.origin + environment.keycloakUrl + '/realms/devapp',
      redirectUri: window.location.origin + '/',
      clientId: 'devapp-web',
      responseType: 'code',
      scope: 'openid profile email',
      showDebugInformation: true,
      requireHttps: false
    };
    this.oauthService.configure(authConfig);
    this.oauthService.loadDiscoveryDocumentAndTryLogin().then(() => {
        this.isLoggedInSubject.next(this.oauthService.hasValidAccessToken());
    });
    this.oauthService.events.subscribe(e => {
       this.isLoggedInSubject.next(this.oauthService.hasValidAccessToken());
    });
  }

  login() {
    this.oauthService.initCodeFlow();
  }

  logout() {
    this.oauthService.logOut();
    this.isLoggedInSubject.next(false);
  }

  getToken(): string {
    return this.oauthService.getAccessToken();
  }

  isLoggedIn(): boolean {
      return this.oauthService.hasValidAccessToken();
  }
}
