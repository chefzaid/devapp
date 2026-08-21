import { Injectable } from '@angular/core';
import { OAuthService, AuthConfig } from 'angular-oauth2-oidc';
import { environment } from '../../environments/environment';
import { BehaviorSubject, ReplaySubject } from 'rxjs';

export type AuthStatus = 'loading' | 'ready' | 'error';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  readonly authEnabled = environment.authEnabled;
  private readonly isLoggedInSubject = new BehaviorSubject<boolean>(!this.authEnabled);
  private readonly authStatusSubject = new BehaviorSubject<AuthStatus>(this.authEnabled ? 'loading' : 'ready');
  private readonly readySubject = new ReplaySubject<void>(1);
  readonly isLoggedIn$ = this.isLoggedInSubject.asObservable();
  readonly authStatus$ = this.authStatusSubject.asObservable();
  readonly ready$ = this.readySubject.asObservable();

  constructor(private oauthService: OAuthService) {
    this.configure();
  }

  private configure(): void {
    if (!this.authEnabled) {
      this.readySubject.next();
      this.readySubject.complete();
      return;
    }

    const authConfig: AuthConfig = {
      issuer: window.location.origin + environment.keycloakUrl + `/realms/${environment.keycloakRealm}`,
      redirectUri: window.location.origin + '/',
      clientId: 'devapp-web',
      responseType: 'code',
      scope: 'openid profile email',
      showDebugInformation: false,
      requireHttps: window.location.protocol === 'https:'
    };
    this.oauthService.configure(authConfig);
    this.oauthService.setupAutomaticSilentRefresh();
    this.oauthService.events.subscribe(() => {
      this.isLoggedInSubject.next(this.oauthService.hasValidAccessToken());
    });
    this.oauthService.loadDiscoveryDocumentAndTryLogin().then(() => {
      this.isLoggedInSubject.next(this.oauthService.hasValidAccessToken());
      this.authStatusSubject.next('ready');
    }).catch((error: unknown) => {
      console.warn('OpenID Connect discovery failed', error);
      this.isLoggedInSubject.next(false);
      this.authStatusSubject.next('error');
    }).finally(() => {
      this.readySubject.next();
      this.readySubject.complete();
    });
  }

  login(): void {
    if (this.authEnabled && this.authStatusSubject.value === 'ready') {
      this.oauthService.initCodeFlow();
    }
  }

  logout(): void {
    if (this.authEnabled) {
      this.oauthService.logOut();
      this.isLoggedInSubject.next(false);
    }
  }

  getToken(): string {
    return this.authEnabled ? this.oauthService.getAccessToken() : '';
  }

  isLoggedIn(): boolean {
    return !this.authEnabled || this.oauthService.hasValidAccessToken();
  }
}
