# Histórico técnico

Build 12 includes a Stories-only plugin adapted from [yt-dlp PR #17885](https://github.com/yt-dlp/yt-dlp/pull/17885), pinned to `3e089b44ea159f6057d8792ae0abc0e9e33127b9`. This experimental patch prefers embedded page data, then the reels API and a GraphQL fallback. Local adaptations bound profile lookup, preserve the existing API shape and retain photo Stories. It requires a specific browser, disables internal retries for Stories and skips the automatic quality probe when pasting a Story URL. Clicking download starts metadata extraction; successful downloads can still perform a second extraction in the existing download phase. Other websites retain their existing extractor. No live Instagram test is run during builds or fixture tests.

Build 13 separates “Cookies para vídeos” (YouTube, Reels, Instagram posts and other links) from “Cookies para Instagram Stories” (both images and videos, including highlights). On migration, the old specific browser choice is retained for Stories and videos default to “Nenhum”. The last successful Stories browser never becomes a preferred browser for video probes. The offline session check uses the Stories preference.

Release 1.5.3 (build 14) disables detailed diagnostics on its first launch, including the preference inherited from the debug builds. Afterwards it respects deliberate changes to the toggle. The offline cookie check and short error log remain available. Stories retain their extractor fix, disabled automatic quality probe and zero internal retries.

