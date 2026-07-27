> Simplified from: [demo-artist-analytics/README.md](README.md)

## One-Sentence Version

This demo shows how an independent musician can use Snowflake to answer questions about their streams, social media, and income — including whether their fan base is getting more excited as a concert approaches.

## The Story

Imagine you are a musician who just released a single. Your streaming platform shows you a total play count, and your social app shows you a follower count — but neither tells you what you actually want to know: is anything building? Are people in Nashville more excited about your show next month than they were two months ago?

This demo sets up two tools for a fictional artist named Jade Hollow. The first is a visual dashboard — three pages showing streams by platform, social media reach and engagement, and income broken down by source (streaming royalties, merchandise, and licensing deals). Any manager or accountant could look at this and understand where the money is coming from.

The second tool is a conversational AI assistant. You open a chat window and ask plain-English questions: "Which streaming platform is growing fastest?" or "My Nashville show is in two weeks — is fan engagement there building or cooling compared to normal?" The assistant reads the same data and answers in seconds, with a chart if that helps.

The momentum score is the centerpiece. For each upcoming show, the system compares social engagement in the 14 days before the concert against a 30-day baseline from earlier in the year. A score above 100 means fans are more active than usual — the show is building buzz. A score below 100 means activity is flat or dropping — maybe worth running some targeted ads.

## The Cast

| Term | What it means |
|------|--------------|
| **Streamlit dashboard (basic tier)** | A web page with charts and numbers — think Spotify For Artists but built by you, in Snowflake |
| **Snowflake Intelligence / CoWork (pro tier)** | A chat interface where you type questions and get answers, like asking a smart assistant |
| **Cortex Agent** | The AI brain behind Intelligence — it translates your question into a database query and returns the answer |
| **Semantic view** | A translation layer that teaches the AI what "streams," "income," and "momentum score" mean in plain business terms |
| **Momentum score** | A number that compares recent fan engagement to a prior baseline — above 100 is good, below 100 needs attention |
| **GENERATOR** | A Snowflake tool used here to create fake-but-realistic data so the demo works without a real artist's account |

## What Changed

- **Before:** An artist sees total plays on Spotify and follower counts on TikTok — no connection between them, no city-level signal, no income breakdown.
- **After:** Streams, social metrics, and income are in one place, connected to upcoming show dates.
- **Before:** Getting an answer required building a custom dashboard or writing SQL.
- **After:** Type a question in plain English; get an answer with a chart.
- **Before:** No way to know if fan activity in a specific city was building before a show.
- **After:** The momentum score does this automatically for every upcoming tour stop.

## What to Watch Out For

The data in this demo is entirely made up. The numbers look real, but Jade Hollow is fictional. The point is to show the interaction pattern — what happens when a real artist's actual streaming and social data flows through this same setup.

To use this with real data, you would connect your streaming platform exports (Spotify for Artists CSV, Apple Music Analytics, etc.) to the same table structure, and point the social tables at your actual TikTok, Instagram, or YouTube data. The architecture does not change; only the source of the numbers changes.

The momentum score requires data from both the social metrics table and the show schedule. If a show is more than 14 days away, the pre-show window has not started yet — the score will show "Pre-window," which is the correct result, not an error.

## The One Thing to Remember

This demo proves that a musician can ask "Is my Nashville show building momentum?" and get a real answer in seconds — that is the whole point.

---

> For the full technical details, see the source document.
