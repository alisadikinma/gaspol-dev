# gaspol-parallel — what a placeholder is, with examples

Moved verbatim from `SKILL.md` (IDS-23). The Anti-Placeholder Checklist and the rule that every implementer dispatch carries it stay in `SKILL.md`.

### What is a Placeholder?

A placeholder is any data that is hardcoded in the component/function when the task specification requires it to come from a real source (API, hook, context, database, props).

### Examples of Placeholders

```typescript
// PLACEHOLDER: Hardcoded array that should come from API
const topics = [
  { id: 1, title: "How to go viral", score: 85 },
  { id: 2, title: "Content strategy", score: 72 },
];

// PLACEHOLDER: Static value that should come from context/hook
const userName = "John Doe";
const isPremium = true;

// PLACEHOLDER: Mock function that should call real API
const handleGenerate = () => {
  console.log("TODO: implement");
  setResult({ success: true }); // fake success
};

// PLACEHOLDER: Component rendering static data instead of props/state
<div className="score">{85}</div>  // should be {score} from props
```

