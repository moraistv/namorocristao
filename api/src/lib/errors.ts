import { NextFunction, Request, Response } from "express";

/** Erro de aplicação com status HTTP e código estável opcional. */
export class AppError extends Error {
  statusCode: number;
  details?: unknown;
  code?: string;

  constructor(
    message: string,
    statusCode = 400,
    details?: unknown,
    code?: string
  ) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.details = details;
    this.code = code;
  }
}

/** Envolve handlers async para encaminhar erros ao middleware. */
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}
