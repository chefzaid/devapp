import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { OrderService } from '../services/order.service';
import { AuthService } from '../services/auth.service';
import { FormsModule } from '@angular/forms';

import { OrderComponent } from './order.component';

describe('OrderComponent', () => {
  let component: OrderComponent;
  let fixture: ComponentFixture<OrderComponent>;

  beforeEach(() => {
    const authSpy = jasmine.createSpyObj('AuthService', ['isLoggedIn', 'getToken', 'login', 'logout'], {
      isLoggedIn$: { subscribe: () => {} }
    });

    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule, FormsModule, OrderComponent],
      providers: [
        OrderService,
        { provide: AuthService, useValue: authSpy }
      ]
    });
    fixture = TestBed.createComponent(OrderComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
