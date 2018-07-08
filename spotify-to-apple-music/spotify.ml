open Lwt
open Cohttp
open Cohttp_lwt
open Cohttp_lwt_unix
open Core
open Migration
open Spotify_j

type keys = {
  client_id: string;
  client_secret: string
}

let access_token_request_headers keys =
  let auth_string = [keys.client_id; keys.client_secret] 
    |> String.concat ~sep:":" 
    |> Base64.Websafe.encode in
  let authorization = ["Basic "; auth_string] 
    |> String.concat in
  Header.of_list [
    ("Content-Type", "application/x-www-form-urlencoded");
    ("Authorization", authorization)
  ]

let request_headers access_token = 
  Header.of_list [
    ("Content-Type", "application/json");
    ("Authorization", String.concat ["Bearer "; access_token])
  ]

let request_access_token keys =
  let uri = Uri.make ~scheme:"https" ~host:"accounts.spotify.com" ~path:"/api/token" () 
  and headers = access_token_request_headers keys
  and body = Body.of_string "grant_type=client_credentials" in
  let%lwt (_, body) = Client.post ~headers:headers ~body:body uri in
  let%lwt raw_body = Body.to_string body in
  try%lwt
    let response = raw_body
      |> access_token_response_of_string in
    Lwt.return response.access_token
  with
    | e -> Lwt.fail e

let map_track track =
  try
    let track = track.track in
    let artist = track.artists
      |> List.hd_exn in
    Some {domain_id=""; name=track.name; artist_name=artist.name; url=None}
  with _ ->
    None

let rec tracks_in_playlist headers uri results =
  match uri with
    | None -> Lwt.return results
    | Some uri -> 
      let%lwt (_, body) = Client.get ~headers:headers uri in
      let%lwt raw_body = Body.to_string body in
      try
        let page = raw_body
          |> playlist_tracks_page_of_string in
        let updated_results = page.items
          |> List.append results in
        let%lwt next_page_results = tracks_in_playlist headers page.next updated_results in
        Lwt.return next_page_results
      with e ->
        Lwt.fail e

let playlist keys user playlist_id =
  let path = Format.sprintf "/v1/users/%s/playlists/%s" user playlist_id in
  let uri = Uri.make ~scheme:"https" ~host:"api.spotify.com" ~path:path () in
  let%lwt token = request_access_token keys in
  let headers = request_headers token in
  let%lwt (_, body) = Client.get ~headers:headers uri in
  let%lwt raw_body = Body.to_string body in
  try
    let playlist = raw_body
      |> playlist_response_of_string in
    let%lwt rest_of_tracks = tracks_in_playlist headers playlist.tracks.next [] in
    let tracks = rest_of_tracks
      |> List.append playlist.tracks.items
      |> List.filter_map ~f:map_track in
    Lwt.return Migration.{name=playlist.name; tracks=tracks}
  with e ->
    Lwt.fail e
