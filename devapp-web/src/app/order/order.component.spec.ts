import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { OrderComponent } from './order.component';
import { OrderService } from '../services/order.service';
import { UserService } from '../services/user.service';

describe('OrderComponent', () => {
  let component: OrderComponent;
  let fixture: ComponentFixture<OrderComponent>;
  let orderServiceSpy: jasmine.SpyObj<OrderService>;
  let userServiceSpy: jasmine.SpyObj<UserService>;

  beforeEach(() => {
    orderServiceSpy = jasmine.createSpyObj('OrderService', ['getAllOrders', 'createOrder']);
    userServiceSpy = jasmine.createSpyObj('UserService', ['getAllUsers']);
    orderServiceSpy.getAllOrders.and.returnValue(of([]));
    userServiceSpy.getAllUsers.and.returnValue(of([]));

    TestBed.configureTestingModule({
      imports: [OrderComponent],
      providers: [
        { provide: OrderService, useValue: orderServiceSpy },
        { provide: UserService, useValue: userServiceSpy }
      ]
    });
    fixture = TestBed.createComponent(OrderComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load orders successfully', () => {
    const orders = [{ id: 1, user: { id: 1, name: 'u1' }, productId: 10, status: 'PENDING' as const }];
    orderServiceSpy.getAllOrders.and.returnValue(of(orders));

    component.loadOrders();

    expect(component.orders).toEqual(orders);
    expect(component.loading).toBeFalse();
    expect(component.error).toBeNull();
  });

  it('should handle load orders failure', () => {
    orderServiceSpy.getAllOrders.and.returnValue(throwError(() => 'order load failed'));

    component.loadOrders();

    expect(component.error).toBe('order load failed');
    expect(component.loading).toBeFalse();
  });

  it('should load users successfully', () => {
    const users = [{ id: 1, name: 'Alice' }];
    userServiceSpy.getAllUsers.and.returnValue(of(users));

    component.loadUsers();

    expect(component.users).toEqual(users);
    expect(component.loadingUsers).toBeFalse();
  });

  it('should handle load users failure', () => {
    userServiceSpy.getAllUsers.and.returnValue(throwError(() => 'user load failed'));

    component.loadUsers();

    expect(component.loadingUsers).toBeFalse();
  });

  it('should validate required fields before creating order', () => {
    component.newOrder = { user: { id: 0, name: '' }, productId: 0, status: 'PENDING' };

    component.createOrder();

    expect(component.error).toBe('Please select a user and enter a product ID');
    expect(orderServiceSpy.createOrder).not.toHaveBeenCalled();
  });

  it('should create order successfully', () => {
    component.newOrder = { user: { id: 1, name: 'Alice' }, productId: 123, status: 'PENDING' };
    orderServiceSpy.createOrder.and.returnValue(of({ id: 4, user: { id: 1, name: 'Alice' }, productId: 123, status: 'APPROVED' }));

    component.createOrder();

    expect(component.orders.length).toBe(1);
    expect(component.creating).toBeFalse();
    expect(component.newOrder.user.id).toBe(0);
  });

  it('should handle create order failure', () => {
    component.newOrder = { user: { id: 1, name: 'Alice' }, productId: 123, status: 'PENDING' };
    orderServiceSpy.createOrder.and.returnValue(throwError(() => 'create order failed'));

    component.createOrder();

    expect(component.error).toBe('create order failed');
    expect(component.creating).toBeFalse();
  });

  it('should update selected user when user exists', () => {
    component.users = [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }];

    component.onUserChange(2);

    expect(component.newOrder.user.id).toBe(2);
    expect(component.newOrder.user.name).toBe('Bob');
  });

  it('should keep current user when selected user does not exist', () => {
    component.users = [{ id: 1, name: 'Alice' }];
    component.newOrder.user = { id: 1, name: 'Alice' };

    component.onUserChange(99);

    expect(component.newOrder.user.id).toBe(1);
  });
});
