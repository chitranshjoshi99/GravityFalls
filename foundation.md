Act as a Principal Systems Architect, Game Designer, and expert on the Disney series "Gravity Falls". You are tasked with generating a comprehensive, highly detailed, step-by-step technical architecture and chapter-wise execution blueprint to build a 2D RPG based on the show. 

This game is strictly for personal, non-commercial educational use, so you must maximize fidelity to the show's actual intellectual property, dialogue, and secrets without sanitizing elements for copyright safety.

CRITICAL OPERATIONAL RULES BEFORE STARTING:
1. PHASED RESEARCH: Do not write code or execution steps yet. Your first task is to do a deep-dive research pass into the plot, episode scripts, and character transcripts of Gravity Falls to map out the entire structural narrative arc.
2. INTERACTIVE GAPS: For every single document you are instructed to create, you MUST first pause, present your current understanding, and ask me specific targeted questions to fill execution gaps before generating that document. Do not move to the next document until I approve the current one.

You will generate the technical architecture docs sequentially in the following exact order, observing the interactive rule for each:

---

### DOCUMENT 1: THEME, ANIMATION, & ASSET TOKENS
Create a master design token blueprint that perfectly translates the "CalArts / Modern Rubber-Hose" vector style into code-friendly constants.
- Define specific color palettes using hex codes: include Earthy Northwest Woods (greens/browns), Supernatural Neons (Bill Cipher yellow, portal blues/pinks), and Mystery Shack interiors.
- Define character sprite anchor points, structural tube-limb bone logic, and large touching-circle eye rendering math.
- Detail the exact layout, dimensions, and framing for sprite sheets. 
- *Note:* Explicitly state within this doc where the user needs to supply specific custom character/asset PNGs to hook into this token framework.

### DOCUMENT 2: GAME PHYSICS ENGINE & MECHANICS
Establish the fundamental 2D framework rules for the RPG engine.
- Define collision boxes for "tube-limb" character shapes, movement velocity, and interaction ranges.
- Map out the gameplay mechanics for the Journal (e.g., pulling it up to read invisible ink under UV light, scanning anomalous entities, and unlocking hidden codes).
- Detail how the physics system handles anomalous gravity shifts, time loops, or floating supernatural artifacts native to the town.

### DOCUMENT 3: WORLD MAPS & ENVIRONMENT ARCHITECTURE
Design the physical structure of the Gravity Falls open/semi-open world map.
- Map out the coordinate grids, transitions, and layers for core locations: The Mystery Shack (and its hidden rooms), the Deep Woods, Lake Gravity Falls, the Northwest Mansion, and the Dusk 2 Dawn Convenience Store.
- Define how layers isolate foreground interaction elements from the highly detailed, nostalgic, atmospheric backgrounds.
- Incorporate hidden structural coordinate triggers for ciphers, codes, and easter eggs baked right into the level geography.

### DOCUMENT 4: BACKGROUND UI, HEADS-UP DISPLAY (HUD), & MENUS
Architect the visual interface systems.
- Outline the HUD layout: Health/Stamina (designed to look like summer camp badges or pine trees), active items (like the grappling hook or flashlight), and Journal quick-access.
- Design the main menu, inventory screens, and dialogue boxes. Dialogue boxes must support rich text formatting to accommodate unique character quirks (e.g., erratic text sizes for Bill Cipher, stutter animations for Dipper, and chaotic colors for Mabel).

### DOCUMENT 5: SOUNDTRACKS, AUDIO ENGINES, & SFX TRIGGERS
Create the audio implementation map.
- Map out dynamic background music (BGM) crossfading logic—transitioning from cozy, acoustic, nostalgic summer tunes to eerie, bass-heavy, supernatural synths seamlessly based on player location.
- Specify exact sound effect (SFX) cues for iconic actions: the Journal opening, the golf cart engine running, paranormal whispers, and portal humming.

### DOCUMENT 6 ONWARDS: ONE DOCUMENT PER CHAPTER (STORY IMPLEMENTATION)
Break down the entire plot of the series chronologically into highly actionable gameplay chapters. Each chapter document must include:
- **Narrative & Dialogue Sync:** Direct incorporation of transcripts, keeping Dipper's anxious skepticism, Mabel's chaotic optimism, Stan's grifter cynicism, and Soos's lovable naivety fully intact.
- **Quest Objectives:** Step-by-step logic detailing primary quests, side-mysteries, NPC interaction nodes, and trigger conditions.
- **Boss Mechanics:** Technical breakdown of boss fights (e.g., the Gnomonster, Gobblewonker, Gideon's Robot, Shape Shifter, and ultimately Bill Cipher's Weirdmageddon phases).
- **Hidden Ciphers:** Integration of specific Caesar, Atbash, A1Z26, and Vigenère ciphers matching the sequence of the show.

---

### INITIAL INSTRUCTION TO LAUNCH:
To begin, do not generate Document 1 yet. To make sure you have the perfect baseline for game development, ask me any foundational questions regarding technical preferences I may have missed (e.g., target game engine, resolution, input devices), and present your initial proposed breakdown of how many Chapters you plan to split the story into based on your series research.


### ADDITIONAL ENGINE CONSTRAINTS FOR THE PROJECT:

- Target Game Engine: Godot Engine (Version 4.x)
- Scripting Language: GDScript
- Platform Target: macOS Native (.app) and Web (HTML5/Export for Itch.io)
- Screen Resolution/Aspect Ratio: 16:9 Standard (e.g., 1920x1080 canvas size, scaled beautifully for MacBook displays)
- Control Inputs: Keyboard (WASD/Arrows + E for interaction, J for Journal) and standard Gamepad support.
