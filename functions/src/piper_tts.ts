export interface PiperAudio {
  audioContent: string;
  languageCode: string;
}

export class PiperTtsError extends Error {
  constructor(
    message: string,
    readonly code: "failed-precondition" | "unavailable" | "resource-exhausted",
  ) {
    super(message);
    this.name = "PiperTtsError";
  }
}

export async function synthesizeWithPiper({
  baseUrl,
  token,
  text,
  language,
  languageCode,
  fetcher = fetch,
}: {
  baseUrl: string;
  token: string;
  text: string;
  language: string;
  languageCode: string;
  fetcher?: typeof fetch;
}): Promise<PiperAudio> {
  let endpoint: URL;
  try {
    endpoint = new URL(baseUrl.trim());
  } catch {
    throw new PiperTtsError("Piper TTS URL is invalid.", "failed-precondition");
  }
  if (
    endpoint.protocol !== "https:" ||
    endpoint.username ||
    endpoint.password ||
    endpoint.search ||
    endpoint.hash
  ) {
    throw new PiperTtsError(
      "Piper TTS URL must be a secure HTTPS base URL.",
      "failed-precondition",
    );
  }
  if (!/^[A-Za-z0-9_-]{32,}$/.test(token)) {
    throw new PiperTtsError(
      "Piper TTS service token is not configured securely.",
      "failed-precondition",
    );
  }

  const url = new URL(
    "synthesize",
    endpoint.href.endsWith("/") ? endpoint : `${endpoint.href}/`,
  );
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 45_000);
  try {
    const response = await fetcher(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "audio/wav",
      },
      body: JSON.stringify({ text, language }),
      signal: controller.signal,
    });

    if (!response.ok) {
      if (response.status === 401 || response.status === 403) {
        throw new PiperTtsError(
          "Piper TTS rejected its configured service token.",
          "failed-precondition",
        );
      }
      if (response.status === 422) {
        throw new PiperTtsError(
          `Piper TTS has no configured voice for ${language}.`,
          "failed-precondition",
        );
      }
      if (response.status === 429) {
        throw new PiperTtsError(
          "Piper TTS is rate-limited.",
          "resource-exhausted",
        );
      }
      throw new PiperTtsError(
        `Piper TTS request failed with status ${response.status}.`,
        "unavailable",
      );
    }

    const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
    if (!contentType.startsWith("audio/wav")) {
      throw new PiperTtsError(
        "Piper TTS returned an unsupported audio format.",
        "unavailable",
      );
    }

    const reader = response.body?.getReader();
    if (!reader) {
      throw new PiperTtsError("Piper TTS returned no audio.", "unavailable");
    }
    const chunks: Uint8Array[] = [];
    let audioLength = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      audioLength += value.length;
      if (audioLength > 6_000_000) {
        await reader.cancel();
        throw new PiperTtsError(
          "Piper TTS audio exceeds the callable response limit.",
          "unavailable",
        );
      }
      chunks.push(value);
    }
    const audio = new Uint8Array(audioLength);
    let offset = 0;
    for (const chunk of chunks) {
      audio.set(chunk, offset);
      offset += chunk.length;
    }
    if (
      audio.length < 44 ||
      String.fromCharCode(...audio.subarray(0, 4)) !== "RIFF" ||
      String.fromCharCode(...audio.subarray(8, 12)) !== "WAVE"
    ) {
      throw new PiperTtsError(
        "Piper TTS returned invalid WAV audio.",
        "unavailable",
      );
    }

    return {
      audioContent: Buffer.from(audio).toString("base64"),
      languageCode,
    };
  } finally {
    clearTimeout(timeout);
  }
}
