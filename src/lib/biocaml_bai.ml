open Core.Std
open Biocaml_internal_utils

open Or_error

type t = ref_seq array
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

let array_init_with_results =
  let module M = struct exception E of Error.t end in
  fun n ~f ->
    let f x = match f x with
      | Ok y -> y
      | Error e -> raise (M.E e)
    in
    try Ok (Array.init n ~f)
    with M.E e -> Error e

let read_bin ic = assert false
  

let read_ref_seq ic =
    check_opt (input_s32 ic |> Int32.to_int) "Number of bins too large in BAI" >>= fun n_bins ->
    (* this is a limitation of the parser due to OCaml's representation of ints on 32 bit systems *)
    check (n_bins >= 0) "Got negative n_bins in BAI" >>= fun () ->
    array_init_with_results n_bins ~f:(fun _ -> read_bin ic)

let read ic =
  try
    let magic = input_string ic 4 in
    check (magic = "BAI\001") "Incorrect magic string, not a BAI file?" >>= fun () ->
    check_opt (input_s32 ic |> Int32.to_int) "Number of refseqs in BAI too large" >>= fun n_ref ->
    check (n_ref >= 0) "Got negative n_ref in BAI" >>= fun () ->
    array_init_with_results n_ref ~f:(fun _ -> read_ref_seq ic) >>= fun r ->
    Ok r
  with End_of_file -> error_string "Unexpected EOF, file corrupted?"

let of_file _ = assert false
