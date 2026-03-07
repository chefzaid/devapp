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

    const req = http.expectOne('/api/orders');
    expect(req.request.method).toBe('GET');
    req.flush(mockOrders);
  });

  it('should create order', () => {
    const order: Order = { user: { id: 1, name: 'u' }, productId: 2 };

    service.createOrder(order).subscribe(data => {
      expect(data).toEqual(order);
    });

    const req = http.expectOne('/api/orders');
    expect(req.request.method).toBe('POST');
    req.flush(order);
  });

  it('should fetch order by id', () => {
    const order: Order = { id: 3, user: { id: 1, name: 'u' }, productId: 2 };

    service.getOrderById(3).subscribe(data => {
      expect(data).toEqual(order);
    });

    const req = http.expectOne('/api/orders/3');
    expect(req.request.method).toBe('GET');
    req.flush(order);
  });

  it('should return server message when available', (done) => {
    service.getAllOrders().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toBe('order failure');
        done();
      }
    });

    const req = http.expectOne('/api/orders');
    req.flush({ message: 'order failure' }, { status: 500, statusText: 'Server Error' });
  });

  it('should return formatted error code message when server message is missing', (done) => {
    service.getAllOrders().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toContain('Error Code: 500');
        done();
      }
    });

    const req = http.expectOne('/api/orders');
    req.flush({}, { status: 500, statusText: 'Server Error' });
  });

  it('should return client-side error message', (done) => {
    service.getAllOrders().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toContain('client order issue');
        done();
      }
    });

    const req = http.expectOne('/api/orders');
    req.error(new ErrorEvent('NetworkError', { message: 'client order issue' }));
  });
});
