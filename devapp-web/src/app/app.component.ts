import { Component } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';
import { NotificationComponent } from './components/notification/notification.component';
import { AuthService } from './services/auth.service';
import { CommonModule } from '@angular/common';
import { Observable } from 'rxjs';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  standalone: true,
  imports: [RouterOutlet, RouterLink, NotificationComponent, CommonModule]
})
export class AppComponent {
  title = 'DevApp Web';
  isLoggedIn$: Observable<boolean>;

  constructor(public authService: AuthService) {
    this.isLoggedIn$ = this.authService.isLoggedIn$;
  }

  logout() {
    this.authService.logout();
  }
}
