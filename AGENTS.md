# CodexTUI

- We should create a swift 5 package that uses the TerminalInput and TerminalOuput packages to
build a swift based Terminal User Interface framework.

# Menu, Status and Overlay Features
- An (optional) Menu Bar that takes up one row of the screen (default top)
- Menu Items that can be aligned left or right. A Menu Item should have its first (or activation) character highlighted and be activated by a ctrl or alt key chord, activation displays a Modal Overlay
- An (optional) Status Bar that takes up one row of the screen (default bottom)
- Status Items that can be aligned left or right 
- Modal Overlays, a selection of modal UI elements including
  - Drop Down Menus with lists of selectable items, activated by RETURN, anchored to their summoning Menu Item
  - Selection List, like a submenu but with a tiitle and centered by default
  - Message Box, a pop up message box with a title, message lines and configuarble buttons, buttons are selected with TAB key and activated by RETURN 
  - Text Entry, a single line text entry box with a title,  customisable buttons selected by TAB activated by RETURN
- All modal overlays should be dismissed without action by ESC
- Modal overlays should capture the keys they require to function, no other element should recieve keystrokes when a modal is active 

# Text/Terminal Features
- One or more scrollable text buffers in the area not covered by the menu and status bars that can be used to display text.
- It should be possible to attach these to a terminal or serial port or other ANSI terminal like text IO source via a Protocol.
- If interactive, these should capture keyboard input

# Display Features
- Display should be buttery smooth, only redraw the parts of the screen that are necessary where possible to avoid flicker
- Bounds: all of the elemnts will need to do some bounds computation, try to centralise and parameterise this, not spread it all around the code 
- The user might resize the terminal window, catch SIGWINCH and handle this with a redraw

# Suggested Primitives
- Start with UI primitives like Box, Button, List, Text, etc and compose them into UI elements 

# Architecture
- Build small, composable components that build up to the full framework

# Code styling suggestions
- the user likes enums, sets, option sets and generally terse code that is highly composable to the point of resembling a DSL


# Deliverable 
A Swift 5 package that enables composable Terminal User Interface

# You Must
## Use Swift 5 compatible syntax at all times, do not use async/await
## Read the rules in STYLERULES.md
## Apply the coding style rules in STYLERULES.md
## Stop trying to fit initialisers on a single line, ignore 80 column limit

# Compatibility
## Target platform is macOS version 11
## Linux compatibility is desirable, at a mimimum, code should compile for testing on linux

