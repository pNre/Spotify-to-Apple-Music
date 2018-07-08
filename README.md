# Spotify → Apple Music 
## Playlist converter

Toy project to try out Apple Music API.

### Requirements

#### Credentials

- Spotify Web API `client id` and `client secret`
- Apple Music API `developer token`
- Apple Music API `music user token`

#### Dependencies

```
opam install jbuilder cohttp cohttp-lwt-unix lwt yojson tls core core_extended atdgen
```

### Usage

```
export SPOTIFY_CLIENT_ID="client id"
export SPOTIFY_CLIENT_SECRET="client secret"
export APPLE_MUSIC_DEV_TOKEN="dev token"
export APPLE_MUSIC_USER_TOKEN="music user token"
```

```
spotify-to-apple-music [Spotify playlist URL]
```
