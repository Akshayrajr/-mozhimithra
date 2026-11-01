import assert from "node:assert/strict";
import test from "node:test";

import { recommendationPrompt, tutorSystemPrompt } from "./tutor_prompts";

const profile = {
  targetLanguage: "Spanish",
  tutorLanguage: "Malayalam",
  skillLevel: "beginner",
  dailyGoalMinutes: 15,
};

test("guided tutor prompt coaches spoken natural language", () => {
  const prompt = tutorSystemPrompt(profile, "guidedLesson", "meet a friend");

  assert.match(prompt, /spoken response/);
  assert.match(prompt, /pronunciation, stress, rhythm/);
  assert.match(prompt, /Malayalam/);
  assert.match(prompt, /meet a friend/);
  assert.match(prompt, /not proof of mastery/);
});

test("translation practice prompt teaches a Malayalam speaker a target phrase", () => {
  const prompt = tutorSystemPrompt(profile, "translationPractice");

  assert.match(prompt, /Translate the learner's stated meaning from Malayalam/);
  assert.match(prompt, /Say in Spanish:/);
  assert.match(prompt, /Pronunciation:/);
  assert.match(prompt, /Practice tip:/);
});

test("recommendation prompt uses speaking progress, not writing", () => {
  const prompt = recommendationPrompt(profile, ["Completed a spoken greeting"]);

  assert.match(prompt, /speaking activity/);
  assert.match(prompt, /Completed a spoken greeting/);
  assert.doesNotMatch(prompt, /writing activity/i);
});

test("rejects unknown tutor modes", () => {
  assert.throws(() => tutorSystemPrompt(profile, "admin"), /Invalid tutor mode/);
});
