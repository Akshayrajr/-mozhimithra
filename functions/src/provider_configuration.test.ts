import assert from "node:assert/strict";
import test from "node:test";

import {
  providerEndpoint,
  providerFailureCode,
  providerReply,
} from "./provider_configuration";

test("accepts the official Gemini OpenAI-compatible HTTPS endpoint", () => {
  const endpoint = providerEndpoint(
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
  );

  assert.equal(endpoint.hostname, "generativelanguage.googleapis.com");
  assert.equal(endpoint.pathname, "/v1beta/openai/chat/completions");
});

test("rejects insecure or credential-bearing provider URLs", () => {
  for (const value of [
    "http://provider.example/chat/completions",
    "https://user:password@provider.example/chat/completions",
    "https://provider.example/chat/completions#secret",
    "not-a-url",
  ]) {
    assert.throws(() => providerEndpoint(value));
  }
});

test("reads standard OpenAI-compatible completion responses", () => {
  assert.equal(
    providerReply({
      choices: [{ message: { content: "  Hola.  " } }],
    }),
    "Hola.",
  );
});

test("supports a simple reply response and rejects malformed output", () => {
  assert.equal(providerReply({ reply: "  Hello. " }), "Hello.");
  assert.equal(providerReply({ choices: [] }), undefined);
  assert.equal(
    providerReply({ choices: [{ message: { content: " " } }] }),
    undefined,
  );
  assert.equal(providerReply(null), undefined);
});

test("limits returned provider text", () => {
  assert.equal(providerReply({ reply: "x".repeat(5_100) })?.length, 5_000);
});

test("classifies provider credential, quota, and availability errors", () => {
  assert.equal(providerFailureCode(401), "failed-precondition");
  assert.equal(providerFailureCode(403), "failed-precondition");
  assert.equal(providerFailureCode(429), "resource-exhausted");
  assert.equal(providerFailureCode(503), "unavailable");
});