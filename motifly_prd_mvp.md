# Product Requirements Document  
## motifly MVP

### 1. Product Overview

**Product Name:** motifly  
**Platform:** iPhone app  
**Stack:** Swift, SwiftUI, SwiftData  

**Purpose:**  
motifly helps users improve French listening and spelling through simple sentence-based dictation practice. The MVP focuses on lightweight daily practice, memory reinforcement, and clear progress tracking without adding unnecessary complexity.

---

### 2. Goal

Build a minimal French dictation app that allows users to:

- listen to a French sentence
- type what they hear
- check the correct answer
- review weak sentences later
- track simple memory performance over time

The app should feel calm, focused, and easy to use in short daily sessions.

---

### 3. Target Users

**Primary users:**
- French learners at beginner to intermediate level
- users who want to improve dictation, spelling, and listening
- users who prefer sentence-level practice over full lessons

---

### 4. MVP Scope

### In Scope

- sentence-based dictation practice
- audio playback for each sentence
- optional image attached to each sentence for memory support
- text input for user dictation answer
- answer checking against the correct sentence
- simple grammar tag labeling
- simple review log per sentence
- simple retrieval score based on past performance
- user can add their own sentence and optionally record their own audio

### Out of Scope for MVP

- advanced AI correction
- deep grammar explanations
- social features
- multiplayer or classroom mode
- spaced repetition with complex algorithms
- offline speech recognition
- full course curriculum
- multiple languages
- teacher dashboards
- pronunciation scoring

---

### 5. Core Product Principles

- keep practice fast and lightweight
- focus on one sentence at a time
- reduce cognitive overload
- make review easy
- prioritize memory reinforcement over too many features

---

### 6. User Problems

Users often struggle to:

- improve French listening with short focused exercises
- remember sentence patterns over time
- connect sound spelling and grammar together
- organize practice material by grammar topic
- revisit weak sentences efficiently

motifly solves this by turning dictation into a simple repeatable habit.

---

### 7. Key User Stories

- As a learner, I want to hear one French sentence and type it out so I can practice listening and spelling.
- As a learner, I want to see an image with the sentence so I can remember it more easily.
- As a learner, I want to compare my answer with the correct sentence so I can learn from mistakes.
- As a learner, I want to tag a sentence with a grammar topic so I can review by pattern.
- As a learner, I want weak sentences to be easier to revisit so I can improve over time.
- As a learner, I want to add my own sentences and audio so I can practice personalized content.

---

### 8. MVP Features

## 8.1 Sentence Dictation Practice

**Description:**  
Users see one sentence card at a time, play audio, and type what they hear.

**Requirements:**
- show one sentence per practice screen
- play sentence audio
- provide text field for answer input
- submit answer manually
- reveal correct answer after submission

**Success condition:**  
User can complete one dictation attempt in under 1 minute.

---

## 8.2 Image Support for Contextual Memory

**Description:**  
Each sentence may optionally include an image to support memory and context.

**Requirements:**
- sentence card can display one image
- image is optional, not required
- image appears above or near the sentence area

**Reason for MVP:**  
Adds memory support without increasing workflow complexity.

---

## 8.3 Audio Playback

**Description:**  
Users can listen to the correct French pronunciation for each sentence.

**Requirements:**
- each sentence has playable audio
- app supports API-provided audio URL or stored local audio file
- user can replay audio multiple times

**MVP simplification:**  
No advanced speed control required for first version.

---

## 8.4 User-Created Sentences and Audio

**Description:**  
Users can create their own sentence cards.

**Requirements:**
- create a sentence
- optionally attach an image
- optionally add a grammar tag
- optionally record audio using device microphone
- save locally with SwiftData

**MVP simplification:**  
No sharing or cloud sync in MVP.

---

## 8.5 Basic Answer Checking

**Description:**  
After user submits an answer, app compares it with the correct sentence.

**Requirements:**
- show correct sentence
- show user answer
- indicate whether answer is correct or not
- store result as correct or incorrect

**MVP simplification:**  
No complex partial grading at first.  
Optional basic metric:
- exact correct
- incorrect

---

## 8.6 Grammar Tag System

**Description:**  
Each sentence can have one or more grammar tags for grouping.

**Examples:**
- passé composé
- imparfait
- articles
- subjunctive
- negation

**Requirements:**
- sentence can store tags
- user can filter review list by tag

**MVP simplification:**  
Tags are manual labels only. No grammar detection needed.

---

## 8.7 Retrieval Score

**Description:**  
Each sentence has a simple score showing how well the user remembers it.

**Purpose:**  
Help surface weak sentences for later review.

