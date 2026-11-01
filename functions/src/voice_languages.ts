export const ttsLocales: Readonly<Record<string, string>> = {
  Arabic: "ar-XA",
  Assamese: "as-IN",
  Bengali: "bn-IN",
  English: "en-US",
  French: "fr-FR",
  German: "de-DE",
  Gujarati: "gu-IN",
  Hindi: "hi-IN",
  Japanese: "ja-JP",
  Kannada: "kn-IN",
  Korean: "ko-KR",
  Malayalam: "ml-IN",
  "Mandarin Chinese": "cmn-CN",
  Marathi: "mr-IN",
  Odia: "or-IN",
  Punjabi: "pa-IN",
  Spanish: "es-ES",
  Tamil: "ta-IN",
  Telugu: "te-IN",
  Urdu: "ur-IN",
};

export function ttsLocaleForLanguage(language: string): string | undefined {
  return ttsLocales[language];
}
