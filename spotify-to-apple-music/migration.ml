type track = {
  domain_id: string;
  name: string;
  artist_name: string;
  url: Uri.t option
}

type tracks_match = {
  source: track;
  destination: track option
}

type playlist = {
  name: string;
  tracks: track list
}