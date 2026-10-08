# MDReader

A small, fast Markdown reader for macOS.

## Features

- Renders headings, lists, task lists, quotes, code blocks, tables and links
- Outline sidebar that follows your scroll position and jumps to any heading
- Find in document (⌘F, ⌘G / ⇧⌘G)
- Clickable checkboxes (`- [ ]` / `- [x]`) that save back to the file
- Paper and Dark themes, separate body and heading fonts, adjustable size, margins and spacing
- Text zoom with ⌘+ / ⌘- / ⌘0
- Copy button on code blocks
- Quick Look extension: press Space on a `.md` file in Finder
- ⌘N / ⌘T start screen with Open, drag and drop, and recent files

## Requirements

Runs on macOS 13 Ventura or later. Building needs Xcode 27.

## Building

Open `Untitled Project.xcodeproj`, select the `MyApp` scheme and run (⌘R).

## Project layout

| Folder | Contents |
|---|---|
| `MyApp/` | The app: windows, settings, commands |
| `Shared/` | Markdown parsing and the reader view, used by the app and Quick Look |
| `QuickLook/` | The Quick Look preview extension |
