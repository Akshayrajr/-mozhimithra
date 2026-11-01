export function providerEndpoint(value: string): URL {
  let endpoint: URL;
  try {
    endpoint = new URL(value.trim());
  } catch {
    throw new Error("Tutor provider URL is invalid.");
  }
  if (
    endpoint.protocol !== "https:" ||
    endpoint.username ||
    endpoint.password ||
    endpoint.hash
  ) {
    throw new Error("Tutor provider URL must be a secure HTTPS endpoint.");
  }
  return endpoint;
}

export function providerReply(value: unknown): string | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }

  const body = value as {
    choices?: { message?: { content?: unknown } }[];
    reply?: unknown;
  };
  const choice = Array.isArray(body.choices) ? body.choices[0] : undefined;
  const reply = choice?.message?.content ?? body.reply;
  return typeof reply === "string" && reply.trim()
    ? reply.trim().slice(0, 5_000)
    : undefined;
}

export function providerFailureCode(
  status: number,
): "failed-precondition" | "resource-exhausted" | "unavailable" {
  if (status === 429) {
    return "resource-exhausted";
  }
  if (status === 400 || status === 401 || status === 403 || status === 404) {
    return "failed-precondition";
  }
  return "unavailable";
}