export enum AppErrorCode {
  Unauthorized = 'UNAUTHORIZED',
  Validation = 'VALIDATION',
  Network = 'NETWORK',
  Server = 'SERVER'
}

export class AppException extends Error {
  code: AppErrorCode;

  constructor(code: AppErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

class GlobalErrorHandler {
  validation(message: string): AppException {
    return new AppException(AppErrorCode.Validation, message);
  }

  unauthorized(message: string): AppException {
    return new AppException(AppErrorCode.Unauthorized, message);
  }

  network(message: string): AppException {
    return new AppException(AppErrorCode.Network, message);
  }

  format(error: Error): string {
    if (error.message.length > 0) {
      return error.message;
    }
    return '操作失败，请稍后重试。';
  }
}

export const globalErrorHandler = new GlobalErrorHandler();