**Simple MVP logic example:**
- start at 0
- +1 when correct
- -1 when incorrect
- minimum 0
- higher score means stronger memory

**Requirements:**
- each sentence stores retrieval score
- score updates after each attempt
- review page can sort low-score sentences first

**MVP simplification:**  
Do not build a complicated spaced repetition algorithm yet.

---

## 8.8 Progress and Review Logs

**Description:**  
Users can see basic history for each sentence.

**Requirements:**
- store last attempted date
- store total attempts
- store total correct count
- show retrieval score
- show sentence history summary on detail page

**MVP simplification:**  
No charts required in first version.

---

### 9. Primary Screens

## 9.1 Home
Shows:
- start practice
- review weak sentences
- browse sentence library
- add sentence

## 9.2 Practice Screen
Shows:
- optional image
- audio play button
- text input area
- submit button
- reveal correct answer after submit

## 9.3 Result Screen
Shows:
- user answer
- correct sentence
- correct / incorrect result
- updated retrieval score
- next sentence button

## 9.4 Sentence Library
Shows:
- list of saved sentences
- grammar tags
- retrieval score
- filter by tag

## 9.5 Add Sentence Screen
Allows user to:
- enter sentence text
- assign grammar tags
- add image
- record audio
- save sentence

## 9.6 Sentence Detail / Review Screen
Shows:
- sentence text
- image
- audio
- retrieval score
- attempt count
- correct count
- last reviewed date

---

### 10. Data Model

## Sentence
- id
- frenchText
- imagePath optional
- audioPathOrURL optional
- createdByUser
- createdAt
- updatedAt

## GrammarTag
- id
- name

## SentenceTagRelation
- sentenceId
- tagId

## AttemptLog
- id
- sentenceId
- userAnswer
- isCorrect
- attemptedAt

## SentenceProgress
- sentenceId
- retrievalScore
- totalAttempts
- totalCorrect
- lastAttemptedAt

For MVP, SentenceProgress can also be stored directly on Sentence if you want fewer models.

---

### 11. Core User Flow

**Practice flow**
1. user taps Start Practice
2. app shows one sentence card
3. user plays audio
4. user types answer
5. user submits
6. app shows correct answer and correctness
7. app updates retrieval score and progress
8. user moves to next sentence

**Creation flow**
1. user taps Add Sentence
2. enters sentence text
3. optionally adds image
4. optionally records audio
5. optionally adds tags
6. saves sentence

**Review flow**
1. user opens Review Weak Sentences
2. app sorts by lowest retrieval score
3. user practices weak items first

---

### 12. Functional Requirements

## Practice
- user can play sentence audio
- user can input typed answer
- user can submit answer
- system stores the result

## Content
- user can browse saved sentences
- user can add a sentence manually
- user can attach one image to a sentence
- user can record one audio file for a sentence

## Organization
- user can add grammar tags to a sentence
- user can filter sentence list by grammar tag

## Progress
- system tracks attempts per sentence
- system tracks correct count per sentence
- system tracks last reviewed date
- system updates retrieval score after each attempt

---

### 13. Non-Functional Requirements

- app should feel simple and responsive
- core actions should take no more than a few taps
- data should persist locally using SwiftData
- UI should be clean and distraction-free
- app should work without account creation
- app should support future expansion later

---

### 14. Success Metrics for MVP

- user can complete first dictation within 2 minutes of opening app
- user can add a custom sentence in under 1 minute
- at least 80 percent of key flows work without confusion:
  - start practice
  - submit answer
  - review sentence
  - add sentence
- users return to review weak sentences multiple times per week

---

### 15. Risks and Simplifications

## Risks
- answer checking can become too complex if partial matching is added too early
- audio generation API may add cost and implementation complexity
- too many stats may distract from the main experience

## Simplifications
- use exact-match correctness for MVP
- keep retrieval score logic simple
- skip AI feedback in first version
- skip cloud sync
- skip advanced grammar analysis

---

### 16. Future Expansion After MVP

Not part of MVP, but good next steps:
- partial error highlighting
- AI explanation of mistakes
- spaced repetition scheduling
- pronunciation comparison
- curated sentence packs
- daily goals and streaks
- cloud sync across devices
- smarter grammar analytics

---

### 17. MVP Summary

**motifly MVP** is a lightweight French dictation app centered on:

- one sentence at a time
- audio-based listening practice
- simple typed dictation
- optional image memory support
- basic progress tracking
- weak sentence review
- manual grammar grouping
- custom sentence creation

The MVP should stay narrow, calm, and useful rather than feature-heavy.
