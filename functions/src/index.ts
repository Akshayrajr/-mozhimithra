import { createHash } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { recommendationPrompt, tutorSystemPrompt, type LearnerProfile } from "./tutor_prompts";
import {
  providerEndpoint,
  providerFailureCode,
  providerReply,
} from "./provider_configuration";
import { PiperTtsError, synthesizeWithPiper } from "./piper_tts";
import { ttsLocaleForLanguage, ttsLocales } from "./voice_languages";

initializeApp();

const region = "asia-south1";
const providerUrl = defineSecret("TUTOR_PROVIDER_URL");
const providerApiKey = defineSecret("TUTOR_API_KEY");
const providerModel = defineSecret("TUTOR_MODEL");
const piperTtsUrl = defineSecret("PIPER_TTS_URL");
const piperTtsToken = defineSecret("PIPER_TTS_TOKEN");
const firestore = getFirestore();

const allowedModes = new Set([
  "conversation",
  "guidedLesson",
  "rolePlay",
  "translationPractice",
]);
const allowedLevels = new Set(["beginner", "intermediate", "advanced"]);

interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}

function requireString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return value.trim();
}

function learnerProfile(value: unknown): LearnerProfile {
  if (typeof value !== "object" || value === null) {
    throw new HttpsError("invalid-argument", "A learning profile is required.");
  }
  const raw = value as Record<string, unknown>;
  const targetLanguage = requireString(raw.targetLanguage, "target language", 60);
  const tutorLanguage = requireString(raw.tutorLanguage, "tutor language", 60);
  const skillLevel = requireString(raw.skillLevel, "skill level", 30);
  const dailyGoalMinutes = raw.dailyGoalMinutes;
  if (
    !Object.hasOwn(ttsLocales, targetLanguage) ||
    !["English", "Malayalam"].includes(tutorLanguage) ||
    !allowedLevels.has(skillLevel) ||
    typeof dailyGoalMinutes !== "number" ||
    !Number.isInteger(dailyGoalMinutes) ||
    dailyGoalMinutes < 5 ||
    dailyGoalMinutes > 120
  ) {
    throw new HttpsError("invalid-argument", "Invalid learning preferences.");
  }
  return { targetLanguage, tutorLanguage, skillLevel, dailyGoalMinutes };
}

function chatHistory(value: unknown): ChatTurn[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 14) {
    throw new HttpsError("invalid-argument", "Invalid conversation history.");
  }
  return value.map((item) => {
    if (typeof item !== "object" || item === null) {
      throw new HttpsError("invalid-argument", "Invalid conversation turn.");
    }
    const raw = item as Record<string, unknown>;
    if (raw.role !== "user" && raw.role !== "assistant") {
      throw new HttpsError("invalid-argument", "Invalid conversation role.");
    }
    return {
      role: raw.role,
      content: requireString(raw.content, "message", 2_000),
    };
  });
}

async function consumeRateLimit(uid: string, operation: string): Promise<void> {
  const now = Date.now();
  const window = Math.floor(now / 60_000);
  const limit = operation === "tutor" ? 12 : 30;
  const userHash = createHash("sha256").update(uid).digest("hex");
  const ref = firestore.collection("functionRateLimits").doc(`${userHash}_${operation}`);

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    const count = data?.window === window ? Number(data.count ?? 0) : 0;
    if (count >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many requests. Please wait a minute and try again.",
      );
    }
    transaction.set(ref, { window, count: count + 1, updatedAt: now });
  });
}

function tutorRequestData(value: unknown): {
  profile: LearnerProfile;
  task: "reply" | "recommendation";
  mode: string;
  history: ChatTurn[];
  recentActivity: string[];
  scenario?: string;
} {
  if (typeof value !== "object" || value === null) {
    throw new HttpsError("invalid-argument", "Invalid tutor request.");
  }
  const raw = value as Record<string, unknown>;
  const profile = learnerProfile(raw.profile);
  if (raw.task !== "reply" && raw.task !== "recommendation") {
    throw new HttpsError("invalid-argument", "Invalid tutor task.");
  }
  const task = raw.task;
  const mode = typeof raw.mode === "string" ? raw.mode : "conversation";
  if (task === "reply" && !allowedModes.has(mode)) {
    throw new HttpsError("invalid-argument", "Invalid tutor mode.");
  }
  const history =
    task === "reply"
      ? chatHistory(raw.history)
      : [{
          role: "user" as const,
          content: "Recommend the learner's next speaking activity.",
        }];
  const recentActivity = Array.isArray(raw.recentActivity)
    ? raw.recentActivity.slice(0, 12).map((activity) =>
        requireString(activity, "recent activity", 300),
      )
    : [];
  const scenario =
    typeof raw.scenario === "string"
      ? raw.scenario.trim().slice(0, 300)
      : undefined;
  return { profile, task, mode, history, recentActivity, scenario };
}

