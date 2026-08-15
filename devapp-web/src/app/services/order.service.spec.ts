import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { OrderService } from './order.service';
import { Order } from '../models/order.model';

describe('OrderService', () => {
    let service: OrderService;
    let http: HttpTestingController;

    beforeEach(() => {
        TestBed.configureTestingModule({
            providers: [provideHttpClient(), provideHttpClientTesting()]
        });
        service = TestBed.inject(OrderService);
        http = TestBed.inject(HttpTestingController);
    });

    afterEach(() => {
        http.verify();
    });

    it('should fetch orders', () => {
        const mockOrders: Order[] = [{ id: 1, userId: 1, userName: 'User', productId: 2, status: 'PENDING' }];

        service.getAllOrders().subscribe(data => {
            expect(data).toEqual(mockOrders);
        });

        const req = http.expectOne('/api/orders');
        expect(req.request.method).toBe('GET');
        req.flush(mockOrders);
    });

    it('should create order', () => {
        const order: Order = { id: 1, userId: 1, userName: 'User', productId: 2, status: 'PENDING' };

        service.createOrder(order).subscribe(data => {
            expect(data).toEqual(order);
        });

        const req = http.expectOne('/api/orders');
        expect(req.request.method).toBe('POST');
        req.flush(order);
    });

    it('should fetch order by id', () => {
        const order: Order = { id: 3, userId: 1, userName: 'User', productId: 2, status: 'APPROVED' };

        service.getOrderById(3).subscribe(data => {
            expect(data).toEqual(order);
        });

        const req = http.expectOne('/api/orders/3');
        expect(req.request.method).toBe('GET');
        req.flush(order);
    });

    it('should return server message when available', async () => {
        service.getAllOrders().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toBe('order failure');
                ;
            }
        });

        const req = http.expectOne('/api/orders');
        req.flush({ message: 'order failure' }, { status: 500, statusText: 'Server Error' });
    });

    it('should return a fallback title when problem details omit a message', async () => {
        service.getAllOrders().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toBe('Request failed (500)');
                ;
            }
        });

        const req = http.expectOne('/api/orders');
        req.flush({}, { status: 500, statusText: 'Server Error' });
    });

    it('should return client-side error message', async () => {
        service.getAllOrders().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toContain('client order issue');
                ;
            }
        });

        const req = http.expectOne('/api/orders');
        req.error(new ErrorEvent('NetworkError', { message: 'client order issue' }));
    });
});
