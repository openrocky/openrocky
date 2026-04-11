# Skills

Skills extend Rocky's capabilities with reusable, user-importable prompt templates that are dynamically registered as callable tools.

## How Skills Work

1. A skill is defined as a YAML frontmatter block + prompt content
2. At runtime, each enabled skill becomes a `skill-{sanitized-name}` tool
3. The AI model can invoke skills just like native tools
4. Skill prompts are also injected into the system prompt for context

## Skill Structure

```yaml
---
name: My Skill
description: A brief description of what this skill does
triggerConditions: When to activate this skill
---

Your prompt content goes here.
This is the instruction the AI follows when the skill is invoked.
```

### Fields

| Field | Description |
|-------|-------------|
| `name` | Display name of the skill |
| `description` | Brief description shown in UI and to the AI model |
| `triggerConditions` | Hint for when the AI should invoke this skill |
| `promptContent` | The actual prompt/instruction (body after frontmatter) |
| `isEnabled` | Whether the skill is active |
| `sourceURL` | Optional URL if imported from a remote source |

## Built-in Skills

Rocky ships with built-in skills that are seeded on first launch:

| Skill | Description |
|-------|-------------|
| **Translator** | Multi-language translation |
| **Summarizer** | Article and URL summarization |
| **Writing Coach** | Proofreading, rewriting, style improvement |
| **Code Helper** | Code explanation, bug fixes, programming help |
| **Math Solver** | Step-by-step math problem solutions |
| **Travel Planner** | Trip itineraries, weather, recommendations |

## Custom Skills

### Creating a Skill

1. Open **Settings → Skills**
2. Tap **Add Skill**
3. Fill in the name, description, trigger conditions, and prompt content
4. Save — the skill is immediately available

### Importing Skills

Skills can be imported from:

- **Local files** — `.md` or `.txt` files with YAML frontmatter
- **Remote URLs** — fetch and install skills from the web

### Skill File Format

Skills are stored as JSON files in `Application Support/OpenRockySkills/{id}.json`. The markdown serialization format (YAML frontmatter + prompt body) is used for import/export.

## Skill Management

`OpenRockyCustomSkillStore` provides:

- **CRUD operations** — create, read, update, delete skills
- **Enable/disable** — toggle skills without deleting them
- **Import/export** — share skills as markdown files
- **Persistence** — skills survive app restarts

## How Skills Differ from Tools

| | Tools | Skills |
|---|-------|--------|
| **Implementation** | Swift code calling system APIs | Prompt templates |
| **Registration** | Compiled into the app | Dynamic at runtime |
| **User-creatable** | No | Yes |
| **Importable** | No | Yes (files or URLs) |
| **Capabilities** | Direct device access | AI reasoning + existing tools |
