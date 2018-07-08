open Lwt
open Cohttp
open Core
open Migration

exception Invalid_uri of string

let apple_music_tokens = Apple_music.{developer=Sys.getenv_exn "APPLE_MUSIC_DEV_TOKEN"; music_user=Sys.getenv_exn "APPLE_MUSIC_USER_TOKEN"}
let spotify_keys = Spotify.{client_id=Sys.getenv_exn "SPOTIFY_CLIENT_ID"; client_secret=Sys.getenv_exn "SPOTIFY_CLIENT_SECRET"}

let rec print_matches = function
  | [] -> []
  | {source=source; destination=Some destination} :: tracks ->
    let url = destination.url
      |> Option.value ~default:Uri.empty
      |> Uri.to_string in
    let print = Lwt_io.printf "%s - %s\n\t=> \x1B[32m%s - %s\n\t%s\x1B[0m\n" source.artist_name source.name destination.artist_name destination.name url in
    List.cons print (print_matches tracks)
  | {source=source; destination=None} :: tracks ->
    let print = Lwt_io.printf "%s - %s\n\t~> \x1B[31mNo match\x1B[0m\n" source.artist_name source.name in
    List.cons print (print_matches tracks)

let convert_playlist playlist_url =
  let path = Uri.path playlist_url in
  let components = String.split path ~on:'/' in
  match components with
    | [ _; "user"; user; "playlist"; playlist_id ] ->
      let%lwt playlist = Spotify.playlist spotify_keys user playlist_id in
      let%lwt results = Lwt_list.map_p (Apple_music.search_catalog_track apple_music_tokens) playlist.tracks in
      let%lwt playlist = Apple_music.create_new_playlist apple_music_tokens playlist.name in
      let tracks = List.filter_map ~f:(fun(x) -> x.destination) results in
      let%lwt result = Apple_music.add_tracks_to_playlist apple_music_tokens playlist tracks in
      results
        |> print_matches
        |> Lwt.join
    | _ -> 
      Lwt.fail (Invalid_uri path)

let () =
  match Sys.argv with
    | [| _; url |] -> convert_playlist (Uri.of_string url) |> Lwt_main.run |> ignore
    | _ -> failwith "Not enough arguments"
