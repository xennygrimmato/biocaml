(** Lines of a file. *)

type item = Biocaml_line.t

(** Errors.

    - [`premature_end_of_input] - expected more lines than available.
*)
module Error : sig

  type t = [
  | `premature_end_of_input
  ]

end

val of_char_stream : char Stream.t -> item Stream.t
val of_channel : in_channel -> item Stream.t
val to_channel : item Stream.t -> out_channel -> unit

(** Buffer of lines. *)
module Buffer : sig

  type t

  (** The exception thrown by [next_line_exn]. *)
  exception No_next_line

  (** Make a new empty buffer. The optional [filename] is used only
      for error reporting; it should be set to the name of the file,
      if any, from which you will feed the buffer. *)
  val make: ?filename:string -> unit -> t

  (** Feed the parser with a line. *)
  val feed_line: t -> item -> unit

  (** Feed the parser with an arbitrary string buffer. *)
  val feed_string: t -> string -> unit

  (** Get the number of lines ready-to-use in the buffer/queue. *)
  val queued_lines: t -> int

  (** Tell if the parser's buffers are empty or not. For instance,
      when there is no more content to feed and [next_line] returns
      [None], [is_empty p = true] means that the content did not end
      with a complete line. *)
  val is_empty: t -> bool

  (** Get the next line. *)
  val next_line: t -> item option

  (** Get the next line, but throw [No_next_line] if there is no line
      to return. *)
  val next_line_exn: t -> item

  (** Get the current position in the stream. *)
  val current_position: t -> Biocaml_pos.t

  (** Return any remaining lines and the unfinished string, without
      removing them from the buffer. *)
  val contents : t -> item list * string option

  (** Empty the buffer. Subsequent call to [contents] will return
      [(\[\], None)]. *)
  val empty : t -> unit

end

module Transform : sig

  (** Return a transform that converts a stream of arbitrary strings
      to a stream of lines. If the input terminates without a newline,
      the trailing string is still considered a line. *)
  val string_to_item : unit -> (string, item) Biocaml_transform.t

  (** Return a transform that converts a stream of lines to a stream
      of pairs of lines. It is considered an error if input ends with an
      odd number of lines. *)
  val group2 :
    unit ->
    (item,
    (item * item, [> `premature_end_of_input ]) Core.Std.Result.t) Biocaml_transform.t

  val item_to_string: ?buffer:[ `clear of int | `reset of int ] ->
    unit -> (item, string) Biocaml_transform.t

  (** Build a stoppable line-oriented parsing_buffer. *)
  val make : ?name:string -> ?filename:string ->
    next:(Buffer.t ->
      [ `not_ready | `output of ('b, 'errnext) Core.Result.t ]) ->
    on_error:(
      [`next of 'errnext
      | `incomplete_input of Biocaml_pos.t * item list * string option] ->
        'err) ->
    unit ->
    (string, ('b, 'err) Core.Result.t) Biocaml_transform.t

  (** Do like [make] but merge [`incomplete_input _] with the
      errors of [~next] (which must be polymorphic variants). *)
  val make_merge_error :
    ?name:string ->
    ?filename:string ->
    next:(Buffer.t ->
      [ `not_ready
      | `output of ('a,
                   [> `incomplete_input of
                     Biocaml_pos.t * item list * string option ]
                     as 'b) Core.Result.t ]) ->
    unit ->
    (string, ('a, 'b) Core.Result.t) Biocaml_transform.t

end
