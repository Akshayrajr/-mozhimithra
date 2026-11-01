import assert from "node:assert/strict";
import test from "node:test";

import { ttsLocaleForLanguage, ttsLocales } from "./voice_languages";

test("provides a Cloud TTS locale for every in-app target language", () => {
  const supportedLanguages = [
    "Arabic",
    "Assamese",
    "Bengali",
    "English",
    "French",
    "German",
    "Gujarati",
    "Hindi",
    "Japanese",
    "Kannada",
    "Korean",
    "Malayalam",
    "Mandarin Chinese",
    "Marathi",
    "Odia",
    "Punjabi",
    "Spanish",
    "Tamil",
    "Telugu",
    "Urdu",
  ];

  assert.deepEqual(Object.keys(ttsLocales).sort(), supportedLanguages.sort());
  for (const language of supportedLanguages) {
    assert.ok(ttsLocaleForLanguage(language), `${language} should have a locale`);
  }
});

test("does not map unknown languages to an unrelated locale", () => {
  assert.equal(ttsLocaleForLanguage("Klingon"), undefined);
});
