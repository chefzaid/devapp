export type OrderStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'COMPLETED';

export interface Order {
  id: number;
  userId: number;
  userName?: string | null;
  productId: number;
  status: OrderStatus;
}

export type CreateOrderRequest = Pick<Order, 'userId' | 'productId'>;
export type UpdateOrderRequest = CreateOrderRequest;
