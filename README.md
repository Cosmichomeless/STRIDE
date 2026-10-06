# STRIDE

## Project Overview

STRIDE is a mobile running tracker focused on reliable location tracking, including while the application is running in the background or while the device screen is locked.

The objective is not to compete with Strava or Nike Run Club.

The objective is to build a technically robust GPS tracking application and understand how mobile operating systems manage:

- Location.
- Background tasks.
- Permissions.
- Battery usage.
- Application lifecycle.

---

# Main Goal

The user should be able to:

1. Start a run.
2. Put the phone in their pocket.
3. Lock the screen.
4. Continue running.
5. Stop the run.
6. See the recorded route and statistics.

---

# Main Features

During a run display:

- Distance.
- Duration.
- Current pace.
- Average pace.
- GPS status.
- Route.

Example:

DISTANCE
6.42 KM

PACE
5'12" / KM

TIME
33:24

---

# Technology Stack

## Mobile

- React Native
- Expo
- TypeScript

## Location

- expo-location

## Background Processing

- expo-task-manager

## Maps

- MapLibre React Native

## State

- Zustand

## Local Database

- SQLite

## Styling

- NativeWind

---

# Technical Objectives

This project should teach and demonstrate:

- GPS permissions.
- Foreground location tracking.
- Background location tracking.
- Background tasks.
- Mobile operating system restrictions.
- Battery-aware design.
- Location accuracy.
- GPS noise filtering.
- Route storage.
- Map rendering.
- Distance calculation.
- Pace calculation.
- Session persistence.
- Crash recovery.

---

# Core Tracking Flow

START RUN

    ↓

Create RunSession

    ↓

Start GPS tracking

    ↓

Receive LocationPoint

    ↓

Validate point

    ↓

Store locally

    ↓

Calculate distance

    ↓

Calculate pace

    ↓

Update UI

When backgrounded:

GPS
    ↓
Background Task
    ↓
SQLite

The UI does not need to remain active for tracking to continue.

---

# Data Model

## Run

Run {
    id
    startedAt
    finishedAt
    distance
    duration
    averagePace
    status
}

## LocationPoint

LocationPoint {
    id
    runId
    latitude
    longitude
    altitude
    accuracy
    speed
    timestamp
}

A run may contain hundreds or thousands of location points.

---

# Distance Calculation

Distance should be calculated using GPS coordinates.

Possible algorithms:

- Haversine formula.
- Geodesic distance library.

The implementation should not blindly accept every GPS point.

Bad GPS samples should be filtered based on:

- Accuracy.
- Unrealistic speed.
- Impossible jumps.
- Timestamp difference.

---

# Background Tracking

This is one of the most important parts of the project.

The application should continue collecting location points when:

- The screen turns off.
- The user switches applications.
- The app moves to the background.

Platform limitations must be documented.

Android and iOS may behave differently.

---

# Run Recovery

The application must handle this scenario:

User starts run

    ↓

App enters background

    ↓

Operating system terminates UI process

    ↓

User reopens application

The app should detect that an active run exists and restore the session.

The database, not UI state, should be the source of truth.

---

# Map

During the run:

- Display current location.
- Display route polyline.

After the run:

- Display complete route.
- Fit map to route.
- Display statistics.

---

# Functional Requirements

## Start Run

The user can:

- Start tracking.
- See GPS status.
- See timer.
- See route.

## During Run

Display:

- Distance.
- Time.
- Pace.
- Route.

Controls:

- Pause.
- Resume.
- Finish.

Optional:

- Lap / split.

## Run History

Display previous runs with:

- Date.
- Distance.
- Duration.
- Average pace.

---

# Architecture

Suggested structure:

src/

features/
    tracking/
    history/
    run-details/

services/
    location/
    tracking/
    calculations/

database/
    runs/
    locationPoints/

tasks/
    backgroundLocationTask.ts

store/

components/

utils/

---

# MVP

The MVP should contain:

- Location permissions.
- Start run.
- GPS tracking.
- Background tracking.
- Distance calculation.
- Timer.
- Route rendering.
- Stop run.
- Save run.
- Run history.

---

# Features Outside Initial MVP

Do NOT implement initially:

- Social network.
- Followers.
- Challenges.
- Leaderboards.
- Training plans.
- Smartwatch integration.
- Heart-rate sensors.
- Strava integration.
- AI coaching.

The focus is reliable tracking.

---

# Important Engineering Challenges

## 1. GPS Noise

GPS data is imperfect.

Example:

Point A
    ↓
Point B 10m away
    ↓
Point C suddenly 400m away
    ↓
Point D returns

The system should detect invalid jumps.

---

## 2. Background Execution

Tracking must continue without requiring the UI to remain open.

---

## 3. Battery Consumption

Location frequency must balance:

ACCURACY

vs

BATTERY

---

## 4. Session Recovery

An active run should survive application restarts whenever possible.

---

# Development Phases

## Phase 1 — Product Definition

Define:

- Run flow.
- Tracking screen.
- History.
- Run details.

## Phase 2 — Location Engine

Implement:

- Permissions.
- GPS updates.
- Location model.

## Phase 3 — Tracking Engine

Implement:

- Sessions.
- Distance.
- Pace.
- Timer.

## Phase 4 — Background Tracking

Implement:

- Task manager.
- Persistent tracking.

## Phase 5 — Database

Persist:

- Runs.
- GPS points.

## Phase 6 — Maps

Implement:

- Route.
- Polyline.
- Run details.

## Phase 7 — Reliability

Test:

- Screen lock.
- Background.
- App restart.
- Poor GPS.
- Permission changes.

## Phase 8 — Documentation

Document:

- Tracking architecture.
- GPS filtering.
- Background execution.
- Battery decisions.

---

# Portfolio Value

STRIDE should demonstrate knowledge of:

- Geolocation.
- Background execution.
- Mobile OS behavior.
- GPS algorithms.
- Persistent state.
- Map rendering.
- Battery-aware architecture.
- Fault tolerance.

The project should be presented as a mobile systems engineering project rather than simply a fitness application.