export const tutorReply = onCall(
  {
    region,
    secrets: [providerUrl, providerApiKey, providerModel],
    timeoutSeconds: 60,
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to use the tutor.");
    }
    const input = tutorRequestData(request.data);
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      if (input.task === "recommendation") {
        return {
          reply:
            input.profile.tutorLanguage === "Malayalam"
              ? "അഭിവാദ്യങ്ങൾ പരിശീലിക്കൂ: നമസ്കാരം പറഞ്ഞ്, എങ്ങനെയുണ്ട് എന്ന് ചോദിക്കൂ."
              : "Practice a greeting: say hello, then ask how the other person is doing.",
        };
      }
      if (input.mode === "translationPractice") {
        throw new HttpsError(
          "failed-precondition",
          "Malayalam translation practice requires a configured AI tutor. The emulator is running in demo mode.",
        );
      }
      return {
        reply:
          input.profile.tutorLanguage === "Malayalam"
            ? `നന്നായി. ${input.profile.targetLanguage}യിൽ പരിശീലനം തുടരാം. നിങ്ങളെക്കുറിച്ച് ഒരു ചെറിയ വാക്യം കൂടി പറയൂ.`
            : `Nice work. Let’s keep practicing ${input.profile.targetLanguage}. Say one more short sentence about yourself.`,
      };
    }
    await consumeRateLimit(request.auth.uid, "tutor");

    let endpoint: URL;
    try {
      endpoint = providerEndpoint(providerUrl.value());
    } catch (error) {
      throw new HttpsError(
        "failed-precondition",
        error instanceof Error ? error.message : "Tutor provider URL is invalid.",
      );
    }

    const systemPrompt =
      input.task === "recommendation"
        ? recommendationPrompt(input.profile, input.recentActivity)
        : tutorSystemPrompt(input.profile, input.mode, input.scenario);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 50_000);
    let response: Response;
    try {
      response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + providerApiKey.value(),
          "Content-Type": "application/json",
          "X-Title": "Mozhi Mithram",
        },
        body: JSON.stringify({
          model: providerModel.value(),
          temperature: 0.7,
          max_tokens: 512,
          messages: [
            { role: "system", content: systemPrompt },
            ...input.history,
          ],
        }),
        signal: controller.signal,
      });
    } catch (error) {
      console.error("Tutor provider request failed.", error);
      throw new HttpsError("unavailable", "Tutor is temporarily unavailable.");
    } finally {
      clearTimeout(timeout);
    }
    if (!response.ok) {
      console.error("Tutor provider returned status", response.status);
      const failureCode = providerFailureCode(response.status);
      if (failureCode === "resource-exhausted") {
        throw new HttpsError(
          failureCode,
          "The AI provider is rate-limited. Try again shortly.",
        );
      }
      if (failureCode === "failed-precondition") {
        throw new HttpsError(
          failureCode,
          "The AI provider rejected its configured endpoint, credentials, or model. Check TUTOR_PROVIDER_URL, TUTOR_API_KEY, and TUTOR_MODEL.",
        );
      }
      throw new HttpsError("unavailable", "Tutor is temporarily unavailable.");
    }
    let body: unknown;
    try {
      body = await response.json();
    } catch {
      throw new HttpsError("internal", "Tutor returned an unreadable response.");
    }
    const reply = providerReply(body);
    if (!reply) {
      throw new HttpsError("internal", "Tutor returned an empty response.");
    }
    return { reply };
  },
);

export const synthesizeSpeech = onCall(
  {
    region,
    secrets: [piperTtsUrl, piperTtsToken],
    timeoutSeconds: 60,
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to use spoken replies.");
    }
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      throw new HttpsError(
        "unavailable",
        "Piper cloud speech is disabled in local emulators; the app can use device speech instead.",
      );
    }
    const text = requireString(
      typeof request.data === "object" && request.data !== null
        ? (request.data as Record<string, unknown>).text
        : undefined,
      "speech text",
      1_200,
    );
    const language = requireString(
      typeof request.data === "object" && request.data !== null
        ? (request.data as Record<string, unknown>).language
        : undefined,
      "language",
      60,
    );
    const languageCode = ttsLocaleForLanguage(language);
    if (!languageCode) {
      throw new HttpsError("invalid-argument", "Unsupported speech language.");
    }
    await consumeRateLimit(request.auth.uid, "speech");

    try {
      return await synthesizeWithPiper({
        baseUrl: piperTtsUrl.value(),
        token: piperTtsToken.value(),
        text,
        language,
        languageCode,
      });
    } catch (error) {
      if (error instanceof PiperTtsError) {
        if (error.code === "unavailable") {
          console.error("Piper TTS request failed.", error.message);
        }
        throw new HttpsError(error.code, error.message);
      }
      console.error("Piper TTS request failed.", error);
      throw new HttpsError(
        "unavailable",
        "Piper speech is temporarily unavailable. The app can try device speech instead.",
      );
    }
  },
);
