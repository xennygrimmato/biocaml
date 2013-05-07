open Biocaml_internal_pervasives
open Result
module Line = Biocaml_line
module Pos = Biocaml_pos

type item = Line.t with sexp

module Error = struct

  type t = [
  | `premature_end_of_input
  ] with sexp

end

module Buffer = struct

  type t = {
    mutable unfinished_line : string option;
    lines : item Queue.t;
    mutable parsed_lines : int;
    filename : string option;
  }

  let make ?filename () =
    {unfinished_line = None;
     lines = Queue.create ();
     parsed_lines = 0;
     filename}

  let feed_line p s =
    Queue.enqueue p.lines s

  let feed_string p s =
    let lines = String.split s ~on:'\n' in
    let rec faux = function
      | [] -> assert false
      | [ "" ] -> (* last char was a "\n" *) ()
      | [ s ] -> (* there is a partial line at the end *)
        p.unfinished_line <- Some s;
      | h :: t ->
        Queue.enqueue p.lines (Line.of_string_unsafe h);
        faux t
    in
    match p.unfinished_line, lines with
    | _, [] -> assert false
    | _, [""] -> ()
    | None, l -> faux l
    | Some s, h :: t ->
      p.unfinished_line <- None;
      faux ((s ^ h) :: t)

  let queued_lines p = Queue.length p.lines

  let peek_line p = Queue.peek p.lines

  let next_line p =
    let l = Queue.dequeue p.lines in
    if l <> None then (
      p.parsed_lines <- p.parsed_lines + 1;
    );
    l

  exception No_next_line

  let next_line_exn p =
    match next_line p with
    | Some s -> s
    | None -> raise No_next_line

  let current_position p =
    Pos.make ?file:p.filename ~line:p.parsed_lines ()

  let is_empty p =
    Queue.is_empty p.lines && p.unfinished_line = None

  let contents p = Queue.to_list p.lines, p.unfinished_line

  let empty p = (Queue.clear p.lines; p.unfinished_line <- None)

end

module Transform = struct

  let string_to_item () =
    let buf = Buffer.make () in
    Biocaml_transform.make ~name:"string_to_lines"
      ~feed:(Buffer.feed_string buf)
      ~next:(function
        | true -> (match Buffer.next_line buf with
            | Some line -> `output line
            | None -> (match Buffer.contents buf with
                | [], None -> `end_of_stream
                | [], Some unfinished_line ->
                    (Buffer.empty buf; `output (Line.of_string_unsafe unfinished_line))
                | _ -> assert false
              )
          )
        | false -> (match Buffer.next_line buf with
            | None -> `not_ready
            | Some line -> `output line
          )
      )
      ()

  let item_to_string ?(buffer:[`clear of int | `reset of int]= `reset 1024) () =
    let module Buffer = Core.Caml.Buffer in
    let buffer, clear_buffer =
      match buffer with
      | `clear s -> (Buffer.create s, Buffer.clear)
      | `reset s -> (Buffer.create s, Buffer.reset) in
    Biocaml_transform.make ~name:"lines_to_string" ()
      ~feed:(fun l ->
        Buffer.add_string buffer (l : Biocaml_line.t :> string);
        Buffer.add_char buffer '\n')
      ~next:(fun stopped ->
        match Buffer.contents buffer with
        | "" -> if stopped then `end_of_stream else `not_ready
        | s ->
          clear_buffer buffer;
          `output s)

  let group2 () =
    let queue : (item * item) Queue.t= Queue.create () in
    let item1 = ref None in
    Biocaml_transform.make ~name:"group2"
      ~feed:(function item -> match !item1 with
        | Some item1' -> (
            Queue.enqueue queue (item1', item);
            item1 := None
          )
        | None -> item1 := Some item
      )
      ~next:(fun stopped -> match Queue.dequeue queue with
        | Some ij -> output_ok ij
        | None ->
          if not stopped then
            `not_ready
          else
            (match !item1 with
             | None -> `end_of_stream
             | Some _ -> output_error `premature_end_of_input
            )
      )
      ()

  let make ?name ?filename ~next ~on_error () =
    let lo_parser = Buffer.make ?filename () in
    Biocaml_transform.make ?name ()
      ~feed:(Buffer.feed_string lo_parser)
      ~next:(fun stopped ->
        match next lo_parser with
        | `output (Ok r) -> `output (Ok r)
        | `output (Error r) -> `output (Error (on_error (`next r)))
        | `not_ready ->
          if stopped then (
            if Buffer.is_empty lo_parser then
              `end_of_stream
            else
              let l,o = Buffer.contents lo_parser in
              `output
                (Error (on_error
                          (`incomplete_input
                             (Buffer.current_position lo_parser,
                              (l :> string list), o))))
          ) else
            `not_ready)

  let make_merge_error =
    make
      ~on_error:(function
        | `next e -> e
        | `incomplete_input e -> `incomplete_input e)

end

let of_char_stream cstr =
  let module Buffer = Biocaml_internal_pervasives.Buffer in
  let f _ = match Stream.peek cstr with
    | None -> None
    | Some _ ->
      let ans = Buffer.create 100 in
      let rec loop () =
        try
          let c = Stream.next_exn cstr in
          if c <> '\n' then (Buffer.add_char ans c; loop())
        with Core.Std.Caml.Stream.Failure -> ()
      in
      loop();
      Some (Buffer.contents ans |! Line.of_string_unsafe)
  in
  Stream.from f

let of_channel cin =
  let f _ =
    try Some (input_line cin |! Line.of_string_unsafe)
    with End_of_file -> None
  in Stream.from f

let to_channel xs oc =
  Stream.iter xs ~f:(fun l ->
    output_string oc (l : item :> string); output_char oc '\n'
  )
