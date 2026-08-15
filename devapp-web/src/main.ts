import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter, Routes } from '@angular/router';
import { provideHttpClient, withInterceptors, withXhr } from '@angular/common/http';
import { provideOAuthClient } from 'angular-oauth2-oidc';
import { AppComponent } from './app/app.component';
import { authGuard } from './app/guards/auth.guard';
import { authInterceptor } from './app/interceptors/auth.interceptor';

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

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(withXhr(), withInterceptors([authInterceptor])),
    provideOAuthClient()
  ]
}).catch(err => console.error(err));
