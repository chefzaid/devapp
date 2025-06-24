
import { Component } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';
import { NotificationComponent } from './components/notification/notification.component';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  standalone: true,
  imports: [RouterOutlet, RouterLink, NotificationComponent]
})
export class AppComponent {
  title = 'DevApp Web';
}
                