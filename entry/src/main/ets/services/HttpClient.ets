import http from '@ohos.net.http';
import { API_BASE_URL } from '../config/AppConfig';
import { AppErrorCode, AppException } from '../utils/AppError';

export interface RequestConfig {
  path: string;
  method: http.RequestMethod;
  body?: string;
  token?: string;
}

interface RequestHeaders {
  'Content-Type': string;
  'Authorization'?: string;
}

interface ErrorResponseDto {
  detail?: string;
}

class HttpClient {
  private token: string = '';

  setToken(token: string): void {
    this.token = token;
  }

  clearToken(): void {
    this.token = '';
  }

  async request(config: RequestConfig): Promise<string> {
    const requestTask = http.createHttp();
    const token = config.token ?? this.token;
    try {
      const headers: RequestHeaders = token.length > 0 ? {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      } : {
        'Content-Type': 'application/json'
      };
      const response = await requestTask.request(`${API_BASE_URL}${config.path}`, {
        method: config.method,
        extraData: config.body ?? '',
        expectDataType: http.HttpDataType.STRING,
        header: headers,
        readTimeout: 15000,
        connectTimeout: 15000
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        if (typeof response.result === 'string') {
          return response.result;
        }
        return '';
      }
      const message = this.formatServerError(response.responseCode, typeof response.result === 'string' ? response.result : '');
      const errorCode = response.responseCode === 401 ? AppErrorCode.Unauthorized : AppErrorCode.Server;
      throw new AppException(errorCode, message);
    } catch (error) {
      if (error instanceof AppException) {
        throw error;
      }
      throw new AppException(AppErrorCode.Network, '网络请求失败，请检查后端服务是否已启动。');
    } finally {
      requestTask.destroy();
    }
  }

  private formatServerError(statusCode: number, rawBody: string): string {
    const detail = this.extractDetail(rawBody);
    if (detail.length > 0) {
      return this.localizeDetail(detail);
    }
    if (statusCode === 400) {
      return '请求参数不正确，请检查输入内容。';
    }
    if (statusCode === 401) {
      return '用户名或密码错误，或登录状态已过期。';
    }
    return `服务请求失败：${statusCode}`;
  }

  private extractDetail(rawBody: string): string {
    if (rawBody.length === 0) {
      return '';
    }
    try {
      const dto = JSON.parse(rawBody) as ErrorResponseDto;
      if (typeof dto.detail === 'string') {
        return dto.detail;
      }
    } catch (error) {
      return '';
    }
    return '';
  }

  private localizeDetail(detail: string): string {
    if (detail === 'Invalid username or password') {
      return '用户名或密码错误。';
    }
    if (detail === 'Username already exists') {
      return '用户名已存在，请换一个用户名。';
    }
    if (detail === 'Username is required') {
      return '请输入用户名。';
    }
    if (detail === 'Password must be at least 6 characters') {
      return '密码至少需要 6 位。';
    }
    if (detail === 'Login required' || detail === 'Session expired') {
      return '登录状态已过期，请重新登录。';
    }
    if (detail === 'Comment content is required') {
      return '请输入评论内容。';
    }
    if (detail === 'Comment content must be at most 200 characters') {
      return '评论内容不能超过 200 字。';
    }
    if (detail === 'Parent comment not found') {
      return '要回复的评论不存在。';
    }
    return detail;
  }
}

export const httpClient = new HttpClient();
