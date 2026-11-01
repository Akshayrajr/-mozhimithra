import assert from "node:assert/strict";
import test from "node:test";

import { PiperTtsError, synthesizeWithPiper } from "./piper_tts";

function wavBytes(): Uint8Array {
  const bytes = new Uint8Array(48);
  bytes.set([82, 73, 70, 70], 0);
  bytes.set([87, 65, 86, 69], 8);
  return bytes;
}

const token = "secure-test-token-12345678901234567890";

test("sends authenticated Piper requests and encodes valid WAV output", async () => {
  let requestUrl = "";
  let authorization = "";
  let requestBody = "";
  const audio = wavBytes();
  const result = await synthesizeWithPiper({
    baseUrl: "https://tts.example.test",
    token,
    text: "Hola",
    language: "Spanish",
    languageCode: "es_ES",
    fetcher: async (input, init) => {
      requestUrl = String(input);
      authorization = new Headers(init?.headers).get("authorization") ?? "";
      requestBody = String(init?.body);
      return new Response(audio, {
        headers: { "content-type": "audio/wav" },
      });
    },
  });

  assert.equal(requestUrl, "https://tts.example.test/synthesize");
  assert.equal(authorization, `Bearer ${token}`);
  assert.deepEqual(JSON.parse(requestBody), {
    text: "Hola",
    language: "Spanish",
  });
  assert.equal(result.languageCode, "es_ES");
  assert.equal(Buffer.from(result.audioContent, "base64").length, 48);
});

test("rejects insecure or credential-bearing Piper URLs", async () => {
  for (const baseUrl of [
    "http://tts.example.test",
    "https://user:password@tts.example.test",
    "https://tts.example.test?token=secret",
    "https://tts.example.test#fragment",
  ]) {
    await assert.rejects(
      synthesizeWithPiper({
        baseUrl,
        token,
        text: "Hola",
        language: "Spanish",
        languageCode: "es_ES",
      }),
      (error: unknown) =>
        error instanceof PiperTtsError &&
        error.code === "failed-precondition" &&
        /secure HTTPS base URL/.test(error.message),
    );
  }
});

test("rejects tokens that are not URL-safe random secrets", async () => {
  for (const invalidToken of [
    "short",
    "x".repeat(32) + " ",
    "x".repeat(31) + "+",
  ]) {
    await assert.rejects(
      synthesizeWithPiper({
        baseUrl: "https://tts.example.test",
        token: invalidToken,
        text: "Hola",
        language: "Spanish",
        languageCode: "es_ES",
      }),
      (error: unknown) =>
        error instanceof PiperTtsError &&
        error.code === "failed-precondition" &&
        /token is not configured securely/.test(error.message),
    );
  }
});

test("rejects unauthenticated, unsupported-language, and server failures", async () => {
  for (const [status, message] of [
    [401, /rejected its configured service token/],
    [422, /no configured voice for Spanish/],
    [503, /status 503/],
  ] as const) {
    await assert.rejects(
      synthesizeWithPiper({
        baseUrl: "https://tts.example.test",
        token,
        text: "Hola",
        language: "Spanish",
        languageCode: "es_ES",
        fetcher: async () => new Response(null, { status }),
      }),
      (error: unknown) =>
        error instanceof PiperTtsError && message.test(error.message),
    );
  }
});

test("rejects mislabeled, incomplete, and oversized audio", async () => {
  const request = (audio: Uint8Array, contentType = "audio/wav") =>
    synthesizeWithPiper({
      baseUrl: "https://tts.example.test",
      token,
      text: "Hola",
      language: "Spanish",
      languageCode: "es_ES",
      fetcher: async () =>
        new Response(audio, { headers: { "content-type": contentType } }),
    });

  await assert.rejects(
    request(wavBytes(), "application/json"),
    /unsupported audio/,
  );
  await assert.rejects(
    request(new Uint8Array(12)),
    /invalid WAV audio/,
  );
  await assert.rejects(
    request(new Uint8Array(6_000_001).fill(1)),
    /exceeds the callable response limit/,
  );
});
