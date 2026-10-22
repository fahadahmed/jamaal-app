# Journal drafts

Drafts of the articles on https://jamaal.app/journal, for the Jamaal web app to publish to DatoCMS. Each file is Markdown with a front-matter block; the body is plain Markdown with `##` headings.

| Front-matter field | What it is | On the site |
|---|---|---|
| `title` | The headline. A full stop ends it; the site sets the last words in italic teal | The article and the index card |
| `slug` | The URL: `/journal/<slug>` | The address |
| `kind` | `How-to`, `Guide` or `Story` | The label above the title |
| `publishedMonth` | e.g. `October 2026` | Beside the label |
| `readMinutes` | Whole minutes | "4 min read" |
| `excerpt` | One or two sentences | The index card and the page's opening line |
| `author`, `authorRole` | Fahad Ahmed, Maker of Jamaal | The byline |
| `next` | The slug of the article to show under "Next" | The footer link |
| `status` | `draft` until it is published | Not shown |

**How the body maps.** Each `##` heading is a section. An article with numbered steps (like "Your first Night Planning") uses a heading per step; map them to whatever step component the site already has. Links between articles are written as `/journal/<slug>`.

**Rules for the words.** Everything here describes what the app does today. If a feature changes, change the article. Never promise a date, and never describe something that isn't built. The voice is calm and first-person, short sentences, no exclamation marks and no urgency, like the rest of the journal.
