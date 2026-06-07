import { common } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import {
  AUTH_PREFS_NAME,
  AUTH_TOKEN_KEY,
  DEFAULT_AVATAR_URL
} from '../config/AppConfig';
import {
  AuthSession,
  ProfileUpdatePayload,
  UserProfile
} from '../models/User';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { httpClient } from './HttpClient';
import http from '@ohos.net.http';

const USER_ID_KEY: string = 'user_id';
const USERNAME_KEY: string = 'username';
const NICKNAME_KEY: string = 'nickname';
const AVATAR_KEY: string = 'avatar_url';
const EMAIL_KEY: string = 'email';
const BIO_KEY: string = 'bio';
const INSTITUTION_KEY: string = 'institution';
const RESEARCH_FIELD_KEY: string = 'research_field';
const CREATED_AT_KEY: string = 'created_at';
const LOCAL_USER_ID_KEY: string = 'local_user_id';
const LOCAL_USERNAME_KEY: string = 'local_username';
const LOCAL_PASSWORD_KEY: string = 'local_password';
const LOCAL_NICKNAME_KEY: string = 'local_nickname';
const LOCAL_AVATAR_KEY: string = 'local_avatar_url';
const LOCAL_EMAIL_KEY: string = 'local_email';
const LOCAL_BIO_KEY: string = 'local_bio';
const LOCAL_INSTITUTION_KEY: string = 'local_institution';
const LOCAL_RESEARCH_FIELD_KEY: string = 'local_research_field';
const LOCAL_CREATED_AT_KEY: string = 'local_created_at';

interface UserProfileDto {
  id: number;
  username: string;
  nickname: string;
  avatar_url: string;
  email?: string;
  bio: string;
  institution: string;
  research_field: string;
  created_at: string;
}

interface AuthResponseDto {
  token: string;
  user: UserProfileDto;
}

interface LoginRequestDto {
  username: string;
  password: string;
}

interface RegisterRequestDto {
  username: string;
  password: string;
  nickname: string;
  email: string;
}

interface ProfileUpdateDto {
  nickname: string;
  avatar_url: string;
  email: string;
  bio: string;
  institution: string;
  research_field: string;
}

interface PasswordResetDto {
  old_password: string;
  new_password: string;
}

