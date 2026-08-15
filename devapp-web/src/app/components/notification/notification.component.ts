import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NotificationService } from '../../services/notification.service';

@Component({
  selector: 'app-notification',
  templateUrl: './notification.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  styleUrls: ['./notification.component.css']
})
export class NotificationComponent {
  private readonly notificationService = inject(NotificationService);
  readonly notifications = toSignal(this.notificationService.getNotifications(), { initialValue: [] });

  removeNotification(id: string): void {
    this.notificationService.remove(id);
  }

  getIconForType(type: string): string {
    switch (type) {
      case 'success': return '✅';
      case 'error': return '❌';
      case 'warning': return '⚠️';
      case 'info': return 'ℹ️';
      default: return 'ℹ️';
    }
  }
}
