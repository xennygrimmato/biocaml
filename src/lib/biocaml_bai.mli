open Core.Std

type t = private ref_seq array
and ref_seq = {
  bins : bin array ;
  intervals : voffset array ;
}
and bin = {
  bin_id : int32 ;
  bin_chunks : chunk array
}
and chunk = {
  chunk_beg : voffset ;
  chunk_end   : voffset
}
and voffset = {
  coffset : int64 ;
  uoffset : int ;
}

val read : in_channel -> t Or_error.t
val of_file : string -> t Or_error.t
