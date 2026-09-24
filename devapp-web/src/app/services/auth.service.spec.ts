import { beforeEach, describe, expect, it, type MockedObject, vi } from "vitest";
import { TestBed } from '@angular/core/testing';
import { AuthService } from './auth.service';
import { RUNTIME_CONFIG } from '../runtime-config';
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

describe('AuthService with runtime identity', () => {
    let oauth: {
        configure: ReturnType<typeof vi.fn>;
        setupAutomaticSilentRefresh: ReturnType<typeof vi.fn>;
        loadDiscoveryDocumentAndTryLogin: ReturnType<typeof vi.fn>;
        hasValidAccessToken: ReturnType<typeof vi.fn>;
        initCodeFlow: ReturnType<typeof vi.fn>;
        getAccessToken: ReturnType<typeof vi.fn>;
        logOut: ReturnType<typeof vi.fn>;
        events: Subject<unknown>;
    };

    beforeEach(() => {
        oauth = {
            configure: vi.fn(),
            setupAutomaticSilentRefresh: vi.fn(),
            loadDiscoveryDocumentAndTryLogin: vi.fn().mockResolvedValue(true),
            hasValidAccessToken: vi.fn().mockReturnValue(false),
            initCodeFlow: vi.fn(),
            getAccessToken: vi.fn().mockReturnValue('access-token'),
            logOut: vi.fn(),
            events: new Subject()
        };
        TestBed.configureTestingModule({
            providers: [
                { provide: OAuthService, useValue: oauth },
                { provide: RUNTIME_CONFIG, useValue: {
                    keycloakUrl: 'https://login.example.test/auth',
                    keycloakRealm: 'people',
                    keycloakClientId: 'devapp-browser'
                } }
            ]
        });
    });

    it('uses the supplied issuer and client while keeping the current browser origin', async () => {
        const service = TestBed.inject(AuthService);
        await firstValueFrom(service.ready$);
        expect(oauth.configure).toHaveBeenCalledWith(expect.objectContaining({
            issuer: 'https://login.example.test/auth/realms/people',
            clientId: 'devapp-browser',
            redirectUri: window.location.origin + '/',
            responseType: 'code'
        }));
        service.login();
        expect(oauth.initCodeFlow).toHaveBeenCalledOnce();
        expect(service.getToken()).toBe('access-token');
        service.logout();
        expect(oauth.logOut).toHaveBeenCalledOnce();
    });

    it('keeps authentication closed and exposes an error after discovery failure', async () => {
        oauth.loadDiscoveryDocumentAndTryLogin.mockRejectedValue(new Error('Identity provider unavailable'));
        const warning = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
        try {
            const service = TestBed.inject(AuthService);
            await firstValueFrom(service.ready$);
            expect(service.isLoggedIn()).toBe(false);
            await expect(firstValueFrom(service.authStatus$)).resolves.toBe('error');
            service.login();
            expect(oauth.initCodeFlow).not.toHaveBeenCalled();
        } finally {
            warning.mockRestore();
        }
    });
});
