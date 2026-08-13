# Music

Library type: **Music**. Source: <https://jellyfin.org/docs/general/server/media/music>

Jellyfin identifies tracks from **embedded tags**, not filenames. Filenames matter when tags are missing (they become the title) and when they contain forbidden characters.

## Layout

One folder = one album. Never put two albums in the same folder. How you group albums is free; artist → album is the layout to use unless the user has another scheme.

```text
Music/
  Some Artist/
    Album A/
      01 Song 1.flac
      02 Song 2.flac
      cover.jpg
    Album B (2018)/
      01 Track 1.m4a
      02 Track 2.m4a
    folder.jpg                 # artist image
  Album X/                     # also valid: album at library root
    Whatever You.mp3
```

Recommended target (tags still win):

```text
Music/<Artist>/<Album (year)>/<NN Title>.<ext>
```

Use the tagged artist/album/title/track number when they exist. Only fall back to the filename if tags are empty.

## Forbidden characters

Same set as video: `< > : " / \ | ? *`. Sanitize even if the rest of the name is ignored.

## Discs

Embedded `disc number` / `total discs` is what Jellyfin uses. Keep every disc of an album under **that album folder**.

Optional disc subfolders are allowed; tags still win:

```text
Album 2/
  Disc 1/
    01 Track.aiff
  Disc 2/
    01 Track.aiff
```

Do not split one album into sibling album folders (`Album (Disc 1)` / `Album (Disc 2)`) unless they are actually separate releases.

## Lyrics

Same folder, same basename:

```text
01 Death Eternal.mp3
01 Death Eternal.lrc      # or .elrc / .txt
```

If you rename the audio file, rename the lyric file with it.

## Images

- Album: `cover.jpg` (also `folder`, `poster`, `jacket`, `default`) next to the tracks.
- Artist: `folder.jpg` in the artist folder.
- Optional: `backdrop`, `logo`, `banner`.

If no external image exists, Jellyfin uses the embedded cover of the first track that has one.

## Containers

| Incoming | Do this |
| --- | --- |
| Audio-only `.mp4` | rename to `.m4a` (otherwise it is not music) |
| Audio-only `.mkv` / `.webm` / `.weba` | rename to `.mka` |
| `.flac` / `.mp3` / `.ogg` / `.opus` / `.m4a` / `.aiff` | keep |

Do not remux unless asked. If you must remux to `.mka`:

```sh
ffmpeg -i "$src" -c:a copy "$dest.mka"
```

Warn that tags/art may not survive.

ID3v1 truncates fields at 30 bytes; mention it when you see ancient MP3s, but do not rewrite tags unless asked.

## From a typical download

```text
Artist-Album-WEB-2020-GROUP/01-artist-song_title.mp3
Artist-Album-WEB-2020-GROUP/02-artist-other_song.mp3
```

becomes (if tags already say Artist / Album / titles):

```text
Music/Artist/Album (2020)/
  01 Song Title.mp3
  02 Other Song.mp3
```

If tags are complete and clean, a conservative rename that only:

- puts the album in `Music/<Artist>/<Album>/`
- removes forbidden characters
- fixes `.mp4` → `.m4a`

is enough. Do not churn filenames just to pretty-print them.

## Move checklist

1. Confirm the set is **one album** (same album tag / obvious disc set).
2. Read tags (`ffprobe`, `kid3-cli`, `metaflac`, etc.) before trusting folder names.
3. Create `Music/<Artist>/<Album>/`.
4. Move every track for that album, plus lyrics and `cover.*`.
5. Rename extensions that Jellyfin will not treat as music.
6. Leave compilation albums as one album folder; use the Album Artist tag, not a fake per-track artist folder, unless the user wants a different scheme.