class AuthService {
  private storage?: preferences.Preferences;
  private session?: AuthSession;
  private registeredUser?: UserProfile;
  private registeredPassword: string = '';
  private nextUserId: number = 2;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.storage = await preferences.getPreferences(context, AUTH_PREFS_NAME);
      this.restoreLocalAccount();
      this.restoreSession();
    } catch (error) {
      this.storage = undefined;
    }
  }

  async checkBackendAvailable(): Promise<boolean> {
    try {
      await httpClient.request({
        path: '/health',
        method: http.RequestMethod.GET,
        timeoutMs: 8000
      });
      return true;
    } catch (error) {
      return false;
    }
  }

  isLoggedIn(): boolean {
    return this.session !== undefined;
  }

  getSession(): AuthSession | undefined {
    return this.session;
  }

  getCurrentUser(): UserProfile | undefined {
    if (!this.session) {
      return undefined;
    }
    return this.session.user;
  }

  getToken(): string {
    if (!this.session) {
      return '';
    }
    return this.session.token;
  }

  async login(username: string, password: string): Promise<AuthSession> {
    const account = username.trim();
    if (account.length === 0 || password.length === 0) {
      throw globalErrorHandler.validation('请输入用户名和密码。');
    }
    try {
      const payload: LoginRequestDto = {
        username: account,
        password
      };
      const response = await httpClient.request({
        path: '/auth/login',
        method: http.RequestMethod.POST,
        body: JSON.stringify(payload)
      });
      const dto = JSON.parse(response) as AuthResponseDto;
      return this.activateSession(this.fromDto(dto.user), dto.token);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.unauthorized('登录失败，请稍后重试。');
      }
    }
    if (account === 'demo' && password === '123456') {
      return this.activateSession(this.createDemoUser(), this.createToken());
    }
    if (this.registeredUser && account === this.registeredUser.username && password === this.registeredPassword) {
      return this.activateSession(this.registeredUser, this.createToken());
    }
    throw globalErrorHandler.unauthorized('用户名或密码错误。');
  }

  async register(username: string, password: string, nickname: string, email: string): Promise<AuthSession> {
    const account = username.trim();
    const displayName = nickname.trim().length > 0 ? nickname.trim() : account;
    if (account.length === 0 || password.length < 6) {
      throw globalErrorHandler.validation('请输入用户名，且密码至少 6 位。');
    }
    try {
      const payload: RegisterRequestDto = {
        username: account,
        password,
        nickname: displayName,
        email: email.trim()
      };
      const response = await httpClient.request({
        path: '/auth/register',
        method: http.RequestMethod.POST,
        body: JSON.stringify(payload)
      });
      const dto = JSON.parse(response) as AuthResponseDto;
      return this.activateSession(this.fromDto(dto.user), dto.token);
    } catch (error) {
      if (error instanceof AppException && error.code === AppErrorCode.Network) {
        return this.registerLocal(account, password, displayName, email);
      }
      if (error instanceof Error) {
        throw error;
      }
      throw globalErrorHandler.validation('注册失败，请稍后重试。');
    }
  }

  registerLocal(account: string, password: string, displayName: string, email: string): AuthSession {
    const user: UserProfile = {
      id: this.nextUserId,
      username: account,
      nickname: displayName,
      avatarUrl: DEFAULT_AVATAR_URL,
      email: email.trim(),
      bio: '',
      institution: '',
      researchField: '',
      createdAt: this.todayText()
    };
    this.nextUserId += 1;
    this.registeredUser = user;
    this.registeredPassword = password;
    this.saveLocalAccount(user, password);
    return this.activateSession(user, this.createToken());
  }

  logout(): void {
    this.session = undefined;
    httpClient.clearToken();
    if (!this.storage) {
      return;
    }
    try {
      this.storage.deleteSync(AUTH_TOKEN_KEY);
      this.storage.deleteSync(USER_ID_KEY);
      this.storage.deleteSync(USERNAME_KEY);
      this.storage.deleteSync(NICKNAME_KEY);
      this.storage.deleteSync(AVATAR_KEY);
      this.storage.deleteSync(EMAIL_KEY);
      this.storage.deleteSync(BIO_KEY);
      this.storage.deleteSync(INSTITUTION_KEY);
      this.storage.deleteSync(RESEARCH_FIELD_KEY);
      this.storage.deleteSync(CREATED_AT_KEY);
      this.storage.flushSync();
    } catch (error) {
      return;
    }
  }

  async updateProfile(payload: ProfileUpdatePayload): Promise<UserProfile> {
    if (!this.session) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
    try {
      const requestPayload: ProfileUpdateDto = {
        nickname: payload.nickname,
        avatar_url: payload.avatarUrl,
        email: payload.email,
        bio: payload.bio,
        institution: payload.institution,
        research_field: payload.researchField
      };
      const response = await httpClient.request({
        path: '/users/me',
        method: http.RequestMethod.PUT,
        body: JSON.stringify(requestPayload),
        token: this.session.token
      });
      const dto = JSON.parse(response) as UserProfileDto;
      return this.replaceCurrentUser(this.fromDto(dto));
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.validation('资料更新失败，请稍后重试。');
      }
      return this.updateProfileLocal(payload);
    }
  }

  updateProfileLocal(payload: ProfileUpdatePayload): UserProfile {
    if (!this.session) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
    const updated: UserProfile = {
      id: this.session.user.id,
      username: this.session.user.username,
      nickname: payload.nickname.trim().length > 0 ? payload.nickname.trim() : this.session.user.username,
      avatarUrl: payload.avatarUrl.trim().length > 0 ? payload.avatarUrl.trim() : DEFAULT_AVATAR_URL,
      email: payload.email.trim(),
      bio: payload.bio.trim(),
      institution: payload.institution.trim(),
      researchField: payload.researchField.trim(),
      createdAt: this.session.user.createdAt
    };
    return this.replaceCurrentUser(updated);
  }

  async resetPassword(oldPassword: string, newPassword: string): Promise<void> {
    if (!this.session) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
    if (newPassword.length < 6) {
      throw globalErrorHandler.validation('新密码至少需要 6 位。');
    }
    try {
      const payload: PasswordResetDto = {
        old_password: oldPassword,
        new_password: newPassword
      };
      await httpClient.request({
        path: '/users/me/password',
        method: http.RequestMethod.PUT,
        body: JSON.stringify(payload),
        token: this.session.token
      });
      this.logout();
      return;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.validation('密码修改失败，请稍后重试。');
      }
      this.resetPasswordLocal(oldPassword, newPassword);
    }
  }

  resetPasswordLocal(oldPassword: string, newPassword: string): void {
    if (!this.session) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
    if (this.session.user.username === 'demo' && oldPassword !== '123456') {
      throw globalErrorHandler.validation('旧密码不正确。');
    }
    if (this.registeredUser && this.session.user.id === this.registeredUser.id) {
      if (oldPassword !== this.registeredPassword) {
        throw globalErrorHandler.validation('旧密码不正确。');
      }
      this.registeredPassword = newPassword;
      this.saveLocalAccount(this.session.user, newPassword);
    }
    this.logout();
  }

  private replaceCurrentUser(user: UserProfile): UserProfile {
    if (!this.session) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
    this.session = {
      token: this.session.token,
      user
    };
    if (this.registeredUser && this.registeredUser.id === user.id) {
      this.registeredUser = user;
      this.saveLocalAccount(user, this.registeredPassword);
    }
    this.saveSession();
    return user;
  }

  private fromDto(dto: UserProfileDto): UserProfile {
    return {
      id: dto.id,
      username: dto.username,
      nickname: dto.nickname,
      avatarUrl: dto.avatar_url,
      email: dto.email ?? '',
      bio: dto.bio,
      institution: dto.institution,
      researchField: dto.research_field,
      createdAt: dto.created_at
    };
  }

  private activateSession(user: UserProfile, token: string): AuthSession {
    this.session = {
      token,
      user
    };
    httpClient.setToken(token);
    this.saveSession();
    return this.session;
  }

  private createDemoUser(): UserProfile {
    return {
      id: 1,
      username: 'demo',
      nickname: '科研日报体验号',
      avatarUrl: DEFAULT_AVATAR_URL,
      email: 'demo@scidaily.local',
      bio: '每天记录一点科研进展，把灵感和进度都留住。',
      institution: '科研日报实验室',
      researchField: '人工智能辅助科研',
      createdAt: '2026-06-01'
    };
  }

  private createToken(): string {
    return `local-${Date.now()}`;
  }

  private todayText(): string {
    const date = new Date();
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  private saveSession(): void {
    if (!this.session || !this.storage) {
      return;
    }
    const user = this.session.user;
    try {
      this.storage.putSync(AUTH_TOKEN_KEY, this.session.token);
      this.storage.putSync(USER_ID_KEY, user.id);
      this.storage.putSync(USERNAME_KEY, user.username);
      this.storage.putSync(NICKNAME_KEY, user.nickname);
      this.storage.putSync(AVATAR_KEY, user.avatarUrl);
      this.storage.putSync(EMAIL_KEY, user.email);
      this.storage.putSync(BIO_KEY, user.bio);
      this.storage.putSync(INSTITUTION_KEY, user.institution);
      this.storage.putSync(RESEARCH_FIELD_KEY, user.researchField);
      this.storage.putSync(CREATED_AT_KEY, user.createdAt);
      this.storage.flushSync();
    } catch (error) {
      return;
    }
  }

  private restoreSession(): void {
    const token = this.getString(AUTH_TOKEN_KEY, '');
    const username = this.getString(USERNAME_KEY, '');
    if (token.length === 0 || username.length === 0) {
      return;
    }
    const user: UserProfile = {
      id: this.getNumber(USER_ID_KEY, 1),
      username,
      nickname: this.getString(NICKNAME_KEY, username),
      avatarUrl: this.getString(AVATAR_KEY, DEFAULT_AVATAR_URL),
      email: this.getString(EMAIL_KEY, ''),
      bio: this.getString(BIO_KEY, ''),
      institution: this.getString(INSTITUTION_KEY, ''),
      researchField: this.getString(RESEARCH_FIELD_KEY, ''),
      createdAt: this.getString(CREATED_AT_KEY, '')
    };
    this.session = {
      token,
      user
    };
    httpClient.setToken(token);
    this.nextUserId = Math.max(this.nextUserId, user.id + 1);
  }

  private saveLocalAccount(user: UserProfile, password: string): void {
    if (!this.storage) {
      return;
    }
    try {
      this.storage.putSync(LOCAL_USER_ID_KEY, user.id);
      this.storage.putSync(LOCAL_USERNAME_KEY, user.username);
      this.storage.putSync(LOCAL_PASSWORD_KEY, password);
      this.storage.putSync(LOCAL_NICKNAME_KEY, user.nickname);
      this.storage.putSync(LOCAL_AVATAR_KEY, user.avatarUrl);
      this.storage.putSync(LOCAL_EMAIL_KEY, user.email);
      this.storage.putSync(LOCAL_BIO_KEY, user.bio);
      this.storage.putSync(LOCAL_INSTITUTION_KEY, user.institution);
      this.storage.putSync(LOCAL_RESEARCH_FIELD_KEY, user.researchField);
      this.storage.putSync(LOCAL_CREATED_AT_KEY, user.createdAt);
      this.storage.flushSync();
    } catch (error) {
      return;
    }
  }

  private restoreLocalAccount(): void {
    const username = this.getString(LOCAL_USERNAME_KEY, '');
    const password = this.getString(LOCAL_PASSWORD_KEY, '');
    if (username.length === 0 || password.length === 0) {
      return;
    }
    const user: UserProfile = {
      id: this.getNumber(LOCAL_USER_ID_KEY, 2),
      username,
      nickname: this.getString(LOCAL_NICKNAME_KEY, username),
      avatarUrl: this.getString(LOCAL_AVATAR_KEY, DEFAULT_AVATAR_URL),
      email: this.getString(LOCAL_EMAIL_KEY, ''),
      bio: this.getString(LOCAL_BIO_KEY, ''),
      institution: this.getString(LOCAL_INSTITUTION_KEY, ''),
      researchField: this.getString(LOCAL_RESEARCH_FIELD_KEY, ''),
      createdAt: this.getString(LOCAL_CREATED_AT_KEY, '')
    };
    this.registeredUser = user;
    this.registeredPassword = password;
    this.nextUserId = Math.max(this.nextUserId, user.id + 1);
  }

  private getString(key: string, fallback: string): string {
    if (!this.storage) {
      return fallback;
    }
    try {
      const value = this.storage.getSync(key, fallback);
      if (typeof value === 'string') {
        return value;
      }
    } catch (error) {
      return fallback;
    }
    return fallback;
  }

  private getNumber(key: string, fallback: number): number {
    if (!this.storage) {
      return fallback;
    }
    try {
      const value = this.storage.getSync(key, fallback);
      if (typeof value === 'number') {
        return value;
      }
    } catch (error) {
      return fallback;
    }
    return fallback;
  }
}

export const authService = new AuthService();
