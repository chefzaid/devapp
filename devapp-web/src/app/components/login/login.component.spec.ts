import { beforeEach, describe, expect, it, type MockedObject, vi } from "vitest";
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { LoginComponent } from './login.component';
import { AuthService } from '../../services/auth.service';
import { CommonModule } from '@angular/common';
import { of } from 'rxjs';

describe('LoginComponent', () => {
    let component: LoginComponent;
    let fixture: ComponentFixture<LoginComponent>;
    let authServiceSpy: MockedObject<AuthService>;

    beforeEach(async () => {
        const authSpy = {
            login: vi.fn().mockName("AuthService.login"),
            authStatus$: of('ready' as const)
        };

        await TestBed.configureTestingModule({
            imports: [LoginComponent, CommonModule],
            providers: [
                { provide: AuthService, useValue: authSpy }
            ]
        }).compileComponents();

        authServiceSpy = TestBed.inject(AuthService) as MockedObject<AuthService>;
        fixture = TestBed.createComponent(LoginComponent);
        component = fixture.componentInstance;
        fixture.detectChanges();
    });

    it('should create', () => {
        expect(component).toBeTruthy();
    });

    it('should call authService.login on login', () => {
        component.login();
        expect(authServiceSpy.login).toHaveBeenCalled();
    });
});
