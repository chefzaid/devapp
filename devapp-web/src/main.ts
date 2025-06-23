
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter, Routes } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { UserComponent } from './app/user/user.component';
import { OrderComponent } from './app/order/order.component';
import { UserService } from './app/services/user.service';
import { OrderService } from './app/services/order.service';
import { environment } from './environments/environment';

const routes: Routes = [
  { path: 'users', component: UserComponent },
  { path: 'orders', component: OrderComponent },
  { path: '', redirectTo: '/users', pathMatch: 'full' }
];

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(),
    UserService,
    OrderService
  ]
}).catch(err => console.error(err));
            