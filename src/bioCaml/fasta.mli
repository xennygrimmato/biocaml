(** Operations on FASTA files. There is no universally agreed upon definition for the FASTA format. This module attempts to support the NCBI definition. See FASTA format definition on NCBI's website, and FASTA format page on wikipedia.org. The most common source of differences is in how the sequence headers are treated. Each header contains a unique name for the sequence, and possibly some additional information. The type of a FASTA file has been made polymorphic in this extra information, allowing for different header conventions to be accomodated. *)

type 'a t
    (** The type of a FASTA file, where each sequence's header information is of type ['a]. *)

exception Bad of string

val of_file : string -> string t
  (** Parse given file. Entire header is treated as the name, and header information taken to be the empty string. Use {!of_file'} to customize header parsing. Raise [Bad] if there are any parse errors. *)
  
val of_file' : (string -> (string * 'a)) -> string -> 'a t
  (** [of_file' parse_header file] parses [file], using [parse_header] to parse a header into the sequence name and any additional header information as specified for the specific FASTA file being parsed. The string passed to [parse_header] will not include the initial ">". Raise [Bad] if there are any parse errors. *)

val fold : (string -> 'a -> Seq.t -> 'b -> 'b) -> 'a t -> 'b -> 'b
  (** [fold f t init] folds over the sequences in [t]. Function [f] is passed the sequence name, the header information, and the sequence. *)

val iter : (string -> 'a -> Seq.t -> unit) -> 'a t -> unit
  
val names : 'a t -> string list
  (** Return names of all sequences in given file. *)

val headers : 'a t -> (string * 'a) list
  (** Return name and header information for all sequences in given file. *)

val get_seq : 'a t -> string -> Seq.t
  (** [get_seq t x] returns the sequence named [x] in [t]. Raise [Failure] if no such sequence. *)

val get_header : 'a t -> string -> 'a
  (** [get_header t x] returns the header for the sequence named [x] in [t]. Raise [Failure] if no such sequence. *)

val get_header_seq : 'a t -> string -> ('a * Seq.t)
  (** [get_header_seq t x] returns the header and sequence for the sequence named [x] in [t]. Raise [Failure] if no such sequence. *)
