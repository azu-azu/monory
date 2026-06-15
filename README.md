# Monory

A personal movie-watching record app for iPhone.

Not a review platform. Not a database. Just a quiet archive of films you've seen — when, where, how you felt.

## Features

- Log movies with date, theater, screen, seat, and screening format
- Write personal notes and impressions (not for others to see)
- Attach ticket images (QR codes, booking screenshots)
- Auto-fill movie info via TMDB API
- OCR scan of ticket images to pre-fill theater, seat, and date

## Tech Stack

- Swift 6 / SwiftUI
- SwiftData (local storage, no backend)
- Vision framework (OCR)
- TMDB API (movie info)
- XcodeGen

## Setup

```bash
# Install XcodeGen if needed
brew install xcodegen

# Copy and fill in secrets
cp Secrets.swift.example monory/App/Secrets.swift
# → Add your TMDB API key (https://www.themoviedb.org/settings/api)

# Copy and fill in local settings
cp local.yml.example local.yml
# → Add your DEVELOPMENT_TEAM ID

# Generate Xcode project
xcodegen generate
```

Then open `monory.xcodeproj` in Xcode and run.
