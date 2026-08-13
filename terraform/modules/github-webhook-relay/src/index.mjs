// Relay "tonto" entre el webhook de organizacion de GitHub (Projects v2) y este
// repositorio. No conoce nada de la logica de negocio de la release: solo
// verifica la firma HMAC, filtra ruido, y reenvia un repository_dispatch con el
// node id del issue que cambio. Toda la logica de cascada vive en
// .github/scripts/update_project_status.py (modo `cascade`), disparado por el
// workflow .github/workflows/project-cascade.yml.
//
// Runtime: Node.js 20.x en AWS Lambda, expuesto via Function URL (auth NONE —
// la autenticidad la garantiza la firma HMAC, no IAM). Sin dependencias de
// terceros: solo node:crypto y fetch global.
//
// Variables de entorno requeridas:
//   GITHUB_WEBHOOK_SECRET   Secret configurado en el webhook de la organizacion.
//   GITHUB_DISPATCH_TOKEN   PAT (classic, scope 'repo') usado para el repository_dispatch.
//   TARGET_REPO             "owner/repo", ej. "CCPL-Solutions/docurural-backend".

import { createHmac, timingSafeEqual } from "node:crypto";

const WEBHOOK_SECRET = process.env.GITHUB_WEBHOOK_SECRET;
const DISPATCH_TOKEN = process.env.GITHUB_DISPATCH_TOKEN;
const TARGET_REPO = process.env.TARGET_REPO;
const DISPATCH_EVENT_TYPE = "project-status-changed";

export const handler = async (event) => {
  if (!WEBHOOK_SECRET || !DISPATCH_TOKEN || !TARGET_REPO) {
    console.error("Faltan variables de entorno: GITHUB_WEBHOOK_SECRET, GITHUB_DISPATCH_TOKEN o TARGET_REPO.");
    return response(500, "misconfigured");
  }

  const rawBody = getRawBody(event);
  const signature = getHeader(event.headers, "x-hub-signature-256");
  if (!isValidSignature(rawBody, signature)) {
    console.warn("Firma invalida — request descartado.");
    return response(401, "invalid signature");
  }

  const githubEvent = getHeader(event.headers, "x-github-event");
  if (githubEvent === "ping") {
    return response(204, "");
  }
  if (githubEvent !== "projects_v2_item") {
    // El webhook de la organizacion solo deberia tener este evento suscrito,
    // pero por si acaso se agrega otro en el futuro, se ignora sin fallar.
    return response(204, "");
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch (error) {
    console.error("Body no es JSON valido:", error);
    return response(400, "invalid json");
  }

  if (!isRelevantEdit(payload)) {
    return response(204, "");
  }

  const contentNodeId = payload.projects_v2_item?.content_node_id;
  if (!contentNodeId) {
    console.warn("Evento projects_v2_item sin content_node_id — se ignora.", payload.projects_v2_item);
    return response(204, "");
  }

  try {
    await dispatch(contentNodeId);
  } catch (error) {
    console.error("Fallo al reenviar repository_dispatch:", error);
    // Se responde 204 igualmente: reintentar no ayuda si el fallo es de config,
    // y GitHub no tiene forma de saber que el relay tuvo un problema aguas abajo.
    return response(204, "");
  }

  return response(204, "");
};

function isRelevantEdit(payload) {
  if (payload.action !== "edited") return false;
  if (payload.projects_v2_item?.content_type !== "Issue") return false;

  const fieldValueChange = payload.changes?.field_value;
  if (!fieldValueChange) return false;

  // El payload documentado por GitHub para este evento no siempre incluye el
  // nombre del campo editado (solo field_node_id / field_type en algunas
  // versiones). Si el nombre esta presente, se filtra por "Status" para
  // reducir ruido; si no, se deja pasar y es update_project_status.py (modo
  // cascade) quien decide si el issue editado es realmente el padre de la
  // release — el peor caso es una cascada de mas que resulta en un no-op.
  if (typeof fieldValueChange.field_name === "string") {
    return fieldValueChange.field_name === "Status";
  }
  return true;
}

async function dispatch(contentNodeId) {
  const url = `https://api.github.com/repos/${TARGET_REPO}/dispatches`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${DISPATCH_TOKEN}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      "User-Agent": "docurural-github-webhook-relay",
    },
    body: JSON.stringify({
      event_type: DISPATCH_EVENT_TYPE,
      client_payload: { content_node_id: contentNodeId },
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`repository_dispatch respondio ${res.status}: ${body}`);
  }
}

function isValidSignature(rawBody, signatureHeader) {
  if (!signatureHeader || !signatureHeader.startsWith("sha256=")) return false;

  const expectedHex = createHmac("sha256", WEBHOOK_SECRET).update(rawBody, "utf8").digest("hex");
  const expected = Buffer.from(`sha256=${expectedHex}`, "utf8");
  const received = Buffer.from(signatureHeader, "utf8");

  if (expected.length !== received.length) return false;
  return timingSafeEqual(expected, received);
}

function getRawBody(event) {
  const body = event.body ?? "";
  return event.isBase64Encoded ? Buffer.from(body, "base64").toString("utf8") : body;
}

function getHeader(headers, name) {
  // Function URLs (payload format 2.0) siempre entregan los headers en minuscula.
  return headers?.[name];
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "content-type": "text/plain" },
    body,
  };
}
