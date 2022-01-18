(* What we need in the markdown generator:
   Special syntaxes:
   - Pandoc's heading attributes
*)

type inlines =
  | String of string
  | ConcatI of inlines * inlines
  | Join of inlines * inlines
      (** [Join] constructor is for joining [inlines] without spaces between them. *)
  | Link of string * inlines
  | Anchor of string
  | Linebreak
  | Noop

and blocks =
  | ConcatB of blocks * blocks
  | Block of inlines
  | CodeBlock of string
  | List of list_type * blocks list
  | Raw_markup of string
  | Block_separator

and list_type = Ordered | Unordered

let ordered_list bs = List (Ordered, bs)

let unordered_list bs = List (Unordered, bs)

let ( ++ ) left right = ConcatI (left, right)

let join left right = Join (left, right)

let blocks above below = ConcatB (above, below)

let block_separator = Block_separator

let text s = String s

let line_break = Linebreak

let noop = Noop

let bold i = Join (String "**", Join (i, String "**"))

let italic i = Join (String "_", Join (i, String "_"))

let subscript i = Join (String "<sub>", Join (i, String "</sub>"))

let superscript i = Join (String "<sup>", Join (i, String "</sup>"))

let code_span s =
  if String.contains s '`' then "`` " ^ s ^ "``" else "`" ^ s ^ "`"

let link ~href i = Link (href, i)

let anchor' i = Anchor i

let raw_markup s = Raw_markup s

let paragraph i = Block i

let code_block s = CodeBlock s

let heading level i =
  let make_hashes n = String.make n '#' in
  let hashes = make_hashes level in
  Block (String hashes ++ i)

let pp_list_item fmt list_type (b : blocks) n pp_blocks =
  match list_type with
  | Unordered -> Format.fprintf fmt "- @[%a@]" pp_blocks b
  | Ordered -> Format.fprintf fmt "%d. @[%a@]" (n + 1) pp_blocks b

let rec pp_inlines fmt i =
  match i with
  | String s -> Format.fprintf fmt "%s" s
  | ConcatI (left, right) ->
      if left = noop then pp_inlines fmt right
      else if right = noop then pp_inlines fmt left
      else Format.fprintf fmt "%a %a" pp_inlines left pp_inlines right
  | Join (left, right) ->
      Format.fprintf fmt "%a%a" pp_inlines left pp_inlines right
  | Link (href, i) -> Format.fprintf fmt "[%a](%s)" pp_inlines i href
  | Anchor s -> Format.fprintf fmt "<a id=\"%s\"></a>" s
  | Linebreak -> Format.fprintf fmt "@\n"
  | Noop -> ()

let rec pp_blocks fmt b =
  match b with
  | ConcatB (above, below) ->
      if above = paragraph noop then pp_blocks fmt below
      else if below = paragraph noop then pp_blocks fmt above
      else Format.fprintf fmt "%a@\n@\n%a" pp_blocks above pp_blocks below
  | Block i -> pp_inlines fmt i
  | CodeBlock s -> Format.fprintf fmt "```@\n%s@\n```" s
  | Block_separator -> Format.fprintf fmt "---"
  | List (list_type, l) ->
      let rec pp_list n l =
        match l with
        | [] -> ()
        | [ x ] -> pp_list_item fmt list_type x n pp_blocks
        | x :: rest ->
            pp_list_item fmt list_type x n pp_blocks;
            Format.fprintf fmt "@\n@\n";
            pp_list (n + 1) rest
      in
      pp_list 0 l
  | Raw_markup s -> Format.fprintf fmt "%s" s
