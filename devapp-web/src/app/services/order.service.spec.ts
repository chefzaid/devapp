import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { OrderService } from './order.service';
import { Order } from '../models/order.model';

describe('OrderService', () => {
  let service: OrderService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });
    service = TestBed.inject(OrderService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('should fetch orders', () => {
    const mockOrders: Order[] = [{ user: { id: 1, name: 'u' }, productId: 2 }];

    service.getAllOrders().subscribe(data => {
      expect(data).toEqual(mockOrders);
    });

    const req = http.expectOne('http://localhost:8081/api/orders');
    expect(req.request.method).toBe('GET');
    req.flush(mockOrders);
  });

  it('should create order', () => {
    const order: Order = { user: { id: 1, name: 'u' }, productId: 2 };

    service.createOrder(order).subscribe(data => {
      expect(data).toEqual(order);
    });

    const req = http.expectOne('http://localhost:8081/api/orders');
    expect(req.request.method).toBe('POST');
    req.flush(order);
  });
});
