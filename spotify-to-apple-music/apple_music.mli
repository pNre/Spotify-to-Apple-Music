type tokens = {
  developer: string;
  music_user: string
}

val create_new_playlist: tokens -> string -> string Lwt.t
val add_tracks_to_playlist: tokens -> string -> Migration.track list -> unit Lwt.t
val search_catalog_track: tokens -> Migration.track -> Migration.tracks_match Lwt.t