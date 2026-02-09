# F7: AI Q&A

## Description

A conversational interface where users can ask questions about their parsed medical data. The AI uses the user's biomarker data as context to provide informed, personalized answers.

## Behavior

1. **Navigation**: A "Ask about your results" button on the dashboard or biomarker view. Route: `/chat` or accessible as a slide-over panel.
2. **Context building**: When a conversation starts, the system assembles context from the user's biomarker data:
   - Latest values for each biomarker
   - Any out-of-range values flagged
   - Trend direction (increasing/decreasing) for frequently tested biomarkers
3. **User message**: The user types a question (e.g., "What does my high LDL cholesterol mean?" or "Are my thyroid levels normal?").
4. **AI call**: The system sends the user's question along with the biomarker context to the language model. The response is streamed back to the UI in real-time via LiveView.
5. **Conversation history**: Previous messages in the conversation are included in the AI context for follow-up questions.
6. **Disclaimer**: Every AI response is followed by a disclaimer: "This is not medical advice. Always consult your healthcare provider."

## Data Model

**conversations**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| user_id | `uuid` | FK → users, NOT NULL, indexed |
| title | `string` | nullable, auto-generated from first message |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**messages**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| conversation_id | `uuid` | FK → conversations, NOT NULL, indexed |
| role | `string` | NOT NULL, values: `user`, `assistant` |
| content | `text` | NOT NULL |
| inserted_at | `utc_datetime` | NOT NULL |

## AI Integration

**Model**: Language model (e.g., `gpt-4o` or `claude-sonnet-4-5-20250929`) — can be a different provider/model than the parsing model.

**System prompt**:
```
You are Meddie, a helpful health assistant. You help users understand their medical test results.

You have access to the user's parsed biomarker data provided below. Use this data to give accurate, relevant answers about their health metrics.

Important guidelines:
- Reference specific values and ranges from the user's data when answering
- Explain medical terms in plain language
- If a value is out of range, explain what it might indicate in general terms
- Always recommend consulting a healthcare provider for medical decisions
- Do not diagnose conditions — explain what results might suggest
- If you don't have enough data to answer a question, say so clearly

User's biomarker data:
{biomarker_context}
```

**Biomarker context format**: A structured text block listing each biomarker with its latest value, unit, reference range, status, and trend (if multiple data points exist).

**Streaming**: Responses are streamed token-by-token via the AI provider's streaming API. Each chunk is pushed to the LiveView socket for real-time display.

## UI Description

- **Chat interface**: A message list with user messages (right-aligned) and assistant messages (left-aligned). An input field with send button at the bottom.
- **Streaming display**: Assistant messages appear character-by-character as tokens stream in.
- **Conversation list**: A sidebar or dropdown listing past conversations by title and date.
- **Disclaimer banner**: A persistent, subtle banner at the top: "Meddie provides informational responses only. This is not medical advice."
- **Quick questions**: Suggested starter questions as clickable chips: "Summarize my latest results", "What should I watch out for?", "Explain my out-of-range values"

## Edge Cases

- **No biomarker data**: If the user has no parsed documents, show: "Upload and parse a medical document first to ask questions about your results."
- **AI API failure**: Show: "Sorry, I couldn't generate a response. Please try again." with a retry option.
- **Very long conversations**: Conversations are truncated to the last 20 messages when building the AI context to stay within token limits. Older messages are still displayed in the UI.
- **Rate limiting**: Users are limited to 50 messages per day to manage API costs. Show remaining count: "45 questions remaining today."
- **Sensitive questions**: The AI should not provide diagnoses or treatment recommendations. The system prompt enforces this, and the disclaimer reminds users.
