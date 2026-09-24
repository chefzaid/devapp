import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter, Routes } from '@angular/router';
import { provideHttpClient, withInterceptors, withXhr } from '@angular/common/http';
import { provideOAuthClient } from 'angular-oauth2-oidc';
import { AppComponent } from './app/app.component';
import { authGuard } from './app/guards/auth.guard';
import { authInterceptor } from './app/interceptors/auth.interceptor';
import { loadRuntimeConfig, RUNTIME_CONFIG } from './app/runtime-config';
import { environment } from './environments/environment';

const routes: Routes = [
  {
    path: 'login',
    loadComponent: () => import('./app/components/login/login.component').then(module => module.LoginComponent)
  },
  {
    path: 'users',
    loadComponent: () => import('./app/user/user.component').then(module => module.UserComponent),
    canActivate: [authGuard]
  },
  {
    path: 'orders',
    loadComponent: () => import('./app/order/order.component').then(module => module.OrderComponent),
    canActivate: [authGuard]
  },
  { path: '', redirectTo: '/users', pathMatch: 'full' }
];

async function startApplication(): Promise<void> {
  const runtimeConfig = environment.authEnabled
    ? await loadRuntimeConfig(window.location.origin)
    : null;
  await bootstrapApplication(AppComponent, {
    providers: [
      { provide: RUNTIME_CONFIG, useValue: runtimeConfig },
      provideRouter(routes),
      provideHttpClient(withXhr(), withInterceptors([authInterceptor])),
      provideOAuthClient()
    ]
  });
}

startApplication().catch((error: unknown) => {
  console.error('DevApp startup failed', error);
  const root = document.querySelector('app-root');
  if (root) {
    root.setAttribute('role', 'alert');
    root.textContent = 'DevApp could not start. Please reload or contact your administrator.';
  }
});
