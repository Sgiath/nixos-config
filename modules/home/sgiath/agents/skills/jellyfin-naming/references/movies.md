# Movies

Library type: **Movies**. Source: <https://jellyfin.org/docs/general/server/media/movies>

## Layout

Every movie gets its own folder. The video basename equals the folder name.

```text
Movies/
  Best Movie Ever (2019)/
    Best Movie Ever (2019).mkv
    Best Movie Ever (2019).en.srt
    Best Movie Ever (2019).nfo
    cover.png
    theme.mp3
  Movie (2021) [imdbid-tt12801262]/
    Movie (2021) [imdbid-tt12801262].mkv
    backdrop.jpg
```

```text
Movie Name (year) [metadata provider id]
```

Year and IDs are optional but make matching reliable. Use the provider title, not the release-group name.

Valid examples:

- `Jellyfin Documentary.mkv` inside `Jellyfin Documentary/`
- `Jellyfin Documentary (2030).mkv`
- `Jellyfin Documentary [imdbid-tt00000000].mkv`
- `Jellyfin Documentary (2030) [imdbid-tt00000000].mkv`

Disc folders live *inside* the movie folder:

```text
Movie (2021) [imdbid-tt12801262]/
  VIDEO_TS/          # or BDMV/
```

`VIDEO_TS` / `BDMV` cannot have multiple versions, multiple parts, or external subtitle/audio tracks.

## From a typical download

```text
The.Matrix.1999.1080p.BluRay.x264-GROUP/the.matrix.1999.mkv
The.Matrix.1999.1080p.BluRay.x264-GROUP/the.matrix.1999.en.srt
```

becomes

```text
Movies/The Matrix (1999) [tmdbid-603]/
  The Matrix (1999) [tmdbid-603].mkv
  The Matrix (1999) [tmdbid-603].en.srt
```

Strip resolution, codec, source, and group tags from the **title**. Those belong in a version label only when you are keeping several encodes of the same film.

## Multiple versions

Same movie, several encodes or cuts: every file must start with the **exact** folder name, then ` - `, then a label.

```text
Movie (2021) [imdbid-tt12801262]/
  Movie (2021) [imdbid-tt12801262] - 2160p.mp4
  Movie (2021) [imdbid-tt12801262] - 1080p.mp4
  Movie (2021) [imdbid-tt12801262] - Directors Cut.mp4
```

Rules:

- Prefix must match the folder character-for-character, including year and IDs.
- Separator is space-hyphen-space. Periods/commas as the separator are not supported.
- Labels are freeform. Brackets are optional: ` - [1080P]`.
- No label → Jellyfin treats each file as a different movie.
- Resolution labels (ending in `p` or `i`) sort high-to-low; other labels sort A–Z. First in that list is the default.

Do not combine versions with stacked parts (`-cd1`).

## 3D and parts

See [shared.md](shared.md). 3D can be a version label (`… - 3D_FTAB.mp4`) if the text before ` - ` still matches the folder.

## Extras and images

Put extras in typed subfolders (`trailers/`, `behind the scenes/`, `featurettes/`, …) or use the suffixes in [shared.md](shared.md#extras). Theme song: `theme.ext` or `theme-music/`.

Prefer `cover.jpg` / `poster.jpg` / `folder.jpg` in the movie folder.

## Move checklist

1. Resolve title + year + TMDB/IMDB id.
2. Sanitize (`:` → ` - `, drop `? * "`, …).
3. Create `Movies/<Name (year) [id]>/`.
4. `mv` the video to `<folder>/<folder>.ext` (or `<folder>/<folder> - Label.ext`).
5. Rename/move every sidecar to the new basename.
6. Leave `VIDEO_TS`/`BDMV` as a directory, not as loose VOBs at the movie root.
