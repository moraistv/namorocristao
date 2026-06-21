import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { AppError } from "../lib/errors";

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof ZodError) {
    return res.status(422).json({
      error: "Dados inválidos",
      details: err.flatten().fieldErrors,
    });
  }

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: err.message,
      details: err.details,
    });
  }

  console.error("Erro não tratado:", err);
  return res.status(500).json({ error: "Erro interno do servidor" });
}
