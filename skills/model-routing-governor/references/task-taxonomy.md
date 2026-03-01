# Task Taxonomy (Routing Labels)

Use these labels as router input. Keep values small and stable.

## Core Labels

- `scene`: `work` | `private`
- `sensitivity`: `normal` | `intimate` | `sensitive_research`
- `task_type`: `coding` | `deep_research` | `writing` | `data_analysis` | `multimedia` | `ops` | `batch_extraction` | `translation` | `planning`
- `modality`: `text` | `image` | `audio` | `video` | `multimodal`
- `complexity`: `low` | `medium` | `high`
- `value`: `normal` | `high`
- `context_size`: `short` | `long` | `huge`
- `language`: `zh` | `en` | `mixed`
- `latency_budget`: `fast` | `balanced` | `quality`
- `cost_budget`: `low` | `balanced` | `high`
- `privacy_requirement`: `normal` | `strict`
- `provider_preference`: `neutral` | `domestic_first` | `global_first`

## Notes

- `sensitive_research` is for research topics that may trigger provider moderation (for example sexual/adult content research). It is distinct from `intimate` (personal/private conversation).
- `value=high` means the task outcome matters enough to justify slower/more expensive models.
- `context_size=huge` should strongly favor long-context models or staged routing.

## Example Label Packs

### Sensitive research (long-form)

```json
{
  "scene": "work",
  "sensitivity": "sensitive_research",
  "task_type": "deep_research",
  "modality": "text",
  "complexity": "high",
  "value": "high",
  "context_size": "long",
  "language": "mixed",
  "provider_preference": "global_first"
}
```

### Domestic-first coding (complex)

```json
{
  "scene": "work",
  "sensitivity": "normal",
  "task_type": "coding",
  "complexity": "high",
  "value": "high",
  "context_size": "long",
  "language": "zh",
  "provider_preference": "domestic_first"
}
```

### Private general chat

```json
{
  "scene": "private",
  "sensitivity": "intimate",
  "task_type": "writing",
  "modality": "text",
  "complexity": "low",
  "value": "normal",
  "context_size": "short",
  "language": "zh",
  "privacy_requirement": "strict"
}
```
