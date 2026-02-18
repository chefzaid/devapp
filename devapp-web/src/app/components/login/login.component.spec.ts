import { ComponentFixture, TestBed } from '@angular/core/testing';
import { LoginComponent } from './login.component';
import { ReactiveFormsModule, FormsModule } from '@angular/forms';
import { AuthService } from '../../services/auth.service';
import { Router } from '@angular/router';
import { of, throwError } from 'rxjs';
import { CommonModule } from '@angular/common';

describe('LoginComponent', () => {
  let component: LoginComponent;
  let fixture: ComponentFixture<LoginComponent>;
  let authServiceSpy: jasmine.SpyObj<AuthService>;
  let routerSpy: jasmine.SpyObj<Router>;

  beforeEach(async () => {
    const authSpy = jasmine.createSpyObj('AuthService', ['login']);
    const rSpy = jasmine.createSpyObj('Router', ['navigate']);

    await TestBed.configureTestingModule({
      imports: [LoginComponent, ReactiveFormsModule, FormsModule, CommonModule],
      providers: [
        { provide: AuthService, useValue: authSpy },
        { provide: Router, useValue: rSpy }
      ]
    }).compileComponents();

    authServiceSpy = TestBed.inject(AuthService) as jasmine.SpyObj<AuthService>;
    routerSpy = TestBed.inject(Router) as jasmine.SpyObj<Router>;
    fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should invalidate the form when empty', () => {
    expect(component.loginForm.valid).toBeFalsy();
  });

  it('should validate the form when filled', () => {
    component.loginForm.controls['username'].setValue('test');
    component.loginForm.controls['password'].setValue('password');
    expect(component.loginForm.valid).toBeTruthy();
  });

  it('should call authService.login on submit', () => {
    authServiceSpy.login.and.returnValue(of({ token: 'fake-token' }));
    component.loginForm.controls['username'].setValue('test');
    component.loginForm.controls['password'].setValue('password');

    component.onSubmit();

    expect(authServiceSpy.login).toHaveBeenCalledWith({ username: 'test', password: 'password' });
    expect(routerSpy.navigate).toHaveBeenCalledWith(['/']);
  });

  it('should set error message on login failure', () => {
    authServiceSpy.login.and.returnValue(throwError(() => new Error('Login failed')));
    component.loginForm.controls['username'].setValue('test');
    component.loginForm.controls['password'].setValue('wrong');

    component.onSubmit();

    expect(component.error).toBe('Invalid username or password');
  });
});
