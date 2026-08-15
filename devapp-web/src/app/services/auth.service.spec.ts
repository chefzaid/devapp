import { beforeEach, describe, expect, it, type MockedObject, vi } from "vitest";
import { TestBed } from '@angular/core/testing';
import { AuthService } from './auth.service';
import { OAuthService } from 'angular-oauth2-oidc';
import { firstValueFrom, Subject } from 'rxjs';

describe('AuthService', () => {
    let service: AuthService;
    let oauthServiceSpy: MockedObject<OAuthService>;

    beforeEach(() => {
        const spy = {
            configure: vi.fn().mockName("OAuthService.configure"),
            setupAutomaticSilentRefresh: vi.fn().mockName("OAuthService.setupAutomaticSilentRefresh"),
            loadDiscoveryDocumentAndTryLogin: vi.fn().mockName("OAuthService.loadDiscoveryDocumentAndTryLogin"),
            hasValidAccessToken: vi.fn().mockName("OAuthService.hasValidAccessToken"),
            getAccessToken: vi.fn().mockName("OAuthService.getAccessToken"),
            initCodeFlow: vi.fn().mockName("OAuthService.initCodeFlow"),
            logOut: vi.fn().mockName("OAuthService.logOut"),
            events: new Subject()
        };
        spy.loadDiscoveryDocumentAndTryLogin.mockResolvedValue(true);
        spy.hasValidAccessToken.mockReturnValue(false);

        TestBed.configureTestingModule({
            providers: [
                AuthService,
                { provide: OAuthService, useValue: spy }
            ]
        });
        oauthServiceSpy = TestBed.inject(OAuthService) as MockedObject<OAuthService>;
        service = TestBed.inject(AuthService);
    });

    it('should be created', () => {
        expect(service).toBeTruthy();
    });

    it('should be ready immediately with authentication disabled locally', async () => {
        await expect(firstValueFrom(service.ready$)).resolves.toBeUndefined();
        expect(service.isLoggedIn()).toBe(true);
        expect(oauthServiceSpy.configure).not.toHaveBeenCalled();
    });

    it('should call initCodeFlow on login', () => {
        service.login();
        expect(oauthServiceSpy.initCodeFlow).not.toHaveBeenCalled();
    });

    it('should call logOut on logout', () => {
        service.logout();
        expect(oauthServiceSpy.logOut).not.toHaveBeenCalled();
    });

    it('should return token from oauthService', () => {
        expect(service.getToken()).toBe('');
    });

    it('should consider local development authenticated', () => {
        expect(service.isLoggedIn()).toBe(true);
        expect(oauthServiceSpy.hasValidAccessToken).not.toHaveBeenCalled();
    });
});
