import { TestBed } from '@angular/core/testing';
import { NotificationService } from './notification.service';

describe('NotificationService', () => {
  let service: NotificationService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(NotificationService);
  });

  it('should add and remove a notification after duration', (done) => {
    let notifications: any[] = [];
    service.getNotifications().subscribe(value => (notifications = value));

    service.show('success', 'saved', 10);
    expect(notifications.length).toBe(1);
    const id = notifications[0].id;

    setTimeout(() => {
      expect(notifications.find(n => n.id === id)).toBeUndefined();
      done();
    }, 20);
  });

  it('should keep notification when duration is zero until manually removed', () => {
    let notifications: any[] = [];
    service.getNotifications().subscribe(value => (notifications = value));

    service.show('info', 'persistent', 0);
    expect(notifications.length).toBe(1);

    service.remove(notifications[0].id);
    expect(notifications.length).toBe(0);
  });

  it('should create notifications via helper methods and clear all', () => {
    let notifications: any[] = [];
    service.getNotifications().subscribe(value => (notifications = value));

    service.success('ok', 0);
    service.error('bad', 0);
    service.warning('warn', 0);
    service.info('info', 0);

    expect(notifications.map(n => n.type)).toEqual(['success', 'error', 'warning', 'info']);

    service.clear();
    expect(notifications.length).toBe(0);
  });
});
