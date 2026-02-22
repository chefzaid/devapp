import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { UserService } from '../services/user.service';
import { AuthService } from '../services/auth.service';
import { FormsModule } from '@angular/forms';

import { UserComponent } from './user.component';

describe('UserComponent', () => {
  let component: UserComponent;
  let fixture: ComponentFixture<UserComponent>;

  beforeEach(() => {
    const authSpy = jasmine.createSpyObj('AuthService', ['isLoggedIn', 'getToken', 'login', 'logout'], {
      isLoggedIn$: { subscribe: () => {} }
    });

    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule, FormsModule, UserComponent],
      providers: [
        UserService,
        { provide: AuthService, useValue: authSpy }
      ]
    });
    fixture = TestBed.createComponent(UserComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
