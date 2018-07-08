open Lwt
open Cohttp
open Cohttp_lwt
open Cohttp_lwt_unix
open Core
open Migration
open Apple_music_playlist_j
open Apple_music_search_j

exception Playlist_creation_failure of exn

type tokens = {
  developer: string;
  music_user: string
}

let request_headers tokens =
  Header.of_list [
    ("Content-Type", "application/json");
    ("Authorization", String.concat ["Bearer "; tokens.developer])
  ]

let user_request_headers tokens =
  Header.of_list [
    ("Content-Type", "application/json");
    ("Authorization", String.concat ["Bearer "; tokens.developer]);
    ("Music-User-Token", tokens.music_user)
  ]

let rec search_catalog_track (tokens: tokens) (track: track) =
  let term = Format.sprintf "%s - %s" track.artist_name track.name in
  let query = [("term", [term]); ("types", ["songs"]); ("limit", ["1"])] in
  let uri = Uri.make ~scheme:"https" ~host:"api.music.apple.com" ~path:"/v1/catalog/it/search" ~query:query ()
  and headers = request_headers tokens in
  let%lwt (response, body) = Client.get ~headers:headers uri in
  match response.status with
    | `Too_many_requests -> 
      let%lwt _ = Lwt_unix.sleep 1.0 in
      search_catalog_track tokens track
    | _ ->
      let%lwt raw_body = Body.to_string body in
      try
        let response = search_response_of_string raw_body in
        let song = response.results.songs 
          |> Option.value_map ~f:(fun (songs) -> songs.data) ~default:[]
          |> List.hd_exn in
        let attributes = Option.value_exn song.attributes in
        let dest = {domain_id=song.id; name=attributes.name; artist_name=attributes.artist_name; url=Some attributes.url} in
        Lwt.return {source=track; destination=Some dest}
      with _ ->
        Lwt.return {source=track; destination=None}

let add_tracks_to_playlist tokens playlist tracks =
  let request_tracks = tracks |> List.map ~f:(fun (track) -> {id=track.domain_id; track_type=`Songs}) in
  let request = string_of_library_playlist_tracks_request {data=request_tracks}
    |> Body.of_string
  and path = Format.sprintf "/v1/me/library/playlists/%s/tracks" playlist in
  let uri = Uri.make ~scheme:"https" ~host:"api.music.apple.com" ~path:path () 
  and headers = user_request_headers tokens in
  let%lwt _ = Client.post ~headers:headers ~body:request uri in
  Lwt.return_unit

let create_new_playlist tokens name =
  let request = {attributes={name=name; description=None}}
    |> string_of_library_playlist_creation_request
    |> Body.of_string
  and uri = Uri.make ~scheme:"https" ~host:"api.music.apple.com" ~path:"/v1/me/library/playlists" () 
  and headers = user_request_headers tokens in
  let%lwt (_, body) = Client.post ~headers:headers ~body:request uri in
  let%lwt raw_body = Body.to_string body in
  try
    let response = library_playlist_response_of_string raw_body in
    let playlist = List.hd_exn response.data in
    Lwt.return playlist.id
  with e ->
    Lwt.fail (Playlist_creation_failure e)
