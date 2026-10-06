# STRIDE

> Native iOS running tracker focused on reliable GPS tracking, background execution, and location data processing.

## Overview

STRIDE is a native iOS running tracker built to explore CoreLocation, background location updates, GPS data processing, persistent sessions, and MapKit.

The objective is not to compete with products such as Strava or Nike Run Club.

Instead, STRIDE uses a focused running experience to explore how a real iOS application interacts with location services and the operating system while running in foreground, background, and with the screen locked.

## Goals

The project is designed to demonstrate knowledge of:

- Swift
- SwiftUI
- CoreLocation
- MapKit
- Background location
- GPS filtering
- Geospatial calculations
- SwiftData
- Swift Concurrency
- iOS lifecycle
- Battery-aware architecture
- Persistent application state
- Failure recovery

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Location:** CoreLocation
- **Maps:** MapKit
- **Persistence:** SwiftData
- **Concurrency:** Swift Concurrency
- **Testing:** Swift Testing / XCTest

The project prioritizes native Apple frameworks.

## Core Tracking Pipeline

```text
CoreLocation
      ↓
Location Updates
      ↓
Validation / Filtering
      ↓
Tracking Session
      ↓
Persistence
      ↓
Calculations
      ↓
SwiftUI
```

The user interface should not be the source of truth for an active running session.

Persistent domain state should determine whether a run is currently active.

## MVP

The initial version should support:

- Location permissions
- GPS availability/status
- Start run
- Pause run
- Resume run
- Finish run
- GPS point collection
- Distance calculation
- Duration
- Current pace
- Average pace
- Background tracking
- Route visualization
- Run persistence
- Run history
- Run details

## Data Model

### Run

```text
Run
├── id
├── startedAt
├── finishedAt
├── duration
├── distance
├── averagePace
└── status
```

### LocationPoint

```text
LocationPoint
├── id
├── runId
├── latitude
├── longitude
├── altitude
├── horizontalAccuracy
├── speed
└── timestamp
```

A single run may contain hundreds or thousands of location samples.

## GPS Filtering

Raw GPS data cannot be assumed to be correct.

For example:

```text
Point A
   ↓
Point B — 8m away
   ↓
Point C — 450m away
   ↓
Point D — returns near Point B
```

Point C is probably GPS noise.

The filtering strategy should consider factors such as:

- `horizontalAccuracy`
- Time between samples
- Impossibly large jumps
- Unrealistic speeds
- Duplicate coordinates
- Stale locations

Filtering decisions should be documented and tested.

## Distance Calculation

Distance should be calculated from validated location samples.

Possible strategies include:

- `CLLocation.distance(from:)`
- Geodesic calculations
- Custom filtering before aggregation

The goal is to avoid accumulating significant distance errors due to GPS noise.

## Background Location

Background behavior is a central part of the project.

STRIDE should investigate and correctly configure:

- `CLLocationManager`
- Authorization states
- Background location updates
- `allowsBackgroundLocationUpdates`
- `activityType`
- `desiredAccuracy`
- `distanceFilter`
- iOS background restrictions

The application should respect the iOS execution model rather than trying to artificially keep the process alive.

## Session Recovery

A run should not exist only in memory.

Conceptually:

```text
Start Run
   ↓
Persist Active Session
   ↓
Receive Locations
   ↓
Persist Locations
   ↓
App changes state
   ↓
Restore Active Session
```

When the app starts, it should be able to determine whether a running session was previously active.

## Maps

MapKit will be used to display:

- Current user position
- Recorded route
- Route polyline
- Completed run
- Automatic map framing

## Project Structure

Initial direction:

```text
STRIDE/
├── App/
├── Features/
│   ├── Tracking/
│   ├── History/
│   └── RunDetails/
├── Location/
├── Tracking/
├── Calculations/
├── Persistence/
├── Models/
├── Maps/
└── Tests/
```

## Development Roadmap

### Phase 1 — Product Definition

Define:

- MVP
- Running flow
- Main screens
- User experience

### Phase 2 — Architecture

Define:

- Location architecture
- Session lifecycle
- Persistence boundaries

### Phase 3 — Data Model

Design:

- Runs
- Location points
- Active session state

### Phase 4 — Location Service

Implement:

- Permissions
- CLLocationManager
- Location stream

### Phase 5 — Tracking Session

Implement:

- Start
- Pause
- Resume
- Finish
- Timer

### Phase 6 — Distance Calculation

Implement validated distance calculation.

### Phase 7 — GPS Filtering

Design and test location filtering.

### Phase 8 — Persistence

Persist:

- Active sessions
- Location points
- Completed runs

### Phase 9 — Background Tracking

Implement and test background behavior.

### Phase 10 — MapKit

Implement:

- Route polyline
- Current location
- Completed route

### Phase 11 — Run History

Build history and details screens.

### Phase 12 — Reliability

Test:

- Screen locking
- Backgrounding
- App restart
- Poor GPS
- Permission changes
- Interrupted runs

### Phase 13 — Battery Optimization

Analyze the relationship between:

```text
Accuracy ↔ Update Frequency ↔ Battery Usage
```

### Phase 14 — Testing

Add tests for:

- Distance
- Pace
- GPS filtering
- Session state

### Phase 15 — Documentation

Document:

- Location architecture
- GPS filtering
- Background behavior
- Trade-offs

### Phase 16 — Release

Prepare final demo and release.

## Out of Scope

The initial version will not include:

- Social network
- Followers
- Leaderboards
- Challenges
- Training plans
- Apple Watch
- HealthKit
- Heart-rate sensors
- Strava integration
- AI coaching
- Backend services

## Project Philosophy

STRIDE is not primarily a fitness product.

It is a mobile systems project built around:

> Reliable native location tracking, background execution, GPS processing, persistence, and lifecycle management.

## Status

🚧 **In development**

Current stage:

**Phase 1 — Product Definition**
