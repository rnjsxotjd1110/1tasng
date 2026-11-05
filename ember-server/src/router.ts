// 경로 → 핸들러. 목록에 없는 것은 모두 404.
import { handleBalance, handleRegister } from "./account";
import { handleAdminReports, handleAdminStats } from "./admin";
import { loadConfig, type Env } from "./env";
import { ApiError, apiErrorResponse, errorResponse } from "./http";
import { handleGetModel } from "./models";
import { handleMessages } from "./proxy/messages";
import { handlePurchase } from "./purchase";
import { handleReport } from "./reports";

export async function route(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const cfg = loadConfig(env);
  const { pathname } = new URL(req.url);
  const method = req.method.toUpperCase();

  try {
    if (method === "POST") {
      switch (pathname) {
        case "/v1/messages":
          return await handleMessages(req, env, cfg, ctx);
        case "/ember/register":
          return await handleRegister(req, env, cfg);
        case "/ember/purchase":
          return await handlePurchase(req, env, cfg);
        case "/ember/report":
          return await handleReport(req, env);
      }
    } else if (method === "GET") {
      switch (pathname) {
        case "/ember/balance":
          return await handleBalance(req, env);
        case "/ember/admin/reports":
          return await handleAdminReports(req, env);
        case "/ember/admin/stats":
          return await handleAdminStats(req, env);
      }
      const m = /^\/v1\/models\/([^/]+)$/.exec(pathname);
      if (m?.[1]) {
        let id: string;
        try {
          id = decodeURIComponent(m[1]);
        } catch {
          throw new ApiError(404, "not_found_error", "not found");
        }
        return await handleGetModel(req, env, id);
      }
    }
    return errorResponse(404, "not_found_error", "not found");
  } catch (err) {
    if (err instanceof ApiError) return apiErrorResponse(err);
    console.error("처리되지 않은 오류:", err);
    return errorResponse(500, "api_error", "internal server error");
  }
}
